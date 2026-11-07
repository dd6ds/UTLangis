//! Backend thread: owns the tokio runtime and the presage manager, runs the
//! registration steps and keeps the receive loop going once registered.

use std::cell::RefCell;
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::rc::Rc;
use std::str::FromStr;

use presage::libsignal_service::configuration::SignalServers;
use presage::libsignal_service::prelude::phonenumber::PhoneNumber;
use presage::libsignal_service::protocol::ServiceId;
use presage::manager::{Confirmation, RegistrationOptions};
use presage::model::identity::OnNewIdentity;
use presage::proto::receipt_message::Type as ReceiptType;
use presage::{Error, Manager};
use presage_store_sqlite::SqliteStore;
use tokio::sync::mpsc::{unbounded_channel, UnboundedReceiver, UnboundedSender};
use tokio::task::{JoinHandle, LocalSet};

use crate::commands::{self, Command};
use crate::events::{EventSink, State};
use crate::linking::{self, LinkResult};
use crate::calls::Calls;
use crate::receipts::Receipts;
use crate::receiver;
use crate::threads::ThreadIndex;
use crate::titles::SignalManager;

/// What the command handlers and the receive loop share. Everything runs on
/// the backend thread, so plain RefCell is enough.
pub struct Shared {
    pub sink: EventSink,
    pub index: RefCell<ThreadIndex>,
    pub receipts: RefCell<Receipts>,
    /// Ringing calls and the calls of the chats (calls.rs).
    pub calls: RefCell<Calls>,
    /// Received messages per thread not yet seen by the user: (sender, sent
    /// timestamp), for read receipts once the chat is opened.
    pub unread: RefCell<HashMap<String, Vec<(ServiceId, u64)>>>,
    pub attachments_dir: PathBuf,
}

enum Phase {
    Unregistered,
    AwaitingCode(Manager<SqliteStore, Confirmation>),
    Registered(SignalManager),
}

struct Worker {
    shared: Rc<Shared>,
    database: String,
    phase: Phase,
    receiving: Option<JoinHandle<()>>,
    /// Linking as an additional device, while it waits for the QR scan.
    linking: Option<JoinHandle<()>>,
    link_done: UnboundedSender<LinkResult>,
}

pub fn run(data_dir: PathBuf, sink: EventSink, mut commands: UnboundedReceiver<String>) {
    init_logging();
    let runtime = match tokio::runtime::Builder::new_current_thread().enable_all().build() {
        Ok(runtime) => runtime,
        Err(error) => return sink.error("start", error),
    };
    // presage's futures are not Send, hence a LocalSet on one thread.
    LocalSet::new().block_on(&runtime, async move {
        let Some(mut worker) = Worker::open(&data_dir, sink).await else {
            return;
        };
        let (link_done, mut link_results) = unbounded_channel();
        worker.link_done = link_done;
        loop {
            tokio::select! {
                text = commands.recv() => {
                    let Some(text) = text else { break };
                    match serde_json::from_str::<Command>(&text) {
                        Ok(command) => worker.handle(command).await,
                        Err(error) => worker.shared.sink.error("command", error),
                    }
                }
                Some(result) = link_results.recv() => worker.finish_link(result).await,
            }
        }
        worker.stop_receiving();
        worker.stop_linking();
    });
}

/// Logs go to stderr, which lands in the app's journal on Ubuntu Touch.
/// RUST_LOG overrides the default level.
fn init_logging() {
    let filter = tracing_subscriber::EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("warn,utlangis_core=info"));
    let _ = tracing_subscriber::fmt().with_env_filter(filter).with_ansi(false).try_init();
}

pub async fn open_store(database: &str) -> Result<SqliteStore, String> {
    SqliteStore::open_with_passphrase(database, None, OnNewIdentity::Trust)
        .await
        .map_err(|e| e.to_string())
}

impl Worker {
    async fn open(data_dir: &Path, sink: EventSink) -> Option<Worker> {
        let attachments_dir = data_dir.join("attachments");
        if let Err(error) = std::fs::create_dir_all(&attachments_dir) {
            sink.error("start", error);
            return None;
        }
        let database = data_dir.join("signal.db3").to_string_lossy().into_owned();
        let store = match open_store(&database).await {
            Ok(store) => store,
            Err(error) => {
                sink.error("start", error);
                return None;
            }
        };
        let shared = Rc::new(Shared {
            sink,
            index: RefCell::new(ThreadIndex::load(data_dir)),
            receipts: RefCell::new(Receipts::load(data_dir)),
            calls: RefCell::new(Calls::load(data_dir)),
            unread: RefCell::new(HashMap::new()),
            attachments_dir,
        });
        let mut worker = Worker {
            shared,
            database,
            phase: Phase::Unregistered,
            receiving: None,
            linking: None,
            // Replaced by run() before the first command.
            link_done: unbounded_channel().0,
        };
        match Manager::load_registered(store).await {
            Ok(manager) => worker.enter_registered(manager),
            Err(Error::NotYetRegisteredError) => worker.shared.sink.state(State::Unregistered, ""),
            Err(error) => {
                worker.shared.sink.error("start", error);
                worker.shared.sink.state(State::Unregistered, "");
            }
        }
        Some(worker)
    }

    async fn handle(&mut self, command: Command) {
        match command {
            Command::Register { phone, captcha, voice } => {
                self.register(&phone, &captcha, voice).await
            }
            Command::Confirm { code } => self.confirm(&code).await,
            Command::Link { device_name } => self.start_linking(device_name),
            Command::CancelLink => {
                self.stop_linking();
                self.shared.sink.state(State::Unregistered, "");
            }
            Command::Threads => self.shared.sink.emit(threads_event(&self.shared)),
            Command::MarkRead { thread, read_receipts } => {
                self.shared.index.borrow_mut().mark_read(&thread);
                self.shared.sink.emit(threads_event(&self.shared));
                let seen = self.shared.unread.borrow_mut().remove(&thread).unwrap_or_default();
                if let (Phase::Registered(manager), true) = (&mut self.phase, read_receipts) {
                    commands::send_receipts(manager, seen, ReceiptType::Read).await;
                }
            }
            Command::Reconnect => {
                if let Phase::Registered(manager) = &self.phase {
                    let manager = manager.clone();
                    self.start_receiving(manager);
                }
            }
            command => match &mut self.phase {
                Phase::Registered(manager) => commands::run(manager, &self.shared, command).await,
                _ => self.shared.sink.error("command", "not registered"),
            },
        }
    }

    async fn register(&mut self, phone: &str, captcha: &str, voice: bool) {
        let sink = &self.shared.sink;
        let phone_number = match PhoneNumber::from_str(phone.trim()) {
            Ok(number) => number,
            Err(error) => return sink.error_kind("register", "phoneNumber", error),
        };
        let store = match open_store(&self.database).await {
            Ok(store) => store,
            Err(error) => return sink.error("register", error),
        };
        let options = RegistrationOptions {
            signal_servers: SignalServers::Production,
            phone_number,
            use_voice_call: voice,
            captcha: Some(captcha.trim()),
            // Only reached while unregistered: a leftover half-finished
            // registration may be overwritten.
            force: true,
        };
        match Manager::register(store, options).await {
            Ok(confirmation) => {
                self.phase = Phase::AwaitingCode(confirmation);
                sink.state(State::AwaitingCode, phone);
            }
            Err(error) => sink.error_kind("register", registration_error_kind(&error), error),
        }
    }

    async fn confirm(&mut self, code: &str) {
        let phase = std::mem::replace(&mut self.phase, Phase::Unregistered);
        let Phase::AwaitingCode(confirmation) = phase else {
            self.phase = phase;
            return self.shared.sink.error("confirm", "no verification code was requested");
        };
        // A failed confirmation consumes the session; the user has to request
        // a new code, which the registration page offers.
        let code: String = code.chars().filter(char::is_ascii_digit).collect();
        match confirmation.confirm_verification_code(code).await {
            Ok(manager) => self.enter_registered(manager),
            Err(error) => {
                self.shared.sink.error_kind("confirm", registration_error_kind(&error), error);
                self.shared.sink.state(State::Unregistered, "");
            }
        }
    }

    fn start_linking(&mut self, device_name: String) {
        if matches!(self.phase, Phase::Registered(_)) {
            return self.shared.sink.error("link", "already registered");
        }
        self.stop_linking();
        self.phase = Phase::Unregistered;
        self.shared.sink.state(State::Linking, "");
        self.linking = Some(linking::start(
            self.database.clone(),
            device_name,
            Rc::clone(&self.shared),
            self.link_done.clone(),
        ));
    }

    fn stop_linking(&mut self) {
        if let Some(task) = self.linking.take() {
            task.abort();
            let _ = std::fs::remove_file(linking::qr_path(&self.shared));
        }
    }

    async fn finish_link(&mut self, result: LinkResult) {
        self.linking = None;
        match result {
            Ok(mut manager) => {
                // A new device starts without contacts; the primary device
                // sends them (and their names) on request.
                if let Err(error) = manager.request_contacts().await {
                    tracing::info!(%error, "contact sync not requested");
                }
                self.enter_registered(manager);
            }
            Err(error) => {
                self.shared.sink.error("link", error);
                self.shared.sink.state(State::Unregistered, "");
            }
        }
    }

    fn enter_registered(&mut self, manager: SignalManager) {
        let phone = manager.registration_data().phone_number.to_string();
        // Device 1 is the primary device; linked devices have higher ids.
        let linked = u32::from(manager.device_id()) != 1;
        self.shared.sink.emit(serde_json::json!({ "ev": "account", "linked": linked }));
        self.shared.sink.state(State::Offline, &phone);
        self.start_receiving(manager.clone());
        self.phase = Phase::Registered(manager);
        self.shared.sink.emit(threads_event(&self.shared));
    }

    fn start_receiving(&mut self, manager: SignalManager) {
        self.stop_receiving();
        let shared = Rc::clone(&self.shared);
        self.receiving = Some(tokio::task::spawn_local(receiver::receive_loop(manager, shared)));
    }

    fn stop_receiving(&mut self) {
        if let Some(task) = self.receiving.take() {
            task.abort();
        }
    }
}

pub fn threads_event(shared: &Shared) -> serde_json::Value {
    serde_json::json!({ "ev": "threads", "threads": shared.index.borrow().to_json() })
}

fn registration_error_kind<E: std::error::Error>(error: &Error<E>) -> &'static str {
    match error {
        Error::CaptchaRequired => "captchaRequired",
        Error::PushChallengeRequired | Error::RequestingCodeForbidden(_) => "codeForbidden",
        Error::UnverifiedRegistrationSession => "wrongCode",
        Error::PhoneNumberError(_) => "phoneNumber",
        _ => "other",
    }
}

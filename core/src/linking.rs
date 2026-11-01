//! Linking UT Langis as an additional device of an existing Signal account
//! (like Signal Desktop): Signal hands out a provisioning address, the app
//! shows it as a QR code ("linkQr" event), and the user scans it with the
//! Signal app on their phone under Settings -> Linked devices.

use std::rc::Rc;

use futures::channel::oneshot;
use presage::libsignal_service::configuration::SignalServers;
use presage::Manager;
use tokio::sync::mpsc::UnboundedSender;
use tokio::task::JoinHandle;

use crate::qr;
use crate::titles::SignalManager;
use crate::worker::{open_store, Shared};

pub type LinkResult = Result<SignalManager, String>;

/// Starts linking in the background; the outcome arrives on `done`.
pub fn start(
    database: String,
    device_name: String,
    shared: Rc<Shared>,
    done: UnboundedSender<LinkResult>,
) -> JoinHandle<()> {
    tokio::task::spawn_local(async move {
        let result = link(&database, device_name, &shared).await;
        let _ = done.send(result);
    })
}

async fn link(database: &str, device_name: String, shared: &Shared) -> LinkResult {
    let store = open_store(database).await?;
    let (address_tx, address_rx) = oneshot::channel();
    let (manager, shown) = futures::join!(
        Manager::link_secondary_device(store, SignalServers::Production, device_name, address_tx),
        async {
            let address = address_rx.await.map_err(|_| "no linking address".to_owned())?;
            let path = qr_path(shared);
            qr::write_pgm(address.as_str(), &path)?;
            shared.sink.emit(serde_json::json!({
                "ev": "linkQr",
                "path": path.to_string_lossy(),
            }));
            Ok::<(), String>(())
        }
    );
    let _ = std::fs::remove_file(qr_path(shared));
    shown?;
    manager.map_err(|e| e.to_string())
}

/// Next to the database; removed once linking ended.
pub fn qr_path(shared: &Shared) -> std::path::PathBuf {
    shared.attachments_dir.with_file_name("link-qr.pgm")
}

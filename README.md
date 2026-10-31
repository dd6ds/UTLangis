# ubSignal

A native Signal messenger for Ubuntu Touch. ubSignal registers the phone as
the **primary device** of your phone number, like the Signal apps for Android
and iOS do — no other phone and no pairing (QR-code linking) is needed.

The Signal protocol work is done by [presage](https://github.com/whisperfish/presage)
(Rust, on top of Signal's own `libsignal`). The user interface is Qt 5.12 /
QML, like the other ubTouch apps.

## Features

- Registration as primary device with captcha and SMS or voice-call code
- Profile name
- One-to-one and group chats: receive, send text and photos
- New chats by phone number or picked from the address book (after asking
  for permission once; Signal contact discovery is only asked about the
  chosen number)
- Conversation list with unread counts, notifications while the app runs
- Light/dark appearance, English and German

Not (yet) included: calls, stories, reactions and replies (only their text
is shown where they carry one), registration lock PIN, linking other devices
(Signal Desktop) to ubSignal.

## Important before registering

- **Your number moves to this phone.** Registering signs Signal out on any
  other phone that uses the same number. Your old chat history is not
  transferred.
- **Registration lock:** if your Signal account has a PIN with registration
  lock, turn the lock off in the old app first (Settings → Account →
  Registration lock). ubSignal cannot answer the PIN challenge.
- Signal tolerates third-party clients but does not support them; server
  changes can break ubSignal until presage is updated.

## Registering

1. Enter your number in international format (`+49…`) and tap *Continue*.
2. Solve the captcha. When it is solved, the page tries to open a
   `signalcaptcha://` link, which ubSignal catches. If the captcha does not
   work in the app, solve it in a browser at
   <https://signalcaptchas.org/registration/generate.html>, copy the
   *Open Signal* link and paste it into the field below the captcha.
3. Enter the 6-digit code from the SMS or call.
4. Set the name people see.

## Building

Requirements: [Clickable](https://clickable-ut.dev) 8.7 or later and Docker.

```bash
clickable build      # build the click package (arm64)
clickable install    # install it on the phone over adb
clickable logs       # follow the app's log
```

The first build takes a while: clickable adds a Rust toolchain, CMake 3.31
and a current `protoc` to its container image (see `clickable.yaml`), and
cargo then compiles libsignal and BoringSSL for arm64. Later builds only
recompile what changed. Cargo's downloads and output live in `build/`.

`core/` can also be built on the development machine for a quick check:

```bash
cd core && cargo build
```

## Layout

```
core/                 Rust backend (static library with a C interface)
  include/ubsignal_core.h   the C interface the app links against
  src/lib.rs          C functions, command and event format
  src/worker.rs       backend thread, registration, receive loop start
  src/receiver.rs     receive loop and incoming messages
  src/commands.rs     send, history, contact lookup, profile
  src/convert.rs      Signal contents -> message rows
  src/threads.rs      conversation list (threads.json)
  src/titles.rs       contact and group names
  src/files.rs        attachments on the phone
src/                  C++: SignalClient (bridge), list models, notifications
qml/                  pages and components
i18n/                 translations
```

## Data on the phone

Everything lives in `~/.local/share/ubsignal/`: `signal.db3` (keys, sessions,
messages; SQLite), `threads.json` (conversation list) and `attachments/`.
The app's AppArmor confinement keeps other apps out of it. Deleting the
folder (or uninstalling) removes the account from this phone; the number then
has to be registered again.

## Translations

All user-visible texts are marked with `qsTr()` (QML) or `tr()` (C++).
After changing texts, refresh the `.ts` file with `lupdate` from the
Clickable container and fill in the German texts:

```bash
docker run --rm -u $(id -u):$(id -g) -v "$PWD":/p -w /p \
  clickable/amd64-20.04-arm64:latest /usr/lib/qt5/bin/lupdate -no-obsolete \
  -locations relative src/*.cpp qml/*.qml \
  -ts i18n/ubsignal_de.ts
python3 i18n/translate_de.py   # fills German; lists any text still missing
```

## Platform constraints

- **Build against Qt 5.12** (`ubuntu-sdk-20.04`): `import QtQuick 2.12` at
  most, `Connections { onSignal: … }`.
- **Lomiri suspends background apps.** The message connection dies while the
  app is suspended; ubSignal reopens it when it comes back to the foreground
  and then receives everything that arrived meanwhile. Notifications in the
  background only work if suspension is turned off for ubSignal (e.g. with
  UT Tweak Tool). Signal has no push service for Ubuntu Touch.
- **Permissions** (`ubsignal.apparmor`): `networking` for Signal's servers,
  `webview` for the captcha page, `content_exchange` to pick photos from
  other apps, `push-notification-client` for notifications, `contacts` for
  the contact picker. The app reads the address book only after the user
  allowed it in its own dialog (or in Settings). `contacts` is a reserved
  policy group: sideloading works, the OpenStore would review it manually.
- **`QT_QUICK_CONTROLS_STYLE=Default` is set in `main.cpp`**, and pages use
  `AppLabel` / `AppField` so both light and dark theme stay readable.

## License

AGPL-3.0, as presage and libsignal, see `LICENSE`.

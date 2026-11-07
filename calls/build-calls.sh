#!/bin/bash
# Builds libutlangis_calls.so (calls/) for arm64 on Signal's RingRTC.
#
#   calls/build-calls.sh <work dir> <output dir>
#
# Fetches the RingRTC sources (tag below) and Signal's prebuilt WebRTC for
# linux-arm64 into the work dir (once), builds this crate as a member of
# RingRTC's workspace (so RingRTC's Cargo.lock applies) and copies the
# library to the output dir. Runs in the Clickable build image.
set -euo pipefail

RINGRTC_TAG=v2.73.0
WEBRTC_VERSION=8037a
WEBRTC_SHA256=d180cb7597ae5eb2d4bf182372156d27be982d8deee67d321a0937219481235e

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mkdir -p "$1" && cd "$1" && pwd)"
OUT="$(mkdir -p "$2" && cd "$2" && pwd)"
RINGRTC="$WORK/ringrtc"

if [[ ! -d "$RINGRTC/.git" ]]; then
    git clone --quiet --depth 1 --branch "$RINGRTC_TAG" https://github.com/signalapp/ringrtc "$RINGRTC"
fi
if [[ ! -f "$RINGRTC/out/release/obj/libwebrtc.a" ]]; then
    archive="$WORK/webrtc-$WEBRTC_VERSION-linux-arm64-release.tar.bz2"
    curl -sSfL -o "$archive" \
        "https://build-artifacts.signal.org/libraries/webrtc-$WEBRTC_VERSION-linux-arm64-release.tar.bz2"
    echo "$WEBRTC_SHA256  $archive" | sha256sum -c --quiet
    mkdir -p "$RINGRTC/out"
    tar -xjf "$archive" -C "$RINGRTC/out"
    rm -f "$archive"
fi

# Our crate inside the RingRTC workspace.
mkdir -p "$RINGRTC/utlangis-calls"
cp -r "$HERE/Cargo.toml" "$HERE/src" "$RINGRTC/utlangis-calls/"
grep -q '"utlangis-calls"' "$RINGRTC/Cargo.toml" \
    || sed -i 's|^members = \[|members = [\n  "utlangis-calls",|' "$RINGRTC/Cargo.toml"

cd "$RINGRTC"
export RUSTUP_TOOLCHAIN=stable
export OUTPUT_DIR="$RINGRTC/out"
export PROTOC="$(command -v protoc)"
export CC_aarch64_unknown_linux_gnu=aarch64-linux-gnu-gcc
export CXX_aarch64_unknown_linux_gnu=aarch64-linux-gnu-g++
export AR_aarch64_unknown_linux_gnu=aarch64-linux-gnu-ar
export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc
export PKG_CONFIG_ALLOW_CROSS=1
export PKG_CONFIG_PATH=/usr/lib/aarch64-linux-gnu/pkgconfig
cargo build --release --target aarch64-unknown-linux-gnu -p utlangis-calls
cp target/aarch64-unknown-linux-gnu/release/libutlangis_calls.so "$OUT/"
aarch64-linux-gnu-strip --strip-debug "$OUT/libutlangis_calls.so"

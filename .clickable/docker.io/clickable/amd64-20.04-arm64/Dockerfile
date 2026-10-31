FROM docker.io/clickable/amd64-20.04-arm64
LABEL base_image_hash="sha256:8e0f2fa7bd1f74a770452c80f20c4fef908dbf94cd074791b1cb25f49347b3bb"
ARG GOPATH="/home/developer/.clickable/go"
ARG SDK_FRAMEWORK="ubuntu-sdk-20.04"
ARG CLICK_FRAMEWORK="ubuntu-sdk-20.04"
ARG CLICK_FRAMEWORK_BASE="20.04"
ARG APPARMOR_POLICY="20.04"
ARG QT_VERSION="5.12"
ARG ARCH="arm64"
ARG ARCH_TRIPLET="aarch64-linux-gnu"
ARG ARCH_RUST="aarch64-unknown-linux-gnu"
ARG NUM_PROCS="8"
ARG ROOT="/home/developer/ubtouch/ubSignal"
ARG BUILD_DIR="/home/developer/ubtouch/ubSignal/build/aarch64-linux-gnu/app"
ARG SRC_DIR="/home/developer/ubtouch/ubSignal"
ARG INSTALL_DIR="/home/developer/ubtouch/ubSignal/build/aarch64-linux-gnu/app/install"
ARG CLICK_LD_LIBRARY_PATH="/home/developer/ubtouch/ubSignal/build/aarch64-linux-gnu/app/install/lib/aarch64-linux-gnu"
ARG CLICK_PATH="/home/developer/ubtouch/ubSignal/build/aarch64-linux-gnu/app/install/lib/aarch64-linux-gnu/bin"
ARG CLICK_QML2_IMPORT_PATH="/home/developer/ubtouch/ubSignal/build/aarch64-linux-gnu/app/install/lib/aarch64-linux-gnu"
ENV RUSTUP_HOME="/opt/rust/rustup" CARGO_HOME="/opt/rust/cargo" PATH="/opt/rust/cargo/bin:/opt/cmake/bin:/opt/protoc/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
RUN echo set debconf/frontend Noninteractive | debconf-communicate && echo set debconf/priority critical | debconf-communicate
RUN apt-get update && apt-get install -y --force-yes --no-install-recommends qtdeclarative5-dev:arm64 qtwebengine5-dev:arm64 && apt-get clean
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates unzip clang libclang-dev
RUN mkdir -p /opt/cmake && curl -sSfL https://github.com/Kitware/CMake/releases/download/v3.31.6/cmake-3.31.6-linux-x86_64.tar.gz | tar xz -C /opt/cmake --strip-components=1
RUN curl -sSfL -o /tmp/protoc.zip https://github.com/protocolbuffers/protobuf/releases/download/v29.3/protoc-29.3-linux-x86_64.zip && unzip -q /tmp/protoc.zip -d /opt/protoc && rm /tmp/protoc.zip
RUN curl -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable --no-modify-path && rustup target add aarch64-unknown-linux-gnu && chmod -R a+rwX /opt/rust /opt/protoc
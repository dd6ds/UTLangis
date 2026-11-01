cmake_minimum_required(VERSION 3.16)
project(utlangis C CXX)

# clickable's container has CMake 3.31 (see clickable.yaml); it may
# normalise install() paths (they are plain here) without warning.
if(POLICY CMP0177)
    cmake_policy(SET CMP0177 NEW)
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_INCLUDE_CURRENT_DIR ON)

# DBus: notifications through Lomiri's Postal service (src/notifier.cpp).
# WebEngine: the registration captcha (qml/CaptchaPage.qml).
find_package(Qt5 COMPONENTS Core Gui Qml Quick DBus WebEngine REQUIRED)

# GStreamer: recording and playing voice messages (src/voicenotes.cpp).
find_package(PkgConfig REQUIRED)
pkg_check_modules(GSTREAMER REQUIRED IMPORTED_TARGET gstreamer-1.0)

# ---------------------------------------------------------------------------
# Rust backend (core/): built by cargo as a static library for the target the
# C++ compiler builds for. clickable's container provides the toolchain, see
# clickable.yaml. Cargo keeps its downloads and output in the build tree so
# repeated builds only recompile what changed.
# ---------------------------------------------------------------------------
if(CMAKE_CXX_COMPILER MATCHES "aarch64")
    set(RUST_TARGET aarch64-unknown-linux-gnu)
    # clickable exports CC/CXX/CFLAGS for the phone. Crates that are also
    # built for the build machine (sqlx's macros compile SQLite) must get the
    # native compiler instead, so both are named per target.
    set(RUST_TARGET_ENV
        CC_aarch64_unknown_linux_gnu=aarch64-linux-gnu-gcc
        CXX_aarch64_unknown_linux_gnu=aarch64-linux-gnu-g++
        AR_aarch64_unknown_linux_gnu=aarch64-linux-gnu-ar
        CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc
        CC_x86_64_unknown_linux_gnu=gcc
        CXX_x86_64_unknown_linux_gnu=g++
        AR_x86_64_unknown_linux_gnu=ar
        CFLAGS_x86_64_unknown_linux_gnu=-O2
        CXXFLAGS_x86_64_unknown_linux_gnu=-O2)
    set(RUST_TARGET_ARGS --target ${RUST_TARGET})
    set(RUST_OUT_DIR ${CMAKE_BINARY_DIR}/cargo-target/${RUST_TARGET}/release)
else()
    # Desktop build for testing on the development machine.
    set(RUST_TARGET_ENV "")
    set(RUST_TARGET_ARGS "")
    set(RUST_OUT_DIR ${CMAKE_BINARY_DIR}/cargo-target/release)
endif()

set(RUST_CORE_LIB ${RUST_OUT_DIR}/libutlangis_core.a)
file(GLOB RUST_CORE_SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/core/src/*.rs)

set(CARGO_ENV
    CARGO_HOME=${CMAKE_BINARY_DIR}/cargo-home
    CARGO_TARGET_DIR=${CMAKE_BINARY_DIR}/cargo-target
    ${RUST_TARGET_ENV})

# Fetch first, so core/fix-sqlcipher-c-char.cmake can correct a fetched
# crate before it is compiled. MAKEFLAGS/MFLAGS are dropped because cargo cannot use
# make's jobserver from inside a custom command.
add_custom_command(
    OUTPUT ${RUST_CORE_LIB}
    COMMAND ${CMAKE_COMMAND} -E env --unset=MAKEFLAGS --unset=MFLAGS ${CARGO_ENV}
            cargo fetch --locked
    COMMAND ${CMAKE_COMMAND} -DCARGO_HOME=${CMAKE_BINARY_DIR}/cargo-home
            -P ${CMAKE_CURRENT_SOURCE_DIR}/core/fix-sqlcipher-c-char.cmake
    COMMAND ${CMAKE_COMMAND} -E env --unset=MAKEFLAGS --unset=MFLAGS ${CARGO_ENV}
            cargo build --release --locked ${RUST_TARGET_ARGS}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/core
    DEPENDS ${RUST_CORE_SOURCES}
            ${CMAKE_CURRENT_SOURCE_DIR}/core/Cargo.toml
            ${CMAKE_CURRENT_SOURCE_DIR}/core/Cargo.lock
            ${CMAKE_CURRENT_SOURCE_DIR}/core/fix-sqlcipher-c-char.cmake
    COMMENT "Building the Rust Signal backend"
    USES_TERMINAL)
add_custom_target(utlangis_core DEPENDS ${RUST_CORE_LIB})

# ---------------------------------------------------------------------------
# Translations: i18n/utlangis_<lang>.ts -> .qm, embedded as :/i18n/*.qm.
# ---------------------------------------------------------------------------
find_package(Qt5LinguistTools REQUIRED)
file(GLOB UTLANGIS_TS_FILES ${CMAKE_CURRENT_SOURCE_DIR}/i18n/utlangis_*.ts)
qt5_add_translation(UTLANGIS_QM_FILES ${UTLANGIS_TS_FILES})
set(UTLANGIS_I18N_QRC ${CMAKE_CURRENT_BINARY_DIR}/i18n.qrc)
set(_i18n_entries "")
foreach(_qm ${UTLANGIS_QM_FILES})
    get_filename_component(_qm_name ${_qm} NAME)
    string(APPEND _i18n_entries "    <file alias=\"i18n/${_qm_name}\">${_qm}</file>\n")
endforeach()
file(WRITE ${UTLANGIS_I18N_QRC}
     "<RCC>\n  <qresource prefix=\"/\">\n${_i18n_entries}  </qresource>\n</RCC>\n")
add_custom_target(utlangis_translations DEPENDS ${UTLANGIS_QM_FILES})

add_executable(utlangis
    src/languagemanager.cpp
    src/languagemanager.h
    src/main.cpp
    src/messagelistmodel.cpp
    src/messagelistmodel.h
    src/notifier.cpp
    src/notifier.h
    src/signalclient.cpp
    src/signalclient.h
    src/systemtheme.cpp
    src/systemtheme.h
    src/threadlistmodel.cpp
    src/threadlistmodel.h
    src/voicenotes.cpp
    src/voicenotes.h
    qml.qrc
    ${UTLANGIS_I18N_QRC})
add_dependencies(utlangis utlangis_translations utlangis_core)

target_include_directories(utlangis PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    ${CMAKE_CURRENT_SOURCE_DIR}/core/include)

# The Rust static library needs pthread, dl and libm from the system, and
# libstdc++ for the C++ parts of BoringSSL (already linked for Qt).
target_link_libraries(utlangis
    Qt5::Core Qt5::Gui Qt5::Qml Qt5::Quick Qt5::DBus Qt5::WebEngine PkgConfig::GSTREAMER
    ${RUST_CORE_LIB} pthread dl m)

install(TARGETS utlangis RUNTIME DESTINATION ${CMAKE_INSTALL_PREFIX})
install(FILES manifest.json DESTINATION ${CMAKE_INSTALL_PREFIX})
install(FILES utlangis.desktop DESTINATION ${CMAKE_INSTALL_PREFIX})
install(FILES utlangis.apparmor DESTINATION ${CMAKE_INSTALL_PREFIX})
install(FILES utlangis.png DESTINATION ${CMAKE_INSTALL_PREFIX})

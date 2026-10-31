# Run by CMakeLists.txt (cmake -P) after cargo has fetched the sources.
#
# The SQLCipher crypto glue in presage's rusqlite fork declares C strings as
# `*const i8`. C's `char` is unsigned on arm64, so Rust's c_char is u8 there
# and the crate does not compile for the phone. This replaces the three
# return types with the portable `core::ffi::c_char` (the crate is no_std);
# on x86_64 nothing changes. Running it again finds nothing to replace.
#
# Input: CARGO_HOME, the directory cargo fetched into.

file(GLOB GLUE_FILES
     "${CARGO_HOME}/git/checkouts/rusqlite-*/*/libsqlite3-sys/src/sqlcipher_custom_crypto.rs")
if(NOT GLUE_FILES)
    message(FATAL_ERROR "sqlcipher_custom_crypto.rs not found below ${CARGO_HOME}")
endif()

foreach(glue ${GLUE_FILES})
    file(READ "${glue}" source)
    string(REPLACE ") -> *const i8 {" ") -> *const core::ffi::c_char {" fixed "${source}")
    if(NOT fixed STREQUAL source)
        file(WRITE "${glue}" "${fixed}")
        message(STATUS "Made ${glue} portable to arm64")
    endif()
endforeach()

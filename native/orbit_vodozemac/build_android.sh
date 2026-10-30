#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT/native/orbit_vodozemac"
command -v cargo >/dev/null || { echo "Rust/cargo required"; exit 2; }
command -v cargo-ndk >/dev/null || { echo "Install cargo-ndk: cargo install cargo-ndk --locked"; exit 2; }
if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
  SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
  if [[ -d "$SDK/ndk" ]]; then
    ANDROID_NDK_HOME="$(find "$SDK/ndk" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -1)"
    export ANDROID_NDK_HOME
  fi
fi
[[ -d "${ANDROID_NDK_HOME:-}" ]] || {
  echo "Set ANDROID_NDK_HOME to your Android SDK NDK directory"; exit 2;
}
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
cargo test --locked
cargo ndk -t arm64-v8a -t armeabi-v7a -t x86_64 \
  -o "$ROOT/android/app/src/main/jniLibs" build --release --locked
echo "Audited-core bridge artifacts prepared. Production E2EE remains review-gated."

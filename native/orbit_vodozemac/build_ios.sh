#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT/native/orbit_vodozemac"
[[ "$(uname)" == "Darwin" ]] || { echo "iOS builds require macOS"; exit 2; }
command -v cargo >/dev/null || { echo "Install Rust/cargo first"; exit 2; }
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
cargo test --locked
for target in aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios; do
  cargo build --target "$target" --release --locked
done
OUT="$ROOT/ios/Runner/NativeCrypto"
mkdir -p "$OUT"
cp target/aarch64-apple-ios/release/liborbit_vodozemac.a \
  "$OUT/liborbit_vodozemac_device.a"
lipo -create \
  target/aarch64-apple-ios-sim/release/liborbit_vodozemac.a \
  target/x86_64-apple-ios/release/liborbit_vodozemac.a \
  -output "$OUT/liborbit_vodozemac_sim.a"
cat > "$ROOT/ios/Flutter/OrbitVodozemac.xcconfig" <<'CFG'
OTHER_LDFLAGS[sdk=iphoneos*] = $(inherited) -Wl,-force_load,$(PROJECT_DIR)/Runner/NativeCrypto/liborbit_vodozemac_device.a
OTHER_LDFLAGS[sdk=iphonesimulator*] = $(inherited) -Wl,-force_load,$(PROJECT_DIR)/Runner/NativeCrypto/liborbit_vodozemac_sim.a
CFG
echo "Built iOS static core. Check symbols and sign your normal iOS app bundle."
echo "Orbit's E2EE release gate remains OFF until reviewed client release."

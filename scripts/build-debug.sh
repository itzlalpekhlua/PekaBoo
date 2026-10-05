#!/usr/bin/env bash
# Build a development-signed Android APK using the server's toolchain.
set -euo pipefail
cd "$(dirname "$0")/.."
TOOLS=${PEKABOO_TOOLS:-$HOME/gamedev-tools}
export JAVA_HOME="$TOOLS/jdk"
export PATH="$JAVA_HOME/bin:$PATH"
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$HOME/.android/debug.keystore"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android
mkdir -p build "$HOME/.android"
if [ ! -f "$GODOT_ANDROID_KEYSTORE_DEBUG_PATH" ]; then
  keytool -genkeypair -keystore "$GODOT_ANDROID_KEYSTORE_DEBUG_PATH" \
    -storepass android -keypass android -alias androiddebugkey \
    -dname 'CN=Android Debug,O=Android,C=US' -keyalg RSA -keysize 2048 -validity 10000
fi
"$TOOLS/godot" --headless --editor --path game --import > build/import-debug.log 2>&1
"$TOOLS/godot" --headless --path game --export-debug Android ../build/PekaBoo-debug.apk > build/export-debug.log 2>&1
"$TOOLS/android-sdk/build-tools/34.0.0/apksigner" verify --print-certs build/PekaBoo-debug.apk
sha256sum build/PekaBoo-debug.apk

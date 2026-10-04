#!/usr/bin/env bash
# Rebuilds build/PekaBoo.apk (PekaBoo by RubinBastakoti) from game/ and signs it. Stops if the export fails.
set -euo pipefail
cd "$(dirname "$0")"
T=$HOME/gamedev-tools
export JAVA_HOME=$T/jdk PATH=$T/jdk/bin:$PATH
KS=$PWD/rubinbastakoti-release.keystore
KS_PASS=$(grep "^Password" KEYSTORE-README.txt | awk '{print $3}')
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=$KS GODOT_ANDROID_KEYSTORE_RELEASE_USER=pekaboo GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=$KS_PASS
mkdir -p build
"$T/godot" --headless --import --path game > /dev/null 2>&1 || true
# bake the house lighting on the PC so phones load it instantly
timeout 300 "$T/godot" --path game --resolution 640x360 -- --bake-out 2>&1 | grep "house:" || true
rm -f build/PeekabooHouse.apk
"$T/godot" --headless --path game --export-release "Android" ../build/PeekabooHouse.apk > build/export.log 2>&1 || true
if [ ! -f build/PeekabooHouse.apk ] || grep -q "export for preset \"Android\" failed" build/export.log; then
  grep -iE "error|warning" build/export.log | head -20
  echo "EXPORT FAILED"; exit 1
fi
BT=$T/android-sdk/build-tools/34.0.0
"$BT/apksigner" sign --ks "$KS" --ks-pass "pass:$KS_PASS" --ks-key-alias pekaboo --v1-signing-enabled true --v2-signing-enabled true --v3-signing-enabled true --out build/signed.apk build/PeekabooHouse.apk
"$BT/apksigner" verify --print-certs build/signed.apk | grep -m1 "Signer #1 certificate DN"
mv -f build/signed.apk build/PekaBoo.apk
rm -f build/PeekabooHouse.apk
rm -f build/*.idsig build/test.apk
cp -f build/PekaBoo.apk "$HOME/Downloads/PekaBoo-v1.0.apk" 2>/dev/null || true
echo "Built: $(pwd)/build/PekaBoo.apk ($(du -h build/PekaBoo.apk | cut -f1))"

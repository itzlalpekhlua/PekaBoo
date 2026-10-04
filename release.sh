#!/usr/bin/env bash
# Builds the public downloads of PekaBoo (no Arijit songs - those stay in the private build):
#   build/public/PekaBoo-v1.0-android.apk, PekaBoo-v1.0-windows.zip, PekaBoo-v1.0-linux.tar.gz
set -euo pipefail
cd "$(dirname "$0")"
T=$HOME/gamedev-tools
VER=v1.0
export JAVA_HOME=$T/jdk PATH=$T/jdk/bin:$PATH
KS=$PWD/rubinbastakoti-release.keystore
KS_PASS=$(grep "^Password" KEYSTORE-README.txt | awk '{print $3}')
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=$KS GODOT_ANDROID_KEYSTORE_RELEASE_USER=pekaboo GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=$KS_PASS
rm -rf build/public && mkdir -p build/public/windows build/public/linux
"$T/godot" --headless --import --path game > /dev/null 2>&1 || true
for preset in "Android Public" "Windows" "Linux"; do
  echo "exporting $preset..."
  "$T/godot" --headless --path game --export-release "$preset" > "build/public/export-${preset// /_}.log" 2>&1 || true
done
BT=$T/android-sdk/build-tools/34.0.0
"$BT/apksigner" sign --ks "$KS" --ks-pass "pass:$KS_PASS" --ks-key-alias pekaboo --out build/public/PekaBoo-$VER-android.apk build/public/PekaBoo-android-unsigned.apk
rm -f build/public/PekaBoo-android-unsigned.apk build/public/*.idsig
cat > build/public/windows/HOW-TO-PLAY.txt <<'TXT'
PekaBoo - by RubinBastakoti
Double-click PekaBoo.exe to play.
If Windows says "Windows protected your PC", click "More info" then "Run anyway"
(the game isn't signed with a paid Microsoft certificate, that's all).
Keys: WASD move, mouse look, Space jump, C crouch, Shift run, E action, 1-9 tools, Esc frees the mouse, F11 fullscreen.
TXT
(cd build/public/windows && rm -f ../PekaBoo-$VER-windows.zip && python3 -m zipfile -c ../PekaBoo-$VER-windows.zip PekaBoo.exe HOW-TO-PLAY.txt)
cat > build/public/linux/HOW-TO-PLAY.txt <<'TXT'
PekaBoo - by RubinBastakoti
Extract, then run:  ./PekaBoo.x86_64   (or double-click it)
Keys: WASD move, mouse look, Space jump, C crouch, Shift run, E action, 1-9 tools, Esc frees the mouse, F11 fullscreen.
TXT
chmod +x build/public/linux/PekaBoo.x86_64
tar -C build/public -czf build/public/PekaBoo-$VER-linux.tar.gz --transform 's,^linux,PekaBoo,' linux
ls -la build/public/PekaBoo-$VER-*

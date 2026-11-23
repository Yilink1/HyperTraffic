#!/bin/sh
# HyperOS 网络助手离线修复 (LibXposed API 102) 构建脚本 (Linux / chroot / Termux)
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
TOOLS=${TOOLS:-$HERE/tools}
cd "$HERE"

rm -rf build && mkdir -p build/classes build/dex build/apk_root/META-INF/xposed

echo "1. Javac..."
javac -encoding UTF-8 --release 11 -cp "$TOOLS/api-102.jar:$TOOLS/android-4.1.1.4.jar" -d build/classes \
    $(find src/main/java -name '*.java')

echo "2. D8 dexing..."
java -cp "$TOOLS/r8-9.5.33.jar" com.android.tools.r8.D8 --min-api 29 \
    --output build/dex $(find build/classes -name '*.class')

echo "3. Aapt packaging..."
aapt package -f -M AndroidManifest.xml -S res \
    -I "$TOOLS/android-4.1.1.4.jar" -F build/base.apk

echo "4. Adding dex and META-INF/xposed..."
cp build/dex/classes.dex build/apk_root/
cp -r src/main/resources/* build/apk_root/
(cd build/apk_root && aapt add ../base.apk classes.dex META-INF/xposed/*)

echo "5. Zipalign..."
zipalign -f 4 build/base.apk HyperTraffic-API102-unsigned.apk

if [ -n "$KEYSTORE" ] && [ -f "$KEYSTORE" ]; then
    echo "6. Signing with provided keystore ($KEYSTORE)..."
    apksigner sign --ks "$KEYSTORE" --ks-pass "pass:$KS_PASS" --key-pass "pass:${KEY_PASS:-$KS_PASS}" \
        --ks-key-alias "$KS_ALIAS" --out HyperTraffic-API102.apk HyperTraffic-API102-unsigned.apk
    echo "=== OK -> $HERE/HyperTraffic-API102.apk ==="
else
    echo "=== OK (Unsigned) -> $HERE/HyperTraffic-API102-unsigned.apk ==="
fi

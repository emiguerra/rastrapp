#!/usr/bin/env bash
# Compila la app para el simulador de iPhone y la reinstala, saltándose el
# `flutter run` que se rompe con Xcode 26. Uso:  sh redeploy.sh
set -uo pipefail
export PATH="/opt/homebrew/bin:$PATH"

UDID="${1:-02433156-8C39-4C77-B912-3A022A53C586}"
PROJ="/Users/emiliaguerra/Desktop/rastrapp/rastrapp"

cd "$PROJ/ios" || exit 1
echo "⏳ compilando…"
xcrun xcodebuild -workspace Runner.xcworkspace -scheme Runner \
  -configuration Debug -sdk iphonesimulator \
  -destination "generic/platform=iOS Simulator" build >/tmp/xcb.log 2>&1
if [ $? -ne 0 ]; then
  echo "❌ build falló:"; grep -iE "error:" /tmp/xcb.log | head; exit 1
fi

APP=$(find "$HOME/Library/Developer/Xcode/DerivedData" -name "Runner.app" \
  -path "*Debug-iphonesimulator*" 2>/dev/null | head -1)
BUNDLE=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP/Info.plist" 2>/dev/null)

xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator 2>/dev/null || true
xcrun simctl install "$UDID" "$APP" && xcrun simctl launch "$UDID" "$BUNDLE"
echo "✅ listo"

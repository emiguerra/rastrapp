#!/usr/bin/env bash
# Compila, firma y sube la app a TestFlight usando una llave de la API de
# App Store Connect. Ver docs/testflight/README.md.  Uso:  sh subir_testflight.sh
set -euo pipefail
export PATH="/opt/homebrew/bin:$PATH"

RAIZ="$(cd "$(dirname "$0")" && pwd)"
ARCHIVO_CONFIG="$RAIZ/subir_testflight.env"
[ -f "$ARCHIVO_CONFIG" ] && . "$ARCHIVO_CONFIG"

: "${ID_LLAVE:?Falta ID_LLAVE (ver subir_testflight.env.ejemplo)}"
: "${ID_EMISOR:?Falta ID_EMISOR (ver subir_testflight.env.ejemplo)}"
RUTA_LLAVE="${RUTA_LLAVE:-$HOME/.appstoreconnect/private_keys/AuthKey_$ID_LLAVE.p8}"
[ -f "$RUTA_LLAVE" ] || { echo "❌ No encuentro la llave en $RUTA_LLAVE"; exit 1; }

CARPETA_SALIDA="$RAIZ/build/testflight"
RUTA_ARCHIVO="$CARPETA_SALIDA/Runner.xcarchive"
REGISTRO="$CARPETA_SALIDA/xcodebuild.log"
AUTENTICACION=(-allowProvisioningUpdates
  -authenticationKeyPath "$RUTA_LLAVE"
  -authenticationKeyID "$ID_LLAVE"
  -authenticationKeyIssuerID "$ID_EMISOR")

VERSION=$(grep -E '^version:' "$RAIZ/pubspec.yaml" | awk '{print $2}')
echo "📦 versión $VERSION (recuerda subir el +N en pubspec.yaml antes de cada envío)"

rm -rf "$CARPETA_SALIDA" && mkdir -p "$CARPETA_SALIDA"
cd "$RAIZ"
flutter pub get
flutter build ios --release --config-only

cd "$RAIZ/ios"
echo "⏳ archivando…"
if ! xcrun xcodebuild -workspace Runner.xcworkspace -scheme Runner \
    -configuration Release -destination "generic/platform=iOS" \
    -archivePath "$RUTA_ARCHIVO" archive "${AUTENTICACION[@]}" >"$REGISTRO" 2>&1; then
  echo "❌ el archivado falló:"; grep -iE "error:" "$REGISTRO" | head; exit 1
fi

echo "⏳ firmando y subiendo a App Store Connect…"
if ! xcrun xcodebuild -exportArchive -archivePath "$RUTA_ARCHIVO" \
    -exportOptionsPlist "$RAIZ/ios/ExportOptions.plist" \
    -exportPath "$CARPETA_SALIDA/export" "${AUTENTICACION[@]}" >>"$REGISTRO" 2>&1; then
  echo "❌ la subida falló:"; grep -iE "error:" "$REGISTRO" | head; exit 1
fi

echo "✅ subido. Aparecerá en TestFlight cuando Apple termine de procesarlo (5–30 min)."

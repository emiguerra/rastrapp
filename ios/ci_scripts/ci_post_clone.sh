#!/bin/sh
# Xcode Cloud ejecuta este script justo después de clonar el repositorio.
# Prepara el proyecto Flutter para que Xcode pueda compilar ios/Runner.xcworkspace.
# Ver docs/xcode-cloud/README.md.
set -eu

paso() { echo ""; echo "▶︎ $1"; }

VERSION_FLUTTER="3.47.9" # misma versión que usamos localmente
RAIZ="$CI_PRIMARY_REPOSITORY_PATH"

# 1. Instalar Flutter
paso "1/4 instalando Flutter $VERSION_FLUTTER"
git clone https://github.com/flutter/flutter.git --depth 1 -b "$VERSION_FLUTTER" "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin"
flutter --disable-analytics
flutter precache --ios

# 2. Generar lib/secrets.dart (no versionado) desde variables de Xcode Cloud
paso "2/4 generando lib/secrets.dart"
: "${SUPABASE_URL:?Falta la variable SUPABASE_URL en el workflow de Xcode Cloud}"
: "${SUPABASE_LLAVE:?Falta la variable SUPABASE_LLAVE en el workflow de Xcode Cloud}"
cat > "$RAIZ/lib/secrets.dart" <<EOF
class Secrets {
  static const String supabaseUrl = '$SUPABASE_URL';
  static const String supabaseKey = '$SUPABASE_LLAVE';
}
EOF

# 3. Dependencias de Dart y configuración de Xcode.
#    El número de build lo pone Xcode Cloud (CI_BUILD_NUMBER), así no hay que
#    subir el +N de pubspec.yaml a mano.
paso "3/4 flutter pub get y configuración de Xcode (build $CI_BUILD_NUMBER)"
cd "$RAIZ"
flutter pub get
flutter build ios --config-only --release --no-codesign --build-number="$CI_BUILD_NUMBER"

# 4. CocoaPods
paso "4/4 pod install"
HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods
cd "$RAIZ/ios"
pod install

paso "✅ listo"
exit 0

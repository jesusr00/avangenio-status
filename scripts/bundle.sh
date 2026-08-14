#!/usr/bin/env bash
#
# bundle.sh — compila AvangenioStatus en Release (universal: Intel + Apple Silicon),
# extrae el .app a dist/ y lo re-firma ad-hoc.
#
# Uso:   scripts/bundle.sh
# Env:   VERSION   (opcional) sobreescribe MARKETING_VERSION en el build.
#                  Si no se pasa, se usa el valor de project.yml.
#
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

APP_NAME="AvangenioStatus"
SCHEME="AvangenioStatus"
DERIVED="$ROOT/build"
DIST="$ROOT/dist"
PRODUCT="$DERIVED/Build/Products/Release/$APP_NAME.app"

# --- Versión: env VERSION > MARKETING_VERSION de project.yml ---
if [[ -z "${VERSION:-}" ]]; then
  VERSION="$(grep -E 'MARKETING_VERSION:' project.yml | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
fi
if [[ -z "$VERSION" ]]; then
  echo "error: no se pudo determinar la versión (VERSION vacío y MARKETING_VERSION ilegible)" >&2
  exit 1
fi
echo "==> Versión: $VERSION"

# --- Prerrequisitos ---
command -v xcodegen >/dev/null 2>&1 || { echo "error: falta xcodegen (brew install xcodegen)" >&2; exit 1; }

# --- Generar proyecto + build universal ---
echo "==> xcodegen generate"
xcodegen generate

echo "==> xcodebuild (Release, universal)"
xcodebuild \
  -project "$APP_NAME.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED" \
  MARKETING_VERSION="$VERSION" \
  ARCHS="x86_64 arm64" ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES \
  clean build

if [[ ! -d "$PRODUCT" ]]; then
  echo "error: no se encontró el .app en $PRODUCT" >&2
  exit 1
fi

# --- Copiar a dist/ ---
echo "==> Copiando a dist/"
rm -rf "$DIST"
mkdir -p "$DIST"
cp -R "$PRODUCT" "$DIST/"
APP="$DIST/$APP_NAME.app"

# --- Re-firma ad-hoc, de dentro hacia afuera (framework embebido antes que el bundle) ---
echo "==> Firma ad-hoc"
FRAMEWORKS="$APP/Contents/Frameworks"
if [[ -d "$FRAMEWORKS" ]]; then
  find "$FRAMEWORKS" -type d -name "*.framework" -print0 | while IFS= read -r -d '' fw; do
    codesign --force --sign - --timestamp=none "$fw"
  done
fi
codesign --force --sign - --timestamp=none --preserve-metadata=entitlements "$APP"

echo "==> Verificando firma"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "✅ Bundle listo: $APP  (v$VERSION)"

#!/usr/bin/env bash
#
# make-dmg.sh — empaqueta dist/AvangenioStatus.app en dist/AvangenioStatus.dmg.
# Usa create-dmg (layout con enlace a /Applications). Si create-dmg no está
# disponible o falla (p. ej. sin GUI en CI), cae a un DMG simple con hdiutil.
#
# Uso:   scripts/make-dmg.sh
# Env:   VERSION   (opcional) se reenvía a bundle.sh si hay que compilar.
#
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

APP_NAME="AvangenioStatus"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"
DMG="$DIST/$APP_NAME.dmg"
VOLNAME="Avangenio Status"

# --- Asegura que el .app exista ---
if [[ ! -d "$APP" ]]; then
  echo "==> No hay .app; ejecutando bundle.sh"
  scripts/bundle.sh
fi

rm -f "$DMG"

make_with_create_dmg() {
  command -v create-dmg >/dev/null 2>&1 || return 1
  echo "==> create-dmg"
  create-dmg \
    --volname "$VOLNAME" \
    --window-pos 200 120 \
    --window-size 640 400 \
    --icon-size 128 \
    --icon "$APP_NAME.app" 175 200 \
    --app-drop-link 505 200 \
    --no-internet-enable \
    "$DMG" "$APP"
}

make_with_hdiutil() {
  echo "==> hdiutil (fallback)"
  local staging
  staging="$(mktemp -d)"
  trap 'rm -rf "$staging"' RETURN
  cp -R "$APP" "$staging/"
  ln -s /Applications "$staging/Applications"
  hdiutil create \
    -volname "$VOLNAME" \
    -srcfolder "$staging" \
    -fs HFS+ \
    -format UDZO -imagekey zlib-level=9 \
    -ov "$DMG"
}

if ! make_with_create_dmg; then
  echo "==> create-dmg no disponible o falló; usando hdiutil"
  make_with_hdiutil
fi

if [[ ! -f "$DMG" ]]; then
  echo "error: no se generó el DMG en $DMG" >&2
  exit 1
fi

echo "✅ DMG listo: $DMG"
shasum -a 256 "$DMG"

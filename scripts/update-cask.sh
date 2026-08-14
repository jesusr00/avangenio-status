#!/usr/bin/env bash
#
# update-cask.sh — actualiza el Cask de Homebrew en el tap jesusr00/homebrew-tap
# con la nueva versión y su sha256, y hace push.
#
# Uso:   scripts/update-cask.sh <VERSION> [ruta-al-DMG]
#        VERSION sin la "v" (ej. 1.0). Si se omite el DMG, se usa dist/AvangenioStatus.dmg.
#
# Env:   TAP_GITHUB_TOKEN  (CI) PAT con escritura en el tap. Si no está, se usa SSH.
#        TAP_REPO          (opcional) override, por defecto jesusr00/homebrew-tap
#        CASK_FILE         (opcional) por defecto Casks/avangenio-status.rb
#
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

VERSION="${1:-}"
DMG="${2:-$ROOT/dist/AvangenioStatus.dmg}"
TAP_REPO="${TAP_REPO:-jesusr00/homebrew-tap}"
CASK_FILE="${CASK_FILE:-Casks/avangenio-status.rb}"

if [[ -z "$VERSION" ]]; then
  echo "uso: scripts/update-cask.sh <VERSION> [ruta-al-DMG]" >&2
  exit 1
fi
if [[ ! -f "$DMG" ]]; then
  echo "error: DMG no encontrado: $DMG" >&2
  exit 1
fi

SHA256="$(shasum -a 256 "$DMG" | cut -d' ' -f1)"
echo "==> Versión: $VERSION"
echo "==> sha256:  $SHA256"

# --- Clonar el tap (token en CI, SSH en local) ---
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [[ -n "${TAP_GITHUB_TOKEN:-}" ]]; then
  CLONE_URL="https://x-access-token:${TAP_GITHUB_TOKEN}@github.com/${TAP_REPO}.git"
else
  CLONE_URL="git@github.com:${TAP_REPO}.git"
fi

echo "==> Clonando $TAP_REPO"
git clone --depth 1 "$CLONE_URL" "$WORK/tap"

TARGET="$WORK/tap/$CASK_FILE"
if [[ ! -f "$TARGET" ]]; then
  echo "error: no existe $CASK_FILE en el tap $TAP_REPO" >&2
  exit 1
fi

# --- Reemplazar version + sha256 ---
sed -i '' \
  -e "s/version \".*\"/version \"$VERSION\"/" \
  -e "s/sha256 \".*\"/sha256 \"$SHA256\"/" \
  "$TARGET"

# --- Commit + push si hay cambios ---
cd "$WORK/tap"
if git diff --quiet; then
  echo "==> Sin cambios en el cask (misma versión y sha256). Nada que hacer."
  exit 0
fi

git config user.name  "${GIT_AUTHOR_NAME:-avangenio-status-ci}"
git config user.email "${GIT_AUTHOR_EMAIL:-ci@users.noreply.github.com}"
git add "$CASK_FILE"
git commit -m "avangenio-status $VERSION"
git push origin HEAD:main

echo "✅ Cask actualizado a v$VERSION en $TAP_REPO"

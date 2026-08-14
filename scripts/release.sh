#!/usr/bin/env bash
#
# release.sh — valida, testea y crea el tag vX.Y.Z que dispara el workflow de release.
# El empaquetado (DMG), el GitHub Release y la actualización del cask los hace CI
# (.github/workflows/release.yml) al recibir el tag.
#
# Uso:   scripts/release.sh
# Env:   SKIP_TESTS=1   omite la corrida de tests (no recomendado).
#
set -euo pipefail

cd "$(dirname "$0")/.."

# --- Versión desde project.yml ---
VERSION="$(grep -E 'MARKETING_VERSION:' project.yml | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
[[ -n "$VERSION" ]] || { echo "error: MARKETING_VERSION ilegible en project.yml" >&2; exit 1; }
TAG="v$VERSION"
echo "==> Release $TAG"

# --- Validaciones ---
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" != "main" ]]; then
  echo "error: debes estar en 'main' (estás en '$BRANCH')" >&2
  exit 1
fi
if ! git diff-index --quiet HEAD --; then
  echo "error: hay cambios sin confirmar; el árbol debe estar limpio" >&2
  exit 1
fi
if git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "error: el tag $TAG ya existe. Sube MARKETING_VERSION en project.yml." >&2
  exit 1
fi

# --- Tests ---
if [[ "${SKIP_TESTS:-0}" != "1" ]]; then
  echo "==> Tests"
  xcodegen generate
  xcodebuild test \
    -project AvangenioStatus.xcodeproj \
    -scheme AvangenioStatus \
    -destination 'platform=macOS' \
    CODE_SIGNING_ALLOWED=NO
fi

# --- Tag + push (dispara CI) ---
echo "==> Creando y empujando $TAG"
git tag -a "$TAG" -m "Avangenio Status $VERSION"
git push origin "$TAG"

echo "✅ Tag $TAG empujado. El workflow de release se encargará del DMG, el Release y el cask."
echo "   Sigue el progreso en: GitHub → Actions"

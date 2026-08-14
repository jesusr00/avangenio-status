# Avangenio Status

App de barra de menú para macOS (14+) que monitorea los servicios de Avangenio
leyendo `https://status.avangenio.com/data.txt` y avisa por notificaciones locales,
por eventos (transiciones con histéresis) y por reportes programados.

## Estructura

- **`AvangenioStatusKit`** — framework con la lógica de dominio (modelos, parser, fetcher,
  detector de eventos, motor de schedules, notificaciones, persistencia y el orquestador
  `AppModel`), aislada del shell para poder testearla.
- **`AvangenioStatus`** — app SwiftUI (`MenuBarExtra`, `LSUIElement`) con las vistas.
- **`AvangenioStatusTests`** — tests unitarios de las capas puras y del `AppModel`.

El `.xcodeproj` **no** se versiona: se genera con [XcodeGen](https://github.com/yonaskolb/XcodeGen)
a partir de `project.yml`.

## Instalación (usuario final)

### Homebrew (recomendado)

```bash
brew install --cask jesusr00/tap/avangenio-status
```

### Descarga directa

Baja el DMG más reciente desde
[Releases](https://github.com/jesusr00/avangenio-status/releases/latest) y arrastra
`AvangenioStatus.app` a `Aplicaciones`.

### Primer arranque (Gatekeeper)

La app está firmada **ad-hoc** (sin notarización de Apple), así que la primera vez macOS
puede bloquearla. Ábrela con **clic derecho → Abrir**, o quita la cuarentena:

```bash
xattr -dr com.apple.quarantine "/Applications/AvangenioStatus.app"
```

## Requisitos

```bash
brew install xcodegen   # solo la primera vez
```

## Generar, compilar y testear

```bash
xcodegen generate
xcodebuild build -project AvangenioStatus.xcodeproj -scheme AvangenioStatus -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
xcodebuild test  -project AvangenioStatus.xcodeproj -scheme AvangenioStatus -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

O abre `AvangenioStatus.xcodeproj` en Xcode y usa ⌘R / ⌘U.

## Empaquetado y release (mantenedores)

La distribución replica el patrón de [downbender](https://github.com/NaztiRS/downbender):
un DMG firmado ad-hoc publicado en GitHub Releases y un Homebrew Cask en el tap
[`jesusr00/homebrew-tap`](https://github.com/jesusr00/homebrew-tap).

Tareas locales (requieren `xcodegen` y, para el DMG, `create-dmg`):

```bash
make bundle    # compila Release universal → dist/AvangenioStatus.app
make dmg       # empaqueta → dist/AvangenioStatus.dmg
```

Para publicar una versión:

1. Sube `MARKETING_VERSION` en `project.yml`.
2. Commit en `main`.
3. `make release` → valida, testea y empuja el tag `vX.Y.Z`.

El tag dispara `.github/workflows/release.yml`, que compila el DMG universal, crea el
GitHub Release y actualiza el Cask (versión + sha256) en el tap. Requiere el secret
`TAP_GITHUB_TOKEN` (PAT con escritura en `jesusr00/homebrew-tap`) en este repo.

## Notas

- Firma ad-hoc ("Sign to Run Locally"), uso personal — sin cuenta de desarrollador de pago.
- La primera vez pedirá permiso de notificaciones; si lo deniegas, Ajustes muestra el estado
  y un botón para reabrir Ajustes del sistema.
- El plan de diseño e implementación vive en `docs/plans/`.

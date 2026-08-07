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

## Notas

- Firma ad-hoc ("Sign to Run Locally"), uso personal — sin cuenta de desarrollador de pago.
- La primera vez pedirá permiso de notificaciones; si lo deniegas, Ajustes muestra el estado
  y un botón para reabrir Ajustes del sistema.
- El plan de diseño e implementación vive en `docs/plans/`.

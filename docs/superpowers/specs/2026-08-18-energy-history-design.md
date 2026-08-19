# Diseño: Historial de baterías y electricidad

**Fecha:** 2026-08-18
**Estado:** Aprobado (diseño) — pendiente de plan de implementación

## Objetivo

Añadir a Avangenio Status un historial consultable del **estado de las
baterías de respaldo (%)** y del **servicio eléctrico estatal (on/off)** a lo
largo del tiempo, visualizado como un **gráfico en una ventana dedicada**:
batería como línea, electricidad como bandas de color de fondo.

Fuera de alcance: internet y ancho de banda (el historial se limita a energía,
según lo pedido). No configurable la retención ni el intervalo por ahora (YAGNI).

## Contexto de la app

- `ServiceStatus` es una instantánea tipada (internet, `bandwidthMbps`,
  `batteryPercent`, `power`, `lastUpdatedRaw`, `fetchedAt`). Hoy se persiste
  **solo la última** en `UserDefaults` vía `SettingsStore`.
- `AppModel` (`@MainActor`, `@Observable`) orquesta `fetch → parse → detect →
  notify` cada N minutos (10 por defecto) en `performPoll()`.
- Dependencias inyectadas por protocolo: `StatusFetching`, `NotificationServing`,
  etc. Seguimos ese patrón para el nuevo almacenamiento.
- `StatusPanelView` es el desplegable de 280 px. La ventana de Ajustes se
  registra como `Window(id: "settings")` en `AvangenioStatusApp` y se abre con
  `openWindow(id:)` + `NSApp.activate`.
- Deployment target **macOS 14** → **Swift Charts** disponible sin dependencias
  externas.

## Modelo de datos

Nuevo en `AvangenioStatusKit/Models/`:

```swift
public struct EnergySample: Codable, Equatable, Sendable {
    public let timestamp: Date         // = fetchedAt local de la lectura
    public let batteryPercent: Double? // nil si el API no lo trajo parseable
    public let power: PowerStatus      // .on / .off
}
```

```swift
public enum HistoryRange: CaseIterable, Sendable {
    case day    // 24 h
    case week   // 7 días
    case month  // 30 días

    var duration: TimeInterval { … } // 24h / 7d / 30d
}
```

**Marca de tiempo:** se usa `fetchedAt` (Date local, ya presente en
`ServiceStatus`) en vez del string CDT del servidor, para no arrastrar parsing
de zona horaria a la capa de almacenamiento.

**Muestreo denso:** una muestra por cada poll (~10 min), **incluyendo respuestas
304 (`notModified`)** — en un 304 el estado sigue vigente, así la línea y las
bandas quedan continuas. Un valor continuo (batería) se representa con más
honestidad con muestreo denso que con solo-cambios (evita interpolar una recta
entre dos cambios lejanos).

## Almacenamiento — `HistoryStore`

Subsistema nuevo, aislado, en `AvangenioStatusKit/Domain/`:

- Protocolo `HistoryStoring` para inyección (igual que `StatusFetching`), de modo
  que `AppModel` dependa de la abstracción y los tests inyecten un doble.
- Implementación `HistoryStore` que persiste `[EnergySample]` en un **archivo
  JSON**: `~/Library/Application Support/AvangenioStatus/energy-history.json`.
  Se usa archivo (no `UserDefaults`) porque es una serie que crece.
- Carga en memoria una vez al init. `append(_:)` crea un array nuevo (estilo
  inmutable), **poda** las muestras más viejas que la retención y reescribe el
  archivo.
- **Retención: 30 días** (constante). ~4.300 muestras densas ≈ ~100 KB.
- Archivo ausente o corrupto → se trata como historial vacío (fail-safe, sin
  romper el arranque).

Interfaz:

```swift
public protocol HistoryStoring: Sendable {
    func load() -> [EnergySample]
    func append(_ sample: EnergySample) -> [EnergySample] // devuelve la serie podada resultante
}
```

`append` devuelve la serie resultante para que `AppModel` sincronice su copia
observable sin releer el archivo.

## Agregación — `HistoryChart` (lógica pura, núcleo de TDD)

Función pura sin estado en `AvangenioStatusKit/Domain/`. Entrada: `[EnergySample]`,
`HistoryRange` y `now: Date` (inyectado para testabilidad). Salida:

```swift
public struct HistoryChartData: Equatable, Sendable {
    public let batterySegments: [[BatteryPoint]] // línea partida por huecos
    public let powerBands: [PowerBand]           // tramos on/off
    public let start: Date                        // dominio X = [start, now]
    public let end: Date
}

public struct BatteryPoint: Equatable, Sendable {
    public let timestamp: Date
    public let percent: Double
}

public struct PowerBand: Equatable, Sendable {
    public let start: Date
    public let end: Date
    public let state: PowerStatus
}
```

Reglas:

1. **Filtrado por rango:** conservar muestras con `timestamp` en `[now -
   range.duration, now]`.
2. **Segmentación de la línea de batería:** se inicia un segmento nuevo cuando
   entre dos muestras consecutivas hay un hueco mayor a un umbral
   (`≈ 2,5 × intervalo de poll`) o cuando `batteryPercent` es `nil`. Así el
   gráfico dibuja **rupturas** en vez de interpolar sobre apagones o periodos
   con la app cerrada. Las muestras con batería `nil` no aportan punto.
3. **Bandas de electricidad:** agrupar muestras contiguas con el mismo `power`
   en `PowerBand` con `start`/`end`. El `end` de una banda se extiende hasta el
   inicio de la siguiente muestra (o hasta `now` la última).
4. Entrada vacía → `batterySegments` y `powerBands` vacíos; el dominio X sigue
   siendo `[now - duration, now]`.

## Vista — `HistoryView`

Nueva en `AvangenioStatus/Views/HistoryView.swift`, SwiftUI + `Charts`, en
ventana dedicada (`id: "history"`):

- Selector de rango segmentado: **24 h / 7 días / 30 días** (`@State`, por
  defecto 7 días).
- Fondo: un `RectangleMark` por cada `PowerBand` con `state == .off`, sombreado
  rojo/naranja translúcido para que los cortes de luz salten a la vista; `on`
  queda neutro.
- Frente: un `LineMark` por cada segmento de `batterySegments`, eje Y fijo
  0–100 %.
- Estado vacío: placeholder "Aún no hay suficientes datos".
- Lee de `model.history` y calcula `HistoryChartData` con `HistoryChart` +
  el rango seleccionado → **se actualiza en vivo** vía `@Observable`.
- Leyenda breve: "Batería (%)" y "Sin electricidad".

## Flujo de datos y conexiones

1. `AppModel` gana `public private(set) var history: [EnergySample]`
   (observable), sembrado desde `historyStore.load()` en el `init`.
2. Nueva dependencia inyectada `historyStore: HistoryStoring = HistoryStore()`.
3. En `performPoll()`, casos `.updated` y `.notModified`: construir
   `EnergySample(timestamp: status.fetchedAt, batteryPercent:
   status.batteryPercent, power: status.power)`, y
   `history = historyStore.append(sample)`. En `.failed`: **no** se añade nada
   (queda hueco → ruptura en el gráfico).
   - En `.notModified` se usa `current` (la última lectura vigente) con un
     `fetchedAt` actualizado para la muestra.
4. Botón **"Historial"** en `StatusPanelView` (junto a "Ajustes") →
   `openWindow(id: "history")` + `NSApp.activate(ignoringOtherApps: true)`.
5. `AvangenioStatusApp` registra `Window("Historial de energía", id:
   "history") { HistoryView(model: appDelegate.model) }`.

## Archivos

**Nuevos (`AvangenioStatusKit`):**
- `Models/EnergySample.swift`
- `Models/HistoryRange.swift`
- `Domain/HistoryStore.swift` (+ protocolo `HistoryStoring`)
- `Domain/HistoryChart.swift` (+ `HistoryChartData`, `BatteryPoint`, `PowerBand`)

**Nuevo (`AvangenioStatus`):**
- `Views/HistoryView.swift`

**Modificados:**
- `App/AppModel.swift` — inyectar `HistoryStoring`, `history` observable,
  append en el poll.
- `Views/StatusPanelView.swift` — botón "Historial".
- `AvangenioStatusApp.swift` — registrar la ventana `history`.

`project.yml` no requiere cambios: las fuentes se agrupan por carpeta y `Charts`
es framework del sistema (`import Charts`).

## Manejo de errores y casos límite

- Archivo de historial ausente/corrupto → historial vacío, sin romper arranque.
- Fetch fallido → sin muestra (hueco honesto en el gráfico).
- `batteryPercent == nil` → la banda de electricidad sí se registra; la línea de
  batería se rompe en ese punto.
- Datos insuficientes/vacíos → placeholder en la vista.
- Poda de retención en cada `append` para acotar tamaño del archivo y memoria.

## Plan de pruebas (TDD, objetivo ≥80 %)

- **`HistoryChartTests`** (grueso): filtrado por rango; segmentación por huecos
  (hueco temporal grande y `nil` de batería); derivación de bandas on/off
  contiguas; extensión del `end` de la última banda hasta `now`; entrada vacía;
  muestra única; límites del rango.
- **`HistoryStoreTests`**: round-trip persistencia; poda de muestras > retención;
  archivo corrupto → vacío; append devuelve serie podada.
- **`AppModelTests`** (extender con un `HistoryStoring` falso): añade muestra en
  `.updated` y `.notModified`; **no** añade en `.failed`; siembra `history`
  desde el store al init.

## Decisiones tomadas (con recomendación, revisables)

- Retención **30 días**, constante.
- Muestreo **denso** incluyendo respuestas 304.
- Huecos representados como **rupturas visuales** (sin interpolar).
- Batería como **línea**; electricidad como **bandas** de fondo.
- Historial **solo de energía** (sin internet/ancho de banda).

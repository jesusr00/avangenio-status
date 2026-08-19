# Historial de baterías y electricidad — Plan de implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Añadir un historial consultable de baterías (%) y servicio eléctrico (on/off), visualizado como gráfico (línea + bandas) en una ventana dedicada.

**Architecture:** Nueva serie temporal de `EnergySample` persistida en un archivo JSON (`HistoryStore`). Se captura una muestra densa en cada poll (incluidos 304). Una función pura (`HistoryChart`) transforma la serie + rango en datos de gráfico (segmentos de batería con rupturas en huecos + bandas on/off). `AppModel` mantiene una copia observable (`history`) y una nueva `HistoryView` (SwiftUI + Swift Charts) la dibuja en una ventana `id: "history"`.

**Tech Stack:** Swift 5, SwiftUI, Swift Charts (framework del sistema, macOS 14), XCTest, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-08-18-energy-history-design.md`

## Global Constraints

- **Plataforma:** macOS 14 (deployment target). Swift Charts disponible sin dependencias externas (`import Charts`).
- **Aislamiento:** toda la lógica de dominio y modelos va en el target `AvangenioStatusKit`; las vistas en el target `AvangenioStatus`. Los tests en `AvangenioStatusTests` (`@testable import AvangenioStatusKit`).
- **Inmutabilidad:** crear arrays/estructuras nuevas, nunca mutar en sitio (estilo del repo).
- **Inyección por protocolo:** las dependencias nuevas se inyectan por protocolo con valor por defecto en el `init`, igual que `StatusFetching`/`NotificationServing`.
- **Logger:** `Logger(subsystem: "com.avangenio.status", category: ...)`.
- **Runner de tests:** `make test` (equivale a `xcodebuild test -project AvangenioStatus.xcodeproj -scheme AvangenioStatus -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`). Para un test concreto añade `-only-testing:AvangenioStatusTests/<Clase>/<método>`. Tras crear archivos nuevos hace falta `make generate` (o `xcodegen generate`) para que entren al proyecto antes de compilar/testear.
- **Commits (regla del usuario, OBLIGATORIA):** NO se hace commit automático. Las etapas de "Commit" marcan el límite natural de cada tarea, pero al ejecutar se dejan los cambios en el working tree y se hace commit **solo cuando el usuario lo pida explícitamente**. Al llegar a un paso de commit, detente y pide confirmación en vez de commitear.

---

### Task 1: Modelos `EnergySample` y `HistoryRange`

**Files:**
- Create: `AvangenioStatusKit/Models/EnergySample.swift`
- Create: `AvangenioStatusKit/Models/HistoryRange.swift`
- Test: `AvangenioStatusTests/EnergySampleTests.swift`

**Interfaces:**
- Consumes: `PowerStatus` (ya existe en `Models/ServiceStatus.swift`).
- Produces:
  - `EnergySample(timestamp: Date, batteryPercent: Double?, power: PowerStatus)` — `Codable, Equatable, Sendable`.
  - `HistoryRange` — `enum { case day, week, month }`, `CaseIterable, Sendable`, con `var duration: TimeInterval` y `var label: String`.

- [ ] **Step 1: Escribir los tests que fallan**

Crear `AvangenioStatusTests/EnergySampleTests.swift`:

```swift
import XCTest
@testable import AvangenioStatusKit

final class EnergySampleTests: XCTestCase {
    func testCodableRoundTrip() throws {
        let sample = EnergySample(timestamp: Date(timeIntervalSince1970: 1000),
                                  batteryPercent: 62.5, power: .off)
        let data = try JSONEncoder().encode(sample)
        let decoded = try JSONDecoder().decode(EnergySample.self, from: data)
        XCTAssertEqual(decoded, sample)
    }

    func testNilBatteryRoundTrip() throws {
        let sample = EnergySample(timestamp: Date(timeIntervalSince1970: 1000),
                                  batteryPercent: nil, power: .on)
        let data = try JSONEncoder().encode(sample)
        let decoded = try JSONDecoder().decode(EnergySample.self, from: data)
        XCTAssertNil(decoded.batteryPercent)
        XCTAssertEqual(decoded, sample)
    }

    func testRangeDurations() {
        XCTAssertEqual(HistoryRange.day.duration, 86_400)
        XCTAssertEqual(HistoryRange.week.duration, 604_800)
        XCTAssertEqual(HistoryRange.month.duration, 2_592_000)
    }

    func testRangeIsCaseIterable() {
        XCTAssertEqual(HistoryRange.allCases, [.day, .week, .month])
    }
}
```

- [ ] **Step 2: Regenerar proyecto y verificar que falla**

Run: `make generate && make test 2>&1 | tail -30`
Expected: FALLA de compilación — `EnergySample`/`HistoryRange` no existen.

- [ ] **Step 3: Implementar los modelos**

Crear `AvangenioStatusKit/Models/EnergySample.swift`:

```swift
import Foundation

/// Una muestra puntual del estado de energía: % de baterías y servicio eléctrico
/// en un instante dado. Base del historial (serie temporal densa).
public struct EnergySample: Codable, Equatable, Sendable {
    /// Instante representado por la muestra (= `fetchedAt` de la lectura).
    public let timestamp: Date
    /// Porcentaje de baterías; `nil` si el API no lo trajo parseable.
    public let batteryPercent: Double?
    /// Servicio eléctrico estatal.
    public let power: PowerStatus

    public init(timestamp: Date, batteryPercent: Double?, power: PowerStatus) {
        self.timestamp = timestamp
        self.batteryPercent = batteryPercent
        self.power = power
    }
}
```

Crear `AvangenioStatusKit/Models/HistoryRange.swift`:

```swift
import Foundation

/// Ventana temporal seleccionable para el historial de energía.
public enum HistoryRange: CaseIterable, Sendable {
    case day    // 24 h
    case week   // 7 días
    case month  // 30 días

    /// Duración hacia atrás desde "ahora".
    public var duration: TimeInterval {
        switch self {
        case .day:   return 24 * 60 * 60
        case .week:  return 7 * 24 * 60 * 60
        case .month: return 30 * 24 * 60 * 60
        }
    }

    /// Etiqueta corta para el selector.
    public var label: String {
        switch self {
        case .day:   return "24 h"
        case .week:  return "7 días"
        case .month: return "30 días"
        }
    }
}
```

- [ ] **Step 4: Regenerar y verificar que pasan**

Run: `make generate && make test 2>&1 | tail -30`
Expected: PASA (incluida la suite existente).

- [ ] **Step 5: Commit** (pedir confirmación al usuario antes; ver Global Constraints)

```bash
git add AvangenioStatusKit/Models/EnergySample.swift AvangenioStatusKit/Models/HistoryRange.swift AvangenioStatusTests/EnergySampleTests.swift AvangenioStatus.xcodeproj
git commit -m "feat: add EnergySample and HistoryRange models"
```

---

### Task 2: `HistoryChart` — filtrado por rango y segmentos de batería

**Files:**
- Create: `AvangenioStatusKit/Domain/HistoryChart.swift`
- Test: `AvangenioStatusTests/HistoryChartTests.swift`

**Interfaces:**
- Consumes: `EnergySample`, `HistoryRange`, `PowerStatus`.
- Produces:
  - `BatteryPoint(timestamp: Date, percent: Double)` — `Equatable, Sendable`.
  - `PowerBand(start: Date, end: Date, state: PowerStatus)` — `Equatable, Sendable`.
  - `HistoryChartData(batterySegments: [[BatteryPoint]], powerBands: [PowerBand], start: Date, end: Date)` — `Equatable, Sendable`.
  - `HistoryChart.build(samples:range:now:gapThreshold:) -> HistoryChartData` (enum namespace, método `static`). En esta tarea `powerBands` sale siempre `[]` (se completa en Task 3).

- [ ] **Step 1: Escribir los tests que fallan**

Crear `AvangenioStatusTests/HistoryChartTests.swift`:

```swift
import XCTest
@testable import AvangenioStatusKit

final class HistoryChartTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func sample(_ offsetSeconds: TimeInterval, battery: Double?, power: PowerStatus = .on) -> EnergySample {
        EnergySample(timestamp: now.addingTimeInterval(offsetSeconds), batteryPercent: battery, power: power)
    }

    func testDomainBounds() {
        let data = HistoryChart.build(samples: [], range: .day, now: now)
        XCTAssertEqual(data.start, now.addingTimeInterval(-86_400))
        XCTAssertEqual(data.end, now)
    }

    func testEmptyReturnsNoSegments() {
        let data = HistoryChart.build(samples: [], range: .week, now: now)
        XCTAssertTrue(data.batterySegments.isEmpty)
    }

    func testFiltersOutOfRange() {
        let inside = sample(-3_600, battery: 80)          // hace 1 h
        let outside = sample(-2 * 86_400, battery: 50)    // hace 2 días
        let data = HistoryChart.build(samples: [outside, inside], range: .day, now: now)
        XCTAssertEqual(data.batterySegments, [[BatteryPoint(timestamp: inside.timestamp, percent: 80)]])
    }

    func testDenseSamplesFormSingleSegment() {
        let s = [sample(-1_800, battery: 90), sample(-1_200, battery: 85), sample(-600, battery: 80)]
        let data = HistoryChart.build(samples: s, range: .day, now: now)
        XCTAssertEqual(data.batterySegments.count, 1)
        XCTAssertEqual(data.batterySegments[0].map(\.percent), [90, 85, 80])
    }

    func testBreaksOnTimeGap() {
        // 40 min entre muestras > umbral 25 min → dos segmentos.
        let s = [sample(-4_800, battery: 90), sample(-2_400, battery: 70)]
        let data = HistoryChart.build(samples: s, range: .day, now: now)
        XCTAssertEqual(data.batterySegments.count, 2)
        XCTAssertEqual(data.batterySegments[0].map(\.percent), [90])
        XCTAssertEqual(data.batterySegments[1].map(\.percent), [70])
    }

    func testBreaksOnNilBattery() {
        let s = [sample(-1_800, battery: 90), sample(-1_200, battery: nil), sample(-600, battery: 80)]
        let data = HistoryChart.build(samples: s, range: .day, now: now)
        XCTAssertEqual(data.batterySegments.count, 2)
        XCTAssertEqual(data.batterySegments[0].map(\.percent), [90])
        XCTAssertEqual(data.batterySegments[1].map(\.percent), [80])
    }

    func testSortsUnorderedInput() {
        let s = [sample(-600, battery: 80), sample(-1_800, battery: 90), sample(-1_200, battery: 85)]
        let data = HistoryChart.build(samples: s, range: .day, now: now)
        XCTAssertEqual(data.batterySegments[0].map(\.percent), [90, 85, 80])
    }
}
```

- [ ] **Step 2: Verificar que falla**

Run: `make generate && make test 2>&1 | tail -30`
Expected: FALLA de compilación — `HistoryChart`/`BatteryPoint`/`HistoryChartData` no existen.

- [ ] **Step 3: Implementar `HistoryChart` (bandas vacías por ahora)**

Crear `AvangenioStatusKit/Domain/HistoryChart.swift`:

```swift
import Foundation

/// Un punto de la línea de batería.
public struct BatteryPoint: Equatable, Sendable {
    public let timestamp: Date
    public let percent: Double
    public init(timestamp: Date, percent: Double) {
        self.timestamp = timestamp
        self.percent = percent
    }
}

/// Un tramo contiguo con el mismo estado eléctrico.
public struct PowerBand: Equatable, Sendable {
    public let start: Date
    public let end: Date
    public let state: PowerStatus
    public init(start: Date, end: Date, state: PowerStatus) {
        self.start = start
        self.end = end
        self.state = state
    }
}

/// Datos listos para dibujar el gráfico del historial.
public struct HistoryChartData: Equatable, Sendable {
    /// Línea de batería partida en segmentos continuos (rupturas en huecos).
    public let batterySegments: [[BatteryPoint]]
    /// Bandas de estado eléctrico (fondo del gráfico).
    public let powerBands: [PowerBand]
    /// Dominio X del gráfico: [start, end].
    public let start: Date
    public let end: Date

    public init(batterySegments: [[BatteryPoint]], powerBands: [PowerBand], start: Date, end: Date) {
        self.batterySegments = batterySegments
        self.powerBands = powerBands
        self.start = start
        self.end = end
    }
}

/// Transforma una serie de muestras en datos de gráfico para un rango dado.
/// Función pura, sin dependencias del reloj (se inyecta `now`).
public enum HistoryChart {
    /// Umbral de hueco: si dos muestras consecutivas distan más que esto, la
    /// línea de batería se rompe (no interpola sobre apagones / app cerrada).
    /// 2,5 × el intervalo de poll por defecto (10 min) = 25 min.
    public static let defaultGapThreshold: TimeInterval = 25 * 60

    public static func build(
        samples: [EnergySample],
        range: HistoryRange,
        now: Date,
        gapThreshold: TimeInterval = defaultGapThreshold
    ) -> HistoryChartData {
        let start = now.addingTimeInterval(-range.duration)
        let windowed = samples
            .filter { $0.timestamp >= start && $0.timestamp <= now }
            .sorted { $0.timestamp < $1.timestamp }

        return HistoryChartData(
            batterySegments: batterySegments(from: windowed, gapThreshold: gapThreshold),
            powerBands: [],   // se completa en Task 3
            start: start,
            end: now
        )
    }

    private static func batterySegments(
        from samples: [EnergySample],
        gapThreshold: TimeInterval
    ) -> [[BatteryPoint]] {
        var segments: [[BatteryPoint]] = []
        var current: [BatteryPoint] = []
        var previousTimestamp: Date?

        for sample in samples {
            guard let percent = sample.batteryPercent else {
                if !current.isEmpty { segments.append(current); current = [] }
                previousTimestamp = nil
                continue
            }
            if let prev = previousTimestamp,
               sample.timestamp.timeIntervalSince(prev) > gapThreshold {
                if !current.isEmpty { segments.append(current); current = [] }
            }
            current.append(BatteryPoint(timestamp: sample.timestamp, percent: percent))
            previousTimestamp = sample.timestamp
        }
        if !current.isEmpty { segments.append(current) }
        return segments
    }
}
```

- [ ] **Step 4: Verificar que pasan**

Run: `make test 2>&1 | tail -30`
Expected: PASA.

- [ ] **Step 5: Commit** (pedir confirmación al usuario antes)

```bash
git add AvangenioStatusKit/Domain/HistoryChart.swift AvangenioStatusTests/HistoryChartTests.swift AvangenioStatus.xcodeproj
git commit -m "feat: add HistoryChart battery segmentation and range filtering"
```

---

### Task 3: `HistoryChart` — bandas de electricidad

**Files:**
- Modify: `AvangenioStatusKit/Domain/HistoryChart.swift`
- Test: `AvangenioStatusTests/HistoryChartTests.swift` (añadir casos)

**Interfaces:**
- Produces: rellena `HistoryChartData.powerBands` con `[PowerBand]` derivadas de tramos contiguos del mismo `power`; la última banda extiende su `end` hasta `now`.

- [ ] **Step 1: Añadir los tests que fallan**

Añadir a `HistoryChartTests`:

```swift
    func testEmptyReturnsNoBands() {
        let data = HistoryChart.build(samples: [], range: .day, now: now)
        XCTAssertTrue(data.powerBands.isEmpty)
    }

    func testSingleBandExtendsToNow() {
        let s = [sample(-1_800, battery: 90, power: .on), sample(-600, battery: 80, power: .on)]
        let data = HistoryChart.build(samples: s, range: .day, now: now)
        XCTAssertEqual(data.powerBands, [
            PowerBand(start: s[0].timestamp, end: now, state: .on)
        ])
    }

    func testTwoBandsOnTransition() {
        let s = [sample(-1_800, battery: 90, power: .on), sample(-600, battery: 80, power: .off)]
        let data = HistoryChart.build(samples: s, range: .day, now: now)
        XCTAssertEqual(data.powerBands, [
            PowerBand(start: s[0].timestamp, end: s[1].timestamp, state: .on),
            PowerBand(start: s[1].timestamp, end: now, state: .off),
        ])
    }

    func testBandsIgnoreNilBattery() {
        // Un hueco de batería (nil) no debe partir las bandas eléctricas.
        let s = [sample(-1_800, battery: 90, power: .off),
                 sample(-1_200, battery: nil, power: .off),
                 sample(-600, battery: 80, power: .off)]
        let data = HistoryChart.build(samples: s, range: .day, now: now)
        XCTAssertEqual(data.powerBands, [
            PowerBand(start: s[0].timestamp, end: now, state: .off)
        ])
    }
```

- [ ] **Step 2: Verificar que fallan**

Run: `make test 2>&1 | tail -30`
Expected: FALLA — `powerBands` sale vacío en los nuevos casos.

- [ ] **Step 3: Implementar las bandas**

En `HistoryChart.build`, reemplazar `powerBands: [],   // se completa en Task 3` por:

```swift
            powerBands: powerBands(from: windowed, now: now),
```

Y añadir este método privado dentro del `enum HistoryChart`:

```swift
    private static func powerBands(from samples: [EnergySample], now: Date) -> [PowerBand] {
        guard let first = samples.first else { return [] }
        var bands: [PowerBand] = []
        var runStart = first.timestamp
        var runState = first.power

        for sample in samples.dropFirst() where sample.power != runState {
            bands.append(PowerBand(start: runStart, end: sample.timestamp, state: runState))
            runStart = sample.timestamp
            runState = sample.power
        }
        bands.append(PowerBand(start: runStart, end: now, state: runState))
        return bands
    }
```

- [ ] **Step 4: Verificar que pasan**

Run: `make test 2>&1 | tail -30`
Expected: PASA (todos los casos de `HistoryChartTests`).

- [ ] **Step 5: Commit** (pedir confirmación al usuario antes)

```bash
git add AvangenioStatusKit/Domain/HistoryChart.swift AvangenioStatusTests/HistoryChartTests.swift
git commit -m "feat: derive power on/off bands in HistoryChart"
```

---

### Task 4: `HistoryStore` (persistencia en archivo JSON)

**Files:**
- Create: `AvangenioStatusKit/Domain/HistoryStore.swift`
- Test: `AvangenioStatusTests/HistoryStoreTests.swift`

**Interfaces:**
- Consumes: `EnergySample`.
- Produces:
  - `protocol HistoryStoring: Sendable { func load() -> [EnergySample]; func append(_ sample: EnergySample) -> [EnergySample] }`
  - `final class HistoryStore: HistoryStoring` con `init(fileURL: URL? = nil, retention: TimeInterval = HistoryStore.retention)` y `static let retention: TimeInterval`.

- [ ] **Step 1: Escribir los tests que fallan**

Crear `AvangenioStatusTests/HistoryStoreTests.swift`:

```swift
import XCTest
@testable import AvangenioStatusKit

final class HistoryStoreTests: XCTestCase {
    private var fileURL: URL!

    override func setUp() {
        super.setUp()
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hist-\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL)
        super.tearDown()
    }

    private func sample(_ t: TimeInterval, battery: Double? = 50, power: PowerStatus = .on) -> EnergySample {
        EnergySample(timestamp: Date(timeIntervalSince1970: t), batteryPercent: battery, power: power)
    }

    func testMissingFileLoadsEmpty() {
        let store = HistoryStore(fileURL: fileURL)
        XCTAssertEqual(store.load(), [])
    }

    func testAppendThenLoadRoundTrip() {
        let store = HistoryStore(fileURL: fileURL)
        _ = store.append(sample(1000, battery: 62.5, power: .off))
        let reopened = HistoryStore(fileURL: fileURL)
        XCTAssertEqual(reopened.load(), [sample(1000, battery: 62.5, power: .off)])
    }

    func testAppendReturnsSeries() {
        let store = HistoryStore(fileURL: fileURL)
        _ = store.append(sample(1000))
        let result = store.append(sample(2000))
        XCTAssertEqual(result.map(\.timestamp.timeIntervalSince1970), [1000, 2000])
    }

    func testPrunesSamplesOlderThanRetention() {
        let store = HistoryStore(fileURL: fileURL, retention: 100)
        _ = store.append(sample(1000))          // viejo
        let result = store.append(sample(2000)) // corte = 2000 - 100 = 1900 → descarta 1000
        XCTAssertEqual(result.map(\.timestamp.timeIntervalSince1970), [2000])
    }

    func testCorruptFileLoadsEmpty() throws {
        try Data("basura no-json".utf8).write(to: fileURL)
        let store = HistoryStore(fileURL: fileURL)
        XCTAssertEqual(store.load(), [])
    }
}
```

- [ ] **Step 2: Verificar que falla**

Run: `make generate && make test 2>&1 | tail -30`
Expected: FALLA de compilación — `HistoryStore` no existe.

- [ ] **Step 3: Implementar `HistoryStore`**

Crear `AvangenioStatusKit/Domain/HistoryStore.swift`:

```swift
import Foundation
import os

/// Abstracción de persistencia del historial de energía (para inyección/tests).
public protocol HistoryStoring: Sendable {
    /// Serie persistida; vacía si no hay archivo o está corrupto.
    func load() -> [EnergySample]
    /// Añade una muestra, poda lo más viejo que la retención, persiste y
    /// devuelve la serie resultante.
    func append(_ sample: EnergySample) -> [EnergySample]
}

/// Persiste el historial como archivo JSON en Application Support (KTD7).
public final class HistoryStore: HistoryStoring, @unchecked Sendable {
    /// Retención: descarta muestras más viejas que esto (30 días).
    public static let retention: TimeInterval = 30 * 24 * 60 * 60

    private let fileURL: URL
    private let retention: TimeInterval
    private let log = Logger(subsystem: "com.avangenio.status", category: "HistoryStore")

    public init(fileURL: URL? = nil, retention: TimeInterval = HistoryStore.retention) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        self.retention = retention
    }

    public func load() -> [EnergySample] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([EnergySample].self, from: data)) ?? []
    }

    public func append(_ sample: EnergySample) -> [EnergySample] {
        let cutoff = sample.timestamp.addingTimeInterval(-retention)
        let pruned = (load() + [sample]).filter { $0.timestamp >= cutoff }
        persist(pruned)
        return pruned
    }

    private func persist(_ samples: [EnergySample]) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(samples)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            log.error("no se pudo persistir el historial: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("AvangenioStatus", isDirectory: true)
            .appendingPathComponent("energy-history.json")
    }
}
```

- [ ] **Step 4: Verificar que pasan**

Run: `make test 2>&1 | tail -30`
Expected: PASA.

- [ ] **Step 5: Commit** (pedir confirmación al usuario antes)

```bash
git add AvangenioStatusKit/Domain/HistoryStore.swift AvangenioStatusTests/HistoryStoreTests.swift AvangenioStatus.xcodeproj
git commit -m "feat: add HistoryStore JSON persistence with retention pruning"
```

---

### Task 5: Integrar el historial en `AppModel`

**Files:**
- Modify: `AvangenioStatusKit/App/AppModel.swift`
- Test: `AvangenioStatusTests/AppModelTests.swift`

**Interfaces:**
- Consumes: `HistoryStoring`, `EnergySample`, `HistoryStore`.
- Produces: `AppModel.init(..., historyStore: HistoryStoring = HistoryStore())` y propiedad observable `public private(set) var history: [EnergySample]`. Se añade muestra en `.updated` (con `status.fetchedAt`) y en `.notModified` (con el instante actual, a partir de `current`); NO en `.failed`.

- [ ] **Step 1: Añadir el fake y los tests que fallan**

En `AppModelTests.swift`, añadir el doble de historial (junto a `FakeFetcher`/`SpyNotifier`):

```swift
/// Store de historial falso: registra lo añadido y sirve una semilla.
final class FakeHistoryStore: HistoryStoring, @unchecked Sendable {
    private(set) var appended: [EnergySample] = []
    private var samples: [EnergySample]
    init(seed: [EnergySample] = []) { self.samples = seed }
    func load() -> [EnergySample] { samples }
    func append(_ sample: EnergySample) -> [EnergySample] {
        appended.append(sample)
        samples.append(sample)
        return samples
    }
}
```

Añadir estos tests a `AppModelTests`:

```swift
    func testUpdatedRecordsHistorySample() async {
        let history = FakeHistoryStore()
        let (model, _, _) = makeModel(
            fetcher: FakeFetcher([.updated(body: body(power: "NO"), etag: "e1")]),
            history: history
        )
        await model.refreshNow()
        XCTAssertEqual(history.appended.count, 1)
        XCTAssertEqual(history.appended.first?.power, .off)
        XCTAssertEqual(history.appended.first?.batteryPercent, 50)
        XCTAssertEqual(model.history.count, 1)
    }

    func testNotModifiedRecordsSampleFromCurrent() async {
        let history = FakeHistoryStore()
        let (model, _, _) = makeModel(
            fetcher: FakeFetcher([
                .updated(body: body(power: "NO"), etag: "e1"),
                .notModified,
            ]),
            history: history
        )
        await model.refreshNow()
        await model.refreshNow()
        XCTAssertEqual(history.appended.count, 2)
        XCTAssertEqual(history.appended.last?.power, .off)   // refleja el estado vigente
    }

    func testFailedFetchDoesNotRecordHistory() async {
        let history = FakeHistoryStore()
        let (model, _, _) = makeModel(
            fetcher: FakeFetcher([.failed(URLError(.timedOut))]),
            history: history
        )
        await model.refreshNow()
        XCTAssertTrue(history.appended.isEmpty)
        XCTAssertTrue(model.history.isEmpty)
    }

    func testSeedsHistoryFromStoreAtInit() {
        let seed = [EnergySample(timestamp: Date(timeIntervalSince1970: 1), batteryPercent: 30, power: .on)]
        let history = FakeHistoryStore(seed: seed)
        let (model, _, _) = makeModel(fetcher: FakeFetcher([.notModified]), history: history)
        XCTAssertEqual(model.history, seed)
    }
```

Actualizar el helper `makeModel(fetcher:store:)` para aceptar el store de historial (los tests existentes siguen compilando porque tiene valor por defecto):

```swift
    private func makeModel(
        fetcher: FakeFetcher,
        store: SettingsStore? = nil,
        history: HistoryStoring? = nil
    ) -> (AppModel, SpyNotifier, FakeFetcher) {
        let notifier = SpyNotifier()
        let model = AppModel(
            fetcher: fetcher,
            parser: StatusParser(),
            detector: EventDetector(),
            scheduleEngine: ScheduleEngine(),
            notifier: notifier,
            store: store ?? freshStore(),
            historyStore: history ?? FakeHistoryStore()
        )
        return (model, notifier, fetcher)
    }
```

- [ ] **Step 2: Verificar que falla**

Run: `make test 2>&1 | tail -30`
Expected: FALLA de compilación — `AppModel.init` no acepta `historyStore`; `model.history` no existe.

- [ ] **Step 3: Implementar la integración en `AppModel`**

En `AvangenioStatusKit/App/AppModel.swift`:

1. Añadir la propiedad observable junto a las demás (tras `notificationsAuthorized`):

```swift
    public private(set) var history: [EnergySample] = []
```

2. Añadir la dependencia junto a las otras (`private let store: SettingsStore`):

```swift
    private let historyStore: HistoryStoring
```

3. Añadir el parámetro al `init` (último, con valor por defecto) y asignarlo + sembrar `history`:

```swift
    public init(
        fetcher: StatusFetching = StatusFetcher(),
        parser: StatusParser = StatusParser(),
        detector: EventDetector = EventDetector(),
        scheduleEngine: ScheduleEngine = ScheduleEngine(),
        notifier: NotificationServing? = NotificationService(),
        store: SettingsStore = SettingsStore(),
        historyStore: HistoryStoring = HistoryStore()
    ) {
        self.fetcher = fetcher
        self.parser = parser
        self.detector = detector
        self.scheduleEngine = scheduleEngine
        self.notifier = notifier
        self.store = store
        self.historyStore = historyStore
        self.settings = store.loadSettings()
        self.schedules = store.loadSchedules()
        self.arming = store.loadArming()
        self.etag = store.loadEtag()
        self.lastScheduleCheck = store.loadLastScheduleCheck() ?? Date()
        self.history = historyStore.load()
        if let last = store.loadLastStatus() {
            self.current = last
            self.iconState = Self.iconState(for: last)
            self.lastCheckedAt = last.fetchedAt
        }
    }
```

4. Añadir el helper privado (p. ej. tras `iconState(for:)`):

```swift
    /// Registra una muestra de energía en el historial (persistente + observable).
    private func recordSample(from status: ServiceStatus, at timestamp: Date) {
        let sample = EnergySample(
            timestamp: timestamp,
            batteryPercent: status.batteryPercent,
            power: status.power
        )
        history = historyStore.append(sample)
    }
```

5. En `performPoll()`, caso `.notModified`, capturar el instante y registrar la muestra desde `current`:

```swift
        case .notModified:
            // El último cuerpo sigue vigente: restaurar el icono desde `current`.
            let now = Date()
            iconState = current.map(Self.iconState(for:)) ?? .unknown
            lastCheckedAt = now
            if let status = current {
                recordSample(from: status, at: now)
            }
```

6. En `performPoll()`, caso `.updated`, tras `iconState = Self.iconState(for: status)` (y antes del bloque de notificación), registrar la muestra:

```swift
            current = status
            store.save(lastStatus: status)
            iconState = Self.iconState(for: status)
            lastCheckedAt = status.fetchedAt
            recordSample(from: status, at: status.fetchedAt)
            if settings.notificationsEnabled, !events.isEmpty {
                notifier?.notify(events: events)
            }
```

- [ ] **Step 4: Verificar que pasan**

Run: `make test 2>&1 | tail -30`
Expected: PASA (toda la suite, incluidos los tests nuevos y los previos de `AppModelTests`).

- [ ] **Step 5: Commit** (pedir confirmación al usuario antes)

```bash
git add AvangenioStatusKit/App/AppModel.swift AvangenioStatusTests/AppModelTests.swift
git commit -m "feat: record energy history samples on each poll"
```

---

### Task 6: `HistoryView` + botón en el panel + ventana

**Files:**
- Create: `AvangenioStatus/Views/HistoryView.swift`
- Modify: `AvangenioStatus/Views/StatusPanelView.swift`
- Modify: `AvangenioStatus/AvangenioStatusApp.swift`

**Interfaces:**
- Consumes: `AppModel.history`, `HistoryChart.build(...)`, `HistoryChartData`, `HistoryRange`.
- Produces: escena `Window(id: "history")` y botón "Historial" que la abre.

Nota: es UI SwiftUI; no hay tests unitarios de vista en este repo (la lógica ya está cubierta por `HistoryChartTests`). La verificación es **compilación** + **humo manual**.

- [ ] **Step 1: Crear `HistoryView`**

Crear `AvangenioStatus/Views/HistoryView.swift`:

```swift
import SwiftUI
import Charts
import AvangenioStatusKit

/// Ventana dedicada: historial de energía. Batería como línea (con rupturas en
/// huecos) y electricidad como bandas de fondo (se sombrean los cortes).
struct HistoryView: View {
    @Bindable var model: AppModel
    @State private var range: HistoryRange = .week

    private var data: HistoryChartData {
        HistoryChart.build(samples: model.history, range: range, now: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if data.batterySegments.isEmpty && data.powerBands.isEmpty {
                emptyState
            } else {
                chart
                legend
            }
        }
        .padding(16)
        .frame(minWidth: 560, minHeight: 360)
    }

    private var header: some View {
        HStack {
            Text("Historial de energía").font(.headline)
            Spacer()
            Picker("Rango", selection: $range) {
                ForEach(HistoryRange.allCases, id: \.self) { r in
                    Text(r.label).tag(r)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
        }
    }

    private var chart: some View {
        Chart {
            ForEach(Array(data.powerBands.enumerated()), id: \.offset) { _, band in
                if band.state == .off {
                    RectangleMark(
                        xStart: .value("Inicio", band.start),
                        xEnd: .value("Fin", band.end),
                        yStart: .value("min", 0),
                        yEnd: .value("max", 100)
                    )
                    .foregroundStyle(Color.red.opacity(0.12))
                }
            }
            ForEach(Array(data.batterySegments.enumerated()), id: \.offset) { index, segment in
                ForEach(segment, id: \.timestamp) { point in
                    LineMark(
                        x: .value("Hora", point.timestamp),
                        y: .value("Batería", point.percent),
                        series: .value("Segmento", index)
                    )
                    .foregroundStyle(Color.accentColor)
                    .interpolationMethod(.monotone)
                }
            }
        }
        .chartYScale(domain: 0...100)
        .chartXScale(domain: data.start...data.end)
        .chartYAxisLabel("Batería (%)")
    }

    private var legend: some View {
        HStack(spacing: 16) {
            Label("Batería (%)", systemImage: "minus")
                .foregroundStyle(Color.accentColor)
            Label("Sin electricidad", systemImage: "square.fill")
                .foregroundStyle(Color.red.opacity(0.5))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.xyaxis.line").font(.largeTitle).foregroundStyle(.secondary)
            Text("Aún no hay suficientes datos").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 2: Añadir el botón "Historial" en el panel**

En `AvangenioStatus/Views/StatusPanelView.swift`, en `private var actions`, añadir el botón entre "Refrescar" y "Ajustes" (tras el `Spacer()`):

```swift
            Spacer()

            Button("Historial") {
                openWindow(id: "history")
                NSApp.activate(ignoringOtherApps: true)
            }

            Button("Ajustes") {
                openWindow(id: "settings")
                // App accesoria (LSUIElement): activar para traer la ventana al frente.
                NSApp.activate(ignoringOtherApps: true)
            }
```

- [ ] **Step 3: Registrar la ventana**

En `AvangenioStatus/AvangenioStatusApp.swift`, dentro de `body: some Scene`, tras la escena `Window("Ajustes…", id: "settings")`:

```swift
        Window("Historial de energía", id: "history") {
            HistoryView(model: appDelegate.model)
        }
        .windowResizability(.contentSize)
```

- [ ] **Step 4: Compilar y verificar**

Run: `make generate && make build 2>&1 | tail -30`
Expected: BUILD SUCCEEDED.

Humo manual: `make bundle && open dist/AvangenioStatus.app` → abrir el panel de la barra → "Historial" → aparece la ventana con el selector de rango y, tras al menos un poll, la línea de batería y (si hubo cortes) las bandas rojas. Sin datos, muestra "Aún no hay suficientes datos".

- [ ] **Step 5: Commit** (pedir confirmación al usuario antes)

```bash
git add AvangenioStatus/Views/HistoryView.swift AvangenioStatus/Views/StatusPanelView.swift AvangenioStatus/AvangenioStatusApp.swift AvangenioStatus.xcodeproj
git commit -m "feat: add energy history window with battery/power chart"
```

---

## Notas de cierre

- Tras completar las 6 tareas, correr la suite completa una vez más: `make test`.
- La densidad del gráfico depende del intervalo de poll y de que la app esté abierta; los huecos (app cerrada / offline) se dibujan como rupturas, no se interpolan.
- Retención fija de 30 días (`HistoryStore.retention`) y umbral de hueco de 25 min (`HistoryChart.defaultGapThreshold`): ambos son constantes de una línea si en el futuro se quieren configurar.

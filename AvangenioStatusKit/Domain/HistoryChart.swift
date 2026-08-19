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
            powerBands: powerBands(from: windowed, now: now),
            start: start,
            end: now
        )
    }

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

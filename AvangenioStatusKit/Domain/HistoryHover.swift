import Foundation

/// Tramo sin electricidad que contiene la muestra señalada por el cursor.
public struct OutageSpan: Equatable, Sendable {
    public let start: Date
    public let end: Date
    /// `true` cuando el tramo llega hasta el final del dominio (el corte sigue abierto).
    public let isOngoing: Bool

    public var duration: TimeInterval { end.timeIntervalSince(start) }

    public init(start: Date, end: Date, isOngoing: Bool) {
        self.start = start
        self.end = end
        self.isOngoing = isOngoing
    }
}

/// Lo que el lector puede decir sobre el instante señalado.
public enum HoverContent: Equatable, Sendable {
    /// Hay una muestra registrada: carga, servicio eléctrico y, dentro de un corte, su tramo.
    case reading(percent: Double, power: PowerStatus, outage: OutageSpan?)
    /// El cursor cae fuera de todo tramo continuo de muestras: no se inventa ningún valor.
    case noData
}

/// Resultado de resolver la posición del cursor contra el historial.
public struct HoverReading: Equatable, Sendable {
    /// Instante donde se dibuja la línea vertical: la muestra anclada, o el propio cursor
    /// cuando no hay datos que anclar.
    public let anchor: Date
    public let content: HoverContent

    public init(anchor: Date, content: HoverContent) {
        self.anchor = anchor
        self.content = content
    }
}

/// Traduce una posición temporal del cursor en lo que el lector debe mostrar.
/// Función pura, sin dependencias de SwiftUI ni del reloj.
public enum HistoryHover {
    public static func reading(at cursor: Date, in data: HistoryChartData) -> HoverReading {
        guard let segment = segment(containing: cursor, in: data.batterySegments),
              let point = nearestPoint(to: cursor, in: segment),
              let band = band(containing: point.timestamp, in: data.powerBands) else {
            return HoverReading(anchor: cursor, content: .noData)
        }

        return HoverReading(
            anchor: point.timestamp,
            content: .reading(
                percent: point.percent,
                power: band.state,
                outage: outage(
                    from: band,
                    domainEnd: data.end,
                    lastKnown: data.batterySegments.last?.last?.timestamp
                )
            )
        )
    }

    /// El tramo continuo cuyo intervalo cubre al cursor. Fuera de todos ellos hay un hueco:
    /// o la app no estaba corriendo, o el API no trajo la carga.
    private static func segment(
        containing cursor: Date,
        in segments: [[BatteryPoint]]
    ) -> [BatteryPoint]? {
        segments.first { segment in
            guard let first = segment.first, let last = segment.last else { return false }
            return cursor >= first.timestamp && cursor <= last.timestamp
        }
    }

    /// Muestra más próxima en el tiempo dentro del tramo, por búsqueda binaria sobre la
    /// serie ya ordenada (el cursor se resuelve en cada movimiento del mouse).
    private static func nearestPoint(to cursor: Date, in segment: [BatteryPoint]) -> BatteryPoint? {
        guard !segment.isEmpty else { return nil }

        var low = 0
        var high = segment.count - 1
        while low < high {
            let mid = (low + high) / 2
            if segment[mid].timestamp < cursor {
                low = mid + 1
            } else {
                high = mid
            }
        }

        let candidate = segment[low]
        guard low > 0 else { return candidate }

        let previous = segment[low - 1]
        let toCandidate = abs(candidate.timestamp.timeIntervalSince(cursor))
        let toPrevious = abs(previous.timestamp.timeIntervalSince(cursor))
        return toPrevious < toCandidate ? previous : candidate
    }

    /// Las bandas son contiguas y ordenadas, así que la última que empieza antes del
    /// instante buscado es la que lo contiene.
    private static func band(containing timestamp: Date, in bands: [PowerBand]) -> PowerBand? {
        bands.last { $0.start <= timestamp }
    }

    /// Un corte solo se declara "en curso" si el registro sigue vivo. Si la última muestra
    /// quedó vieja (app cerrada, equipo apagado), el tramo se recorta a lo último que se
    /// midió en vez de extrapolar horas que nadie observó.
    private static func outage(
        from band: PowerBand,
        domainEnd: Date,
        lastKnown: Date?
    ) -> OutageSpan? {
        guard band.state == .off else { return nil }

        let isFresh = lastKnown.map {
            domainEnd.timeIntervalSince($0) <= HistoryChart.defaultGapThreshold
        } ?? false

        let end = isFresh ? band.end : min(band.end, lastKnown ?? band.end)
        return OutageSpan(start: band.start, end: end, isOngoing: isFresh && band.end >= domainEnd)
    }
}

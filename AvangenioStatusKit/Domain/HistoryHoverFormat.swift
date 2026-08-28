import Foundation

/// Cadenas del lector del historial: hora del instante señalado y duración de un corte.
/// El porcentaje sigue saliendo de `MetricFormat.percent`, que ya es la fuente única.
public enum HistoryHoverFormat {
    /// Hora con minutos. En 7 y 30 días la hora sola es ambigua, así que se antepone la fecha.
    public static func timestamp(
        _ date: Date,
        range: HistoryRange,
        timeZone: TimeZone = .current
    ) -> String {
        formatter(pattern: range == .day ? "HH:mm" : "d MMM, HH:mm", timeZone: timeZone)
            .string(from: date)
    }

    /// Duración compacta en horas y minutos, ej. "3 h 20 min", "45 min", "2 h".
    public static func duration(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(max(0, interval) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours == 0 { return "\(minutes) min" }
        if minutes == 0 { return "\(hours) h" }
        return "\(hours) h \(minutes) min"
    }

    /// El lector se redibuja en cada movimiento del mouse, así que los formateadores se
    /// reutilizan en vez de construirse por llamada.
    private static let cache = FormatterCache()

    private static func formatter(pattern: String, timeZone: TimeZone) -> DateFormatter {
        cache.formatter(pattern: pattern, timeZone: timeZone)
    }

    private final class FormatterCache: @unchecked Sendable {
        private let lock = NSLock()
        private var formatters: [String: DateFormatter] = [:]

        func formatter(pattern: String, timeZone: TimeZone) -> DateFormatter {
            let key = "\(pattern)|\(timeZone.identifier)"
            lock.lock()
            defer { lock.unlock() }

            if let cached = formatters[key] { return cached }

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "es")
            formatter.timeZone = timeZone
            formatter.dateFormat = pattern
            formatters[key] = formatter
            return formatter
        }
    }
}

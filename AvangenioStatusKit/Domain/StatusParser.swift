import Foundation

/// Convierte el texto plano del API en un `ServiceStatus` tipado.
///
/// Formato esperado (5 líneas, tolerante a espaciado):
/// ```
/// Ultima actualizacion: Fri Aug  7 12:19:01 CDT 2026
/// Internet Status: OK
/// Ancho de Banda por Usuario: 4.42 Mbps
/// Estado de las baterías: 26.00%
/// Servicio Eléctrico Estatal: NO
/// ```
public struct StatusParser: Sendable {
    private let now: @Sendable () -> Date

    public init(now: @escaping @Sendable () -> Date = { Date() }) {
        self.now = now
    }

    /// Devuelve `nil` si el formato es irreconocible (sin crashear).
    /// Requiere al menos: última actualización, estado de internet y estado eléctrico.
    public func parse(_ text: String) -> ServiceStatus? {
        var lastUpdated: String?
        var internet: InternetStatus?
        var bandwidth: Double?
        var battery: Double?
        var power: PowerStatus?

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(rawLine)
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].lowercased().trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)

            if key.contains("actualiz") {
                lastUpdated = value
            } else if key.contains("internet") {
                internet = value.uppercased() == "OK" ? .ok : .down
            } else if key.contains("ancho de banda") {
                bandwidth = Self.firstNumber(in: value)
            } else if key.contains("bater") {          // baterías / baterias
                battery = Self.firstNumber(in: value)
            } else if key.contains("ctrico") {          // eléctrico / electrico
                power = value.uppercased() == "YES" ? .on : .off
            }
        }

        guard let lastUpdated, !lastUpdated.isEmpty,
              let internet, let power else { return nil }

        return ServiceStatus(
            lastUpdatedRaw: lastUpdated,
            internet: internet,
            bandwidthMbps: bandwidth,
            batteryPercent: battery,
            power: power,
            fetchedAt: now()
        )
    }

    /// Extrae el primer número contiguo (con punto o coma decimal) de un texto.
    /// "4.42 Mbps" → 4.42 · "26.00%" → 26.0 · "26%" → 26.0 · sin dígitos → nil.
    static func firstNumber(in text: String) -> Double? {
        var current = ""
        for ch in text {
            if ch.isNumber {
                current.append(ch)
            } else if ch == "." || ch == "," {
                current.append(".")
            } else if !current.isEmpty {
                break
            }
        }
        return Double(current)
    }
}

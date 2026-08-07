import Foundation

/// Estado del servicio de internet reportado por el API.
public enum InternetStatus: String, Codable, Sendable {
    case ok
    case down
}

/// Servicio eléctrico estatal (YES/NO en el API).
public enum PowerStatus: String, Codable, Sendable {
    case on
    case off
}

/// Instantánea tipada de las métricas del API de Avangenio.
///
/// Las 4 métricas de estado (internet, ancho de banda, baterías, electricidad)
/// más la marca de "última actualización" reportada y el instante local de fetch.
public struct ServiceStatus: Codable, Equatable, Sendable {
    /// Texto crudo de "Ultima actualizacion" tal cual lo reporta el API (zona CDT).
    public var lastUpdatedRaw: String
    public var internet: InternetStatus
    /// Ancho de banda por usuario en Mbps; `nil` si el API no lo trae parseable.
    public var bandwidthMbps: Double?
    /// Porcentaje de baterías de respaldo; `nil` si no viene parseable.
    public var batteryPercent: Double?
    public var power: PowerStatus
    /// Instante local en que la app obtuvo estos datos.
    public var fetchedAt: Date

    public init(
        lastUpdatedRaw: String,
        internet: InternetStatus,
        bandwidthMbps: Double?,
        batteryPercent: Double?,
        power: PowerStatus,
        fetchedAt: Date
    ) {
        self.lastUpdatedRaw = lastUpdatedRaw
        self.internet = internet
        self.bandwidthMbps = bandwidthMbps
        self.batteryPercent = batteryPercent
        self.power = power
        self.fetchedAt = fetchedAt
    }
}

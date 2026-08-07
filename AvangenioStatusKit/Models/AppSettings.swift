import Foundation

/// Ajustes configurables por el usuario, persistidos en `UserDefaults`.
public struct AppSettings: Codable, Equatable, Sendable {
    /// Umbral de baterías (%). Por defecto 30 (KTD3).
    public var batteryThreshold: Double
    /// Umbral de ancho de banda (Mbps). Por defecto 1.0 (KTD3).
    public var bandwidthThresholdMbps: Double
    /// Intervalo de polling en minutos. Por defecto 10 (R2).
    public var pollingMinutes: Int
    /// Toggle general de avisos: silencia eventos **y** reportes programados (R9).
    public var notificationsEnabled: Bool

    public init(
        batteryThreshold: Double = 30,
        bandwidthThresholdMbps: Double = 1.0,
        pollingMinutes: Int = 10,
        notificationsEnabled: Bool = true
    ) {
        self.batteryThreshold = batteryThreshold
        self.bandwidthThresholdMbps = bandwidthThresholdMbps
        self.pollingMinutes = pollingMinutes
        self.notificationsEnabled = notificationsEnabled
    }
}

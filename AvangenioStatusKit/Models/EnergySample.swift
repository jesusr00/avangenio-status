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

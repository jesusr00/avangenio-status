import Foundation

/// Flags de histéresis por métrica de umbral.
///
/// Una métrica "armada" puede disparar un aviso al cruzar a la baja; tras disparar
/// se desarma hasta que la métrica vuelve a superar el umbral (evita spam en cada poll).
public struct ArmingState: Codable, Equatable, Sendable {
    public var batteryArmed: Bool
    public var bandwidthArmed: Bool

    public init(batteryArmed: Bool = true, bandwidthArmed: Bool = true) {
        self.batteryArmed = batteryArmed
        self.bandwidthArmed = bandwidthArmed
    }
}

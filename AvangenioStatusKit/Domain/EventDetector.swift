import Foundation

/// Compara el estado previo con el actual y produce los eventos a notificar,
/// aplicando histéresis por umbral (KTD4). Función pura, sin I/O.
public struct EventDetector: Sendable {
    public init() {}

    /// - Parameters:
    ///   - previous: última lectura conocida, o `nil` en el primer arranque (línea base).
    ///   - current: lectura nueva.
    ///   - settings: umbrales vigentes.
    ///   - arming: flags de armado por métrica.
    /// - Returns: eventos detectados y el nuevo estado de armado.
    public func detect(
        previous: ServiceStatus?,
        current: ServiceStatus,
        settings: AppSettings,
        arming: ArmingState
    ) -> (events: [StatusEvent], arming: ArmingState) {
        // Primer arranque: no se emiten eventos, solo se fija la línea base de armado.
        guard let previous else {
            return ([], Self.rearm(current: current, settings: settings, arming: arming))
        }

        var events: [StatusEvent] = []
        var arming = arming

        if current.power != previous.power {
            events.append(.powerChanged(to: current.power))
        }
        if current.internet != previous.internet {
            events.append(.internetChanged(to: current.internet))
        }

        if let battery = current.batteryPercent {
            if battery < settings.batteryThreshold {
                if arming.batteryArmed {
                    events.append(.batteryBelowThreshold(value: battery, threshold: settings.batteryThreshold))
                    arming.batteryArmed = false
                }
            } else {
                arming.batteryArmed = true   // re-arme al recuperar
            }
        }

        if let bandwidth = current.bandwidthMbps {
            if bandwidth < settings.bandwidthThresholdMbps {
                if arming.bandwidthArmed {
                    events.append(.bandwidthBelowThreshold(value: bandwidth, threshold: settings.bandwidthThresholdMbps))
                    arming.bandwidthArmed = false
                }
            } else {
                arming.bandwidthArmed = true
            }
        }

        return (events, arming)
    }

    /// Fija el armado según la línea base: armado si la métrica está por encima del umbral,
    /// desarmado si ya está por debajo (así no se dispara mientras se mantiene bajo sin cruce).
    static func rearm(current: ServiceStatus, settings: AppSettings, arming: ArmingState) -> ArmingState {
        var arming = arming
        if let battery = current.batteryPercent {
            arming.batteryArmed = battery >= settings.batteryThreshold
        }
        if let bandwidth = current.bandwidthMbps {
            arming.bandwidthArmed = bandwidth >= settings.bandwidthThresholdMbps
        }
        return arming
    }
}

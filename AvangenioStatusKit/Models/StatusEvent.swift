import Foundation

/// Un cambio de estado digno de notificar, detectado al comparar dos lecturas.
public enum StatusEvent: Equatable, Sendable {
    /// El servicio eléctrico estatal cambió de estado.
    case powerChanged(to: PowerStatus)
    /// El estado de internet cambió (cayó o se recuperó).
    case internetChanged(to: InternetStatus)
    /// Las baterías cruzaron a la baja el umbral configurado.
    case batteryBelowThreshold(value: Double, threshold: Double)
    /// El ancho de banda cruzó a la baja el umbral configurado.
    case bandwidthBelowThreshold(value: Double, threshold: Double)
}

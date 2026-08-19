import Foundation

/// Ventana temporal seleccionable para el historial de energía.
public enum HistoryRange: CaseIterable, Sendable {
    case day    // 24 h
    case week   // 7 días
    case month  // 30 días

    /// Duración hacia atrás desde "ahora".
    public var duration: TimeInterval {
        switch self {
        case .day:   return 24 * 60 * 60
        case .week:  return 7 * 24 * 60 * 60
        case .month: return 30 * 24 * 60 * 60
        }
    }

    /// Etiqueta corta para el selector.
    public var label: String {
        switch self {
        case .day:   return "24 h"
        case .week:  return "7 días"
        case .month: return "30 días"
        }
    }
}

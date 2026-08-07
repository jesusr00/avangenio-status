import SwiftUI
import AvangenioStatusKit

/// Icono de la barra de menú: distingue el estado por **forma (SF Symbol) y color**,
/// no solo por color (daltonismo / rendering monocromo) (R4).
struct StatusIcon: View {
    let model: AppModel

    var body: some View {
        Image(systemName: symbol)
            .foregroundStyle(color)
            .accessibilityLabel(label)
    }

    private var symbol: String {
        switch model.iconState {
        case .ok: return "checkmark.circle.fill"
        case .alert: return "exclamationmark.triangle.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    private var color: Color {
        switch model.iconState {
        case .ok: return .green
        case .alert: return .red
        case .unknown: return .secondary
        }
    }

    private var label: String {
        switch model.iconState {
        case .ok: return "Avangenio: todo OK"
        case .alert: return "Avangenio: alerta"
        case .unknown: return "Avangenio: sin conexión"
        }
    }
}

import SwiftUI
import AvangenioStatusKit

/// Caja flotante del historial: lo que hay en el instante señalado por el cursor.
/// En un hueco muestra solo la hora y "Sin datos"; nunca completa lo que no se registró.
struct HoverReadoutBox: View {
    let reading: HoverReading
    let range: HistoryRange

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(HistoryHoverFormat.timestamp(reading.anchor, range: range))
                .font(.caption.weight(.semibold))

            switch reading.content {
            case .noData:
                Text("Sin datos").font(.caption).foregroundStyle(.secondary)

            case let .reading(percent, power, outage):
                Text("Batería \(MetricFormat.percent(percent))").font(.caption)
                Text(power == .off ? "Sin electricidad" : "Con electricidad")
                    .font(.caption)
                    .foregroundStyle(power == .off ? Color.red : Color.green)
                if let outage {
                    Text(outageText(outage)).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7).stroke(Color.secondary.opacity(0.25))
        )
        .shadow(radius: 5, y: 2)
    }

    private func outageText(_ outage: OutageSpan) -> String {
        let start = HistoryHoverFormat.timestamp(outage.start, range: range)
        let duration = HistoryHoverFormat.duration(outage.duration)

        if outage.isOngoing {
            return "Corte desde \(start) · \(duration) en curso"
        }
        let end = HistoryHoverFormat.timestamp(outage.end, range: range)
        return "Corte \(start) → \(end) · \(duration)"
    }
}

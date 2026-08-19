import SwiftUI
import Charts
import AvangenioStatusKit

/// Ventana dedicada: historial de energía. Batería como línea (con rupturas en
/// huecos) y electricidad como bandas de fondo (se sombrean los cortes).
struct HistoryView: View {
    @Bindable var model: AppModel
    @State private var range: HistoryRange = .week

    private var data: HistoryChartData {
        HistoryChart.build(samples: model.history, range: range, now: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if data.batterySegments.isEmpty && data.powerBands.isEmpty {
                emptyState
            } else {
                chart
                legend
            }
        }
        .padding(16)
        .frame(minWidth: 560, minHeight: 360)
    }

    private var header: some View {
        HStack {
            Text("Historial de energía").font(.headline)
            Spacer()
            Picker("Rango", selection: $range) {
                ForEach(HistoryRange.allCases, id: \.self) { r in
                    Text(r.label).tag(r)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()
        }
    }

    private var chart: some View {
        Chart {
            ForEach(Array(data.powerBands.enumerated()), id: \.offset) { _, band in
                if band.state == .off {
                    RectangleMark(
                        xStart: .value("Inicio", band.start),
                        xEnd: .value("Fin", band.end),
                        yStart: .value("min", 0),
                        yEnd: .value("max", 100)
                    )
                    .foregroundStyle(Color.red.opacity(0.12))
                }
            }
            ForEach(Array(data.batterySegments.enumerated()), id: \.offset) { index, segment in
                ForEach(segment, id: \.timestamp) { point in
                    LineMark(
                        x: .value("Hora", point.timestamp),
                        y: .value("Batería", point.percent),
                        series: .value("Segmento", index)
                    )
                    .foregroundStyle(Color.accentColor)
                    .interpolationMethod(.monotone)
                }
            }
        }
        .chartYScale(domain: 0...100)
        .chartXScale(domain: data.start...data.end)
        .chartYAxisLabel("Batería (%)")
    }

    private var legend: some View {
        HStack(spacing: 16) {
            Label("Batería (%)", systemImage: "minus")
                .foregroundStyle(Color.accentColor)
            Label("Sin electricidad", systemImage: "square.fill")
                .foregroundStyle(Color.red.opacity(0.5))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.xyaxis.line").font(.largeTitle).foregroundStyle(.secondary)
            Text("Aún no hay suficientes datos").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

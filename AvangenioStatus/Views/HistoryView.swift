import SwiftUI
import Charts
import AvangenioStatusKit

/// Ventana dedicada: historial de energía. Batería como línea (con rupturas en
/// huecos) y electricidad como bandas de fondo (se sombrean los cortes).
struct HistoryView: View {
    @Bindable var model: AppModel
    @State private var range: HistoryRange = .week
    @State private var hover: HoverReading?

    var body: some View {
        // Se construye una sola vez por render: el lector resuelve contra estos mismos
        // datos, en lugar de recalcularlos en cada movimiento del mouse.
        let data = HistoryChart.build(samples: model.history, range: range, now: Date())

        return VStack(alignment: .leading, spacing: 12) {
            header
            if data.batterySegments.isEmpty && data.powerBands.isEmpty {
                emptyState
            } else {
                chart(data)
                legend
            }
        }
        .padding(16)
        .frame(minWidth: 560, minHeight: 360)
        .onChange(of: range) { hover = nil }
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

    private func chart(_ data: HistoryChartData) -> some View {
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
            if let hover {
                RuleMark(x: .value("Hora", hover.anchor))
                    .foregroundStyle(Color.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                if case let .reading(percent, _, _) = hover.content {
                    PointMark(
                        x: .value("Hora", hover.anchor),
                        y: .value("Batería", percent)
                    )
                    .foregroundStyle(Color.accentColor)
                    .symbolSize(60)
                }
            }
        }
        .chartYScale(domain: 0...100)
        .chartXScale(domain: data.start...data.end)
        .chartYAxisLabel("Batería (%)")
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            hover = reading(at: location, proxy: proxy, geometry: geometry, data: data)
                        case .ended:
                            hover = nil
                        }
                    }
            }
        }
    }

    /// Traduce la posición del cursor a la lectura del dominio. Devuelve `nil` fuera del
    /// área de trazado para que no quede un crosshair colgado.
    private func reading(
        at location: CGPoint,
        proxy: ChartProxy,
        geometry: GeometryProxy,
        data: HistoryChartData
    ) -> HoverReading? {
        guard let plotAnchor = proxy.plotFrame else { return nil }
        let plot = geometry[plotAnchor]
        guard plot.contains(location) else { return nil }

        guard let date = proxy.value(atX: location.x - plot.minX, as: Date.self) else { return nil }
        return HistoryHover.reading(at: date, in: data)
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

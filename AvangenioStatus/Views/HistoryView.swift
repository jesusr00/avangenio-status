import SwiftUI
import Charts
import AvangenioStatusKit

/// Ventana dedicada: historial de energía. Batería como línea (con rupturas en
/// huecos) y electricidad como bandas de fondo (se sombrean los cortes).
struct HistoryView: View {
    @Bindable var model: AppModel
    @State private var range: HistoryRange = .week
    @State private var hover: HoverReading?
    @State private var hoverLocation: CGPoint?
    @State private var readoutSize: CGSize = .zero

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
        .onChange(of: range) { clearHover() }
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
                            if let found = reading(at: location, proxy: proxy, geometry: geometry, data: data) {
                                hover = found
                                hoverLocation = location
                            } else {
                                clearHover()
                            }
                        case .ended:
                            clearHover()
                        }
                    }

                if let hover, let hoverLocation {
                    HoverReadoutBox(reading: hover, range: range)
                        .background(
                            GeometryReader { box in
                                Color.clear.preference(key: ReadoutSizeKey.self, value: box.size)
                            }
                        )
                        .offset(readoutOffset(for: hoverLocation, in: geometry.size))
                        .allowsHitTesting(false)
                }
            }
            .onPreferenceChange(ReadoutSizeKey.self) { readoutSize = $0 }
        }
    }

    private func clearHover() {
        hover = nil
        hoverLocation = nil
    }

    /// La caja se coloca arriba a la derecha del cursor y se voltea contra los bordes
    /// para no salirse de la ventana.
    private func readoutOffset(for location: CGPoint, in container: CGSize) -> CGSize {
        let margin: CGFloat = 12

        var x = location.x + margin
        if x + readoutSize.width > container.width {
            x = location.x - margin - readoutSize.width
        }
        x = min(max(0, x), max(0, container.width - readoutSize.width))

        var y = location.y - margin - readoutSize.height
        if y < 0 {
            y = location.y + margin
        }
        y = min(max(0, y), max(0, container.height - readoutSize.height))

        return CGSize(width: x, height: y)
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

/// Ancho y alto reales de la caja del lector, para poder voltearla contra los bordes.
private struct ReadoutSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

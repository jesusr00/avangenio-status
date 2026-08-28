import SwiftUI
import Charts
import AvangenioStatusKit

/// Ventana dedicada: historial de energía. Batería como línea (con rupturas en
/// huecos) y electricidad como bandas de fondo (se sombrean los cortes).
struct HistoryView: View {
    @Bindable var model: AppModel
    @State private var range: HistoryRange = .week
    @State private var data: HistoryChartData?
    @State private var hover: HoverReading?
    @State private var hoverLocation: CGPoint?
    @State private var readoutSize: CGSize = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if let data, !(data.batterySegments.isEmpty && data.powerBands.isEmpty) {
                chart(data)
                legend
            } else {
                emptyState
            }
        }
        .padding(16)
        .frame(minWidth: 560, minHeight: 360)
        .onAppear { rebuild() }
        .onChange(of: range) {
            clearHover()
            rebuild()
        }
        // La serie es de solo-añadir: basta con mirar la última muestra para saber
        // que llegó un poll nuevo.
        .onChange(of: model.history.last?.timestamp) { rebuild() }
    }

    /// Los datos se derivan al abrir y en cada poll, no dentro de `body`: mover el mouse
    /// invalida el estado del hover en cada evento y no debe rehacer la serie completa.
    private func rebuild() {
        data = HistoryChart.build(samples: model.history, range: range, now: Date())
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
                    let origin = HistoryHoverLayout.readoutOrigin(
                        cursor: hoverLocation,
                        boxSize: readoutSize,
                        container: geometry.size
                    )
                    HoverReadoutBox(reading: hover, range: range)
                        .background(
                            GeometryReader { box in
                                Color.clear.preference(key: ReadoutSizeKey.self, value: box.size)
                            }
                        )
                        .offset(x: origin.x, y: origin.y)
                        // Sin medida todavía no se sabe hacia dónde voltear: se oculta ese
                        // primer cuadro en vez de dibujarla en el sitio equivocado.
                        .opacity(readoutSize == .zero ? 0 : 1)
                        .allowsHitTesting(false)
                }
            }
            // El desmontaje reporta cero; conservar la última medida real evita que la
            // caja vuelva a aparecer sin voltear al reentrar.
            .onPreferenceChange(ReadoutSizeKey.self) { size in
                if size != .zero { readoutSize = size }
            }
        }
    }

    private func clearHover() {
        hover = nil
        hoverLocation = nil
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

import SwiftUI
import AvangenioStatusKit

/// Panel desplegable de la barra de menú: 4 métricas de estado + hora de última
/// actualización, con estados de carga y desconexión explícitos (R5).
struct StatusPanelView: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @State private var isRefreshing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            Divider()

            if let status = model.current {
                metrics(for: status)
                    .opacity(isDisconnected ? 0.5 : 1)
                if isDisconnected {
                    Label("Sin conexión · mostrando último estado", systemImage: "wifi.slash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if model.lastCheckedAt == nil {
                Label("Cargando…", systemImage: "arrow.triangle.2.circlepath")
                    .foregroundStyle(.secondary)
            } else {
                Label("Sin conexión con el API", systemImage: "wifi.slash")
                    .foregroundStyle(.secondary)
            }

            Divider()

            actions
        }
        .padding(12)
        .frame(width: 280)
    }

    private var isDisconnected: Bool {
        model.iconState == .unknown && model.current != nil
    }

    private var header: some View {
        HStack(spacing: 8) {
            LogoBadge(size: 26)
            Text("Avangenio Status").font(.headline)
            Spacer()
            StatusIcon(model: model)
        }
    }

    private func metrics(for status: ServiceStatus) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            row("Internet", value: status.internet == .ok ? "OK" : "Caído",
                ok: status.internet == .ok)
            row("Ancho de banda",
                value: status.bandwidthMbps.map(MetricFormat.mbps) ?? "—")
            row("Baterías",
                value: status.batteryPercent.map(MetricFormat.percent) ?? "—")
            row("Electricidad", value: status.power == .on ? "Sí" : "No",
                ok: status.power == .on)
            row("Actualizado", value: DateDisplay.spanish(fromAPITimestamp: status.lastUpdatedRaw))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func row(_ label: String, value: String, ok: Bool? = nil) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(ok == false ? Color.red : .primary)
                .fontWeight(ok == false ? .semibold : .regular)
        }
    }

    private var actions: some View {
        HStack {
            Button {
                Task {
                    isRefreshing = true
                    await model.refreshNow()
                    isRefreshing = false
                }
            } label: {
                Label("Refrescar", systemImage: "arrow.clockwise")
            }
            .disabled(isRefreshing)

            Spacer()

            Button("Historial") {
                openWindow(id: "history")
                NSApp.activate(ignoringOtherApps: true)
            }

            Button("Ajustes") {
                openWindow(id: "settings")
                // App accesoria (LSUIElement): activar para traer la ventana al frente.
                NSApp.activate(ignoringOtherApps: true)
            }

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .help("Salir")
        }
    }
}

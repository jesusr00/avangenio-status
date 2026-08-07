import SwiftUI
import AvangenioStatusKit

/// Ajustes: umbrales, polling, avisos, arranque al login, estado del permiso y schedules (R9, R10, R12).
struct SettingsView: View {
    @Bindable var model: AppModel
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchError: String?
    @State private var editing: Schedule?

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        LogoBadge(size: 56)
                        Text("Avangenio Status").font(.headline)
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
                .listRowBackground(Color.clear)
            }

            Section("Umbrales de aviso") {
                LabeledContent("Baterías") {
                    HStack {
                        Slider(value: $model.settings.batteryThreshold, in: 0...100, step: 1)
                        Text("\(Int(model.settings.batteryThreshold))%").monospacedDigit().frame(width: 44, alignment: .trailing)
                    }
                }
                LabeledContent("Ancho de banda") {
                    HStack {
                        Slider(value: $model.settings.bandwidthThresholdMbps, in: 0...20, step: 0.5)
                        Text(String(format: "%.1f Mbps", model.settings.bandwidthThresholdMbps))
                            .monospacedDigit().frame(width: 70, alignment: .trailing)
                    }
                }
            }

            Section("Consulta") {
                Stepper("Cada \(model.settings.pollingMinutes) min",
                        value: $model.settings.pollingMinutes, in: 1...120)
                Toggle("Avisos (eventos y reportes)", isOn: $model.settings.notificationsEnabled)
                Toggle("Arrancar al iniciar sesión", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            try LaunchAtLogin.setEnabled(newValue)
                            launchError = nil
                        } catch {
                            launchError = error.localizedDescription
                            launchAtLogin = LaunchAtLogin.isEnabled
                        }
                    }
                if let launchError {
                    Text(launchError).font(.caption).foregroundStyle(.red)
                }
            }

            Section("Notificaciones") {
                if model.notificationsAuthorized {
                    Label("Permiso concedido", systemImage: "checkmark.seal")
                        .foregroundStyle(.green)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Notificaciones desactivadas — no recibirás avisos",
                              systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Button("Abrir Ajustes del sistema") {
                            model.openSystemNotificationSettings()
                        }
                    }
                }
            }

            Section("Reportes programados") {
                if model.schedules.isEmpty {
                    Text("Sin reportes programados.").foregroundStyle(.secondary)
                }
                ForEach($model.schedules) { $schedule in
                    HStack {
                        Toggle("", isOn: $schedule.isEnabled).labelsHidden()
                        VStack(alignment: .leading) {
                            Text(Self.describe(schedule.mode)).font(.body)
                            Text(Self.describe(schedule.weekdays)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            editing = schedule
                        } label: { Image(systemName: "pencil") }
                        Button(role: .destructive) {
                            model.schedules.removeAll { $0.id == schedule.id }
                        } label: { Image(systemName: "trash") }
                    }
                }
                Button {
                    let new = Schedule(weekdays: Weekday.weekdays, mode: .fixedTime(hour: 9, minute: 0))
                    editing = new
                } label: {
                    Label("Añadir reporte", systemImage: "plus")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 560)
        .task { await model.refreshAuthorization() }
        .sheet(item: $editing) { schedule in
            ScheduleEditorView(schedule: schedule) { saved in
                if let index = model.schedules.firstIndex(where: { $0.id == saved.id }) {
                    model.schedules[index] = saved
                } else {
                    model.schedules.append(saved)
                }
            }
        }
    }

    // MARK: - Descripciones legibles

    static func describe(_ mode: ScheduleMode) -> String {
        switch mode {
        case let .fixedTime(hour, minute):
            return String(format: "A las %02d:%02d", hour, minute)
        case let .range(startHour, startMinute, endHour, endMinute, everyHours):
            return String(format: "De %02d:%02d a %02d:%02d cada %dh",
                          startHour, startMinute, endHour, endMinute, everyHours)
        }
    }

    static func describe(_ weekdays: Set<Weekday>) -> String {
        Weekday.displayOrdered
            .filter(weekdays.contains)
            .map(\.shortName)
            .joined(separator: " ")
    }
}

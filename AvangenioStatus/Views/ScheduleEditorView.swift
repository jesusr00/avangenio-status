import SwiftUI
import AvangenioStatusKit

/// Editor de un reporte programado: días, y modo hora fija vs rango con intervalo.
struct ScheduleEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (Schedule) -> Void

    @State private var isEnabled: Bool
    @State private var weekdays: Set<Weekday>
    @State private var isRange: Bool
    @State private var startHour: Int
    @State private var startMinute: Int
    @State private var endHour: Int
    @State private var endMinute: Int
    @State private var everyHours: Int
    private let id: UUID

    init(schedule: Schedule, onSave: @escaping (Schedule) -> Void) {
        self.onSave = onSave
        self.id = schedule.id
        _isEnabled = State(initialValue: schedule.isEnabled)
        _weekdays = State(initialValue: schedule.weekdays)
        switch schedule.mode {
        case let .fixedTime(hour, minute):
            _isRange = State(initialValue: false)
            _startHour = State(initialValue: hour)
            _startMinute = State(initialValue: minute)
            _endHour = State(initialValue: 18)
            _endMinute = State(initialValue: 0)
            _everyHours = State(initialValue: 2)
        case let .range(sh, sm, eh, em, every):
            _isRange = State(initialValue: true)
            _startHour = State(initialValue: sh)
            _startMinute = State(initialValue: sm)
            _endHour = State(initialValue: eh)
            _endMinute = State(initialValue: em)
            _everyHours = State(initialValue: every)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reporte programado").font(.headline)

            weekdayPicker

            Picker("Modo", selection: $isRange) {
                Text("Hora fija").tag(false)
                Text("Rango con intervalo").tag(true)
            }
            .pickerStyle(.segmented)

            timeControls

            if let error = validationError {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancelar") { dismiss() }
                Button("Guardar") {
                    onSave(makeSchedule())
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(validationError != nil)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private var weekdayPicker: some View {
        HStack(spacing: 6) {
            ForEach(Weekday.displayOrdered, id: \.self) { day in
                let selected = weekdays.contains(day)
                Button(day.shortName) {
                    if selected { weekdays.remove(day) } else { weekdays.insert(day) }
                }
                .buttonStyle(.bordered)
                .tint(selected ? .accentColor : .gray)
            }
        }
    }

    @ViewBuilder
    private var timeControls: some View {
        Stepper("Inicio: \(twoDigit(startHour)):\(twoDigit(startMinute))", value: $startHour, in: 0...23)
        Stepper("Minuto inicio: \(twoDigit(startMinute))", value: $startMinute, in: 0...59, step: 5)
        if isRange {
            Stepper("Fin: \(twoDigit(endHour)):\(twoDigit(endMinute))", value: $endHour, in: 0...23)
            Stepper("Minuto fin: \(twoDigit(endMinute))", value: $endMinute, in: 0...59, step: 5)
            Stepper("Cada \(everyHours) h", value: $everyHours, in: 1...12)
        }
    }

    // MARK: - Lógica

    private var validationError: String? {
        if weekdays.isEmpty { return "Selecciona al menos un día." }
        if isRange {
            let start = startHour * 60 + startMinute
            let end = endHour * 60 + endMinute
            if end <= start { return "La hora de fin debe ser posterior a la de inicio." }
        }
        return nil
    }

    private func makeSchedule() -> Schedule {
        let mode: ScheduleMode = isRange
            ? .range(startHour: startHour, startMinute: startMinute,
                     endHour: endHour, endMinute: endMinute, everyHours: everyHours)
            : .fixedTime(hour: startHour, minute: startMinute)
        return Schedule(id: id, isEnabled: isEnabled, weekdays: weekdays, mode: mode)
    }

    private func twoDigit(_ value: Int) -> String { String(format: "%02d", value) }
}

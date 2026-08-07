import Foundation

/// Calcula disparos de reportes programados en hora local (KTD6, KD6). Función pura,
/// con `Calendar` inyectable para testear de forma determinista.
public struct ScheduleEngine: Sendable {
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Próximo instante de disparo estrictamente posterior a `now`, entre todos los
    /// schedules habilitados; `nil` si no hay ninguno.
    public func nextFireDate(after now: Date, schedules: [Schedule]) -> Date? {
        schedules
            .filter(\.isEnabled)
            .compactMap { nextFire(after: now, schedule: $0) }
            .min()
    }

    /// Disparos vencidos en el intervalo `(since, until]` (para recuperar tras suspensión).
    public func missedFires(since: Date, until: Date, schedules: [Schedule]) -> [Date] {
        guard until > since else { return [] }
        var result: [Date] = []
        for schedule in schedules where schedule.isEnabled {
            var cursor = since
            while let next = nextFire(after: cursor, schedule: schedule), next <= until {
                result.append(next)
                cursor = next
            }
        }
        return result.sorted()
    }

    // MARK: - Internos

    /// Próximo disparo de un schedule, buscando hasta 8 días adelante.
    func nextFire(after now: Date, schedule: Schedule) -> Date? {
        let startOfToday = calendar.startOfDay(for: now)
        for dayOffset in 0..<8 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else { continue }
            let weekdayValue = calendar.component(.weekday, from: day)
            guard let weekday = Weekday(rawValue: weekdayValue),
                  schedule.weekdays.contains(weekday) else { continue }

            for time in fireTimes(for: schedule.mode) {
                // `date(bySettingHour:)` devuelve nil si la hora no existe ese día
                // (hueco de cambio de horario / DST); en ese caso usamos el siguiente
                // instante válido que coincida con esa hora, en vez de saltarlo.
                let fire = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: day)
                    ?? calendar.nextDate(
                        after: day,
                        matching: DateComponents(hour: time.hour, minute: time.minute),
                        matchingPolicy: .nextTime
                    )
                if let fire, fire > now {
                    return fire
                }
            }
        }
        return nil
    }

    /// Horas de disparo dentro de un día, en orden ascendente.
    func fireTimes(for mode: ScheduleMode) -> [(hour: Int, minute: Int)] {
        switch mode {
        case let .fixedTime(hour, minute):
            return [(hour, minute)]
        case let .range(startHour, startMinute, endHour, endMinute, everyHours):
            guard everyHours > 0 else { return [] }
            let startMinutes = startHour * 60 + startMinute
            let endMinutes = endHour * 60 + endMinute
            var times: [(hour: Int, minute: Int)] = []
            var minutes = startMinutes
            while minutes <= endMinutes {
                times.append((minutes / 60, minutes % 60))
                minutes += everyHours * 60
            }
            return times
        }
    }
}

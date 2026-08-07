import Foundation

/// Día de la semana. Los raw values coinciden con `Calendar.component(.weekday)`
/// en el calendario Gregoriano (1 = domingo … 7 = sábado).
public enum Weekday: Int, Codable, CaseIterable, Sendable, Comparable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Días hábiles (lunes a viernes), atajo común para schedules.
    public static var weekdays: Set<Weekday> { [.monday, .tuesday, .wednesday, .thursday, .friday] }

    /// Orden de presentación canónico (lunes primero), fuente única para las vistas.
    public static var displayOrdered: [Weekday] {
        [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    }

    /// Etiqueta corta canónica (fuente única para las vistas).
    public var shortName: String {
        switch self {
        case .monday: return "L"
        case .tuesday: return "M"
        case .wednesday: return "X"
        case .thursday: return "J"
        case .friday: return "V"
        case .saturday: return "S"
        case .sunday: return "D"
        }
    }
}

/// Modo de disparo de un schedule.
public enum ScheduleMode: Codable, Equatable, Sendable {
    /// Una hora fija (ej. 9:00).
    case fixedTime(hour: Int, minute: Int)
    /// Un rango horario con intervalo (ej. 8:00–18:00 cada 2h).
    case range(startHour: Int, startMinute: Int, endHour: Int, endMinute: Int, everyHours: Int)
}

/// Un reporte programado definido por el usuario.
public struct Schedule: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    /// Permite activar/desactivar sin borrar (R9).
    public var isEnabled: Bool
    public var weekdays: Set<Weekday>
    public var mode: ScheduleMode

    public init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        weekdays: Set<Weekday>,
        mode: ScheduleMode
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.weekdays = weekdays
        self.mode = mode
    }
}

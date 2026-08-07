import Foundation

/// Persistencia de ajustes, schedules, último estado conocido, armado y ETag
/// mediante `UserDefaults` + `Codable` (KTD7, R11).
public final class SettingsStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let prefix = "com.avangenio.status."

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: Ajustes

    public func loadSettings() -> AppSettings { decode("settings") ?? AppSettings() }
    public func save(settings: AppSettings) { encode(settings, "settings") }

    // MARK: Schedules

    public func loadSchedules() -> [Schedule] { decode("schedules") ?? [] }
    public func save(schedules: [Schedule]) { encode(schedules, "schedules") }

    // MARK: Último estado conocido

    public func loadLastStatus() -> ServiceStatus? { decode("lastStatus") }
    public func save(lastStatus: ServiceStatus?) {
        if let lastStatus {
            encode(lastStatus, "lastStatus")
        } else {
            defaults.removeObject(forKey: key("lastStatus"))
        }
    }

    // MARK: Armado de umbrales

    public func loadArming() -> ArmingState { decode("arming") ?? ArmingState() }
    public func save(arming: ArmingState) { encode(arming, "arming") }

    // MARK: ETag

    public func loadEtag() -> String? { defaults.string(forKey: key("etag")) }
    public func save(etag: String?) {
        if let etag {
            defaults.set(etag, forKey: key("etag"))
        } else {
            defaults.removeObject(forKey: key("etag"))
        }
    }

    // MARK: Checkpoint de reportes programados

    public func loadLastScheduleCheck() -> Date? {
        guard defaults.object(forKey: key("lastScheduleCheck")) != nil else { return nil }
        return Date(timeIntervalSince1970: defaults.double(forKey: key("lastScheduleCheck")))
    }

    public func save(lastScheduleCheck: Date) {
        defaults.set(lastScheduleCheck.timeIntervalSince1970, forKey: key("lastScheduleCheck"))
    }

    // MARK: Helpers

    private func key(_ name: String) -> String { prefix + name }

    private func decode<T: Decodable>(_ name: String) -> T? {
        guard let data = defaults.data(forKey: key(name)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func encode<T: Encodable>(_ value: T, _ name: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key(name))
        }
    }
}

import Foundation
import UserNotifications

/// Interfaz mínima de notificación que consume el `AppModel` (inyectable en tests).
public protocol NotificationServing: AnyObject, Sendable {
    func notify(events: [StatusEvent])
    func notifySummary(_ status: ServiceStatus)
    func requestAuthorizationIfNeeded() async -> Bool
}

/// Envoltura de `UNUserNotificationCenter`: permiso, avisos de evento y resumen (U6, KTD8).
///
/// Fija un delegate `willPresent` para que los banners se muestren aun con la app en
/// primer plano (panel abierto o durante el smoke test); si no, macOS los suprime.
public final class NotificationService: NSObject, NotificationServing, UNUserNotificationCenterDelegate, @unchecked Sendable {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
        center.delegate = self
    }

    public func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    public func notify(events: [StatusEvent]) {
        for event in events {
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: Self.content(for: event),
                trigger: nil
            )
            center.add(request)
        }
    }

    public func notifySummary(_ status: ServiceStatus) {
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: Self.summaryContent(for: status),
            trigger: nil
        )
        center.add(request)
    }

    // MARK: Presentación en primer plano

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    // MARK: Construcción de contenido (pura, testeable)

    static func content(for event: StatusEvent) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.sound = .default
        switch event {
        case let .powerChanged(to):
            content.title = "Servicio eléctrico estatal"
            content.body = to == .on ? "⚡️ Energía restablecida." : "🔌 Energía caída."
        case let .internetChanged(to):
            content.title = "Internet"
            content.body = to == .ok ? "🟢 Internet recuperado." : "🔴 Internet caído."
        case let .batteryBelowThreshold(value, threshold):
            content.title = "Baterías de respaldo"
            content.body = "🔋 Baterías por debajo del \(MetricFormat.percent(threshold)) (\(MetricFormat.percent(value)))."
        case let .bandwidthBelowThreshold(value, threshold):
            content.title = "Ancho de banda"
            content.body = "📉 Ancho de banda bajo \(MetricFormat.mbps(threshold)) (\(MetricFormat.mbps(value)))."
        }
        return content
    }

    static func summaryContent(for status: ServiceStatus) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Estado de Avangenio"
        content.sound = .default
        let internet = status.internet == .ok ? "OK" : "caído"
        let power = status.power == .on ? "sí" : "no"
        let bandwidth = status.bandwidthMbps.map(MetricFormat.mbps) ?? "—"
        let battery = status.batteryPercent.map(MetricFormat.percent) ?? "—"
        content.body = "Internet: \(internet) · Banda: \(bandwidth) · Baterías: \(battery) · Electricidad: \(power)\nActualizado: \(status.lastUpdatedRaw)"
        return content
    }
}

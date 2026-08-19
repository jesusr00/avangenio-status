import Foundation
import Observation
import AppKit
import os

/// Estado visual del icono de la barra (R4).
public enum IconState: Sendable {
    case ok
    case alert
    case unknown
}

/// Orquestador observable: coordina fetch → parse → detección → notificación y
/// expone estado a las vistas SwiftUI. Aísla la lógica de dominio del shell (KTD2).
@MainActor
@Observable
public final class AppModel {
    // Estado observable por las vistas.
    public private(set) var current: ServiceStatus?
    public private(set) var iconState: IconState = .unknown
    public private(set) var lastCheckedAt: Date?
    public private(set) var notificationsAuthorized = false
    /// Serie observable del historial de energía (baterías + electricidad).
    public private(set) var history: [EnergySample] = []

    public var settings: AppSettings {
        didSet {
            store.save(settings: settings)
            // Reiniciar el timer solo si cambió el intervalo (no en cada tick de slider).
            if settings.pollingMinutes != oldValue.pollingMinutes {
                restartPollTimer()
            }
        }
    }

    public var schedules: [Schedule] {
        didSet {
            store.save(schedules: schedules)
            scheduleNextReport()
        }
    }

    // Dependencias (inyectables).
    private let fetcher: StatusFetching
    private let parser: StatusParser
    private let detector: EventDetector
    private let scheduleEngine: ScheduleEngine
    private let notifier: NotificationServing?
    private let store: SettingsStore
    private let historyStore: HistoryStoring

    // Estado interno.
    private var arming: ArmingState
    private var etag: String?
    private var pollTimer: Timer?
    private var scheduleTimer: Timer?
    private var lastScheduleCheck: Date
    private var pollTask: Task<Void, Never>?
    private var wakeObserver: NSObjectProtocol?
    private let log = Logger(subsystem: "com.avangenio.status", category: "AppModel")

    public init(
        fetcher: StatusFetching = StatusFetcher(),
        parser: StatusParser = StatusParser(),
        detector: EventDetector = EventDetector(),
        scheduleEngine: ScheduleEngine = ScheduleEngine(),
        notifier: NotificationServing? = NotificationService(),
        store: SettingsStore = SettingsStore(),
        historyStore: HistoryStoring = HistoryStore()
    ) {
        self.fetcher = fetcher
        self.parser = parser
        self.detector = detector
        self.scheduleEngine = scheduleEngine
        self.notifier = notifier
        self.store = store
        self.historyStore = historyStore
        self.settings = store.loadSettings()
        self.schedules = store.loadSchedules()
        self.arming = store.loadArming()
        self.etag = store.loadEtag()
        self.lastScheduleCheck = store.loadLastScheduleCheck() ?? Date()
        self.history = historyStore.load()
        if let last = store.loadLastStatus() {
            self.current = last
            self.iconState = Self.iconState(for: last)
            self.lastCheckedAt = last.fetchedAt
        }
    }

    /// Arranca polling, scheduler, observación de wake y solicitud de permiso.
    public func start() {
        restartPollTimer()
        scheduleNextReport()
        observeWake()
        Task { await catchUpMissedReports() }   // reportes vencidos mientras la app estuvo cerrada
        Task { notificationsAuthorized = await (notifier?.requestAuthorizationIfNeeded() ?? false) }
    }

    /// Fuerza un fetch inmediato (botón "Refrescar ahora").
    public func refreshNow() async {
        await poll()
    }

    /// Reevalúa el estado del permiso de notificaciones (R12).
    public func refreshAuthorization() async {
        notificationsAuthorized = await (notifier?.requestAuthorizationIfNeeded() ?? false)
    }

    /// Abre el panel de Notificaciones en Ajustes del sistema (recuperación de permiso, R12).
    public func openSystemNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Ciclo de polling

    /// Serializa el polling: si ya hay un fetch en curso, se espera a ese en vez de
    /// lanzar otro (evita respuestas fuera de orden y ETags duplicados).
    private func poll() async {
        if let pollTask {
            await pollTask.value
            return
        }
        let task = Task { await self.performPoll() }
        pollTask = task
        await task.value
        pollTask = nil
    }

    private func performPoll() async {
        let result = await fetcher.fetch(etag: etag)
        switch result {
        case let .failed(error):
            log.error("poll falló: \(error.localizedDescription, privacy: .public)")
            iconState = .unknown
            lastCheckedAt = Date()
        case .notModified:
            // El último cuerpo sigue vigente: restaurar el icono desde `current`.
            let now = Date()
            iconState = current.map(Self.iconState(for:)) ?? .unknown
            lastCheckedAt = now
            if let status = current {
                recordSample(from: status, at: now)
            }
        case let .updated(body, newEtag):
            etag = newEtag
            store.save(etag: newEtag)
            guard let status = parser.parse(body) else {
                iconState = .unknown
                lastCheckedAt = Date()
                return
            }
            let (events, newArming) = detector.detect(
                previous: current,
                current: status,
                settings: settings,
                arming: arming
            )
            arming = newArming
            store.save(arming: newArming)
            current = status
            store.save(lastStatus: status)
            iconState = Self.iconState(for: status)
            lastCheckedAt = status.fetchedAt
            recordSample(from: status, at: status.fetchedAt)
            if settings.notificationsEnabled, !events.isEmpty {
                notifier?.notify(events: events)
            }
        }
    }

    static func iconState(for status: ServiceStatus) -> IconState {
        (status.power == .off || status.internet == .down) ? .alert : .ok
    }

    /// Registra una muestra de energía en el historial (persistente + observable).
    private func recordSample(from status: ServiceStatus, at timestamp: Date) {
        let sample = EnergySample(
            timestamp: timestamp,
            batteryPercent: status.batteryPercent,
            power: status.power
        )
        history = historyStore.append(sample)
    }

    // MARK: - Timers

    private func restartPollTimer() {
        pollTimer?.invalidate()
        let interval = TimeInterval(max(1, settings.pollingMinutes) * 60)
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func scheduleNextReport() {
        scheduleTimer?.invalidate()
        guard let next = scheduleEngine.nextFireDate(after: Date(), schedules: schedules) else { return }
        let interval = max(1, next.timeIntervalSinceNow)
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in await self?.fireScheduledReport() }
        }
        RunLoop.main.add(timer, forMode: .common)
        scheduleTimer = timer
    }

    func fireScheduledReport() async {
        await poll()
        if settings.notificationsEnabled, let status = current {
            notifier?.notifySummary(status)
        }
        updateScheduleCheckpoint(Date())
        scheduleNextReport()
    }

    /// Al arrancar, recupera cualquier reporte que venciera mientras la app estuvo cerrada.
    func catchUpMissedReports() async {
        let now = Date()
        let missed = scheduleEngine.missedFires(since: lastScheduleCheck, until: now, schedules: schedules)
        await poll()   // refresco de estado al arrancar, con o sin reportes vencidos
        if !missed.isEmpty, settings.notificationsEnabled, let status = current {
            notifier?.notifySummary(status)
        }
        updateScheduleCheckpoint(now)
    }

    private func updateScheduleCheckpoint(_ date: Date) {
        lastScheduleCheck = date
        store.save(lastScheduleCheck: date)
    }

    // MARK: - Suspensión / wake

    private func observeWake() {
        // Evita observers duplicados si start() se llamara más de una vez.
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.handleWake() }
        }
    }

    func handleWake() async {
        let now = Date()
        let missed = scheduleEngine.missedFires(since: lastScheduleCheck, until: now, schedules: schedules)
        // Siempre refrescar el estado al despertar (el timer no dispara durante la suspensión)
        // y realinear la cadencia de polling.
        await poll()
        restartPollTimer()
        if !missed.isEmpty, settings.notificationsEnabled, let status = current {
            notifier?.notifySummary(status)
        }
        updateScheduleCheckpoint(now)
        scheduleNextReport()
    }
}

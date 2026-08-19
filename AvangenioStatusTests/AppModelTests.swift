import XCTest
@testable import AvangenioStatusKit

/// Fetcher fake: entrega resultados en orden y cuenta las llamadas.
final class FakeFetcher: StatusFetching, @unchecked Sendable {
    private let results: [FetchResult]
    private(set) var callCount = 0
    private(set) var receivedEtags: [String?] = []

    init(_ results: [FetchResult]) { self.results = results }

    func fetch(etag: String?) async -> FetchResult {
        receivedEtags.append(etag)
        defer { callCount += 1 }
        return results[min(callCount, results.count - 1)]
    }
}

/// Notifier espía: registra avisos y resúmenes.
final class SpyNotifier: NotificationServing, @unchecked Sendable {
    private(set) var eventBatches: [[StatusEvent]] = []
    private(set) var summaries: [ServiceStatus] = []

    func notify(events: [StatusEvent]) { eventBatches.append(events) }
    func notifySummary(_ status: ServiceStatus) { summaries.append(status) }
    func requestAuthorizationIfNeeded() async -> Bool { true }
}

/// Store de historial falso: registra lo añadido y sirve una semilla.
final class FakeHistoryStore: HistoryStoring, @unchecked Sendable {
    private(set) var appended: [EnergySample] = []
    private var samples: [EnergySample]
    init(seed: [EnergySample] = []) { self.samples = seed }
    func load() -> [EnergySample] { samples }
    func append(_ sample: EnergySample) -> [EnergySample] {
        appended.append(sample)
        samples.append(sample)
        return samples
    }
}

@MainActor
final class AppModelTests: XCTestCase {

    func testFailedFetchSetsUnknownAndNoNotification() async {
        let (model, notifier, _) = makeModel([.failed(URLError(.timedOut))])
        await model.refreshNow()
        XCTAssertEqual(model.iconState, .unknown)
        XCTAssertTrue(notifier.eventBatches.isEmpty)
    }

    func testNotModifiedDoesNotReprocess() async {
        let (model, notifier, _) = makeModel([.notModified])
        await model.refreshNow()
        XCTAssertNil(model.current)
        XCTAssertNotNil(model.lastCheckedAt)
        XCTAssertTrue(notifier.eventBatches.isEmpty)
    }

    func testUpdatedWithPowerOffIsAlert() async {
        let (model, _, _) = makeModel([.updated(body: body(power: "NO"), etag: "e1")])
        await model.refreshNow()
        XCTAssertEqual(model.iconState, .alert)
        XCTAssertEqual(model.current?.power, .off)
    }

    func testUpdatedAllOkIsOk() async {
        let (model, _, _) = makeModel([.updated(body: body(power: "YES"), etag: nil)])
        await model.refreshNow()
        XCTAssertEqual(model.iconState, .ok)
    }

    func testTransitionTriggersNotification() async {
        let (model, notifier, _) = makeModel([
            .updated(body: body(power: "YES"), etag: nil),  // línea base, sin evento
            .updated(body: body(power: "NO"), etag: nil),   // transición → evento
        ])
        await model.refreshNow()
        await model.refreshNow()
        XCTAssertEqual(notifier.eventBatches.count, 1)
        XCTAssertEqual(notifier.eventBatches.first, [.powerChanged(to: .off)])
    }

    func testRefreshNowForcesFetch() async {
        let fetcher = FakeFetcher([.notModified])
        let (model, _, _) = makeModel(fetcher: fetcher)
        await model.refreshNow()
        await model.refreshNow()
        XCTAssertEqual(fetcher.callCount, 2)
    }

    func testDisabledNotificationsSuppressEvents() async {
        let store = freshStore()
        store.save(settings: AppSettings(notificationsEnabled: false))
        let (model, notifier, _) = makeModel(
            fetcher: FakeFetcher([
                .updated(body: body(power: "YES"), etag: nil),
                .updated(body: body(power: "NO"), etag: nil),
            ]),
            store: store
        )
        await model.refreshNow()
        await model.refreshNow()
        XCTAssertTrue(notifier.eventBatches.isEmpty)
    }

    func testNotModifiedAfterUpdatedPreservesStatusAndDoesNotRenotify() async {
        let (model, notifier, _) = makeModel([
            .updated(body: body(power: "NO"), etag: "e1"),
            .notModified,
        ])
        await model.refreshNow()
        let afterFirst = model.current
        await model.refreshNow()
        XCTAssertEqual(model.current, afterFirst)          // 304 preserva el estado
        XCTAssertEqual(model.iconState, .alert)            // icono restaurado, no unknown
        XCTAssertEqual(notifier.eventBatches.count, 0)     // sin re-notificar en 304
    }

    func testUnparseableBodyIsUnknown() async {
        let (model, notifier, _) = makeModel([.updated(body: "basura", etag: "e1")])
        await model.refreshNow()
        XCTAssertEqual(model.iconState, .unknown)
        XCTAssertNil(model.current)
        XCTAssertTrue(notifier.eventBatches.isEmpty)
    }

    func testForwardsStoredEtagOnNextFetch() async {
        let fetcher = FakeFetcher([
            .updated(body: body(power: "YES"), etag: "e1"),
            .notModified,
        ])
        let (model, _, _) = makeModel(fetcher: fetcher)
        await model.refreshNow()
        await model.refreshNow()
        XCTAssertEqual(fetcher.receivedEtags, [nil, "e1"])
    }

    func testInternetDownIsAlert() async {
        let body = """
        Ultima actualizacion: x
        Internet Status: DOWN
        Ancho de Banda por Usuario: 4.42 Mbps
        Estado de las baterías: 50.00%
        Servicio Eléctrico Estatal: YES
        """
        let (model, _, _) = makeModel([.updated(body: body, etag: nil)])
        await model.refreshNow()
        XCTAssertEqual(model.iconState, .alert)
    }

    func testRestoresLastStatusFromStore() {
        let store = freshStore()
        let saved = ServiceStatus(lastUpdatedRaw: "x", internet: .down, bandwidthMbps: 1, batteryPercent: 20, power: .off, fetchedAt: Date(timeIntervalSince1970: 100))
        store.save(lastStatus: saved)
        let (model, _, _) = makeModel(fetcher: FakeFetcher([.notModified]), store: store)
        XCTAssertEqual(model.current, saved)
        XCTAssertEqual(model.iconState, .alert)
        XCTAssertEqual(model.lastCheckedAt, saved.fetchedAt)
    }

    func testScheduledReportEmitsSummary() async {
        let (model, notifier, _) = makeModel([.updated(body: body(power: "YES"), etag: nil)])
        await model.fireScheduledReport()
        XCTAssertEqual(notifier.summaries.count, 1)
    }

    // MARK: historial de energía

    func testUpdatedRecordsHistorySample() async {
        let history = FakeHistoryStore()
        let (model, _, _) = makeModel(
            fetcher: FakeFetcher([.updated(body: body(power: "NO"), etag: "e1")]),
            history: history
        )
        await model.refreshNow()
        XCTAssertEqual(history.appended.count, 1)
        XCTAssertEqual(history.appended.first?.power, .off)
        XCTAssertEqual(history.appended.first?.batteryPercent, 50)
        XCTAssertEqual(model.history.count, 1)
    }

    func testNotModifiedRecordsSampleFromCurrent() async {
        let history = FakeHistoryStore()
        let (model, _, _) = makeModel(
            fetcher: FakeFetcher([
                .updated(body: body(power: "NO"), etag: "e1"),
                .notModified,
            ]),
            history: history
        )
        await model.refreshNow()
        await model.refreshNow()
        XCTAssertEqual(history.appended.count, 2)
        XCTAssertEqual(history.appended.last?.power, .off)   // refleja el estado vigente
    }

    func testFailedFetchDoesNotRecordHistory() async {
        let history = FakeHistoryStore()
        let (model, _, _) = makeModel(
            fetcher: FakeFetcher([.failed(URLError(.timedOut))]),
            history: history
        )
        await model.refreshNow()
        XCTAssertTrue(history.appended.isEmpty)
        XCTAssertTrue(model.history.isEmpty)
    }

    func testSeedsHistoryFromStoreAtInit() {
        let seed = [EnergySample(timestamp: Date(timeIntervalSince1970: 1), batteryPercent: 30, power: .on)]
        let history = FakeHistoryStore(seed: seed)
        let (model, _, _) = makeModel(fetcher: FakeFetcher([.notModified]), history: history)
        XCTAssertEqual(model.history, seed)
    }

    // MARK: helpers

    private func freshStore() -> SettingsStore {
        SettingsStore(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
    }

    private func makeModel(_ results: [FetchResult]) -> (AppModel, SpyNotifier, FakeFetcher) {
        makeModel(fetcher: FakeFetcher(results))
    }

    private func makeModel(
        fetcher: FakeFetcher,
        store: SettingsStore? = nil,
        history: HistoryStoring? = nil
    ) -> (AppModel, SpyNotifier, FakeFetcher) {
        let notifier = SpyNotifier()
        let model = AppModel(
            fetcher: fetcher,
            parser: StatusParser(),
            detector: EventDetector(),
            scheduleEngine: ScheduleEngine(),
            notifier: notifier,
            store: store ?? freshStore(),
            historyStore: history ?? FakeHistoryStore()
        )
        return (model, notifier, fetcher)
    }

    private func body(power: String) -> String {
        """
        Ultima actualizacion: x
        Internet Status: OK
        Ancho de Banda por Usuario: 4.42 Mbps
        Estado de las baterías: 50.00%
        Servicio Eléctrico Estatal: \(power)
        """
    }
}

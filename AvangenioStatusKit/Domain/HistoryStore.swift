import Foundation
import os

/// Abstracción de persistencia del historial de energía (para inyección/tests).
public protocol HistoryStoring: Sendable {
    /// Serie persistida; vacía si no hay archivo o está corrupto.
    func load() -> [EnergySample]
    /// Añade una muestra, poda lo más viejo que la retención, persiste y
    /// devuelve la serie resultante.
    func append(_ sample: EnergySample) -> [EnergySample]
}

/// Persiste el historial como archivo JSON en Application Support (KTD7).
public final class HistoryStore: HistoryStoring, @unchecked Sendable {
    /// Retención: descarta muestras más viejas que esto (30 días).
    public static let retention: TimeInterval = 30 * 24 * 60 * 60

    private let fileURL: URL
    private let retention: TimeInterval
    private let log = Logger(subsystem: "com.avangenio.status", category: "HistoryStore")

    public init(fileURL: URL? = nil, retention: TimeInterval = HistoryStore.retention) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        self.retention = retention
    }

    public func load() -> [EnergySample] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([EnergySample].self, from: data)) ?? []
    }

    public func append(_ sample: EnergySample) -> [EnergySample] {
        let cutoff = sample.timestamp.addingTimeInterval(-retention)
        let pruned = (load() + [sample]).filter { $0.timestamp >= cutoff }
        persist(pruned)
        return pruned
    }

    private func persist(_ samples: [EnergySample]) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(samples)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            log.error("no se pudo persistir el historial: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("AvangenioStatus", isDirectory: true)
            .appendingPathComponent("energy-history.json")
    }
}

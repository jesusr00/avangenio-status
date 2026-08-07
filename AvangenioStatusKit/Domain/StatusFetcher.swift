import Foundation

/// Resultado de una consulta al API, distinguiendo los tres casos relevantes.
public enum FetchResult: Sendable {
    case updated(body: String, etag: String?)
    case notModified
    case failed(Error)
}

/// Interfaz de fetch para poder inyectar fakes en tests del `AppModel`.
public protocol StatusFetching: Sendable {
    func fetch(etag: String?) async -> FetchResult
}

/// Descarga `data.txt` con GET condicional (ETag / If-None-Match) y sin caché,
/// para que un `304` real llegue crudo en vez de ser enmascarado por `URLCache` (KTD5).
public struct StatusFetcher: StatusFetching {
    private let url: URL
    private let session: URLSession

    public init(
        url: URL = URL(string: "https://status.avangenio.com/data.txt")!,
        session: URLSession? = nil
    ) {
        self.url = url
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.ephemeral
            config.urlCache = nil
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            // Timeouts acotados: un poll no debe sobrevivir a su propia cadencia.
            config.timeoutIntervalForRequest = 15
            config.timeoutIntervalForResource = 30
            self.session = URLSession(configuration: config)
        }
    }

    public func fetch(etag: String?) async -> FetchResult {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if let etag {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failed(URLError(.badServerResponse))
            }
            if http.statusCode == 304 {
                return .notModified
            }
            guard (200..<300).contains(http.statusCode) else {
                return .failed(URLError(.badServerResponse))
            }
            let newEtag = http.value(forHTTPHeaderField: "ETag")
            let body = String(decoding: data, as: UTF8.self)
            return .updated(body: body, etag: newEtag)
        } catch {
            return .failed(error)
        }
    }
}

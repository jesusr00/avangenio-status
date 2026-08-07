import XCTest
@testable import AvangenioStatusKit

/// URLProtocol de prueba: respuesta programable + registro del último request.
final class MockURLProtocol: URLProtocol {
    static var statusCode = 200
    static var body = Data()
    static var headers: [String: String] = [:]
    static var error: Error?
    static var lastRequest: URLRequest?

    static func reset() {
        statusCode = 200
        body = Data()
        headers = [:]
        error = nil
        lastRequest = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        MockURLProtocol.lastRequest = request
        if let error = MockURLProtocol.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: MockURLProtocol.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: MockURLProtocol.headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: MockURLProtocol.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class StatusFetcherTests: XCTestCase {
    private let url = URL(string: "https://example.com/data.txt")!
    private var session: URLSession!

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
    }

    func testNotModified() async {
        MockURLProtocol.statusCode = 304
        let result = await StatusFetcher(url: url, session: session).fetch(etag: "abc")
        guard case .notModified = result else { return XCTFail("esperaba .notModified") }
    }

    func testUpdatedPropagatesBodyAndEtag() async {
        MockURLProtocol.statusCode = 200
        MockURLProtocol.body = Data("hola".utf8)
        MockURLProtocol.headers = ["ETag": "xyz"]
        let result = await StatusFetcher(url: url, session: session).fetch(etag: nil)
        guard case let .updated(body, etag) = result else { return XCTFail("esperaba .updated") }
        XCTAssertEqual(body, "hola")
        XCTAssertEqual(etag, "xyz")
    }

    func testSendsIfNoneMatchHeader() async {
        MockURLProtocol.statusCode = 200
        _ = await StatusFetcher(url: url, session: session).fetch(etag: "myetag")
        XCTAssertEqual(MockURLProtocol.lastRequest?.value(forHTTPHeaderField: "If-None-Match"), "myetag")
    }

    func testNetworkFailure() async {
        MockURLProtocol.error = URLError(.timedOut)
        let result = await StatusFetcher(url: url, session: session).fetch(etag: nil)
        guard case .failed = result else { return XCTFail("esperaba .failed") }
    }

    func testServerErrorIsFailed() async {
        MockURLProtocol.statusCode = 500
        MockURLProtocol.body = Data("error".utf8)
        let result = await StatusFetcher(url: url, session: session).fetch(etag: nil)
        guard case .failed = result else { return XCTFail("esperaba .failed para 500") }
    }

    func testEmptyBodyIsUpdatedEmpty() async {
        MockURLProtocol.statusCode = 200
        MockURLProtocol.body = Data()
        let result = await StatusFetcher(url: url, session: session).fetch(etag: nil)
        guard case let .updated(body, _) = result else { return XCTFail("esperaba .updated") }
        XCTAssertEqual(body, "")
    }
}

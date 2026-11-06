import Foundation
import Supabase
import Testing
@testable import Beckon

@Suite(.serialized) @MainActor
struct GroomingMatchTransportTests {
    @Test(arguments: [nil, GroomingLocationMode.customerComesToGroomer, .groomerComesToCustomer], [nil, "next-page"])
    func nullableFiltersRemainPresentInRPC(location: GroomingLocationMode?, cursor: String?) async throws {
        GroomingMatchTransport.reset()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [GroomingMatchTransport.self]
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let client = SupabaseClient(supabaseURL: URL(string: "https://grooming-test.invalid")!, supabaseKey: "test-key",
            options: .init(global: .init(session: session)))
        let page = try await SupabaseGroomerRequestRepository(client: client).groomingMatches(
            groomerID: UUID(), location: location, page: .init(mode: .fit, cursor: cursor))
        #expect(page.items.isEmpty)
        let data = try #require(GroomingMatchTransport.body())
        let payload = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(payload.keys) == ["p_sort", "p_limit", "p_cursor", "p_location"])
        if let cursor { #expect(payload["p_cursor"] as? String == cursor) }
        else { #expect(payload["p_cursor"] is NSNull) }
        if let location { #expect(payload["p_location"] as? String == location.rawValue) }
        else { #expect(payload["p_location"] is NSNull) }
    }
}

nonisolated private final class GroomingMatchTransport: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var captured: Data?
    static func reset() { lock.withLock { captured = nil } }
    static func body() -> Data? { lock.withLock { captured } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        var data = request.httpBody ?? Data()
        if let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                data.append(contentsOf: buffer.prefix(count))
            }
        }
        Self.lock.withLock { Self.captured = data }
        let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        // The deployed four-argument RPC has no defaults. Omission fails routing,
        // while an explicit JSON null requests the first page / all locations.
        let valid = request.url?.path == "/rest/v1/rpc/get_grooming_matches"
            && Set(payload.keys) == ["p_sort", "p_limit", "p_cursor", "p_location"]
        let response = valid ? """
        {"items":[],"ranking_revision":"test-page","score_as_of":"2026-11-06T08:00:00Z",
        "valid_until":"2026-11-06T08:05:00Z","algorithm_version":"matching-v1",
        "requested_mode":"fit","effective_mode":"fit","pending_count":0,"assessment_count":0,"next_cursor":null}
        """ : """
        {"code":"PGRST202","message":"Required RPC arguments missing"}
        """
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: valid ? 200 : 404,
            httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(response.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

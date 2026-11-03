import Foundation
import Supabase
import Testing
@testable import Beckon

@Suite(.serialized) @MainActor
struct ChatSendTransportTests {
    @Test(arguments: [false, true])
    func insertAndLostAcknowledgementRecoveryKeepOneIdentity(duplicate: Bool) async throws {
        let id = UUID(), conversation = UUID(), sender = UUID()
        ChatSendTransport.configure(id: id, conversation: conversation, sender: sender, duplicate: duplicate)
        let (repository, session) = makeRepository()
        defer { session.invalidateAndCancel() }
        let message = try await repository.sendMessage(messageID: id, conversationID: conversation, senderID: sender, body: "Hello")
        #expect(message.id == id)
        let requests = ChatSendTransport.requests()
        #expect(requests.map(\.httpMethod) == (duplicate ? ["POST", "GET"] : ["POST"]))
        let post = try #require(requests.first)
        let data: Data
        if let body = post.httpBody { data = body }
        else {
            let stream = try #require(post.httpBodyStream)
            stream.open(); defer { stream.close() }
            var collected = Data(), bytes = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&bytes, maxLength: bytes.count)
                if count <= 0 { break }; collected.append(contentsOf: bytes.prefix(count))
            }
            data = collected
        }
        let payload = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(payload["id"] as? String == id.uuidString.lowercased())
        #expect(Set(payload.keys) == ["id", "conversation_id", "sender_id", "body"])
        if duplicate {
            let query = URLComponents(url: try #require(requests.last?.url), resolvingAgainstBaseURL: false)?.queryItems ?? []
            #expect(query.contains { $0.name == "id" && $0.value == "eq.\(id.uuidString.lowercased())" })
            #expect(query.contains { $0.name == "sender_id" && $0.value == "eq.\(sender.uuidString.lowercased())" })
            #expect(query.contains { $0.name == "conversation_id" && $0.value == "eq.\(conversation.uuidString.lowercased())" })
        }
    }

    @Test(arguments: ["body", "sender_id", "conversation_id", "id", "kind", "booking_id", "missing"])
    func duplicateIdentityNeverAcceptsDifferentContent(field: String) async throws {
        let id = UUID(), conversation = UUID(), sender = UUID()
        ChatSendTransport.configure(id: id, conversation: conversation, sender: sender, duplicate: true, mismatch: field)
        let (repository, session) = makeRepository()
        defer { session.invalidateAndCancel() }
        await #expect(throws: ChatRepositoryError.invalidMessage) {
            try await repository.sendMessage(messageID: id, conversationID: conversation, senderID: sender, body: "Hello")
        }
        #expect(ChatSendTransport.requests().map(\.httpMethod) == ["POST", "GET"])
    }

    private func makeRepository() -> (SupabaseChatRepository, URLSession) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ChatSendTransport.self]
        let session = URLSession(configuration: configuration)
        let client = SupabaseClient(supabaseURL: URL(string: "https://chat-send.invalid")!, supabaseKey: "test-key",
            options: .init(global: .init(session: session)))
        return (SupabaseChatRepository(client: client), session)
    }
}

private nonisolated final class ChatSendTransport: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var captured: [URLRequest] = []
    nonisolated(unsafe) private static var row: [String: Any] = [:]
    nonisolated(unsafe) private static var isDuplicate = false
    nonisolated(unsafe) private static var isMissing = false
    static func configure(id: UUID, conversation: UUID, sender: UUID, duplicate: Bool, mismatch: String? = nil) {
        lock.withLock {
            captured = []; isDuplicate = duplicate; isMissing = mismatch == "missing"
            row = ["id": id.uuidString, "conversation_id": conversation.uuidString, "sender_id": sender.uuidString,
                "kind": "text", "body": "Hello", "created_at": "2026-11-03T12:00:00Z"]
            if let mismatch, mismatch != "missing" {
                row[mismatch] = mismatch == "body" ? "Different" : mismatch == "kind" ? "booking_card" : UUID().uuidString
            }
        }
    }
    static func requests() -> [URLRequest] { lock.withLock { captured } }
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "chat-send.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let url = request.url else { return }
        let (status, payload): (Int, Any) = Self.lock.withLock {
            Self.captured.append(request)
            if Self.isDuplicate, request.httpMethod == "POST" {
                return (409, ["code": "23505", "message": "duplicate primary key", "details": "", "hint": ""])
            }
            return (200, Self.isMissing ? [] : [Self.row])
        }
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil,
            headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let data = try? JSONSerialization.data(withJSONObject: payload) { client?.urlProtocol(self, didLoad: data) }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

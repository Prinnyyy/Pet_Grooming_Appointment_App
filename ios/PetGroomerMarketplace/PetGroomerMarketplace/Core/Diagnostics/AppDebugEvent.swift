import Foundation
import Observation
import OSLog
import SwiftUI

enum AppDebugEventLevel: String, CaseIterable, Codable, Sendable {
    case debug
    case info
    case warning
    case error
}

enum AppDebugEventCategory: String, CaseIterable, Codable, Sendable {
    case feedback
    case store
    case repository
    case navigation
    case action
    case lifecycle
    case test
}

struct AppDebugEvent: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let timestamp: Date
    let level: AppDebugEventLevel
    let category: AppDebugEventCategory
    let source: String
    let scope: String?
    let message: String
    let underlyingErrorType: String?
    let underlyingErrorCode: String?
    let correlationID: String?
    let durationMs: Int?
    let metadata: [String: String]

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: AppDebugEventLevel,
        category: AppDebugEventCategory,
        source: String,
        scope: String? = nil,
        message: String,
        underlyingErrorType: String? = nil,
        underlyingErrorCode: String? = nil,
        correlationID: String? = nil,
        durationMs: Int? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.source = AppDebugEventSanitizer.sanitizedText(source)
        self.scope = scope.map(AppDebugEventSanitizer.sanitizedText)
        self.message = AppDebugEventSanitizer.sanitizedText(message)
        self.underlyingErrorType = underlyingErrorType.map(AppDebugEventSanitizer.sanitizedText)
        self.underlyingErrorCode = underlyingErrorCode.map(AppDebugEventSanitizer.sanitizedText)
        self.correlationID = correlationID.map(AppDebugEventSanitizer.supportReference)
        self.durationMs = durationMs
        self.metadata = AppDebugEventSanitizer.sanitizedMetadata(metadata)
    }
}

enum AppDebugEventSanitizer {
    static func sanitizedMetadata(_ metadata: [String: String]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: metadata.map { key, value in
            (key, sanitizedMetadataValue(value, forKey: key))
        })
    }

    static func sanitizedMetadataValue(_ value: String, forKey key: String) -> String {
        let lowercasedKey = key.lowercased()

        if lowercasedKey == "scenarioid"
            || lowercasedKey == "scenario_id"
            || lowercasedKey == "phase"
            || lowercasedKey == "actorrole"
            || lowercasedKey == "actor_role" {
            return sanitizedText(value)
        }

        if lowercasedKey.contains("password")
            || lowercasedKey.contains("token")
            || lowercasedKey.contains("authorization")
            || lowercasedKey.contains("apikey")
            || lowercasedKey.contains("api_key") {
            return lowercasedKey.contains("url") ? "[redacted-url]" : "[redacted]"
        }

        if lowercasedKey.contains("email") {
            return emailDomain(from: value) ?? "[redacted-email]"
        }

        if lowercasedKey.contains("uuid")
            || lowercasedKey.contains("userid")
            || lowercasedKey.contains("user_id")
            || lowercasedKey.hasSuffix("id") {
            return supportReference(value)
        }

        if lowercasedKey.contains("storagepath")
            || lowercasedKey.contains("storage_path")
            || lowercasedKey.contains("path") {
            return sanitizedStoragePath(value)
        }

        return sanitizedText(value)
    }

    static func sanitizedText(_ value: String) -> String {
        var result = value
        result = replace(
            result,
            pattern: #"(?i)[A-Z0-9._%+\-]+@([A-Z0-9.\-]+\.[A-Z]{2,})"#,
            template: "[email-domain:$1]"
        )
        result = replace(
            result,
            pattern: #"(?i)\b(token|access_token|refresh_token|password|apikey|api_key|authorization)(=|:|\s+)[^\s&]+"#,
            template: "$1$2[redacted]"
        )
        result = replace(
            result,
            pattern: #"\b([0-9A-Fa-f]{8})-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\b"#,
            template: "$1"
        )
        result = replace(
            result,
            pattern: #"https?://[^\s"]+"#,
            template: "[redacted-url]"
        )
        return result
    }

    static func supportReference(_ value: String) -> String {
        if let uuidRange = value.range(
            of: #"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"#,
            options: .regularExpression
        ) {
            return String(value[uuidRange].prefix(8)).uppercased()
        }

        return sanitizedText(String(value.prefix(12)))
    }

    private static func emailDomain(from value: String) -> String? {
        let pieces = value.split(separator: "@", maxSplits: 1)
        guard pieces.count == 2 else { return nil }
        return String(pieces[1]).lowercased()
    }

    private static func sanitizedStoragePath(_ value: String) -> String {
        let components = value.split(separator: "/").map(String.init)
        guard let bucket = components.first else { return sanitizedText(value) }
        let last = components.last.map(sanitizedText) ?? "object"
        return "\(bucket)/\(last.prefix(16))"
    }

    private static func replace(
        _ value: String,
        pattern: String,
        template: String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return value
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.stringByReplacingMatches(
            in: value,
            range: range,
            withTemplate: template
        )
    }
}

enum AppDebugEventJSONLCodec {
    static func encodeLine(_ event: AppDebugEvent) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(event)
        return String(decoding: data, as: UTF8.self)
    }

    static func decodeLine(_ line: String) throws -> AppDebugEvent {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AppDebugEvent.self, from: Data(line.utf8))
    }
}

@MainActor
protocol AppDebugEventWriting: AnyObject {
    func append(_ line: String) throws
    func replace(with lines: [String]) throws
    func clear() throws
}

@MainActor
final class AppDebugEventFileWriter: AppDebugEventWriting {
    static let maximumLineCount = 5_000
    static let maximumFileSizeBytes = 5 * 1024 * 1024
    static let retentionInterval: TimeInterval = 24 * 60 * 60

    let fileURL: URL
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let supportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        fileURL = supportURL
            .appendingPathComponent("GroomlyDebug", isDirectory: true)
            .appendingPathComponent("debug-events.jsonl")
        try? trimExistingLog()
    }

    func append(_ line: String) throws {
        try ensureDirectory()
        let data = Data((line + "\n").utf8)
        if fileManager.fileExists(atPath: fileURL.path) == false {
            fileManager.createFile(atPath: fileURL.path, contents: nil)
        }

        let handle = try FileHandle(forWritingTo: fileURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
        try handle.close()

        let lineCount = ((try? readLines()) ?? []).count
        if try fileSizeBytes() > Self.maximumFileSizeBytes
            || lineCount > Self.maximumLineCount {
            try trimExistingLog()
        }
    }

    func replace(with lines: [String]) throws {
        try ensureDirectory()
        let joined = lines.joined(separator: "\n")
        let payload = joined.isEmpty ? Data() : Data((joined + "\n").utf8)
        try payload.write(to: fileURL, options: .atomic)
    }

    func clear() throws {
        try replace(with: [])
    }

    func readLines() throws -> [String] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        return text.split(separator: "\n").map(String.init)
    }

    private func trimExistingLog() throws {
        let cutoff = Date().addingTimeInterval(-Self.retentionInterval)
        let lines = (try? readLines()) ?? []
        let retained = lines.suffix(Self.maximumLineCount).filter { line in
            guard let event = try? AppDebugEventJSONLCodec.decodeLine(line) else {
                return false
            }
            return event.timestamp >= cutoff
        }
        try replace(with: Array(retained))
    }

    private func ensureDirectory() throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    private func fileSizeBytes() throws -> Int {
        let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
        return attributes[.size] as? Int ?? 0
    }
}

@MainActor
private final class AppDebugEventNoopWriter: AppDebugEventWriting {
    func append(_ line: String) throws {}
    func replace(with lines: [String]) throws {}
    func clear() throws {}
}

struct AppDebugTestOpsSnapshot: Equatable, Sendable {
    let runID: String?
    let scenarioID: String?
    let activePhase: String?
    let actorRole: String?
    let latestEvent: AppDebugEvent?
}

@MainActor
@Observable
final class AppDebugEventRecorder {
    static let shared = AppDebugEventRecorder()
    static let maximumMemoryEvents = 5_000

    private(set) var events: [AppDebugEvent] = []
    private(set) var testOpsConfiguration: AppTestOpsConfiguration?
    private(set) var latestTestOpsEvent: AppDebugEvent?
    private let writer: any AppDebugEventWriting
    private let emitsToOSLog: Bool
    private let logger = Logger(
        subsystem: "com.prinnyyy.PetGroomerMarketplace",
        category: "DebugEvents"
    )

    init(
        writer: (any AppDebugEventWriting)? = nil,
        emitsToOSLog: Bool = true
    ) {
        #if DEBUG
        self.writer = writer ?? AppDebugEventFileWriter()
        self.emitsToOSLog = emitsToOSLog
        #else
        self.writer = writer ?? AppDebugEventNoopWriter()
        self.emitsToOSLog = false
        #endif
    }

    @discardableResult
    func record(
        level: AppDebugEventLevel,
        category: AppDebugEventCategory,
        source: String,
        scope: String? = nil,
        message: String,
        underlyingError: (any Error)? = nil,
        underlyingErrorType: String? = nil,
        underlyingErrorCode: String? = nil,
        correlationID: String? = nil,
        durationMs: Int? = nil,
        metadata: [String: String] = [:]
    ) -> AppDebugEvent {
        let identity = AppDebugErrorClassifier.identity(for: underlyingError)
        let event = AppDebugEvent(
            level: level,
            category: category,
            source: source,
            scope: scope,
            message: message,
            underlyingErrorType: underlyingErrorType ?? identity.type,
            underlyingErrorCode: underlyingErrorCode ?? identity.code,
            correlationID: correlationID,
            durationMs: durationMs,
            metadata: metadata
        )

        #if DEBUG
        events.append(event)
        if events.count > Self.maximumMemoryEvents {
            events.removeFirst(events.count - Self.maximumMemoryEvents)
        }

        if let line = try? AppDebugEventJSONLCodec.encodeLine(event) {
            try? writer.append(line)
        }
        emitToOSLog(event)
        #endif

        return event
    }

    func configureTestOps(_ configuration: AppTestOpsConfiguration) {
        testOpsConfiguration = configuration.isEnabled ? configuration : nil
        guard configuration.isEnabled else { return }

        recordTestOps(
            level: .info,
            phase: "launch",
            source: "AppDebugEventRecorder.configureTestOps",
            message: "TestOps launch context configured",
            metadata: configuration.metadata
        )
    }

    @discardableResult
    func recordTestOps(
        level: AppDebugEventLevel,
        phase: String,
        actorRole: String? = nil,
        source: String,
        message: String,
        underlyingError: (any Error)? = nil,
        durationMs: Int? = nil,
        metadata: [String: String] = [:]
    ) -> AppDebugEvent {
        let configuration = testOpsConfiguration
        var testMetadata = metadata
        if let runID = configuration?.runID {
            testMetadata["automationRunID"] = runID
        }
        if let scenarioID = configuration?.scenarioID {
            testMetadata["scenarioID"] = scenarioID
        }
        testMetadata["phase"] = phase
        if let actorRole {
            testMetadata["actorRole"] = actorRole
        }

        let event = record(
            level: level,
            category: .test,
            source: source,
            scope: configuration?.scope ?? "testops",
            message: message,
            underlyingError: underlyingError,
            correlationID: configuration?.runID,
            durationMs: durationMs,
            metadata: testMetadata
        )
        latestTestOpsEvent = event
        return event
    }

    func clear() {
        events = []
        latestTestOpsEvent = nil
        try? writer.clear()
    }

    func exportSnapshot(since date: Date) -> String {
        events
            .filter { $0.timestamp >= date }
            .compactMap { try? AppDebugEventJSONLCodec.encodeLine($0) }
            .joined(separator: "\n")
    }

    var recentErrorsAndCancellations: [AppDebugEvent] {
        events.filter {
            $0.level == .error
                || $0.message.lowercased().contains("cancelled")
        }
    }

    var testOpsSnapshot: AppDebugTestOpsSnapshot? {
        guard let configuration = testOpsConfiguration else { return nil }

        return AppDebugTestOpsSnapshot(
            runID: configuration.runID.map(AppDebugEventSanitizer.supportReference),
            scenarioID: configuration.scenarioID,
            activePhase: latestTestOpsEvent?.metadata["phase"],
            actorRole: latestTestOpsEvent?.metadata["actorRole"],
            latestEvent: latestTestOpsEvent
        )
    }

    private func emitToOSLog(_ event: AppDebugEvent) {
        guard emitsToOSLog else { return }
        let line = [
            event.timestamp.formatted(.iso8601),
            event.level.rawValue,
            event.category.rawValue,
            event.scope ?? "global",
            event.source,
            event.message,
        ].joined(separator: " | ")

        switch event.level {
        case .debug:
            logger.debug("\(line, privacy: .public)")
        case .info:
            logger.info("\(line, privacy: .public)")
        case .warning:
            logger.warning("\(line, privacy: .public)")
        case .error:
            logger.error("\(line, privacy: .public)")
        }
    }
}

enum AppDebugErrorClassifier {
    static func isCancellation(_ error: any Error) -> Bool {
        if error is CancellationError {
            return true
        }

        if let urlError = error as? URLError,
           urlError.code == .cancelled {
            return true
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain,
           nsError.code == NSURLErrorCancelled {
            return true
        }

        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? any Error {
            return isCancellation(underlying)
        }

        return false
    }

    static func identity(for error: (any Error)?) -> (
        type: String?,
        code: String?
    ) {
        guard let error else { return (nil, nil) }

        if let urlError = error as? URLError {
            return ("URLError", "\(urlError.code.rawValue)")
        }

        let nsError = error as NSError
        let typeName = String(describing: type(of: error))
        if nsError.domain != typeName,
           nsError.domain.hasSuffix(".\(typeName)") == false {
            return (nsError.domain, "\(nsError.code)")
        }

        return (
            typeName,
            String(describing: error)
        )
    }
}

private struct AppDebugEventRecorderKey: EnvironmentKey {
    static let defaultValue: AppDebugEventRecorder? = nil
}

extension EnvironmentValues {
    var appDebugEventRecorder: AppDebugEventRecorder? {
        get { self[AppDebugEventRecorderKey.self] }
        set { self[AppDebugEventRecorderKey.self] = newValue }
    }
}

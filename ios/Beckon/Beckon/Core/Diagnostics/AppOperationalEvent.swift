import Foundation
import OSLog
import SwiftUI

enum AppOperationalEventLevel: String, CaseIterable, Codable, Sendable {
    case info
    case warning
    case error
}

enum AppOperationalEventCategory: String, CaseIterable, Codable, Sendable {
    case lifecycle
    case funnel
    case crash
}

enum AppOperationalFunnelStep: String, CaseIterable, Codable, Sendable {
    case appLaunch = "app.launch"
    case appForegrounded = "app.foregrounded"
    case appBackgrounded = "app.backgrounded"
    case authSignedOut = "auth.signed_out"
    case authRestored = "auth.restored"
    case roleOnboarding = "role.onboarding"
    case roleResolved = "role.resolved"
    case profileLoadFailed = "profile.load_failed"

    var message: String {
        switch self {
        case .appLaunch:
            "App launch recorded."
        case .appForegrounded:
            "App foregrounded."
        case .appBackgrounded:
            "App backgrounded."
        case .authSignedOut:
            "Signed-out auth state reached."
        case .authRestored:
            "Signed-in auth state restored."
        case .roleOnboarding:
            "Role onboarding reached."
        case .roleResolved:
            "Role workspace resolved."
        case .profileLoadFailed:
            "Profile load failed."
        }
    }
}

struct AppOperationalEvent: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let timestamp: Date
    let level: AppOperationalEventLevel
    let category: AppOperationalEventCategory
    let source: String
    let scope: String?
    let message: String
    let correlationID: String?
    let metadata: [String: String]

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: AppOperationalEventLevel,
        category: AppOperationalEventCategory,
        source: String,
        scope: String? = nil,
        message: String,
        correlationID: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.source = AppDebugEventSanitizer.sanitizedText(source)
        self.scope = scope.map(AppDebugEventSanitizer.sanitizedText)
        self.message = AppDebugEventSanitizer.sanitizedText(message)
        self.correlationID = correlationID.map(AppDebugEventSanitizer.supportReference)
        self.metadata = AppDebugEventSanitizer.sanitizedMetadata(metadata)
    }
}

enum AppOperationalEventJSONLCodec {
    static func encodeLine(_ event: AppOperationalEvent) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(event)
        return String(decoding: data, as: UTF8.self)
    }

    static func decodeLine(_ line: String) throws -> AppOperationalEvent {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AppOperationalEvent.self, from: Data(line.utf8))
    }
}

@MainActor
protocol AppOperationalEventWriting: AnyObject {
    func append(_ line: String) throws
    func replace(with lines: [String]) throws
    func clear() throws
}

@MainActor
final class AppOperationalEventFileWriter: AppOperationalEventWriting {
    let fileURL: URL
    private let fileManager: FileManager
    private let maximumLineCount: Int
    private let retentionInterval: TimeInterval

    init(
        fileManager: FileManager = .default,
        directoryURL: URL? = nil,
        maximumLineCount: Int = 1_000,
        retentionInterval: TimeInterval = 7 * 24 * 60 * 60
    ) {
        self.fileManager = fileManager
        self.maximumLineCount = maximumLineCount
        self.retentionInterval = retentionInterval

        let supportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        fileURL = (directoryURL ?? supportURL.appendingPathComponent("BeckonOperational", isDirectory: true))
            .appendingPathComponent("operational-events.jsonl")
        try? trimExistingLog()
    }

    func append(_ line: String) throws {
        try ensureDirectory()
        if fileManager.fileExists(atPath: fileURL.path) == false {
            fileManager.createFile(atPath: fileURL.path, contents: nil)
        }

        let handle = try FileHandle(forWritingTo: fileURL)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data((line + "\n").utf8))
        try handle.close()

        if ((try? readLines()) ?? []).count > maximumLineCount {
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
        let cutoff = Date().addingTimeInterval(-retentionInterval)
        let retained = ((try? readLines()) ?? [])
            .suffix(maximumLineCount)
            .filter { line in
                guard let event = try? AppOperationalEventJSONLCodec.decodeLine(line) else {
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
}

@MainActor
@Observable
final class AppOperationalEventRecorder {
    static let shared = AppOperationalEventRecorder()
    static let maximumMemoryEvents = 1_000

    private enum RunState {
        static let active = "active"
        static let background = "background"
    }

    private enum DefaultsKey {
        static let runID = "beckon.operational.currentRunID"
        static let runState = "beckon.operational.currentRunState"
        static let updatedAt = "beckon.operational.currentRunUpdatedAt"
    }

    private(set) var events: [AppOperationalEvent] = []
    private let writer: any AppOperationalEventWriting
    private let userDefaults: UserDefaults
    private let now: () -> Date
    private let makeRunID: () -> UUID
    private let logger = Logger(
        subsystem: "com.hellobeckon.beckon",
        category: "OperationalEvents"
    )
    private var runID: UUID?
    #if DEBUG
    private var debugRecorder: AppDebugEventRecorder?
    #endif

    init(
        writer: (any AppOperationalEventWriting)? = nil,
        userDefaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init,
        makeRunID: @escaping () -> UUID = UUID.init
    ) {
        self.writer = writer ?? AppOperationalEventFileWriter()
        self.userDefaults = userDefaults
        self.now = now
        self.makeRunID = makeRunID
    }

    #if DEBUG
    func setDebugRecorder(_ recorder: AppDebugEventRecorder?) {
        debugRecorder = recorder
    }
    #endif

    func beginLaunch() {
        recordCrashSuspectIfNeeded()

        let newRunID = makeRunID()
        runID = newRunID
        persistRun(state: RunState.active, runID: newRunID)
        recordFunnelStep(.appLaunch, scope: "app")
    }

    func recordScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            let activeRunID = runID ?? makeRunID()
            runID = activeRunID
            persistRun(state: RunState.active, runID: activeRunID)
            recordFunnelStep(.appForegrounded, scope: "app")
        case .background:
            let activeRunID = runID ?? makeRunID()
            runID = activeRunID
            persistRun(state: RunState.background, runID: activeRunID)
            recordFunnelStep(.appBackgrounded, scope: "app")
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    func recordFunnelStep(
        _ step: AppOperationalFunnelStep,
        scope: String,
        actorRole: UserRole? = nil,
        metadata: [String: String] = [:]
    ) {
        var eventMetadata = metadata
        eventMetadata["step"] = step.rawValue
        if let actorRole {
            eventMetadata["actorRole"] = actorRole.rawValue
        }

        record(
            level: step == .profileLoadFailed ? .warning : .info,
            category: .funnel,
            source: "AppOperationalEventRecorder.recordFunnelStep",
            scope: scope,
            message: step.message,
            metadata: eventMetadata
        )
    }

    @discardableResult
    func record(
        level: AppOperationalEventLevel,
        category: AppOperationalEventCategory,
        source: String,
        scope: String? = nil,
        message: String,
        correlationID: String? = nil,
        metadata: [String: String] = [:]
    ) -> AppOperationalEvent {
        let event = AppOperationalEvent(
            timestamp: now(),
            level: level,
            category: category,
            source: source,
            scope: scope,
            message: message,
            correlationID: correlationID ?? runID?.uuidString,
            metadata: metadata
        )
        events.append(event)
        if events.count > Self.maximumMemoryEvents {
            events.removeFirst(events.count - Self.maximumMemoryEvents)
        }

        if let line = try? AppOperationalEventJSONLCodec.encodeLine(event) {
            try? writer.append(line)
        }
        emitToOSLog(event)
        mirrorToDebugRecorder(event)
        return event
    }

    func clear() {
        events = []
        try? writer.clear()
    }

    private func recordCrashSuspectIfNeeded() {
        guard userDefaults.string(forKey: DefaultsKey.runState) == RunState.active,
              let previousRunID = userDefaults.string(forKey: DefaultsKey.runID) else {
            return
        }

        record(
            level: .warning,
            category: .crash,
            source: "AppOperationalEventRecorder.beginLaunch",
            scope: "app",
            message: "Previous run did not close cleanly.",
            correlationID: previousRunID,
            metadata: [
                "previousRunID": previousRunID,
                "previousState": RunState.active,
            ]
        )
    }

    private func persistRun(state: String, runID: UUID) {
        userDefaults.set(runID.uuidString, forKey: DefaultsKey.runID)
        userDefaults.set(state, forKey: DefaultsKey.runState)
        userDefaults.set(now().timeIntervalSince1970, forKey: DefaultsKey.updatedAt)
    }

    private func emitToOSLog(_ event: AppOperationalEvent) {
        let line = [
            event.timestamp.formatted(.iso8601),
            event.level.rawValue,
            event.category.rawValue,
            event.scope ?? "global",
            event.source,
            event.message,
        ].joined(separator: " | ")

        switch event.level {
        case .info:
            logger.info("\(line, privacy: .public)")
        case .warning:
            logger.warning("\(line, privacy: .public)")
        case .error:
            logger.error("\(line, privacy: .public)")
        }
    }

    private func mirrorToDebugRecorder(_ event: AppOperationalEvent) {
        #if DEBUG
        let debugLevel: AppDebugEventLevel = switch event.level {
        case .info:
            .info
        case .warning:
            .warning
        case .error:
            .error
        }
        let debugCategory: AppDebugEventCategory = switch event.category {
        case .lifecycle, .crash:
            .lifecycle
        case .funnel:
            .action
        }
        debugRecorder?.record(
            level: debugLevel,
            category: debugCategory,
            source: event.source,
            scope: event.scope,
            message: event.message,
            correlationID: event.correlationID,
            metadata: event.metadata
        )
        #endif
    }
}

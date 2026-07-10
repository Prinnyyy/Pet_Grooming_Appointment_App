import Foundation
import SwiftUI
import Testing
@testable import Beckon

struct AppDebugEventTests {
    @Test @MainActor
    func metadataSanitizerRedactsSensitiveValues() throws {
        let metadata = AppDebugEventSanitizer.sanitizedMetadata(
            [
                "email": "owner@example.com",
                "password": "plain-text-password",
                "userID": "11111111-2222-3333-4444-555555555555",
                "storagePath": "groomer-avatars/11111111-2222-3333-4444-555555555555/avatar.jpg",
                "signedURL": "https://example.supabase.co/storage/v1/object/sign/groomer-avatars/avatar.jpg?token=secret-token",
            ]
        )
        let event = AppDebugEvent(
            level: .error,
            category: .repository,
            source: "SupabaseBookingRepository.bookings",
            scope: "customer.bookings",
            message: "owner@example.com failed with token secret-token",
            underlyingErrorType: "URLError",
            underlyingErrorCode: "-1001",
            correlationID: "11111111-2222-3333-4444-555555555555",
            durationMs: 120,
            metadata: metadata
        )
        let line = try AppDebugEventJSONLCodec.encodeLine(event)

        #expect(metadata["email"] == "example.com")
        #expect(metadata["password"] == "[redacted]")
        #expect(metadata["userID"] == "11111111")
        #expect(metadata["signedURL"] == "[redacted-url]")
        #expect(line.contains("owner@example.com") == false)
        #expect(line.contains("plain-text-password") == false)
        #expect(line.contains("secret-token") == false)
        #expect(line.contains("11111111-2222-3333-4444-555555555555") == false)
    }

    @Test @MainActor
    func feedbackCenterRecordsPromptLifecycleEvents() throws {
        let writer = AppDebugEventWriterSpy()
        let recorder = AppDebugEventRecorder(
            writer: writer,
            emitsToOSLog: false
        )
        let center = BeckonFeedbackCenter(debugRecorder: recorder)
        let scope = BeckonFeedbackScope.page("customer.bookings")
        let error = BeckonGlobalFeedbackError(
            scope: scope,
            sourceKey: "customer.bookings.load",
            title: "We Could Not Update Requests",
            message: "We could not load bookings. Please try again."
        )

        center.showError(error)
        center.showError(error)
        center.clearTransientPrompts(in: scope)

        let sources = recorder.events.map(\.source)
        #expect(sources.contains("BeckonFeedbackCenter.enqueue"))
        #expect(sources.contains("BeckonFeedbackCenter.presented"))
        #expect(sources.contains("BeckonFeedbackCenter.suppressedDuplicate"))
        #expect(sources.contains("BeckonFeedbackCenter.clearedScope"))
        #expect(sources.contains("BeckonFeedbackCenter.dismissed"))

        let enqueue = try #require(
            recorder.events.first { $0.source == "BeckonFeedbackCenter.enqueue" }
        )
        #expect(enqueue.scope == "customer.bookings")
        #expect(enqueue.metadata["sourceKey"] == "customer.bookings.load")
        #expect(enqueue.metadata["title"] == "We Could Not Update Requests")
        #expect(enqueue.metadata["message"] == "We could not load bookings. Please try again.")
        #expect(writer.lines.isEmpty == false)
    }

    @Test @MainActor
    func cancellationClassifierRecognizesTaskAndNetworkCancellation() {
        #expect(AppDebugErrorClassifier.isCancellation(CancellationError()))
        #expect(AppDebugErrorClassifier.isCancellation(URLError(.cancelled)))
        #expect(
            AppDebugErrorClassifier.isCancellation(
                NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)
            )
        )
    }

    @Test @MainActor
    func testOpsEventsIncludeScenarioMetadataAndStaySanitized() throws {
        let writer = AppDebugEventWriterSpy()
        let recorder = AppDebugEventRecorder(
            writer: writer,
            emitsToOSLog: false
        )
        let configuration = AppTestOpsConfiguration(
            runID: "TESTOPS-20260701-123456",
            scenarioID: "marketplace_full_lifecycle",
            clearsSessionBeforeRestore: true,
            disablesAnimations: true
        )
        recorder.configureTestOps(configuration)

        recorder.recordTestOps(
            level: .info,
            phase: "customer.publish",
            actorRole: "customer",
            source: "TestOps.backend.marketplaceFullLifecycle",
            message: "signed in beckon.customer001@example.com with token=secret",
            metadata: [
                "customerUUID": "11111111-2222-3333-4444-555555555555",
                "email": "beckon.customer001@example.com",
                "password": "BeckonTest!2026",
            ]
        )

        let event = try #require(recorder.events.last)
        let line = try #require(writer.lines.last)

        #expect(event.category == .test)
        #expect(event.scope == "testops.marketplace_full_lifecycle")
        #expect(event.correlationID == "TESTOPS-2026")
        #expect(event.metadata["automationRunID"] == "TESTOPS-2026")
        #expect(event.metadata["scenarioID"] == "marketplace_full_lifecycle")
        #expect(event.metadata["phase"] == "customer.publish")
        #expect(event.metadata["actorRole"] == "customer")
        #expect(event.metadata["customerUUID"] == "11111111")
        #expect(event.metadata["email"] == "example.com")
        #expect(event.metadata["password"] == "[redacted]")
        #expect(line.contains("beckon.customer001@example.com") == false)
        #expect(line.contains("BeckonTest!2026") == false)
        #expect(line.contains("secret") == false)
        #expect(recorder.testOpsSnapshot?.runID == "TESTOPS-2026")
        #expect(recorder.testOpsSnapshot?.scenarioID == "marketplace_full_lifecycle")
        #expect(recorder.testOpsSnapshot?.latestEvent?.source == "TestOps.backend.marketplaceFullLifecycle")
    }
}

struct AppOperationalEventTests {
    @Test @MainActor
    func operationalEventsSanitizeSensitiveMetadata() throws {
        let event = AppOperationalEvent(
            level: .info,
            category: .funnel,
            source: "CustomerRequestsStore.publish",
            scope: "customer.requests",
            message: "owner@example.com published request with token=secret-token",
            correlationID: "11111111-2222-3333-4444-555555555555",
            metadata: [
                "email": "owner@example.com",
                "userID": "11111111-2222-3333-4444-555555555555",
                "password": "plain-text-password",
                "requestCount": "1",
            ]
        )

        let line = try AppOperationalEventJSONLCodec.encodeLine(event)

        #expect(event.metadata["email"] == "example.com")
        #expect(event.metadata["userID"] == "11111111")
        #expect(event.metadata["password"] == "[redacted]")
        #expect(event.metadata["requestCount"] == "1")
        #expect(event.correlationID == "11111111")
        #expect(line.contains("owner@example.com") == false)
        #expect(line.contains("plain-text-password") == false)
        #expect(line.contains("secret-token") == false)
        #expect(line.contains("11111111-2222-3333-4444-555555555555") == false)
    }

    @Test @MainActor
    func operationalRecorderWritesTrimmedLocalJSONL() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let writer = AppOperationalEventFileWriter(
            directoryURL: directoryURL,
            maximumLineCount: 2,
            retentionInterval: 24 * 60 * 60
        )
        let recorder = AppOperationalEventRecorder(
            writer: writer,
            userDefaults: isolatedOperationalEventDefaults(),
            now: Date.init,
            makeRunID: UUID.init
        )

        recorder.recordFunnelStep(.appLaunch, scope: "app")
        recorder.recordFunnelStep(.authRestored, scope: "auth")
        recorder.recordFunnelStep(.roleResolved, scope: "customer.home", actorRole: .customer)

        let lines = try writer.readLines()
        #expect(lines.count == 2)

        let events = try lines.map(AppOperationalEventJSONLCodec.decodeLine)
        #expect(events.map(\.metadata["step"]) == ["auth.restored", "role.resolved"])
        #expect(events.last?.metadata["actorRole"] == "customer")
        #expect(events.last?.scope == "customer.home")
    }

    @Test @MainActor
    func launchDetectsPreviousRunThatStayedActive() throws {
        let writer = AppOperationalEventWriterSpy()
        let userDefaults = isolatedOperationalEventDefaults()
        let firstRunID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let secondRunID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!

        let firstRecorder = AppOperationalEventRecorder(
            writer: writer,
            userDefaults: userDefaults,
            now: { Date(timeIntervalSince1970: 1_000) },
            makeRunID: { firstRunID }
        )
        firstRecorder.beginLaunch()
        firstRecorder.recordScenePhase(.active)

        let secondRecorder = AppOperationalEventRecorder(
            writer: writer,
            userDefaults: userDefaults,
            now: { Date(timeIntervalSince1970: 1_100) },
            makeRunID: { secondRunID }
        )
        secondRecorder.beginLaunch()

        let crashSuspect = try #require(
            secondRecorder.events.first { $0.category == .crash }
        )
        #expect(crashSuspect.level == .warning)
        #expect(crashSuspect.message == "Previous run did not close cleanly.")
        #expect(crashSuspect.metadata["previousRunID"] == "11111111")
        #expect(crashSuspect.metadata["previousState"] == "active")
    }

    @Test @MainActor
    func backgroundedPreviousRunDoesNotRecordCrashSuspect() throws {
        let writer = AppOperationalEventWriterSpy()
        let userDefaults = isolatedOperationalEventDefaults()

        let firstRecorder = AppOperationalEventRecorder(
            writer: writer,
            userDefaults: userDefaults,
            now: { Date(timeIntervalSince1970: 2_000) },
            makeRunID: { UUID(uuidString: "11111111-2222-3333-4444-555555555555")! }
        )
        firstRecorder.beginLaunch()
        firstRecorder.recordScenePhase(.active)
        firstRecorder.recordScenePhase(.background)

        let secondRecorder = AppOperationalEventRecorder(
            writer: writer,
            userDefaults: userDefaults,
            now: { Date(timeIntervalSince1970: 2_100) },
            makeRunID: { UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")! }
        )
        secondRecorder.beginLaunch()

        #expect(secondRecorder.events.contains { $0.category == .crash } == false)
    }

    private func isolatedOperationalEventDefaults() -> UserDefaults {
        let suiteName = "AppOperationalEventTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

@MainActor
final class AppDebugEventWriterSpy: AppDebugEventWriting {
    private(set) var lines: [String] = []

    func append(_ line: String) throws {
        lines.append(line)
    }

    func replace(with lines: [String]) throws {
        self.lines = lines
    }

    func clear() throws {
        lines = []
    }
}

@MainActor
final class AppOperationalEventWriterSpy: AppOperationalEventWriting {
    private(set) var lines: [String] = []

    func append(_ line: String) throws {
        lines.append(line)
    }

    func replace(with lines: [String]) throws {
        self.lines = lines
    }

    func clear() throws {
        lines = []
    }
}

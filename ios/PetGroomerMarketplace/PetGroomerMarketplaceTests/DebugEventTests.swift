import Foundation
import Testing
@testable import PetGroomerMarketplace

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
        let center = GroomlyFeedbackCenter(debugRecorder: recorder)
        let scope = GroomlyFeedbackScope.page("customer.bookings")
        let error = GroomlyGlobalFeedbackError(
            scope: scope,
            sourceKey: "customer.bookings.load",
            title: "We Could Not Update Requests",
            message: "We could not load bookings. Please try again."
        )

        center.showError(error)
        center.showError(error)
        center.clearTransientPrompts(in: scope)

        let sources = recorder.events.map(\.source)
        #expect(sources.contains("GroomlyFeedbackCenter.enqueue"))
        #expect(sources.contains("GroomlyFeedbackCenter.presented"))
        #expect(sources.contains("GroomlyFeedbackCenter.suppressedDuplicate"))
        #expect(sources.contains("GroomlyFeedbackCenter.clearedScope"))
        #expect(sources.contains("GroomlyFeedbackCenter.dismissed"))

        let enqueue = try #require(
            recorder.events.first { $0.source == "GroomlyFeedbackCenter.enqueue" }
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
            message: "signed in groomly.customer001@example.com with token=secret",
            metadata: [
                "customerUUID": "11111111-2222-3333-4444-555555555555",
                "email": "groomly.customer001@example.com",
                "password": "GroomlyTest!2026",
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
        #expect(line.contains("groomly.customer001@example.com") == false)
        #expect(line.contains("GroomlyTest!2026") == false)
        #expect(line.contains("secret") == false)
        #expect(recorder.testOpsSnapshot?.runID == "TESTOPS-2026")
        #expect(recorder.testOpsSnapshot?.scenarioID == "marketplace_full_lifecycle")
        #expect(recorder.testOpsSnapshot?.latestEvent?.source == "TestOps.backend.marketplaceFullLifecycle")
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

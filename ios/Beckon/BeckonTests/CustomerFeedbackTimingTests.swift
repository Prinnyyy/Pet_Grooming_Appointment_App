import Foundation
import Testing
@testable import Beckon

@MainActor
struct CustomerFeedbackTimingTests {
    @Test func readingTimeUsesTextLengthWithKindSpecificFloorsAndCaps() {
        #expect(FeedbackTimingPolicy.seconds(.notice, "Saved") == 4)
        #expect(FeedbackTimingPolicy.seconds(.error, "Failed") == 5)
        #expect(FeedbackTimingPolicy.seconds(.snackbar, "Removed") == 6)
        #expect(abs(FeedbackTimingPolicy.seconds(.notice, words: 16) - 7.1) < 0.001)
        #expect(FeedbackTimingPolicy.seconds(.notice, words: 100) == 8)
        #expect(FeedbackTimingPolicy.seconds(.error, words: 100) == 9)
        #expect(FeedbackTimingPolicy.seconds(.snackbar, words: 100) == 10)
        #expect(FeedbackTimingPolicy.seconds(.notice, "one two three four", "five six seven eight nine ten") == 5)
    }

    @Test func toastPreservesSentenceCaseNamesAndDecimals() {
        let split = BeckonNoticeToast.split("Saved for McKenzie. Paid $12.50.")
        #expect(split.title == "Saved for McKenzie")
        #expect(split.detail == "Paid $12.50.")
        #expect(BeckonNoticeToast.split("Paid $12.50.").title == "Paid $12.50")
    }

    @Test func staleSnackbarDismissCannotRemoveReplacementAndUndoRunsOnce() async throws {
        let center = SnackbarCenter()
        var calls = 0
        center.show(title: "Removed", systemImage: "heart.slash") { calls += 100 }
        let oldID = try #require(center.item?.id)
        center.show(title: "Removed another", systemImage: "heart.slash") { calls += 1 }
        center.dismiss(oldID)
        #expect(center.item != nil)
        center.perform()
        center.perform()
        #expect(center.item == nil)
        for _ in 0..<20 where calls == 0 { await Task.yield() }
        #expect(calls == 1)
    }

    @Test func completedProgressCancelsNoOtherPromptAndTimersStartOnPresentation() async throws {
        let center = BeckonFeedbackCenter()
        let progress = BeckonGlobalFeedbackProgress(title: "Sending")
        center.showProgress(progress)
        let notice = center.showNotice("Sent.")
        #expect(center.promptExpiresAt == nil)
        let releasedAt = Date()
        center.clearProgress(matching: progress)
        let deadline = ContinuousClock.now + .seconds(10)
        while center.notice?.id != notice && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(center.notice?.id == notice)
        let expiresAt = try #require(center.promptExpiresAt)
        // Assert the timer's origin, not how quickly this test gets its MainActor turn.
        #expect(expiresAt.timeIntervalSince(releasedAt) >= FeedbackTimingPolicy.seconds(.notice, "Sent."))
        #expect(expiresAt.timeIntervalSinceNow <= FeedbackTimingPolicy.seconds(.notice, "Sent."))
        center.clearNotice(id: notice)
        #expect(center.promptExpiresAt == nil)
    }
}

import Foundation
import Testing
@testable import Beckon

@MainActor struct GroomerRequestStageTests {
    @Test func newAndOfferedShareTheRequestStoryButDoNotShareMatches() {
        let matches = GroomerSandboxFixtures.matches()
        let now = Date()
        let new = GroomerRequestStage(.init(matched: matches[0]), now: now)
        let offered = GroomerRequestStage(.init(matched: matches[4]), now: now)
        #expect(new.kind == .new)
        #expect(new.canAnswer)
        #expect(offered.kind == .offered)
        #expect(!offered.canAnswer)
        #expect(offered.canWithdraw)
    }

    @Test func expiryBoundaryClosesAnOtherwiseStaleOpenRequest() throws {
        let matched = GroomerSandboxFixtures.matches()[0]
        let expiry = try #require(GroomingRequestDateFormatting.parsedDate(from: matched.request.expiresAt))
        let before = GroomerRequestStage(.init(matched: matched), now: expiry.addingTimeInterval(-1))
        let exact = GroomerRequestStage(.init(matched: matched), now: expiry)
        let after = GroomerRequestStage(.init(matched: matched), now: expiry.addingTimeInterval(1))
        #expect(before.kind == .new && before.closesSoon)
        #expect(exact.kind == .closed && !exact.canAnswer)
        #expect(after.kind == .closed && !after.canAnswer)
        #expect(exact.closed?.status.title == "Expired")
    }

    @Test func closingWithin24HoursIsStrictAndNotAnExpiredCountdown() throws {
        let matched = GroomerSandboxFixtures.matches()[0]
        let expiry = try #require(GroomingRequestDateFormatting.parsedDate(from: matched.request.expiresAt))
        #expect(!GroomerRequestStage(.init(matched: matched), now: expiry.addingTimeInterval(-86400)).closesSoon)
        #expect(GroomerRequestStage(.init(matched: matched), now: expiry.addingTimeInterval(-86399)).closesSoon)
        #expect(!GroomerRequestStage(.init(matched: matched), now: expiry).closesSoon)
    }

    @Test func offerGroupsPartitionTheirInputAndAcceptedOffersStayBooked() throws {
        let items = GroomerSandboxFixtures.offers()
        let groups = GroomerOfferGroups(items, now: Date())
        let all = groups.attention + groups.pending + groups.booked + groups.earlier
        #expect(Set(all.map(\.id)) == Set(items.map(\.id)))
        #expect(all.count == items.count)
        for item in items where item.offer.status == .acceptedByCustomer {
            #expect(GroomerRequestStage(.init(item: item), now: .distantFuture).kind == .booked)
        }
        #expect(!groups.earlier.isEmpty)
    }

    @Test func invalidQuoteIsAnActionFailureRatherThanPaginationFailure() async {
        let session = GroomerSandboxSession(state: .loaded)
        await session.requests.load()
        let matched = GroomerSandboxFixtures.matches()[0]
        await session.requests.submitOffer(for: matched, proposedStart: Date(), proposedEnd: Date(),
            priceEstimateText: "invalid", message: "")
        #expect(session.requests.actionErrorMessage != nil)
        #expect(session.requests.loadMoreErrorMessage == nil)
        #expect(session.requests.loadErrorMessage == nil)
        await session.requests.load()
        #expect(session.requests.actionErrorMessage == nil)
    }

    @Test func pageReadFailureDoesNotBecomeAnActionOrPaginationFailure() async {
        let repository = GroomerRequestRepositoryFake(matchedRequestsResult: .failure(.networkUnavailable))
        let store = GroomerRequestsStore(groomerID: UUID(), repository: repository)
        await store.load()
        #expect(store.loadErrorMessage != nil)
        #expect(store.actionErrorMessage == nil)
        #expect(store.loadMoreErrorMessage == nil)
    }

    @Test func localSubmitReloadWithdrawReloadKeepsOneConsistentRequestStory() async throws {
        let session = GroomerSandboxSession(state: .loaded)
        await session.requests.load()
        let matched = GroomerSandboxFixtures.matches()[0]
        let start = try #require(GroomingRequestDateFormatting.parsedDate(from: matched.request.preferredStart))
        await session.requests.submitOffer(for: matched, proposedStart: start, proposedEnd: start.addingTimeInterval(3600),
            priceEstimateText: "85", message: "Gentle care")
        #expect(session.requests.actionErrorMessage == nil)
        await session.offers.load()
        let item = try #require(session.offers.offers.first { $0.offer.requestID == matched.request.id })
        #expect(item.offer.priceEstimate == 85)
        #expect(item.offer.message == "Gentle care")
        await session.requests.load()
        let offered = try #require(session.requests.matchedRequests.first { $0.id == matched.id })
        #expect(GroomerRequestStage(.init(matched: offered), now: Date()).kind == .offered)
        await session.requests.withdrawOffer(for: offered)
        await session.requests.load()
        await session.offers.load()
        let reopened = try #require(session.requests.matchedRequests.first { $0.id == matched.id })
        #expect(GroomerRequestStage(.init(matched: reopened), now: Date()).kind == .new)
        #expect(session.offers.offers.first { $0.id == item.id }?.offer.status == .withdrawnByGroomer)
    }

    @Test func notificationReadAndMutationFailuresHaveDifferentOwners() async {
        let owner = UUID()
        let repository = GroomerNotificationRepositoryFake(notificationsResult: .failure(.networkUnavailable),
            markAllReadResult: .failure(.networkUnavailable))
        let store = GroomerNotificationsStore(groomerID: owner, repository: repository)
        await store.load()
        #expect(store.errorMessage != nil)
        #expect(store.actionErrorMessage == nil)
        await store.markAllRead()
        #expect(store.actionErrorMessage != nil)
        #expect(store.loadMoreErrorMessage == nil)
    }
}

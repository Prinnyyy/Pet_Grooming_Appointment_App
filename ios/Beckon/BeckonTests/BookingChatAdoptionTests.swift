import Foundation
import Testing
@testable import Beckon

@MainActor struct BookingChatAdoptionTests {
    @Test func snapshotDoesNotFollowLaterBookingChanges() throws {
        let booking = BookingsStoreTests.booking(status: .cancelledByCustomer)
        let event = ChatBookingEvent(version: 1, action: "confirmed", bookingID: booking.id,
            actorID: booking.customerID, actorRole: "customer", scheduledStart: "2026-11-06T18:00:00Z",
            scheduledEnd: "2026-11-06T19:00:00Z", price: 85, timeZone: "America/Los_Angeles")
        let display = event.displayBooking(fallback: booking)
        #expect(event.title == "Confirmed")
        #expect(display.status == .confirmed)
        #expect(display.scheduledStart == "2026-11-06T18:00:00Z")
        #expect(display.priceEstimate == 85)
        #expect(booking.status == .cancelledByCustomer, "Display snapshots must not mutate action state")
        let decoded = try JSONDecoder().decode(ChatBookingEvent.self, from: JSONEncoder().encode(event))
        #expect(decoded == event)
        #expect(event.verified(bookingID: UUID(), senderID: booking.customerID) == nil)
        #expect(event.verified(bookingID: booking.id, senderID: booking.groomerID) == nil)
    }

    @Test func cancellationAndCompletionUseTheActorNotTheRecordedCompleter() {
        let booking = BookingsStoreTests.booking(status: .completed)
        for (actor, role) in [(booking.customerID, "customer"), (booking.groomerID, "groomer")] {
            let event = ChatBookingEvent(version: 1, action: "cancel", bookingID: booking.id, actorID: actor, actorRole: role)
            #expect(event.title == "Cancelled by \(role)")
            let message = ChatMessage(id: UUID(), conversationID: UUID(), senderID: actor, kind: .bookingCard,
                body: nil, booking: booking, createdAt: booking.createdAt, bookingEvent: event)
            #expect(message.isSentBy(actor))
        }
        let confirmation = ChatBookingEvent(version: 1, action: "confirm_completion", bookingID: booking.id,
            actorID: booking.customerID, actorRole: "customer")
        #expect(confirmation.title == "Completed")
        #expect(confirmation.actorID == booking.customerID)
    }

    @Test func legacyAutomaticTextIsHiddenButAnIdenticalHumanMessageStays() {
        let booking = BookingsStoreTests.booking()
        let conversation = UUID()
        let card = ChatMessage(id: UUID(), conversationID: conversation, senderID: booking.customerID, kind: .bookingCard,
            body: nil, booking: booking, createdAt: "2026-11-03T12:00:00.123456Z")
        let body = "Hi! I've accepted your offer and confirmed this booking. Looking forward to working with you!"
        let automatic = ChatMessage(id: UUID(), conversationID: conversation, senderID: booking.customerID, kind: .text,
            body: body, booking: nil, createdAt: "2026-11-03T12:00:00.123457Z")
        let human = ChatMessage(id: UUID(), conversationID: conversation, senderID: booking.customerID, kind: .text,
            body: body, booking: nil, createdAt: "2026-11-03T12:00:01.123457Z")
        let visible = ChatLegacyBookingMessages.present([card, automatic, human])
        #expect(visible.map(\.id) == [card.id, human.id])
        #expect(visible.first?.bookingEvent?.title == "Confirmed")
        #expect(ChatLegacyBookingMessages.present([automatic]).count == 1, "Never hide an unpaired text")
    }

    @Test func snapshotSurvivesCacheWithoutRestoringActionStores() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let booking = BookingsStoreTests.booking()
        let conversation = ChatConversation(id: UUID(), customerID: booking.customerID, groomerID: booking.groomerID,
            createdAt: booking.createdAt, updatedAt: booking.updatedAt)
        let event = ChatBookingEvent(version: 1, action: "start", bookingID: booking.id, actorID: booking.groomerID, actorRole: "groomer")
        let message = ChatMessage(id: UUID(), conversationID: conversation.id, senderID: booking.groomerID,
            kind: .bookingCard, body: nil, booking: booking, createdAt: booking.createdAt, bookingEvent: event)
        let cache = FileChatDisplayCache(directory: directory)
        cache.save(participantID: booking.customerID, role: .customer, conversations: [conversation],
            messages: [conversation.id: [message]], generation: cache.generation)
        #expect(cache.snapshot(participantID: booking.customerID, role: .customer)?.messages[conversation.id]?.first?.bookingEvent == event)
        let restored = ChatStore(participantID: booking.customerID, role: .customer, repository: ChatRepositoryFake(), displayCache: cache)
        #expect(restored.bookingDetailStore(for: message) == nil)
        #expect(!restored.canSendMessages(in: conversation))
    }

    @Test func confirmedReviewClearsDraftAndDoesNotInventPetFitEvidence() async {
        let booking = BookingsStoreTests.booking(status: .completed)
        let review = BookingReview(id: UUID(), bookingID: booking.id, customerID: booking.customerID,
            groomerID: booking.groomerID, rating: 4, content: "My review", createdAt: booking.updatedAt)
        let repository = BookingRepositoryFake(bookingsResult: .success([booking]))
        repository.reviewContextResult = .success(.init(bookingID: booking.id, contextRevision: UUID(),
            evidenceContextVersion: 2, serviceAt: nil, allowedKeys: []))
        repository.reviewResult = .success(.init(review: review, groomerRatingAverage: 4, groomerRatingCount: 1))
        let store = BookingsStore(participantID: booking.customerID, role: .customer, repository: repository, initialBookings: [booking])
        store.updateReviewComposeDraft(.init(rating: 4, content: "My review"), for: booking)
        await store.loadReviewContext(for: booking)
        await store.createReview(for: booking, rating: 4, content: "My review")
        #expect(store.reviewComposeDrafts[booking.id] == nil)
        #expect(store.booking(withID: booking.id)?.review == review)
        #expect(repository.lastReviewDraft?.petFitOutcomes.isEmpty == true)
    }

    @Test func reviewDraftKeepsEditsOnFailureAndIsSeparatedByBookingAndAccount() async {
        let booking = BookingsStoreTests.booking(status: .completed)
        let repository = BookingRepositoryFake(bookingsResult: .success([booking]))
        repository.reviewContextResult = .success(.init(bookingID: booking.id, contextRevision: UUID(),
            evidenceContextVersion: 2, serviceAt: nil, allowedKeys: []))
        let store = BookingsStore(participantID: booking.customerID, role: .customer, repository: repository, initialBookings: [booking])
        var draft = BookingReviewComposeDraft(rating: 3, content: "My own words.")
        draft.toggleStarter("Handled Mochi gently.")
        draft.toggleStarter("Handled Mochi gently.")
        #expect(draft.content == "My own words.")
        store.updateReviewComposeDraft(draft, for: booking)
        await store.loadReviewContext(for: booking)
        repository.reviewResult = .failure(.networkUnavailable)
        await store.createReview(for: booking, rating: draft.rating, content: draft.content)
        #expect(store.reviewComposeDraft(for: booking.id) == draft)
        #expect(store.reviewComposeDraft(for: UUID()).content.isEmpty)
        let other = BookingsStore(participantID: UUID(), role: .customer, repository: repository)
        other.updateReviewComposeDraft(draft, for: booking)
        #expect(other.reviewComposeDraft(for: booking.id).content.isEmpty)
        #expect(repository.reviewCallCount == 1)
    }
}

import Foundation
import Testing
@testable import Beckon

@MainActor
struct CustomerFlowSandboxTests {
    @Test func everyScreenStateCanPrepareAndResetWithoutLiveServices() async throws {
        for screen in CustomerSandboxScreen.allCases {
            for state in screen.states {
                let session = CustomerSandboxSession(screen: screen, state: state)
                try await session.prepare()
                #expect(session.pets.directory.path.contains("BeckonPetFlowSandbox"))
                #expect(session.accountRepository.currentSession()?.userID == CustomerSandboxFixtures.customerID)
                session.invalidate()
                #expect(!session.boundary.isActive)
                #expect(!FileManager.default.fileExists(atPath: session.pets.directory.path))
            }
        }
    }

    @Test func loadedStoresHaveConsistentFixturesAndOffers() async throws {
        let session = CustomerSandboxSession()
        defer { session.invalidate() }
        try await session.prepare()
        await session.requests.load()
        let request = try #require(session.requests.activeRequests.first)
        await session.requests.loadOffers(for: request)
        #expect(session.requests.offerReviewsByRequestID[request.id]?.count == 3)
        #expect(session.requests.errorMessage == nil)
        await session.bookings.load()
        await session.profile.load()
        await session.chat.loadConversations()
        await session.notifications.load()
        #expect(session.profile.profile?.userID == session.customerID)
        #expect(session.chat.conversations.count == 1)
        #expect(session.notifications.unreadCount == 2)
        #expect(try await session.bookingRepository.booking(customerID: session.customerID, requestID: request.id) == nil)
    }

    @Test func cancelledBookingKeepsItsSourceRequestForRepublishing() async throws {
        let session = CustomerSandboxSession(screen: .tabs, state: .cancelled)
        defer { session.invalidate() }
        try await session.prepare()
        let booking = try #require(session.bookingRepository.items.first)
        let source = try await session.marketplaceRepository.request(customerID: session.customerID, requestID: booking.requestID)
        #expect(source.id == booking.requestID)
        #expect(source.customerID == booking.customerID)
    }

    @Test func mutationsRemainLocalAndAcceptanceIsIdempotent() async throws {
        let first = CustomerSandboxSession()
        let second = CustomerSandboxSession()
        defer { first.invalidate(); second.invalidate() }
        try await first.prepare(); try await second.prepare()
        let result = try await first.bookingRepository.acceptOffer(offerID: CustomerSandboxFixtures.id(50))
        #expect(try await first.bookingRepository.acceptOffer(offerID: CustomerSandboxFixtures.id(50)) == result)
        #expect(first.bookingRepository.items.count == 2)
        #expect(second.bookingRepository.items.count == 1)
        #expect(first.marketplaceRepository.items[0].status == .booked)
        #expect(second.marketplaceRepository.items[0].status == .hasOffers)
        _ = try await first.marketplaceRepository.setFavorite(groomerID: CustomerSandboxFixtures.id(71), isFavorite: true, expectedRevision: nil)
        #expect(!second.marketplaceRepository.savedIDs.contains(CustomerSandboxFixtures.id(71)))
        _ = try await first.chatRepository.sendMessage(conversationID: CustomerSandboxFixtures.conversationID,
            senderID: first.customerID, body: "Local only")
        #expect(second.chatRepository.messageItems.count == 3)
    }

    @Test func loadingCancellationAndErrorStatesTerminateOnReset() async throws {
        let session = CustomerSandboxSession(screen: .messages, state: .loading)
        try await session.prepare()
        let load = Task { await session.chat.loadConversations() }
        await Task.yield()
        session.invalidate()
        await load.value
        #expect(session.chat.conversations.isEmpty)
        let error = CustomerSandboxSession(screen: .requests, state: .error)
        defer { error.invalidate() }
        try await error.prepare()
        await error.requests.load()
        #expect(error.requests.errorMessage != nil)
    }

    @Test func publicationAndPhotoRecoveryUseOnlyDisposableStorage() async throws {
        for screen: CustomerSandboxScreen in [.publication, .photoRetry] {
            let session = CustomerSandboxSession(screen: screen, state: screen.states[0])
            try await session.prepare()
            #expect(session.publication.pending != nil)
            if screen == .photoRetry {
                #expect(session.requests.requestPhotoUploadRetries.count == 1)
                await session.requests.retryRequestPhotos(for: CustomerSandboxFixtures.requestID)
                #expect(session.requests.requestPhotoUploadRetries.isEmpty)
            }
            session.invalidate()
            #expect(!FileManager.default.fileExists(atPath: session.pets.directory.path))
        }
    }

    @Test func wizardBypassPreservesUserEntriesAndNeverCallsRealPublication() async throws {
        let session = CustomerSandboxSession(screen: .wizardPet)
        defer { session.invalidate() }
        try await session.prepare()
        let flow = CustomerRequestWizardState(store: session.requests)
        session.requests.streetAddress = "My own preview input"
        for _ in CustomerRequestWizardStep.allCases.dropLast() {
            session.advanceRequest(flow)
            #expect(session.requests.streetAddress == "My own preview input")
        }
        session.advanceRequest(flow)
        #expect(session.requests.isShowingWizard)
        #expect(session.requests.streetAddress == "My own preview input")
        #expect(session.requests.discoveryFlow?.requestID == nil)
        #expect(session.requests.discoveryFlow?.session != nil)
        #expect(session.publication.pending == nil)
    }

    @Test func newRequestsHaveIndependentIdentitiesAndInvitationState() async throws {
        let session = CustomerSandboxSession()
        defer { session.invalidate() }
        try await session.prepare()
        let repo = session.marketplaceRepository
        let seededIDs = Set(repo.items.map(\.id))
        let firstDraft = session.draft, secondDraft = session.draft
        let firstSession = repo.prepareLocal(draft: firstDraft)
        let secondSession = repo.prepareLocal(draft: secondDraft)
        let first = try await repo.publish(operationID: firstDraft.publishOperationID, session: firstSession,
            poolEnabled: false, groomerIDs: [CustomerSandboxFixtures.id(71)])
        let second = try await repo.publish(operationID: secondDraft.publishOperationID, session: secondSession,
            poolEnabled: true, groomerIDs: [CustomerSandboxFixtures.id(72)])
        #expect(first.requestID != second.requestID)
        #expect(first.requestID != CustomerSandboxFixtures.requestID)
        #expect(repo.items.count == seededIDs.count + 2)
        #expect(Set(repo.items.map(\.id)) == seededIDs.union([first.requestID, second.requestID]))
        #expect(try await repo.publish(operationID: firstDraft.publishOperationID, session: firstSession,
            poolEnabled: false, groomerIDs: [CustomerSandboxFixtures.id(71)]) == first)
        #expect(repo.items.count == seededIDs.count + 2)
        #expect(Set(repo.items.map(\.id)) == seededIDs.union([first.requestID, second.requestID]))
        let progress = try await repo.progress(requestIDs: [first.requestID, second.requestID])
        #expect(progress.first { $0.requestID == first.requestID }?.poolEnabled == false)
        #expect(progress.first { $0.requestID == second.requestID }?.invitations.map(\.groomerID) == [CustomerSandboxFixtures.id(72)])
    }

    @Test func chatBookingCardsUseInjectedStoreAndMemoryReadCache() async throws {
        let session = CustomerSandboxSession(screen: .chat)
        defer { session.invalidate() }
        try await session.prepare()
        #expect(session.chat.sandboxBookingStore === session.bookings)
        await session.chat.loadMessages(for: session.chatRepository.conversationFixture)
        #expect(session.bookings.booking(withID: CustomerSandboxFixtures.bookingID) != nil)
    }

    @Test func acceptedRescheduleUpdatesLocalTimeAndReplays() async throws {
        let session = CustomerSandboxSession(screen: .reschedule, state: .reschedulePending)
        defer { session.invalidate() }
        try await session.prepare()
        let proposal = try #require(session.bookingRepository.proposal)
        let operation = BookingRescheduleOperation(id: UUID(), bookingID: proposal.bookingID,
            expectedRevision: proposal.baseRevision, proposalID: proposal.id, action: .accept, newStart: nil)
        let result = try await session.bookingRepository.mutateReschedule(operation)
        #expect(result.booking.scheduledStart == proposal.proposedStart)
        #expect(result.booking.agreementSnapshot?.scheduledStart == proposal.proposedStart)
        #expect(try await session.bookingRepository.mutateReschedule(operation).booking == result.booking)
    }
}

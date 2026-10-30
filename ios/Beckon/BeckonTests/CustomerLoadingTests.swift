import Foundation
import Testing
@testable import Beckon

@MainActor
struct CustomerLoadingTests {
    @Test func revealSkipsFastPlaceholdersAndNeverRepeatsOnRefresh() {
        #expect(DesignTokens.Motion.skeletonShowDelay == 0.15)
        var state = DesignRevealState(isLoading: true)
        #expect(state.phase == .waiting)
        #expect(state.revealDelay(at: 0.1) == 0)
        let revealed = state.reveal()
        #expect(revealed)
        state.showPlaceholder(at: 3)
        #expect(state.phase == .content)
        let repeated = state.reveal()
        #expect(!repeated)
        #expect(state.startedWaiting)
        let cached = DesignRevealState(isLoading: false)
        #expect(cached.phase == .content && !cached.startedWaiting)
    }

    @Test func shownPlaceholderKeepsItsOriginalMinimumDeadline() {
        var state = DesignRevealState(isLoading: true)
        state.showPlaceholder(at: 10)
        state.showPlaceholder(at: 10.2)
        #expect(abs(state.revealDelay(at: 10.1) - 0.35) < 0.001)
        #expect(state.revealDelay(at: 10.46) == 0)
        let revealed = state.reveal()
        #expect(revealed)
        #expect(state.startedWaiting)
    }

    @Test(arguments: [CustomerSandboxState.loaded, .empty, .error])
    func actualAnswerSettlesAllFiveStores(state: CustomerSandboxState) async {
        let session = CustomerSandboxSession(state: state)
        defer { session.invalidate() }
        session.boundary.state = state
        #expect(!session.pets.store.hasLoadedOnce && !session.requests.hasLoadedOnce)
        #expect(!session.bookings.hasLoadedOnce && !session.chat.hasLoadedOnce && !session.profile.hasLoadedOnce)
        await load(session)
        #expect(session.pets.store.hasLoadedOnce && session.requests.hasLoadedOnce)
        #expect(session.bookings.hasLoadedOnce && session.chat.hasLoadedOnce && session.profile.hasLoadedOnce)
        // The same Stores retain their first-answer state across the next refresh.
        session.boundary.state = .loading
        let refresh = Task { await load(session) }
        await Task.yield()
        #expect(session.pets.store.hasLoadedOnce && session.requests.hasLoadedOnce)
        #expect(session.bookings.hasLoadedOnce && session.chat.hasLoadedOnce && session.profile.hasLoadedOnce)
        refresh.cancel()
        await refresh.value
    }

    @Test func cancellationIsNotAFirstAnswerAndRetryCanSettle() async {
        let session = CustomerSandboxSession(state: .loaded)
        defer { session.invalidate() }
        session.boundary.state = .loading
        let pending = Task { await load(session) }
        try? await Task.sleep(for: .milliseconds(30))
        pending.cancel()
        await pending.value
        #expect(!session.pets.store.hasLoadedOnce && !session.requests.hasLoadedOnce)
        #expect(!session.bookings.hasLoadedOnce && !session.chat.hasLoadedOnce && !session.profile.hasLoadedOnce)
        session.boundary.state = .loaded
        await load(session)
        #expect(session.pets.store.hasLoadedOnce && session.requests.hasLoadedOnce)
        #expect(session.bookings.hasLoadedOnce && session.chat.hasLoadedOnce && session.profile.hasLoadedOnce)
    }

    @Test func savedPetIsImmediatelyAvailableForANewRequestAndSurvivesAnOlderRead() async throws {
        let session = CustomerSandboxSession(state: .empty)
        defer { session.invalidate() }
        try await session.prepare()
        let pet = CustomerRequestsStoreTests.pet(customerID: session.customerID)
        let repository = CustomerRequestPetRepositoryFake()
        var readStarted = false
        var releaseRead = false
        repository.onPetRead = {
            readStarted = true
            while !releaseRead { await Task.yield() }
        }
        let store = CustomerRequestsStore(customerID: session.customerID, petRepository: repository,
            requestRepository: session.marketplaceRepository, bookingRepository: session.bookingRepository,
            appointmentReminderScheduler: HomePreviewReminders(), handoffAcknowledgementDefaults: session.defaults)
        let oldRead = Task { await store.load() }
        while !readStarted { await Task.yield() }
        store.synchronizePets([pet])
        store.startCreate()
        #expect(store.pets == [pet] && store.selectedPetID == pet.id)
        releaseRead = true
        await oldRead.value
        #expect(store.pets == [pet] && store.selectedPetID == pet.id)
        let foreignPet = CustomerRequestsStoreTests.pet(customerID: UUID())
        store.synchronizePets([foreignPet])
        #expect(store.pets == [pet])
        store.synchronizePets([])
        #expect(store.pets.isEmpty && store.selectedPetID == nil)
    }

    @Test func groomingReplayStartsBothReadsWithoutTheTabShell() async throws {
        let session = CustomerSandboxSession(screen: .requests, state: .loading)
        defer { session.invalidate() }
        try await session.prepare()
        #expect(!session.requests.hasLoadedOnce && !session.bookings.hasLoadedOnce)
        let activation = Task { await session.activate() }
        await Task.yield()
        session.boundary.state = .loaded
        await activation.value
        #expect(session.requests.hasLoadedOnce && session.bookings.hasLoadedOnce)
    }

    private func load(_ session: CustomerSandboxSession) async {
        async let pets: Void = session.pets.store.load()
        async let requests: Void = session.requests.load()
        async let bookings: Void = session.bookings.load()
        async let chat: Void = session.chat.loadConversations()
        async let profile: Void = session.profile.load()
        _ = await (pets, requests, bookings, chat, profile)
    }
}

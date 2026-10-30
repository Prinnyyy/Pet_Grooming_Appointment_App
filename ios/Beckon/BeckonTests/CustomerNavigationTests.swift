import Foundation
import Testing
@testable import Beckon

@MainActor
struct CustomerNavigationTests {
    @Test func manualTabsPreserveHistoryButActionHandoffsClearBothStacks() {
        let navigation = CustomerNavigation()
        navigation.open(.notifications)
        navigation.selection = .account
        navigation.open(.savedGroomers)
        navigation.selection = .home
        #expect(navigation.home == [.notifications])
        #expect(navigation.account == [.savedGroomers])
        let id = UUID()
        navigation.grooming = [.history]
        navigation.open(.grooming(.booking(id)))
        #expect(navigation.selection == .requests && navigation.home.isEmpty)
        #expect(navigation.grooming == [.grooming(.booking(id))])
        navigation.open(.bookingConversation(id))
        #expect(navigation.selection == .messages && navigation.grooming.isEmpty)
        navigation.open(.bookingConversation(id))
        #expect(navigation.messages.count == 1)
    }

    @Test func homeGlanceAndPublicationSelectTheCardWithoutPushingDetail() {
        let navigation = CustomerNavigation()
        navigation.home = [.notifications]
        navigation.grooming = [.history, .grooming(.request(UUID()))]
        let id = UUID()
        navigation.showGrooming(id)
        #expect(navigation.home.isEmpty && navigation.grooming.isEmpty)
        #expect(navigation.selection == .requests && navigation.focusedGroomingID == id)
    }

    @Test func addPetRoundTripKeepsDraftAndSelectsOnlyTheNewPet() async throws {
        let session = CustomerSandboxSession(state: .loaded)
        defer { session.invalidate() }
        try await session.prepare()
        let store = session.requests
        store.startCreate()
        store.wizardInitialStep = .time // A template may have opened later before returning to pet selection.
        store.serviceNotes = "Keep this draft across pet editing"
        let originalID = store.selectedPetID
        store.wizardResumeState = .init(date: store.preferredStart, timeWindow: .detailed, flexible: true, returnsToReview: true)
        store.suspendWizardForPet()
        store.setWizardPresentation(false) // SwiftUI sheet dismissal must not cancel/reset the draft.
        #expect(!store.isShowingWizard && store.isWizardSuspendedForPet)
        #expect(store.serviceNotes == "Keep this draft across pet editing")
        store.resumeWizardAfterPet(store.pets) // Cancel pet form.
        #expect(store.isShowingWizard && store.selectedPetID == originalID)
        #expect(store.wizardInitialStep == .pet)
        store.suspendWizardForPet()
        let added = CustomerRequestsStoreTests.pet(customerID: session.customerID)
        store.resumeWizardAfterPet(store.pets + [added])
        #expect(store.isShowingWizard && store.selectedPetID == added.id)
        let wizard = CustomerRequestWizardState(store: store)
        #expect(wizard.selectedTimeWindow == .detailed && wizard.isFlexibleWithTime)
        #expect(store.wizardResumeState?.returnsToReview == true)
        store.cancelWizard()
        #expect(store.wizardResumeState == nil && !store.isWizardSuspendedForPet)
    }

    @Test func completedPublicationSurvivesSheetDismissalCallback() async throws {
        let session = CustomerSandboxSession(state: .loaded)
        defer { session.invalidate() }
        try await session.prepare()
        session.requests.startCreate()
        let id = session.requests.requests[0].id
        session.requests.finishWizard(requestID: id)
        session.requests.setWizardPresentation(false)
        #expect(session.requests.completedWizardRequestID == id)
        #expect(!session.requests.isShowingWizard)
    }

    @Test func expiredSessionCannotResumeSuspendedWizard() async throws {
        let session = CustomerSandboxSession(state: .loaded)
        try await session.prepare()
        session.requests.startCreate()
        session.requests.suspendWizardForPet()
        session.invalidate()
        session.requests.resumeWizardAfterPet([])
        #expect(!session.requests.isShowingWizard)
    }

    @Test func launchWaitsForAnimationAndNeverReappearsAfterSignIn() {
        var state = LaunchPresentationState()
        state.minimumElapsed = true
        state.update(isReady: true)
        #expect(!state.hasDismissed)
        state.introFinished = true
        state.update(isReady: true)
        #expect(state.hasDismissed)
        state.update(isReady: false) // Profile resolution or recovery after sign-in.
        #expect(state.hasDismissed)
    }

    @Test func eventLogQueuesWritesInOrderAndKeepsRetentionBounds() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("events.jsonl")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let file = SerialEventLogFile(url: url, maximumLines: 2, retention: 3600)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        struct Line: Codable { let timestamp: Date; let order: Int }
        let old = String(decoding: try encoder.encode(Line(timestamp: Date().addingTimeInterval(-7200), order: -1)), as: UTF8.self)
        file.replace(with: [old])
        for value in 0..<3 {
            file.append(String(decoding: try encoder.encode(Line(timestamp: Date(), order: value)), as: UTF8.self))
        }
        let lines = try file.readLines()
        #expect(lines.count == 2 && lines[0].contains("\"order\":1") && lines[1].contains("\"order\":2"))
        file.replace(with: [])
        #expect(try file.readLines().isEmpty)
    }
}

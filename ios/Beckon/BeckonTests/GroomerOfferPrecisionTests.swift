import Foundation
import Testing
@testable import Beckon

@MainActor struct GroomerOfferPrecisionTests {
    @Test func timerWheelsPreserveTotalMinutesAndServiceBounds() {
        let session = GroomerSandboxSession(state: .loaded)
        let form = GroomerOfferFormState(store: session.requests)
        form.durationMinutesText = "95"
        #expect(form.durationHours == 1 && form.durationMinutePart == 35)
        form.durationHours = 2
        #expect(form.durationMinutesText == "155")
        form.durationMinutePart = 47
        #expect(form.durationMinutesText == "167")
        form.durationHours = 0
        #expect(form.durationMinutesText == "47")
        #expect(form.availableDurationMinutes == 15...59)
        form.durationMinutePart = 0
        #expect(form.durationMinutesText == "15")
        form.durationHours = 12
        #expect(form.durationMinutesText == "720")
        #expect(form.availableDurationMinutes == 0...0)
    }

    @Test func untouchedStartPreservesWindowSecondsButAnEditedMinuteUsesThePicker() async throws {
        let session = GroomerSandboxSession(state: .loaded)
        await session.requests.load()
        let matched = try #require(session.requests.matchedRequests.first)
        let form = GroomerOfferFormState(store: session.requests)
        let instant = try #require(GroomingRequestDateFormatting.parsedDate(from: "2030-11-02T18:15:37Z"))
        form.proposedStart = instant
        await form.loadServiceTimeZone(for: matched)
        #expect(form.resolvedProposedStart == instant)
        form.proposedStart = form.proposedStart.addingTimeInterval(60)
        #expect(form.resolvedProposedStart == instant.addingTimeInterval(23))
    }

    @Test func repeatedTimeStillRequiresAChoiceAndCannotMovePrecisionToAnotherOccurrence() async throws {
        let session = GroomerSandboxSession(state: .loaded)
        await session.requests.load()
        let matched = try #require(session.requests.matchedRequests.first)
        let form = GroomerOfferFormState(store: session.requests)
        let instant = try #require(GroomingRequestDateFormatting.parsedDate(from: "2026-11-01T09:30:37Z"))
        form.proposedStart = instant
        await form.loadServiceTimeZone(for: matched)
        guard case let .ambiguous(first,last) = form.proposedStartResolution else {
            Issue.record("Repeated local time was not preserved as ambiguous"); return
        }
        #expect(form.resolvedProposedStart == nil)
        form.selectedOccurrence = last
        #expect(form.resolvedProposedStart == instant)
        form.selectedOccurrence = first
        #expect(form.resolvedProposedStart == first)
    }

    @Test func defaultOfferAtAnExactWindowBoundarySubmitsWithoutMovingOutsideConsent() async throws {
        let session = GroomerSandboxSession(state: .loaded)
        await session.requests.load()
        let matched = try #require(session.requests.matchedRequests.first { $0.request.petSnapshot.name == "Mochi" })
        let form = GroomerOfferFormState(store: session.requests)
        await form.initializeOfferFormIfNeeded(for: matched)
        #expect(form.resolvedProposedStart == GroomingRequestDateFormatting.parsedDate(from: matched.request.preferredStart))
        let count = try await session.requestRepository.offers(groomerID: session.groomerID).count
        await form.submitOffer(for: matched)
        #expect(session.requests.actionErrorMessage == nil)
        #expect(try await session.requestRepository.offers(groomerID: session.groomerID).count == count + 1)
    }
}

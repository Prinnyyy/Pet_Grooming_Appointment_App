import SwiftUI

/// Each page owns one independent offer; offers share a request, not a version chain.
struct GroomerGroomingOfferPage: View {
    let selected: GroomerOfferListItem
    let workspace: GroomerGroomingWorkspace
    let isCurrent: Bool
    let justSent: Bool
    let viewWaiting: () -> Void
    let openBooking: (UUID) -> Void
    let onWithdrawn: () -> Void
    let makeOffer: (GroomerMatchedRequest) -> Void

    @State private var confirming = false
    @State private var working = false
    @State private var verifiedItem: GroomerOfferListItem?
    @State private var verifiedMatch: GroomerMatchedRequest?
    @State private var actionError: String?
    @State private var selectedPet: GroomingRequestPetSnapshot?
    private var session: GroomerGroomingSession { workspace.session }
    private var item: GroomerOfferListItem { verifiedItem ?? workspace.offers.first { $0.id == selected.id } ?? selected }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { clock in
            let stage = GroomerRequestStage(GroomerRequestSubject(item: item), now: clock.date)
            let booking = workspace.booking(for: item)
            let withdrawn = item.offer.status == .withdrawnByGroomer
            let showsWaiting = justSent && stage.kind == .offered
            let allowsWithdrawal = verifiedMatch.map { canWithdraw($0, now: clock.date) } ?? false
            DesignPage {
                GroomerVisitRequestOverview(subject: .init(item: item), photo: workspace.photo(for: item.offer.requestID), stage: stage, now: clock.date,
                    decision: workspace.offerDecision(.init(item: item, stage: stage)), selectedPet: $selectedPet, hasLinkedBooking: booking != nil)
                if let request = item.request {
                    GroomerVisitRequestFacts(request: request, booking: booking, groomerID: session.groomerID)
                }
                if withdrawn, let verifiedMatch, canReoffer(verifiedMatch, now: clock.date) {
                    BeckonLedgeNote(systemImage: "checkmark.circle", text: "Offer withdrawn. This request is back in Matches.")
                    GroomerVisitNavigationButton { makeOffer(verifiedMatch) } label: {
                        Label("Make a new offer", systemImage: "tag")
                    }
                    .buttonStyle(GroomerVisitRequestFooterActionStyle())
                    .accessibilityIdentifier("groomerVisit.offer.again")
                }
                GroomerVisitRequestOfferRecord(offer: item.offer)
                if let actionError { BeckonLedgeNote(systemImage: "exclamationmark.circle", text: actionError) }
            }
            .modifier(GroomerVisitRequestFooter(showsPrimary: showsWaiting || stage.kind == .booked,
                onWithdrawOffer: allowsWithdrawal ? { confirming = true } : nil, busy: working) {
                if stage.kind == .booked {
                    GroomerVisitViewBookingAction(booking: booking, open: { openBooking($0.id) }, refresh: refresh)
                } else {
                    GroomerVisitNavigationButton(action: viewWaiting) { GroomerVisitDetailNavigationLabel(title: "View waiting offers") }
                        .buttonStyle(GroomerVisitRequestFooterActionStyle())
                        .accessibilityIdentifier("groomerVisit.offer.sent")
                }
            })
            .onChange(of: isCurrent ? workspace.offerDetailUpdates(item, stage: stage) : [], initial: true) {
                _, updates in workspace.didDisplay(updates)
            }
        }
        .beckonHidesTabBar()
        .groomerVisitDetailPresentation()
        .navigationTitle(item.offer.status == .acceptedByCustomer ? "Request" : "Offer")
        .navigationBarTitleDisplayMode(.inline)
        .beckonNavigationDestination(item: $selectedPet) { pet in
            GroomerVisitRequestPetProfile(pet: pet, photos: workspace.petProfilePhotos(for: item.offer.requestID))
        }
        .task(id: selected.id) { await verifyMatch() }
        .refreshable { await refresh() }
        .groomerVisitDesignModal(isPresented: $confirming) {
            .groomerVisitWithdrawOffer(price: item.offer.priceSummary, petName: item.groomerVisitPet?.name) {
                Task { await withdraw() }
            }
        }
    }

    private func refresh() async {
        await workspace.refresh(.offers)
        if item.offer.status == .acceptedByCustomer, workspace.booking(for: item) == nil {
            await workspace.refresh(.bookings)
        }
        await verifyMatch()
    }

    private func verifyMatch() async {
        if let refreshed = try? await workspace.offerItem(id: selected.id, forceRefresh: true) { verifiedItem = refreshed }
        verifiedMatch = try? await session.requestRepository.matchedRequest(groomerID: session.groomerID, requestID: selected.offer.requestID)
    }

    private func canReoffer(_ match: GroomerMatchedRequest, now: Date) -> Bool {
        match.offer?.id == selected.id && GroomerRequestStage(.init(matched: match), now: now).canAnswer
    }

    private func canWithdraw(_ match: GroomerMatchedRequest, now: Date) -> Bool {
        match.offer?.id == selected.id && item.offer.status == .pending &&
            GroomerRequestStage(.init(matched: match, item: item), now: now).canWithdraw
    }

    private func withdraw() async {
        guard !working else { return }
        working = true
        defer { working = false }
        actionError = nil
        await verifyMatch()
        if let match = verifiedMatch, canWithdraw(match, now: Date()) {
            await session.requests.withdrawOffer(for: match)
            actionError = session.requests.actionErrorMessage
        }
        await workspace.refresh(.offers)
        await workspace.refresh(.matches)
        await verifyMatch()
        if item.offer.status == .acceptedByCustomer {
            await workspace.refresh(.bookings)
            actionError = "The customer accepted this offer before it could be withdrawn."
        } else if item.offer.status == .withdrawnByGroomer {
            onWithdrawn()
        } else if actionError == nil {
            actionError = "This offer has changed. Review its current status."
        }
    }
}

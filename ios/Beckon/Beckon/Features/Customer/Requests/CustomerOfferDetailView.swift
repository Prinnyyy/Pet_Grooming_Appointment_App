// Offer detail page of the customer prototype (opened from the offers list, the request detail's offer cards and a notification) and
// the card header it uses. The page carries everything the booking needs (what, when, where, the price, the cancellation terms) and
// ends in one pinned "Confirm booking" button: there is no confirmation page after it (S-055). Moved out of
// the Grooming detail page (it was the request detail page) in S-037.
// Same data and actions as Features/Customer/Requests/CustomerRequestDetailView.swift. Stores and fixtures stay shared.
import Foundation
import SwiftUI


struct CustomerOfferAcceptancePresentation: Equatable {
    static let cancellationCopy =
        "You can cancel from Manage on the grooming page before service starts. Cancelling will not reopen this request or its other offers."

    let service: String
    let price: String
    let time: String
    let location: String
    let address: String
    let cancellation: String

    init(
        request: CustomerGroomingRequest,
        offerReview: CustomerOfferReview
    ) {
        service = (offerReview.offer.agreementSnapshot?.serviceType ?? request.serviceType).title
        price = offerReview.offer.priceSummary
        time = offerReview.proposedTimeSummary
        location = BeckonGroomingLocationModePresentation(
            mode: offerReview.offer.agreementSnapshot?.locationMode ?? request.locationMode,
            perspective: .customer
        ).title
        address = Self.addressSummary(
            request: request,
            offerReview: offerReview
        )
        cancellation = Self.cancellationCopy
    }

    private static func addressSummary(
        request: CustomerGroomingRequest,
        offerReview: CustomerOfferReview
    ) -> String {
        if let agreement = offerReview.offer.agreementSnapshot, agreement.isSupported {
            return agreement.address.summary
        }
        if offerReview.offer.agreementSnapshotLoaded {
            return "Original address unverified. A new offer is required."
        }
        switch request.locationMode {
        case .groomerComesToCustomer:
            return formattedAddress(
                line1: request.streetAddress,
                line2: request.addressLine2,
                city: request.city,
                state: request.state,
                zipCode: request.zipCode
            )
        case .customerComesToGroomer:
            guard let profile = offerReview.groomerProfile else {
                return "The groomer's address will appear in your booking."
            }
            return formattedAddress(
                line1: profile.baseStreetAddress,
                line2: profile.baseAddressLine2,
                city: profile.baseCity,
                state: profile.baseState,
                zipCode: profile.baseZipCode
            )
        }
    }

    private static func formattedAddress(
        line1: String?,
        line2: String?,
        city: String?,
        state: String?,
        zipCode: String?
    ) -> String {
        let street = [line1, line2]
            .compactMap(normalized)
            .joined(separator: ", ")
        let locality = [normalized(city), normalized(state)]
            .compactMap { $0 }
            .joined(separator: ", ")
        let localityAndZip = [normalized(locality), normalized(zipCode)]
            .compactMap { $0 }
            .joined(separator: " ")
        let parts = [normalized(street), normalized(localityAndZip)]
            .compactMap { $0 }
        return parts.isEmpty
            ? "Address will appear in your booking."
            : parts.joined(separator: ", ")
    }

    private static func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}


struct CustomerOfferDetailView: View {
    let request: CustomerGroomingRequest
    let offerID: UUID
    let store: CustomerRequestsStore
    @Environment(\.bookingConfirmed) private var bookingConfirmed
    @State private var acceptedBookingHandoff: CustomerRequestBookingHandoff?
    @State private var isSubmitting = false
    @State private var hasAttemptedAcceptance = false

    private var offerReview: CustomerOfferReview? {
        store.offers(for: request).first { $0.id == offerID }
    }

    var body: some View {
        Group {
            if let offerReview {
                ZStack {
                    BeckonExpressiveBackdrop()

                    ScrollView {
                        BeckonCascade(spacing: DesignTokens.Spacing.lg) {
                            BeckonLedgeHeading(title: "Offer", systemImage: "tag.fill")

                            groomerCard(offerReview)
                            TimelineView(.periodic(from: .now, by: 1)) { _ in
                                appointmentCard(offerReview)
                            }
                            requestCard(offerReview)
                            BeckonLedgeNote(systemImage: "arrow.uturn.backward.circle",
                                text: acceptance(offerReview).cancellation)
                            TimelineView(.periodic(from: .now, by: 1)) { _ in
                                statusBlock(offerReview)
                            }
                        }
                        .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                        .padding(.top, DesignTokens.Spacing.lg)
                        .padding(.bottom, DesignTokens.Spacing.xl)
                    }
                    .scrollContentBackground(.hidden)
                }
                .accessibilityIdentifier("customer.offers.detail")
                .beckonEntranceRhythm(.detail)
                // The one button of the page, pinned: it says what it books, and one tap books it.
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if canAccept(offerReview) {
                        TimelineView(.periodic(from: .now, by: 1)) { _ in
                            confirmBar(offerReview)
                        }
                    }
                }
                .navigationTitle("Offer")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                ZStack {
                    BeckonExpressiveBackdrop()

                    BeckonLedgeNote(systemImage: "tag.slash", text: "Offer unavailable. Refresh offers and try again.")
                        .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                }
                .navigationTitle("Offer")
            }
        }
        .navigationDestination(item: $acceptedBookingHandoff) { handoff in
            GroomingDetailView(
                target: .booking(handoff.booking.id),
                requestStore: store,
                bookingsStore: store.bookingDetailStore(for: handoff.booking),
                celebratesNewBooking: true
            )
        }
    }

    private func acceptance(_ offerReview: CustomerOfferReview) -> CustomerOfferAcceptancePresentation {
        CustomerOfferAcceptancePresentation(request: request, offerReview: offerReview)
    }

    private func canAccept(_ offerReview: CustomerOfferReview) -> Bool {
        store.hasUnresolvedAcceptance(for: offerReview.id)
            || (offerReview.offer.status == .pending && (store.request(withID: request.id) ?? request).status.isOpenForOffers)
    }

    private func groomerCard(_ offerReview: CustomerOfferReview) -> some View {
        BeckonCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                CustomerOfferCardHeader(
                    title: offerReview.groomerTitle,
                    subtitle: offerReview.groomerLocationSummary,
                    systemImage: "person.crop.circle.fill",
                    profileAvatarData: offerReview.groomerAvatarPhotoData,
                    profileAvatarTone: .groomer
                ) {
                    if offerReview.groomerProfile?.isVerified == true {
                        BeckonStatusChip(.verified)
                        .accessibilityLabel("Verified groomer")
                    }
                }

                DesignValueRow(
                    title: "Rating",
                    value: offerReview.ratingSummary,
                    systemImage: "star.fill"
                )

                if let fitEvidence = offerReview.fitEvidencePresentation {
                    BeckonFitEvidenceBlock(
                        scoreText: fitEvidence.scoreText,
                        summary: fitEvidence.listSummary,
                        reason: fitEvidence.reason,
                        isCompact: false
                    )
                }

                if let bio = offerReview.groomerProfile?.bio {
                    Text(bio)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// The appointment being offered, with everything the old confirmation page listed: the price and the time up top, then the
    /// service, where it happens and the address (the Start and End rows said the time twice).
    private func appointmentCard(_ offerReview: CustomerOfferReview) -> some View {
        let acceptance = acceptance(offerReview)
        return BeckonCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                CustomerOfferCardHeader(
                    title: offerReview.offer.priceSummary,
                    subtitle: offerReview.proposedTimeSummary,
                    systemImage: "tag.fill"
                ) {
                    BeckonStatusChip(offerReview.offer.statusPresentation())
                }

                DesignValueRow(title: "Service", value: acceptance.service, systemImage: "scissors")
                DesignValueRow(title: "Service location", value: acceptance.location, systemImage: "location")
                DesignValueRow(title: "Address", value: acceptance.address, systemImage: "mappin.and.ellipse")

                if let message = offerReview.offer.message {
                    Text(message)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func requestCard(_ offerReview: CustomerOfferReview) -> some View {
        BeckonCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                CustomerOfferCardHeader(
                    title: request.petSnapshot.name,
                    subtitle: request.serviceType.title,
                    systemImage: "pawprint.fill"
                ) {
                    BeckonStatusChip(request.status.presentation)
                }

                DesignValueRow(
                    title: "Requested time",
                    value: requestTimeSummary,
                    systemImage: "calendar"
                )
            }
        }
    }

    /// Only what the button cannot say: why an offer cannot be booked (closed, expired, needs an update), and a failed booking.
    @ViewBuilder
    private func statusBlock(_ offerReview: CustomerOfferReview) -> some View {
        let actionable = canAccept(offerReview)
        let blocked = actionable && !offerReview.offer.canConfirmCurrentTerms && !store.hasUnresolvedAcceptance(for: offerReview.id)
        if !actionable {
            BeckonCard {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    CustomerOfferCardHeader(
                        title: "Acceptance",
                        subtitle: acceptanceMessage(for: offerReview),
                        systemImage: "checkmark.circle.fill"
                    )
                    BeckonStatusChip(.acceptance(offer: offerReview.offer.status, request: request.status))
                }
            }
        } else if blocked {
            BeckonLedgeNote(systemImage: "exclamationmark.circle", text: acceptanceMessage(for: offerReview))
        }
        if hasAttemptedAcceptance, let errorMessage = store.errorMessage {
            BeckonErrorBanner(title: "We could not confirm this booking", message: errorMessage)
        }
    }

    private func confirmBar(_ offerReview: CustomerOfferReview) -> some View {
        let acceptance = acceptance(offerReview)
        let unresolved = store.hasUnresolvedAcceptance(for: offerReview.id)
        return CustomerOfferConfirmBar(
            summary: "\(acceptance.price) · \(acceptance.time)",
            title: unresolved ? "Check booking status"
                : offerReview.offer.hasPassedConfirmationDeadline() ? "Offer expired" : "Confirm booking",
            isSubmitting: isSubmitting || store.isAcceptingOffer(offerReview.offer.id),
            isEnabled: offerReview.offer.canConfirmCurrentTerms || unresolved,
            action: { confirm(offerReview) }
        )
    }

    private func confirm(_ offerReview: CustomerOfferReview) {
        guard !isSubmitting else { return }
        isSubmitting = true
        hasAttemptedAcceptance = true

        Task {
            let handoff = await store.accept(offerReview: offerReview, for: request)
            isSubmitting = false
            guard let handoff else { return }
            if let bookingConfirmed { bookingConfirmed(handoff) }
            else { acceptedBookingHandoff = handoff }
            await store.acknowledgeBookingHandoff(for: handoff)
        }
    }

    private func acceptanceMessage(for offerReview: CustomerOfferReview) -> String {
        if offerReview.offer.status == .pending,
           request.status.isOpenForOffers {
            if offerReview.offer.hasPassedConfirmationDeadline() {
                return "This offer has expired. Request a new offer."
            }
            if offerReview.offer.requiresAgreementUpdate {
                return "Updated agreement required. Request a new offer."
            }
            if let evaluation = offerReview.offer.quoteEvaluation, !evaluation.selectable || !evaluation.termsValid {
                return evaluation.summary
            }
            if offerReview.offer.requiresTimingUpdate {
                return "The groomer needs to replace this offer with updated timing details. Your request remains open."
            }
            return "Review the proposed appointment before you confirm."
        } else if offerReview.offer.status == .acceptedByCustomer {
            return "This offer is now a confirmed booking."
        } else if request.status == .booked {
            return "This request is already booked."
        } else {
            return "This offer can no longer be accepted."
        }
    }

    private var requestTimeSummary: String {
        request.preferredTimePresentation.summary
    }
}


/// The pinned bottom of the offer page: one line that says what the button books (price and time), and the button. One tap
/// books; the page above has already shown the groomer, the place and the cancellation terms.
private struct CustomerOfferConfirmBar: View {
    let summary: String
    let title: String
    let isSubmitting: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        BeckonPinnedBar(summary: summary) {
            Button(action: action) {
                DesignActionLabel(title: isSubmitting ? "Confirming…" : title, systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(BeckonLedgeButtonStyle(.pill))
            .disabled(isSubmitting || !isEnabled)
            .accessibilityHint("Books this appointment: \(summary).")
            .accessibilityIdentifier("customer.offers.confirm")
        }
    }
}


private struct CustomerOfferCardHeader<Trailing: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let title: String
    let subtitle: String
    let systemImage: String
    let profileAvatarData: Data?
    let profileAvatarTone: BeckonDefaultProfileAvatarTone?
    private let trailing: Trailing

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        profileAvatarData: Data? = nil,
        profileAvatarTone: BeckonDefaultProfileAvatarTone? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.profileAvatarData = profileAvatarData
        self.profileAvatarTone = profileAvatarTone
        self.trailing = trailing()
    }

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.md))
            : AnyLayout(HStackLayout(alignment: .top, spacing: DesignTokens.Spacing.md))
        layout {
            if let profileAvatarTone {
                BeckonProfileAvatar(
                    data: profileAvatarData,
                    tone: profileAvatarTone,
                    size: DesignTokens.Spacing.xl + DesignTokens.Spacing.md,
                    cornerRadius: (DesignTokens.Spacing.xl + DesignTokens.Spacing.md) / 2,
                    placeholderSize: 18
                )
            } else {
                Image(systemName: systemImage)
                    .font(DesignTokens.Typography.Expressive.glyph)
                    .foregroundStyle(DesignTokens.Colors.customerDeep)
                    .frame(
                        width: DesignTokens.Spacing.xl + DesignTokens.Spacing.md,
                        height: DesignTokens.Spacing.xl + DesignTokens.Spacing.md
                    )
                    .background(DesignTokens.Colors.customerTint)
                    .clipShape(DesignTokens.Shapes.circular)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.Expressive.headline)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .designSupportingText()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing
        }
        .accessibilityElement(children: .combine)
    }
}


extension CustomerOfferCardHeader where Trailing == EmptyView {
    init(
        title: String,
        subtitle: String,
        systemImage: String
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        profileAvatarData = nil
        profileAvatarTone = nil
        trailing = EmptyView()
    }
}

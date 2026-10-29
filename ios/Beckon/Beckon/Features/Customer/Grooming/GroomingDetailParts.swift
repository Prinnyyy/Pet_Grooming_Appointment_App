// The parts of the Grooming detail page (S-062). One page for a grooming from the day it is posted to the day it is reviewed, so
// its parts are made for that: a hero that is the card opened up (same identity, same four-stop path and bubble), a card that
// says what needs the owner, one details card that is "your request" before there is a booking and "your appointment" after,
// the review, a timeline of what happened, and quiet manage rows.
import SwiftUI


// MARK: Hero

/// The card of the Grooming tab, opened up: who and when, then the path with its bubble. Closed (cancelled, expired, not
/// confirmed) it has no path, one line instead.
struct GroomingDetailHero: View {
    struct Closed {
        let status: BeckonStatusPresentation
        let message: String
    }

    let species: String
    let avatarData: Data?
    let title: String
    let time: String
    var when: BeckonWhen?
    /// The path and bubble, from the same builder the card uses; nil when the grooming is closed.
    let card: GroomingCardContent?
    var closed: Closed?
    /// "Closes in 23 hours" on an open request.
    var closes: String?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            identity
            if let card {
                BeckonJourney(stops: BeckonJourneyStop.groomingPath, current: card.current, fills: card.fills,
                    bubble: card.bubble, celebratingColumn: card.celebratesColumn)
            } else if let closed {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    BeckonStatusChip(closed.status)
                    Text(closed.message)
                        .designSupportingText()
                }
            }
            if let closes {
                BeckonMetaChip(text: closes, systemImage: "clock")
            }
        }
        .designCardBody()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(([title, time] + [card?.status, closed?.message].compactMap { $0 }).joined(separator: ". "))
        .accessibilityIdentifier("customer.grooming.detail.hero")
    }

    private var identity: some View {
        (typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.md))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DesignTokens.Spacing.md))) {
            BeckonPetAvatar(data: avatarData, systemImage: BeckonPetPresentation.symbol(for: species),
                width: 56, height: 56, cornerRadius: 28)
                .overlay(Circle().strokeBorder(DesignTokens.Colors.customerFill, lineWidth: DesignTokens.Ledge.edgeWidth + 1))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.Expressive.headline)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                if let when {
                    BeckonWhenLabel(when: when)
                } else {
                    Text(time)
                        .font(DesignTokens.Typography.Expressive.supporting)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}


// MARK: Needs you

/// Something the owner has to read or answer (a new time to reply to, a reported service to confirm, an operation to check, a request
/// that cannot go on): a card with a warm strip on top that says what it is, so it is the first thing under the hero.
struct GroomingNeedsCard<Content: View>: View {
    /// Warm when the owner has to do something, mint when it is only something to read.
    enum Tone { case attention, info }

    let title: String
    let systemImage: String
    var tone: Tone = .attention
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label {
                Text(title).font(DesignTokens.Typography.Expressive.emphasis)
            } icon: {
                Image(systemName: systemImage).font(DesignTokens.Typography.Expressive.emphasis)
            }
            .foregroundStyle(tone == .attention ? DesignTokens.Colors.statusWarningText : DesignTokens.Colors.customerInk)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .background(tone == .attention ? DesignTokens.Colors.statusWarningFill : DesignTokens.Colors.customerFill)
            .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) { content }
                .padding(DesignTokens.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous))
        .beckonLedge(.card)
    }
}


/// The filled button or the secondary button of a needs-you card or a page block.
struct GroomingActionButton: View {
    enum Style { case primary, secondary }

    let title: String
    let systemImage: String
    var style: Style = .primary
    let identifier: String
    let action: () -> Void

    var body: some View {
        let isPrimary = style == .primary
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: systemImage)
                Text(title).multilineTextAlignment(.center)
            }
            .font(isPrimary ? DesignTokens.Typography.Expressive.headline : DesignTokens.Typography.Expressive.emphasis)
            .foregroundStyle(isPrimary ? DesignTokens.Colors.customerInk : DesignTokens.Colors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: isPrimary ? DesignTokens.Metrics.ledgePrimaryButtonHeight
                : DesignTokens.Metrics.minimumTouchTarget)
        }
        .buttonStyle(BeckonLedgeButtonStyle(isPrimary ? .pill : .card))
        .accessibilityIdentifier(identifier)
    }
}


// MARK: Details

/// What the grooming is, in one card. Before there is a booking it is the request (where, the pet, the notes, the photos); once
/// there is one it is the appointment too (the service and the time on a date tile, the price, the confirmed address, the groomer
/// with the way to message them). Rows appear when there is something to say.
struct GroomingDetailsCard: View {
    let request: CustomerGroomingRequest?
    let booking: Booking?
    let requestStore: CustomerRequestsStore?
    let onOpenChat: ((Booking) -> Void)?
    @Environment(\.dynamicTypeSize) private var typeSize

    private var petSnapshot: GroomingRequestPetSnapshot? {
        request?.petSnapshot ?? booking?.agreementSnapshot?.petSnapshot ?? booking?.requestPetSnapshot
    }

    private var notes: String? {
        let text = request?.serviceNotes ?? booking?.agreementSnapshot?.serviceNotes
        return text.flatMap { $0.isEmpty ? nil : $0 }
    }

    private var photos: [GroomingRequestPhoto] {
        guard let request, let requestStore else { return [] }
        return requestStore.requestPhotos(for: request)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            BeckonLedgeHeading(title: booking == nil ? "Your request" : "Appointment",
                systemImage: booking == nil ? "doc.text.fill" : "calendar")
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                if let booking { appointmentHeader(booking) }
                if let locationRow { locationRow }
                if let pet = petDetail {
                    DesignFactRow(systemImage: "pawprint.fill", title: "Pet", value: pet)
                }
                if let notes { DesignFactRow(systemImage: "text.quote", title: "Notes", value: notes) }
                photosStrip
                if let booking {
                    DesignRowDivider()
                    groomerFoot(booking)
                }
            }
            .designCardBody()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("customer.grooming.detail.details")
    }

    // MARK: Rows

    /// The date, the service, the time and the price: the first thing about an appointment.
    private func appointmentHeader(_ booking: Booking) -> some View {
        (typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.md))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DesignTokens.Spacing.lg))) {
            if let parts = BeckonBookingCountdown.dateParts(for: booking) {
                BeckonDateTile(month: parts.month, day: parts.day)
            }
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(booking.appointmentServiceTitle)
                    .font(DesignTokens.Typography.Expressive.headline)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(booking.scheduledTimeSummary)
                    .font(DesignTokens.Typography.Expressive.supporting)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .accessibilityLabel(booking.scheduledTimePresentation.accessibilityLabel)
                    .fixedSize(horizontal: false, vertical: true)
                (typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.xs))
                    : AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.sm))) {
                    Text(booking.priceSummary)
                        .font(DesignTokens.Typography.Expressive.emphasis)
                        .foregroundStyle(DesignTokens.Colors.customerDeep)
                        .fixedSize()
                    Text("#\(booking.referenceCode)")
                        .font(DesignTokens.Typography.Expressive.chip)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var locationRow: DesignFactRow? {
        if let booking {
            let title = booking.locationMode.map { BeckonGroomingLocationModePresentation(mode: $0, perspective: .customer).title }
                ?? "Location not confirmed"
            return DesignFactRow(systemImage: "location.fill", title: title, value: booking.appointmentAddressSummary)
        }
        guard let request else { return nil }
        return DesignFactRow(systemImage: "location.fill",
            title: BeckonGroomingLocationModePresentation(mode: request.locationMode, perspective: .customer).title,
            value: "\(request.streetAddress), \(request.city), \(request.state) \(request.zipCode)")
    }

    /// Breed (or species) and size; the name is already the title.
    private var petDetail: String? {
        guard let pet = petSnapshot else { return nil }
        let parts = [pet.breed ?? pet.species, pet.size.map { "Size \($0)" }].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var photosStrip: some View {
        if !photos.isEmpty, let requestStore {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    ForEach(photos) { photo in
                        BeckonModuleImage(data: requestStore.requestPhotoData(for: photo)) {
                            Image(systemName: "photo").foregroundStyle(DesignTokens.Colors.textTertiary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(DesignTokens.Colors.placeholderFill)
                        }
                        .frame(width: 84, height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.pill, style: .continuous))
                        .accessibilityLabel("Request photo")
                    }
                }
            }
            .beckonTracksScroll()
        }
    }

    private func groomerFoot(_ booking: Booking) -> some View {
        (typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.md))
            : AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.md))) {
            BeckonProfileAvatar(data: booking.groomerAvatarPhotoData, tone: .groomer, size: 44,
                cornerRadius: DesignTokens.CornerRadius.pill)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Your groomer")
                    .font(DesignTokens.Typography.Expressive.chip)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                Text(booking.partnerDisplayTitle(for: .customer))
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let onOpenChat {
                Button { onOpenChat(booking) } label: {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Image(systemName: "bubble.left.fill")
                        Text("Message").lineLimit(1)
                    }
                    .fixedSize()
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.customerInk)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
                }
                .buttonStyle(BeckonLedgeButtonStyle(.pill))
                .accessibilityLabel("Message your groomer")
                .accessibilityIdentifier("bookings.detail.open-chat")
            }
        }
    }
}


// MARK: Review

/// The last stop of the path: once the service is over, how it went. The form until it is sent, the stars after.
struct GroomingReviewSection: View {
    let booking: Booking
    let store: BookingsStore
    var focusedTarget: FocusState<GroomingReviewFocusTarget?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            BeckonLedgeHeading(title: "Review", systemImage: "star.fill")
            if let review = booking.review {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= review.rating ? "star.fill" : "star")
                                .foregroundStyle(DesignTokens.Colors.ratingStar)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(review.ratingSummary)
                    Text(review.displayContent)
                        .designSupportingText()
                }
                .designCardBody()
                .accessibilityIdentifier("bookings.review.display")
            } else {
                GroomingReviewForm(booking: booking, store: store, accent: .customer, focusedTarget: focusedTarget)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("customer.grooming.detail.review")
    }
}


// MARK: Timeline

/// One thing that happened, on a line that runs down the left.
struct GroomingTimelineEntry: Identifiable {
    let id: String
    let systemImage: String
    let title: String
    var detail: String?
    var note: String?
}


/// What happened to this grooming, newest last, as a vertical line with a mint dot for each thing. It is a record to look up, not
/// something to act on, so it is closed until opened.
struct GroomingTimeline: View {
    let entries: [GroomingTimelineEntry]
    /// A link under the line (the offers, when there were some).
    var offersDestination: AnyView?
    var offersTitle = "See all offers"
    @State private var isOpen: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(entries: [GroomingTimelineEntry], offersDestination: AnyView? = nil, offersTitle: String = "See all offers",
         startsOpen: Bool = false) {
        self.entries = entries
        self.offersDestination = offersDestination
        self.offersTitle = offersTitle
        _isOpen = State(initialValue: startsOpen)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            Button {
                withAnimation(reduceMotion ? DesignTokens.Motion.reduced : DesignTokens.Motion.swap) { isOpen.toggle() }
            } label: {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    BeckonLedgeHeading(title: "Activity", systemImage: "clock.arrow.circlepath", count: entries.count)
                    Spacer(minLength: DesignTokens.Spacing.sm)
                    Image(systemName: "chevron.down")
                        .font(DesignTokens.Typography.Expressive.chip)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(BeckonGuardedPlainButtonStyle())
            .accessibilityValue(isOpen ? "Expanded" : "Collapsed")
            .accessibilityHint("Shows what has happened to this grooming, and when.")
            .accessibilityIdentifier("customer.grooming.detail.activity.toggle")

            if isOpen {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        row(entry, isLast: index == entries.count - 1)
                    }
                    if let offersDestination {
                        NavigationLink { offersDestination } label: {
                            DesignLinkCardLabel(title: offersTitle, summary: "Every offer, with its history",
                                systemImage: "square.stack.3d.up.fill")
                        }
                        .buttonStyle(BeckonLedgeButtonStyle(.card))
                        .padding(.top, DesignTokens.Spacing.md)
                        .accessibilityIdentifier("customer.requests.see-offers")
                    }
                }
                .designCardBody()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("customer.grooming.detail.activity")
    }

    private func row(_ entry: GroomingTimelineEntry, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            VStack(spacing: 0) {
                Image(systemName: entry.systemImage)
                    .font(DesignTokens.Typography.Expressive.timelineGlyph) // glyph inside a fixed-size dot, fixed by design
                    .foregroundStyle(DesignTokens.Colors.customerInk)
                    .frame(width: 28, height: 28)
                    .background(DesignTokens.Colors.customerFill, in: Circle())
                    .accessibilityHidden(true)
                if !isLast {
                    Rectangle()
                        .fill(DesignTokens.Colors.borderSoft)
                        .frame(width: 3)
                        .frame(maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(entry.title)
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                if let detail = entry.detail {
                    Text(detail)
                        .font(DesignTokens.Typography.Expressive.chip)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }
                if let note = entry.note {
                    Text(note).designSupportingText()
                }
            }
            .padding(.bottom, isLast ? DesignTokens.Spacing.none : DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

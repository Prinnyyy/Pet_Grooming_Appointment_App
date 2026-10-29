// The card of one grooming (S-056; the request card of the old Requests tab again in S-058). A request and the booking it becomes
// are one thing to the owner, so they are one card: the request card, and the same path simply goes on after Booked. Top to
// bottom: who and when; two short facts (how long a request stays open and who can see it; or the groomer and the price); the
// path of four stops (`BeckonJourney`: Posted, Offers, Booked, Finished) with a bubble that bounces over the
// stop that is happening; the next step as the one filled button; Details and one more quiet action under it. Once the service is
// done the card asks for one thing only: a single button, Leave a review. The card leaves the row for History when the review is in. Every card of a row
// is the same width and the same height, and a card never changes shape when its stage does: only the lit nodes, the bubble, the
// facts and the buttons do.
//
// Two sizes: `.full` (the Grooming tab) and `.glance` (Home's Next up: the who and when, a chevron and the path; the whole card
// opens the Grooming tab on it).
import SwiftUI


/// What a card says, as plain data (the page builds it from a request or a booking, a preview builds it from fixtures).
struct GroomingCardContent: Identifiable {
    struct Fact: Equatable {
        let systemImage: String
        let text: String
    }

    let id: UUID
    let species: String
    let avatarData: Data?
    /// "Full groom · Mochi".
    let title: String
    /// The time as one string (VoiceOver and anything that cannot choose between two lengths).
    let time: String
    /// The time as the card writes it: the whole range, or the start only when the range does not fit.
    var when: BeckonWhen?
    /// What the bubble says, for VoiceOver ("3 offers to compare").
    let status: String
    /// At most two short lines under the title.
    let facts: [Fact]
    /// The path: the stop in progress, how full the line after each stop is, and the bubble.
    let current: Int
    let fills: [Double]
    let bubble: BeckonJourney.Bubble?
    let celebratesColumn: Int?
    let primaryTitle: String
    let primarySymbol: String
    /// False when the card asks for one thing only (a finished booking waiting for its review): just the filled button, and `footnote`
    /// in the place of the quiet actions, so the path and the button stay where they are on the other cards of the row.
    var hasQuietActions = true
    var footnote: String?
    var requestID: UUID? = nil
}


/// The quiet action next to Details (Cancel request on a request, Message on a booking).
struct GroomingQuietAction: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    var isDestructive = false
    var isDisabled = false
    let action: () -> Void
}


struct GroomingCard: View {
    enum Style { case full, glance }

    let content: GroomingCardContent
    var style: Style = .full
    var secondary: GroomingQuietAction?
    let onOpen: () -> Void
    var onPrimary: () -> Void = {}
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var scaledFullHeight = DesignTokens.Metrics.groomingCardHeight
    @ScaledMetric(relativeTo: .body) private var scaledGlanceHeight = DesignTokens.Metrics.groomingGlanceCardHeight

    private var height: CGFloat? {
        guard !typeSize.isAccessibilitySize else { return nil }
        return style == .full
            ? max(scaledFullHeight, DesignTokens.Metrics.groomingCardHeight)
            : max(scaledGlanceHeight, DesignTokens.Metrics.groomingGlanceCardHeight)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // The top of the card (who, facts, path) opens the grooming; in the full size the buttons below do the next step.
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    identity
                    if style == .full {
                        facts
                        Spacer(minLength: 0)
                    }
                    journey
                        // Without the facts above it, the bubble would bounce into the time line.
                        .padding(.top, style == .glance ? DesignTokens.Spacing.sm : DesignTokens.Spacing.none)
                    if style == .glance { Spacer(minLength: 0) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .contentShape(Rectangle())
            }
            .buttonStyle(BeckonGuardedPlainButtonStyle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(style == .full ? "Opens the details." : "Opens this grooming in the Grooming tab.")
            .accessibilityIdentifier("customer.grooming.card.\(content.id.uuidString)")
            .accessibilityValue(AppTestOpsAccessibility.requestReference(content.requestID ?? content.id))

            if style == .full {
                Spacer(minLength: DesignTokens.Spacing.xs)
                Button(action: onPrimary) {
                    DesignActionLabel(title: content.primaryTitle, systemImage: content.primarySymbol)
                }
                .buttonStyle(BeckonLedgeButtonStyle(.pill))
                .accessibilityIdentifier("customer.grooming.primary.\(content.id.uuidString)")
            .accessibilityValue(AppTestOpsAccessibility.requestReference(content.requestID ?? content.id))

                if content.hasQuietActions {
                    quietActions
                } else if let footnote = content.footnote {
                    Text(footnote)
                        .font(DesignTokens.Typography.Expressive.supporting)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.minimumTouchTarget)
                }
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: height, alignment: .top)
        .multilineTextAlignment(.leading)
        .beckonLedge(.card)
    }

    private var journey: some View {
        BeckonJourney(stops: BeckonJourneyStop.groomingPath, current: content.current, fills: content.fills,
            bubble: content.bubble, celebratingColumn: content.celebratesColumn)
    }

    private var accessibilityLabel: String {
        ([content.title, content.time, content.status] + content.facts.map(\.text)).joined(separator: ". ")
    }

    /// The pet, "Service · Pet" and when (the booking's time once it is booked), each one line.
    private var identity: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            BeckonPetAvatar(
                data: content.avatarData,
                systemImage: BeckonPetPresentation.symbol(for: content.species),
                width: 48, height: 48, cornerRadius: 24
            )
            .overlay(Circle().strokeBorder(DesignTokens.Colors.customerFill, lineWidth: DesignTokens.Ledge.edgeWidth + 1))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(content.title)
                    .font(DesignTokens.Typography.Expressive.headline)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                if let when = content.when {
                    BeckonWhenLabel(when: when)
                } else {
                    Text(content.time)
                        .font(DesignTokens.Typography.Expressive.supporting)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if style == .glance {
                Image(systemName: "chevron.right")
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.customerDeep)
                    .accessibilityHidden(true)
            }
        }
    }

    private var facts: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            ForEach(Array(content.facts.enumerated()), id: \.offset) { _, fact in
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: fact.systemImage)
                        .font(DesignTokens.Typography.Expressive.label)
                        .foregroundStyle(DesignTokens.Colors.customerDeep)
                        .frame(width: DesignTokens.Spacing.lg)
                        .accessibilityHidden(true)
                    Text(fact.text)
                        .font(DesignTokens.Typography.Expressive.supporting)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                }
            }
        }
        .padding(.top, DesignTokens.Spacing.xs)
    }

    /// Details, and the one more thing this grooming can do, as text under the filled button so the three never compete.
    private var quietActions: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 0))
            : AnyLayout(HStackLayout(spacing: 0))
        return layout {
            Button(action: onOpen) {
                DesignQuietAction(title: "Details", systemImage: "doc.text.magnifyingglass")
            }
            .buttonStyle(BeckonGuardedPlainButtonStyle())
            .accessibilityIdentifier("customer.grooming.details.\(content.id.uuidString)")
            .accessibilityValue(AppTestOpsAccessibility.requestReference(content.requestID ?? content.id))

            if let secondary {
                if !typeSize.isAccessibilitySize {
                    Rectangle()
                        .fill(DesignTokens.Colors.divider)
                        .frame(width: 1, height: DesignTokens.Metrics.ledgeIconTile)
                        .accessibilityHidden(true)
                }
                Button(action: secondary.action) {
                    DesignQuietAction(title: secondary.title, systemImage: secondary.systemImage,
                        isDestructive: secondary.isDestructive)
                }
                .buttonStyle(BeckonGuardedPlainButtonStyle())
                .disabled(secondary.isDisabled)
                .accessibilityIdentifier("customer.grooming.\(secondary.id).\(content.id.uuidString)")
            }
        }
    }
}


// MARK: Past

/// A finished or closed grooming, one compact row: a completed, cancelled or unconfirmed booking, or a cancelled or expired request.
struct GroomingPastContent: Identifiable {
    let id: UUID
    let species: String
    let avatarData: Data?
    let title: String
    let time: String
    let detail: String?
    let status: BeckonStatusPresentation
    var requestID: UUID? = nil
}


struct GroomingPastRow: View {
    let content: GroomingPastContent
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button(action: action) {
            (typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.sm))
                : AnyLayout(HStackLayout(alignment: .center, spacing: DesignTokens.Spacing.md))) {
                HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                    BeckonPetAvatar(
                        data: content.avatarData,
                        systemImage: BeckonPetPresentation.symbol(for: content.species),
                        width: 44, height: 44, cornerRadius: 22
                    )
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(content.title)
                            .font(DesignTokens.Typography.Expressive.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                        Text(content.time)
                            .font(DesignTokens.Typography.Expressive.supporting)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                        if let detail = content.detail {
                            Text(detail)
                                .font(DesignTokens.Typography.Expressive.chip)
                                .foregroundStyle(DesignTokens.Colors.textSecondary)
                                .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                BeckonStatusChip(content.status)
            }
            .padding(DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(BeckonLedgeButtonStyle(.card))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("customer.grooming.past.\(content.id.uuidString)")
            .accessibilityValue(AppTestOpsAccessibility.requestReference(content.requestID ?? content.id))
    }
}


// MARK: From a request or a booking

extension GroomingCardContent {
    /// A card from an entry of the feed. `reach` is the request's short line on who can see it (the full card only).
    static func entry(_ entry: GroomingEntry, reach: String? = nil, now: Date = Date()) -> GroomingCardContent {
        switch entry {
        case .request(let item): .request(item, reach: reach, now: now)
        case .booking(let booking, let handoff, let avatar): .booking(booking, avatar: avatar, isNew: handoff != nil, now: now, request: handoff?.request)
        }
    }

    /// An open request (waiting, or with offers). `reach` is the short line on who can see it.
    static func request(_ card: CustomerRequestActionCardItem, reach: String?, now: Date = Date()) -> GroomingCardContent {
        let request = card.request
        let summary = CustomerRequestSummaryPresentation(card: card)
        let hasOffers = request.status == .hasOffers
        let when = BeckonWhen(start: request.preferredStart, end: request.preferredEnd,
            zoneIdentifier: request.preferenceTimeZoneIdentifier, now: now)
        var facts: [Fact] = []
        if let closes = closingText(request, now: now) { facts.append(Fact(systemImage: "clock", text: closes)) }
        if let reach { facts.append(Fact(systemImage: "person.2.fill", text: reach)) }
        return GroomingCardContent(
            id: request.id,
            species: request.petSnapshot.species,
            avatarData: card.petAvatarPhotoData,
            title: summary.title,
            time: when?.full ?? [summary.time.text, summary.time.timeZoneNotice].compactMap { $0 }.joined(separator: " · "),
            when: when,
            status: hasOffers
                ? (card.loadedOfferCount.map { "\($0) offer\($0 == 1 ? "" : "s") to compare" } ?? "Offers to compare")
                : "Waiting for offers",
            facts: facts,
            current: 1,
            fills: hasOffers ? [1, 0.35, 0, 0] : [0.55, 0, 0, 0],
            bubble: .init(kind: hasOffers ? .offers(card.loadedOfferCount) : .waiting, column: 1),
            celebratesColumn: nil,
            primaryTitle: hasOffers ? "Compare offers" : "Invite groomers",
            primarySymbol: hasOffers ? "tag.fill" : "person.badge.plus"
        )
    }

    /// A booking: the same card, the path lit up to Booked. The owner is at Booked until the appointment day is over: its calendar
    /// pulses and the bubble says when ("In 3 days", "Tomorrow", then "Today!"). The line on to Finished is empty before the day,
    /// half full on the day, most of the way once the appointment's own time is over. The day ending, or the groomer marking the
    /// service done, whichever is first, moves the bubble to Finished: "Rate it!" and one button. The groomer does not have to press
    /// anything for that to happen. The one thing that stays at Booked on the day is a reported service waiting for the owner.
    static func booking(_ booking: Booking, avatar: Data?, isNew: Bool, now: Date = Date(), request: CustomerGroomingRequest? = nil) -> GroomingCardContent {
        let isFinished = GroomingFeed.isFinished(booking, now: now)
        let needsReview = isFinished && booking.review == nil
        let phase = booking.fulfillment?.phase
        let when = BeckonWhen(start: booking.scheduledStart, end: booking.scheduledEnd,
            zoneIdentifier: booking.agreementSnapshot?.serviceTimeZoneIdentifier ?? booking.serviceTimeZoneIdentifier, now: now)
        // "Today" is also what an appointment that runs past midnight is until it ends.
        let isRunning = GroomingRequestDateFormatting.parsedDate(from: booking.scheduledEnd).map { $0 > now } ?? false
        let countdown = BeckonBookingCountdown.label(for: booking, now: now) ?? (isRunning ? "Today" : nil)
        let countdownText = countdown == "Today" ? "Today!" : countdown
        var bubble: BeckonJourney.Bubble? = .init(kind: .countdown(countdownText ?? "Confirmed"), column: 2)
        var status = countdown.map { "Confirmed, \($0.lowercased())" } ?? "Confirmed"
        if isFinished && !needsReview {
            // Done and reviewed: a history page shows the whole path lit and says nothing more.
            bubble = nil
            status = "Finished and reviewed"
        } else if needsReview {
            bubble = .init(kind: .review, column: 3)
            status = "Finished, leave a review"
        } else if phase == .outcomeReported {
            bubble = .init(kind: .confirmOutcome, column: 2)
            status = "Confirm the outcome"
        } else if isNew {
            bubble = .init(kind: .booked, column: 2)
            status = "Booking confirmed"
        }
        return GroomingCardContent(
            id: booking.id,
            species: booking.agreementSnapshot?.petSnapshot.species ?? booking.requestPetSnapshot?.species ?? "",
            avatarData: avatar,
            title: groomingTitle(booking, request: request),
            time: when?.full ?? booking.scheduledTimeSummary,
            when: when,
            status: status,
            facts: [
                Fact(systemImage: "person.crop.circle.fill", text: booking.partnerDisplayTitle(for: .customer)),
                Fact(systemImage: "tag.fill", text: booking.priceSummary),
            ],
            current: isFinished ? (needsReview ? 3 : 4) : 2,
            fills: [1, 1, GroomingFeed.waitingProgress(booking, now: now)],
            bubble: bubble,
            celebratesColumn: isNew && !isFinished && (phase == nil || phase == .scheduled) ? 2 : nil,
            primaryTitle: needsReview ? "Leave a review" : "View booking",
            primarySymbol: needsReview ? "star.fill" : "arrow.right",
            hasQuietActions: !needsReview,
            footnote: needsReview ? "Your review helps other pet owners." : nil,
            requestID: booking.requestID
        )
    }

    static func groomingTitle(_ booking: Booking, request: CustomerGroomingRequest? = nil) -> String {
        let service = booking.agreementSnapshot?.serviceType.title ?? booking.serviceType?.title ?? request?.serviceType.title ?? "Grooming"
        let pet = booking.agreementSnapshot?.petSnapshot.name ?? booking.requestPetSnapshot?.name ?? request?.petSnapshot.name
        return pet.map { "\(service) · \($0)" } ?? service
    }

    private static func closingText(_ request: CustomerGroomingRequest, now: Date) -> String? {
        guard request.status.isOpenForOffers, let date = GroomingRequestDateFormatting.parsedDate(from: request.expiresAt),
              date > now else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Closes " + formatter.localizedString(for: date, relativeTo: now)
    }
}


extension GroomingPastContent {
    /// "Sun, Oct 25 · 3:44–5:44 PM" becomes "Sun, Oct 25": a past row has no room for the hours next to its status.
    private static func dateOnly(_ summary: String) -> String {
        summary.components(separatedBy: " · ").first ?? summary
    }

    static func booking(_ booking: Booking, avatar: Data?, now: Date = Date()) -> GroomingPastContent {
        GroomingPastContent(
            id: booking.id,
            species: booking.agreementSnapshot?.petSnapshot.species ?? booking.requestPetSnapshot?.species ?? "",
            avatarData: avatar,
            title: GroomingCardContent.groomingTitle(booking),
            time: dateOnly(booking.scheduledTimeSummary),
            detail: booking.partnerDisplayTitle(for: .customer),
            status: GroomingFeed.isFinished(booking, now: now)
                ? .init(title: "Finished", systemImage: "checkmark.circle", tone: .success)
                : booking.status.presentation,
            requestID: booking.requestID
        )
    }

    static func closedRequest(_ request: CustomerGroomingRequest, avatar: Data?) -> GroomingPastContent {
        GroomingPastContent(
            id: request.id,
            species: request.petSnapshot.species,
            avatarData: avatar,
            title: request.displayTitle,
            time: dateOnly(request.preferredTimePresentation.text),
            detail: nil,
            status: request.status.presentation
        )
    }
}

// The booking message of a chat (design): the grooming a conversation is about, as one card in the thread. It used to be a white row
// with a calendar disc, "Confirmed" and a line of small print, laid out inside a full-width face so that its content sat off to one
// side, the time broke before "PM", and nothing said which pet or which service it was. Now it is a ticket in three zones: a strip
// with the booking's state and its reference, what the booking is (the date on the app's own date tile, "Bella · Full groom", when,
// where), and the price with the way into the page. It is the thread's subject and not a person's remark, so it is as wide as the
// page and the same for both sides, never a bubble that leans to one of them. A chat is calm (GUIDE 2): the card has a press and a
// band that changes colour with the state, and no entrance of its own.
import SwiftUI


/// A booking posted into a conversation, read as it stands now (the strip says Completed once it is, whatever it said when it was
/// posted). Put it in a `NavigationLink` or `Button` with the ledge card style: the card is the label, the style draws its face.
struct ChatBookingMessageCard: View {
    let booking: Booking
    /// Who is reading: the words for where it takes place are the owner's ("My home") or the groomer's ("Customer's home").
    let role: UserRole
    @Environment(\.dynamicTypeSize) private var typeSize

    private var presentation: BeckonStatusPresentation { booking.status.presentation }
    private var isCancelled: Bool { booking.status.isCancellation }

    private var when: BeckonWhen? {
        BeckonWhen(start: booking.scheduledStart, end: booking.scheduledEnd,
            zoneIdentifier: booking.agreementSnapshot?.serviceTimeZoneIdentifier ?? booking.serviceTimeZoneIdentifier)
    }

    /// The same words and symbols as the request's "where" (`BeckonGroomingLocationModePresentation`).
    private var place: (title: String, systemImage: String)? {
        guard let mode = booking.locationMode else { return nil }
        let perspective: BeckonGroomingLocationPerspective = role == .customer ? .customer : .groomer
        return (BeckonGroomingLocationModePresentation(mode: mode, perspective: perspective).title,
            mode == .groomerComesToCustomer ? "house.fill" : "storefront.fill")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BeckonStateStrip(title: presentation.title, systemImage: presentation.systemImage,
                tone: .init(BeckonStatusChip.Tone(rawValue: presentation.tone.rawValue) ?? .neutral),
                mark: "#\(booking.referenceCode)")
            summary
            DesignRowDivider()
            foot
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens booking details")
    }

    /// What the booking is: the day on its tile, then the pet and the service, when, and where. A cancelled booking keeps its words
    /// and loses its colour (a grey tile, a struck-through time), so it cannot be taken for a live one at a glance.
    private var summary: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.md))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DesignTokens.Spacing.lg))
        return layout {
            if let parts = BeckonBookingCountdown.dateParts(for: booking) {
                BeckonDateTile(month: parts.month, day: parts.day, isMuted: isCancelled)
            }
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(booking.displayTitle)
                    .font(DesignTokens.Typography.Expressive.headline)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let when {
                    BeckonWhenLabel(when: when,
                        color: isCancelled ? DesignTokens.Colors.textTertiary : DesignTokens.Colors.textSecondary)
                        .strikethrough(isCancelled)
                }
                if let place {
                    Label {
                        Text(place.title)
                    } icon: {
                        Image(systemName: place.systemImage)
                    }
                    .font(DesignTokens.Typography.Expressive.chip)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignTokens.Spacing.lg)
    }

    /// The price, and the way into the page ("Details", the word the Grooming card uses for it), so a tap has something to read
    /// as: a bare chevron did not say that the card opens.
    private var foot: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.sm))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DesignTokens.Spacing.md))
        return layout {
            Text(booking.priceSummary)
                .font(DesignTokens.Typography.Expressive.emphasis)
                .foregroundStyle(isCancelled ? DesignTokens.Colors.textTertiary : DesignTokens.Colors.customerDeep)
                .fixedSize()
            if !typeSize.isAccessibilitySize { Spacer(minLength: DesignTokens.Spacing.md) }
            HStack(spacing: DesignTokens.Spacing.xs) {
                Text("Details")
                Image(systemName: "chevron.right").imageScale(.small)
            }
            .font(DesignTokens.Typography.Expressive.emphasis)
            .foregroundStyle(DesignTokens.Colors.customerDeep)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.minimumTouchTarget, alignment: .leading)
    }

    private var accessibilityLabel: String {
        let parts: [String?] = [presentation.title, booking.displayTitle, when?.full ?? booking.scheduledTimeSummary, place?.title,
            booking.priceSummary]
        return parts.compactMap { $0 }.joined(separator: ", ")
    }
}


/// What stands where the card would be when the store has no such booking (still on its way, or gone): the strip alone, in the card's
/// own shape, so the thread keeps one family of cards.
struct ChatBookingUnavailableCard: View {
    var body: some View {
        BeckonStateStrip(title: "This grooming is unavailable", systemImage: "calendar.badge.exclamationmark", tone: .neutral)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous))
            .beckonLedge(.card)
    }
}


// MARK: Previews

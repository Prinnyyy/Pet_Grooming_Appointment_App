import SwiftUI

/// Compact event ticket. Snapshot facts describe this message; current Booking Stores own actions.
struct ChatBookingMessageCard: View {
    let booking: Booking
    let role: UserRole
    var event: ChatBookingEvent? = nil
    var includesFooter = true
    @Environment(\.dynamicTypeSize) private var typeSize
    private var display: Booking { event?.displayBooking(fallback: booking) ?? booking }
    private var cancelled: Bool { event?.isCancelled == true }
    private var when: BeckonWhen? {
        BeckonWhen(start: display.scheduledStart, end: display.scheduledEnd,
            zoneIdentifier: display.serviceTimeZoneIdentifier)
    }
    private var tone: BeckonStateStrip.Tone {
        guard let event else { return .neutral }
        if cancelled || display.status == .unfulfilled { return .neutral }
        if event.isCompletion { return .success }
        if event.isWarning { return .warning }
        return .accent
    }
    private var symbol: String {
        if cancelled { return "calendar.badge.minus" }
        if event?.isCompletion == true { return "checkmark.seal.fill" }
        if event?.action == "start" { return "scissors" }
        if event?.isWarning == true { return "exclamationmark.bubble" }
        if event?.action.hasPrefix("reschedule_") == true { return "calendar.badge.clock" }
        return "calendar.badge.checkmark"
    }
    var body: some View {
        VStack(spacing: 0) {
            BeckonStateStrip(title: event?.title ?? "Booking update", systemImage: symbol, tone: tone, mark: "#\(booking.referenceCode)")
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                if !typeSize.isAccessibilitySize, let parts = BeckonBookingCountdown.dateParts(for: display) {
                    VStack(spacing: 0) {
                        Text(parts.month).font(DesignTokens.Typography.Expressive.chip)
                        Text(parts.day).font(DesignTokens.Typography.Expressive.title)
                    }
                    .frame(width: 42, height: 48)
                    .foregroundStyle(cancelled ? DesignTokens.Colors.textSecondary : DesignTokens.Colors.customerInk)
                    .background(cancelled ? DesignTokens.Colors.iconTileFill : DesignTokens.Colors.customerTint,
                        in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.inset))
                }
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(event?.petName.map { "\($0) · \(display.appointmentServiceTitle)" } ?? display.displayTitle).font(DesignTokens.Typography.Expressive.emphasis)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                    if event?.version != 1 {
                        Text("Current appointment").font(DesignTokens.Typography.Expressive.chip)
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                    }
                    if let when {
                        Text(when.short).strikethrough(cancelled)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                    if let mode = display.locationMode {
                        let place = BeckonGroomingLocationModePresentation(mode: mode, perspective: role == .customer ? .customer : .groomer)
                        Label(place.title, systemImage: mode == .groomerComesToCustomer ? "house.fill" : "storefront.fill")
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                    if let start = event?.previousStart, let previous = BeckonWhen(start: start, end: nil, zoneIdentifier: display.serviceTimeZoneIdentifier) {
                        Text("Was \(previous.start)").strikethrough().foregroundStyle(DesignTokens.Colors.textTertiary)
                    }
                }.font(DesignTokens.Typography.Expressive.chip)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.padding(.horizontal, DesignTokens.Spacing.lg).padding(.vertical, DesignTokens.Spacing.md)
            if includesFooter {
                DesignRowDivider()
                ChatBookingCardFooter(price: display.priceSummary, cancelled: cancelled) {
                    ChatBookingDetailsLabel()
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ChatBookingDetailsLabel: View {
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Text("Details"); Image(systemName: "chevron.right").imageScale(.small)
        }.font(DesignTokens.Typography.Expressive.label)
            .foregroundStyle(DesignTokens.Colors.customerDeep)
            .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
    }
}

struct ChatBookingCardFooter<Details: View>: View {
    let price: String
    var cancelled = false
    @ViewBuilder let details: Details
    var body: some View {
        HStack {
            Text(price).font(DesignTokens.Typography.Expressive.headline)
                .foregroundStyle(cancelled ? DesignTokens.Colors.textSecondary : DesignTokens.Colors.customerDeep)
            Spacer(minLength: DesignTokens.Spacing.sm)
            details
        }.padding(.horizontal, DesignTokens.Spacing.lg).padding(.vertical, DesignTokens.Spacing.xs)
    }
}

struct ChatBookingUnavailableCard: View {
    var body: some View {
        BeckonStateStrip(title: "This grooming is unavailable", systemImage: "calendar.badge.exclamationmark", tone: .neutral)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous))
            .beckonLedge(.card)
    }
}

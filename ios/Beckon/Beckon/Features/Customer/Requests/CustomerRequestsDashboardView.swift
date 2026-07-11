import Foundation
import SwiftUI

struct CustomerRequestsRootHeader: View {
    let cardCount: Int

    var body: some View {
        ZStack(alignment: .trailing) {
            CustomerTabTitle("Requests")

            if cardCount > 0 {
                BeckonStatusChip(
                    "\(cardCount)",
                    systemImage: cardCount == 1 ? "doc.text.fill" : "rectangle.stack.fill",
                    tone: .customer
                )
            }
        }
    }
}

struct CustomerRequestProgressCarousel: View {
    let cards: [CustomerRequestActionCardItem]
    let store: CustomerRequestsStore
    @Binding var focusedRequestID: UUID?
    let onViewBooking: (CustomerRequestBookingHandoff) -> Void
    let onCancelRequest: (CustomerGroomingRequest) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                        ForEach(cards) { card in
                            CustomerRequestProgressCard(
                                card: card,
                                store: store,
                                onViewBooking: onViewBooking,
                                onCancelRequest: onCancelRequest
                            )
                            .containerRelativeFrame(.horizontal) { length, _ in
                                length
                            }
                            .id(card.request.id)
                        }
                    }
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, DesignTokens.Spacing.screenHorizontal, for: .scrollContent)
                .padding(.horizontal, -DesignTokens.Spacing.screenHorizontal)
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
                .scrollTargetBehavior(.viewAligned)
                .onAppear {
                    scrollToFocusedRequest(using: proxy)
                }
                .onChange(of: focusedRequestID) { _, _ in
                    scrollToFocusedRequest(using: proxy)
                }
                .onChange(of: cards.map(\.request.id)) { _, _ in
                    scrollToFocusedRequest(using: proxy)
                }
            }

        }
    }

    private var cardCount: Int {
        cards.count
    }

    private func scrollToFocusedRequest(using proxy: ScrollViewProxy) {
        guard let requestID = focusedRequestID,
              cards.contains(where: { $0.request.id == requestID }) else {
            return
        }

        withAnimation(.smooth(duration: 0.35)) {
            proxy.scrollTo(requestID, anchor: .center)
        }
        focusedRequestID = nil
    }
}

struct CustomerRequestActionCardSummaryCarousel: View {
    let cards: [CustomerRequestActionCardItem]
    let onSelectRequest: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    ForEach(cards) { card in
                        Button {
                            onSelectRequest(card.request.id)
                        } label: {
                            CustomerRequestActionCardSummary(card: card)
                        }
                        .buttonStyle(.plain)
                            .containerRelativeFrame(.horizontal) { length, _ in
                                length
                            }
                    }
                }
                .padding(.vertical, DesignTokens.Spacing.sm)
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, DesignTokens.Spacing.screenHorizontal, for: .scrollContent)
            .padding(.horizontal, -DesignTokens.Spacing.screenHorizontal)
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .scrollTargetBehavior(.viewAligned)

        }
    }
}

struct CustomerRequestActionCardSummary: View {
    let card: CustomerRequestActionCardItem

    var body: some View {
        BeckonCard(
            isSelected: card.isBookingHandoff,
            padding: CustomerRequestProgressCardLayout.padding
        ) {
            CustomerRequestBriefHeader(
                request: card.request,
                petAvatarPhotoData: card.petAvatarPhotoData,
                presentation: CustomerRequestProgressCardPresentation(
                    request: card.request,
                    handoff: card.handoff
                )
            )
        }
        .beckonShadow(DesignTokens.Shadows.carouselCard)
        .accessibilityIdentifier("customer.requests.progress-card.summary")
    }
}

private struct CustomerRequestProgressCard: View {
    let card: CustomerRequestActionCardItem
    let store: CustomerRequestsStore
    let onViewBooking: (CustomerRequestBookingHandoff) -> Void
    let onCancelRequest: (CustomerGroomingRequest) -> Void

    var body: some View {
        BeckonCard(
            isSelected: presentation.isConfirmedHandoff,
            padding: CustomerRequestProgressCardLayout.padding
        ) {
            VStack(alignment: .leading, spacing: CustomerRequestProgressCardLayout.contentSpacing) {
                CustomerRequestBriefHeader(
                    request: request,
                    petAvatarPhotoData: card.petAvatarPhotoData,
                    presentation: presentation
                )

                Divider()
                    .overlay(DesignTokens.Colors.borderSoft)

                CustomerRequestTimelineList(
                    request: request,
                    density: CustomerRequestProgressCardLayout.timelineDensity
                )

                if let handoff {
                    CustomerRequestBookingHandoffAction(
                        handoff: handoff,
                        onViewBooking: onViewBooking
                    )
                } else {
                    CustomerRequestActionRow(
                        request: request,
                        store: store,
                        onCancelRequest: onCancelRequest
                    )
                }
            }
        }
        .beckonShadow(DesignTokens.Shadows.carouselCard)
        .accessibilityIdentifier(
            AppTestOpsAccessibility.identifier(
                prefix: "customer.requests.row",
                serviceNotes: request.serviceNotes
            ) ?? (isBookingHandoff
                ? "customer.requests.booking-handoff"
                : "customer.requests.progress-card")
        )
        .accessibilityValue(
            AppTestOpsAccessibility.requestReference(request.id)
        )
    }

    private var isBookingHandoff: Bool {
        handoff != nil
    }

    private var request: CustomerGroomingRequest { card.request }
    private var handoff: CustomerRequestBookingHandoff? { card.handoff }

    private var presentation: CustomerRequestProgressCardPresentation {
        CustomerRequestProgressCardPresentation(
            request: request,
            handoff: handoff
        )
    }
}

private enum CustomerRequestProgressCardLayout {
    static let padding = DesignTokens.Spacing.lg
    static let contentSpacing = DesignTokens.Spacing.md
    static let timelineDensity = CustomerRequestTimelineDensity.regular
}

struct CustomerRequestProgressCardPresentation {
    struct InfoLine: Equatable {
        let systemImage: String
        let text: String
    }

    let headline: String
    let subtitle: String
    let chipTitle: String
    let chipSystemImage: String
    let chipTone: BeckonStatusChip.Tone
    let infoLines: [InfoLine]
    let isConfirmedHandoff: Bool

    init(
        request: CustomerGroomingRequest,
        handoff: CustomerRequestBookingHandoff?
    ) {
        isConfirmedHandoff = handoff != nil

        if let handoff {
            headline = "Booking\nConfirmed"
            subtitle = request.title
            chipTitle = "Booking"
            chipSystemImage = "checkmark.seal.fill"
            chipTone = .success
            infoLines = [
                InfoLine(
                    systemImage: "calendar",
                    text: Self.compactDisplayRange(
                        from: handoff.booking.scheduledStart,
                        to: handoff.booking.scheduledEnd
                    )
                ),
                InfoLine(
                    systemImage: "mappin.and.ellipse",
                    text: request.compactLocationSummary
                ),
            ]
        } else {
            headline = request.progressCardHeadline
            subtitle = request.title
            chipTitle = request.dashboardChipTitle
            chipSystemImage = request.dashboardChipSystemImage
            chipTone = request.dashboardChipTone
            infoLines = [
                InfoLine(
                    systemImage: "calendar",
                    text: Self.compactDisplayRange(
                        from: request.preferredStart,
                        to: request.preferredEnd
                    )
                ),
                InfoLine(
                    systemImage: "mappin.and.ellipse",
                    text: request.compactLocationSummary
                ),
            ]
        }
    }

    private static func compactDisplayRange(from start: String, to end: String) -> String {
        "\(compactDisplayString(from: start)) - \(compactDisplayString(from: end))"
    }

    private static func compactDisplayString(from value: String) -> String {
        guard let date = GroomingRequestDateFormatting.parsedDate(from: value) else {
            return value
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }
}

private struct CustomerRequestBookingHandoffAction: View {
    let handoff: CustomerRequestBookingHandoff
    let onViewBooking: (CustomerRequestBookingHandoff) -> Void

    var body: some View {
        Button {
            onViewBooking(handoff)
        } label: {
            CustomerRequestActionLabel(
                title: "View Booking",
                systemImage: "arrow.right",
                tone: .primary
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View Booking")
        .accessibilityIdentifier("customer.requests.booking-handoff.view-booking")
    }
}

private struct CustomerRequestTimelineList: View {
    let request: CustomerGroomingRequest
    let density: CustomerRequestTimelineDensity

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                CustomerRequestTimelineRow(
                    step: step,
                    isLast: index == steps.count - 1,
                    density: density
                )
            }
        }
    }

    private var steps: [CustomerRequestTimelineStep] {
        switch request.status {
        case .open:
            [
                .published(createdAt: request.createdAt, state: .complete),
                .matching(state: .active),
                .offers(state: .upcoming),
                .booking(state: .upcoming),
            ]
        case .hasOffers:
            [
                .published(createdAt: request.createdAt, state: .complete),
                .matching(title: "Matched Groomers", subtitle: "Groomers can now send offers", state: .complete),
                .offers(state: .active),
                .booking(state: .upcoming),
            ]
        case .booked:
            [
                .published(createdAt: request.createdAt, state: .complete),
                .matching(title: "Matched Groomers", subtitle: "A groomer offer was selected", state: .complete),
                .offers(state: .complete),
                .booking(state: .complete),
            ]
        case .cancelled:
            [
                .published(createdAt: request.createdAt, state: .complete),
                .matching(title: "Request Cancelled", subtitle: "This request is closed", state: .stopped),
                .offers(state: .upcoming),
                .booking(state: .upcoming),
            ]
        case .expired:
            [
                .published(createdAt: request.createdAt, state: .complete),
                .matching(title: "Request Expired", subtitle: "Create a new request to keep looking", state: .stopped),
                .offers(state: .upcoming),
                .booking(state: .upcoming),
            ]
        case .unknown:
            [
                .published(createdAt: request.createdAt, state: .complete),
                .matching(title: "Request Status Unknown", subtitle: "Refresh to check the latest status", state: .stopped),
                .offers(state: .upcoming),
                .booking(state: .upcoming),
            ]
        }
    }
}

private struct CustomerRequestBriefHeader: View {
    let request: CustomerGroomingRequest
    let petAvatarPhotoData: Data?
    let presentation: CustomerRequestProgressCardPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.lg) {
                    BeckonPetAvatar(
                        data: petAvatarPhotoData,
                        fallbackText: request.petSnapshot.displayEmoji,
                        background: AnyShapeStyle(request.avatarBackground),
                        width: 68,
                        height: 68,
                        cornerRadius: 34
                    )

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(presentation.headline)
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.86)
                            .lineSpacing(1)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(presentation.subtitle)
                            .font(DesignTokens.Typography.body)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .layoutPriority(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                BeckonStatusChip(
                    presentation.chipTitle,
                    systemImage: presentation.chipSystemImage,
                    tone: presentation.chipTone
                )
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                ForEach(Array(presentation.infoLines.enumerated()), id: \.offset) { _, infoLine in
                    CustomerRequestBriefInfoLine(
                        systemImage: infoLine.systemImage,
                        text: infoLine.text
                    )
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CustomerRequestBriefInfoLine: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)
                .frame(width: 18)
                .accessibilityHidden(true)

            Text(text)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .lineLimit(lineLimit)
                .minimumScaleFactor(systemImage == "calendar" ? 0.74 : 0.92)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var lineLimit: Int {
        systemImage == "calendar" ? 1 : 2
    }
}

private enum CustomerRequestTimelineDensity: Equatable {
    case regular
    case compact

    var markerSize: CGFloat {
        switch self {
        case .regular:
            38
        case .compact:
            34
        }
    }

    var connectorHeight: CGFloat {
        switch self {
        case .regular:
            30
        case .compact:
            24
        }
    }

    var connectorWidth: CGFloat {
        switch self {
        case .regular:
            3
        case .compact:
            2
        }
    }

    var horizontalSpacing: CGFloat {
        switch self {
        case .regular:
            DesignTokens.Spacing.md
        case .compact:
            DesignTokens.Spacing.md
        }
    }

    var titleFont: Font {
        switch self {
        case .regular:
            DesignTokens.Typography.body.weight(.bold)
        case .compact:
            DesignTokens.Typography.body.weight(.bold)
        }
    }

    var subtitleFont: Font {
        switch self {
        case .regular:
            DesignTokens.Typography.caption
        case .compact:
            DesignTokens.Typography.caption
        }
    }

    var textTopPadding: CGFloat {
        switch self {
        case .regular:
            2
        case .compact:
            2
        }
    }
}

private struct CustomerRequestTimelineRow: View {
    let step: CustomerRequestTimelineStep
    let isLast: Bool
    let density: CustomerRequestTimelineDensity

    var body: some View {
        HStack(alignment: .top, spacing: density.horizontalSpacing) {
            VStack(spacing: 0) {
                marker

                if !isLast {
                    Rectangle()
                        .fill(step.connectorColor)
                        .frame(
                            width: density.connectorWidth,
                            height: density.connectorHeight
                        )
                }
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(step.title)
                    .font(density.titleFont)
                    .foregroundStyle(step.titleColor)
                    .fixedSize(horizontal: false, vertical: true)

                Text(step.subtitle)
                    .font(density.subtitleFont)
                    .foregroundStyle(step.subtitleColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, density.textTopPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var marker: some View {
        ZStack {
            Circle()
                .fill(step.markerColor)
                .frame(width: density.markerSize, height: density.markerSize)

            if step.state == .complete {
                Image(systemName: "checkmark")
                    .font(completeMarkerFont)
                    .foregroundStyle(DesignTokens.Colors.surface)
            } else if step.state == .stopped {
                Image(systemName: "xmark")
                    .font(stoppedMarkerFont)
                    .foregroundStyle(DesignTokens.Colors.surface)
            }
        }
        .accessibilityHidden(true)
    }

    private var completeMarkerFont: Font {
        density == .compact ? .subheadline.weight(.bold) : .headline.weight(.bold)
    }

    private var stoppedMarkerFont: Font {
        density == .compact ? .caption.weight(.bold) : .subheadline.weight(.bold)
    }
}

private struct CustomerRequestTimelineStep: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let state: CustomerRequestTimelineStepState

    static func published(
        createdAt: String,
        state: CustomerRequestTimelineStepState
    ) -> CustomerRequestTimelineStep {
        CustomerRequestTimelineStep(
            id: "published",
            title: "Request Published",
            subtitle: publishedSubtitle(from: createdAt),
            state: state
        )
    }

    static func matching(
        title: String = "Matching Groomers",
        subtitle: String = "Finding the best fit nearby",
        state: CustomerRequestTimelineStepState
    ) -> CustomerRequestTimelineStep {
        CustomerRequestTimelineStep(
            id: "matching",
            title: title,
            subtitle: subtitle,
            state: state
        )
    }

    static func offers(state: CustomerRequestTimelineStepState) -> CustomerRequestTimelineStep {
        let subtitle = switch state {
        case .complete:
            "Offer accepted"
        case .active:
            "Review groomer offers"
        case .upcoming:
            "Waiting for groomers to respond"
        case .stopped:
            "No offer activity"
        }

        return CustomerRequestTimelineStep(
            id: "offers",
            title: "Offers Received",
            subtitle: subtitle,
            state: state
        )
    }

    static func booking(state: CustomerRequestTimelineStepState) -> CustomerRequestTimelineStep {
        CustomerRequestTimelineStep(
            id: "booking",
            title: "Booking Confirmed",
            subtitle: state == .complete ? "Your appointment is booked" : "Accept an offer to book",
            state: state
        )
    }

    private static func publishedSubtitle(from createdAt: String) -> String {
        guard let date = GroomingRequestDateFormatting.parsedDate(from: createdAt) else {
            return "Published"
        }

        let elapsed = Date().timeIntervalSince(date)
        if elapsed >= 0, elapsed < 60 * 60 {
            return "Just now"
        }

        if Calendar.current.isDateInToday(date) {
            return "Today"
        }

        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

private enum CustomerRequestTimelineStepState {
    case complete
    case active
    case upcoming
    case stopped
}

private extension CustomerRequestTimelineStep {
    var markerColor: Color {
        switch state {
        case .complete:
            DesignTokens.Colors.success
        case .active:
            DesignTokens.Colors.customerPrimary
        case .upcoming:
            DesignTokens.Colors.borderSoft
        case .stopped:
            DesignTokens.Colors.error
        }
    }

    var connectorColor: Color {
        switch state {
        case .complete:
            DesignTokens.Colors.success.opacity(0.9)
        case .active:
            DesignTokens.Colors.customerPrimary.opacity(0.55)
        case .upcoming:
            DesignTokens.Colors.borderSoft
        case .stopped:
            DesignTokens.Colors.borderSoft
        }
    }

    var titleColor: Color {
        switch state {
        case .complete, .active:
            DesignTokens.Colors.textPrimary
        case .upcoming:
            DesignTokens.Colors.textTertiary
        case .stopped:
            DesignTokens.Colors.error
        }
    }

    var subtitleColor: Color {
        switch state {
        case .complete, .active:
            DesignTokens.Colors.textSecondary
        case .upcoming, .stopped:
            DesignTokens.Colors.textTertiary
        }
    }
}

private struct CustomerRequestActionRow: View {
    let request: CustomerGroomingRequest
    let store: CustomerRequestsStore
    let onCancelRequest: (CustomerGroomingRequest) -> Void

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            detailLink
            cancelButton
        }
    }

    private var detailLink: some View {
        NavigationLink {
            CustomerRequestDetailView(
                requestID: request.id,
                store: store
            )
        } label: {
            CustomerRequestActionLabel(
                title: "Detail",
                systemImage: "doc.text.magnifyingglass",
                tone: .neutral
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Request Detail")
        .accessibilityIdentifier(
            AppTestOpsAccessibility.identifier(
                prefix: "customer.requests.detail",
                serviceNotes: request.serviceNotes
            ) ?? "customer.requests.detail"
        )
        .accessibilityValue(
            AppTestOpsAccessibility.requestReference(request.id)
        )
    }

    private var cancelButton: some View {
        Button {
            onCancelRequest(request)
        } label: {
            CustomerRequestActionLabel(
                title: store.isCancelling(request) ? "Cancelling" : "Cancel",
                systemImage: store.isCancelling(request) ? "hourglass" : "xmark.circle",
                tone: .destructive
            )
        }
        .buttonStyle(.plain)
        .disabled(!request.status.isOpenForOffers || store.isCancelling(request))
        .accessibilityLabel("Cancel Request")
        .accessibilityIdentifier("customer.requests.cancel")
    }
}

private struct CustomerRequestActionLabel: View {
    enum Tone {
        case primary
        case neutral
        case destructive

        var foreground: Color {
            switch self {
            case .primary:
                DesignTokens.Colors.customerPrimaryDark
            case .neutral:
                DesignTokens.Colors.textPrimary
            case .destructive:
                DesignTokens.Colors.error
            }
        }

        var border: Color {
            switch self {
            case .primary:
                DesignTokens.Colors.customerPrimary.opacity(0.46)
            case .neutral:
                DesignTokens.Colors.border
            case .destructive:
                DesignTokens.Colors.error.opacity(0.34)
            }
        }

        var background: Color {
            switch self {
            case .primary:
                DesignTokens.Colors.customerPrimary.opacity(0.15)
            case .neutral, .destructive:
                DesignTokens.Colors.surface
            }
        }
    }

    @Environment(\.isEnabled) private var isEnabled

    let title: String
    let systemImage: String
    let tone: Tone

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(DesignTokens.Typography.body.weight(.bold))
            .foregroundStyle(isEnabled ? tone.foreground : DesignTokens.Colors.textTertiary)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.button, style: .continuous)
                    .fill(tone.background)
            }
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.button, style: .continuous)
                    .stroke(isEnabled ? tone.border : DesignTokens.Colors.borderSoft, lineWidth: 1.2)
            }
            .opacity(isEnabled ? 1 : 0.58)
            .contentShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.button, style: .continuous))
    }
}

struct CustomerCancelledRequestsSection: View {
    let requests: [CustomerGroomingRequest]
    let store: CustomerRequestsStore
    let onRepublishRequest: (CustomerGroomingRequest) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            BeckonSectionHeader(
                "Recent Closed Requests",
                subtitle: "Your three most recent cancelled requests can be reviewed or used to start a new request."
            )

            LazyVStack(spacing: DesignTokens.Spacing.md) {
                ForEach(requests) { request in
                    NavigationLink {
                        CustomerRequestDetailView(
                            requestID: request.id,
                            store: store,
                            onRepublishRequest: onRepublishRequest
                        )
                    } label: {
                        CustomerCancelledRequestRow(
                            request: request,
                            petAvatarPhotoData: store.primaryPetPhotoData(petID: request.petID)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct CustomerCancelledRequestRow: View {
    let request: CustomerGroomingRequest
    let petAvatarPhotoData: Data?

    var body: some View {
        BeckonCard {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                BeckonPetAvatar(
                    data: petAvatarPhotoData,
                    fallbackText: request.petSnapshot.displayEmoji,
                    background: AnyShapeStyle(request.avatarBackground),
                    width: 48,
                    height: 48,
                    cornerRadius: 24
                )

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(request.title)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(timeSummary)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                BeckonStatusChip(
                    "Cancelled",
                    systemImage: "xmark.circle.fill",
                    tone: .neutral
                )
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var timeSummary: String {
        "\(GroomingRequestDateFormatting.displayString(from: request.preferredStart)) - \(GroomingRequestDateFormatting.displayString(from: request.preferredEnd))"
    }
}

struct CustomerRequestsEmptyDashboard: View {
    var body: some View {
        BeckonEmptyState(
            title: CustomerRequestEmptyCopy.title,
            message: CustomerRequestEmptyCopy.message,
            systemImage: "doc.text.magnifyingglass",
            accent: .customer
        )
    }
}

enum CustomerRequestEmptyCopy {
    static let title = "No Active Request"
    static let message = "Open quests and newly confirmed booking handoffs will appear here."
}

private extension CustomerGroomingRequest {
    var progressCardHeadline: String {
        switch status {
        case .open:
            "Open\nRequest"
        case .hasOffers:
            "Offers\nReady"
        case .booked:
            "Confirmed\nQuest"
        case .cancelled:
            "Cancelled\nRequest"
        case .expired:
            "Expired\nRequest"
        case .unknown:
            "Unknown\nStatus"
        }
    }

    var avatarBackground: LinearGradient {
        LinearGradient(
            colors: [
                DesignTokens.Colors.customerPrimary.opacity(0.28),
                DesignTokens.Colors.groomerAccent.opacity(0.20),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var dashboardChipTitle: String {
        switch status {
        case .open:
            "Matching"
        case .hasOffers:
            "Offers Ready"
        case .booked:
            "Booked"
        case .cancelled:
            "Cancelled"
        case .expired:
            "Expired"
        case .unknown:
            "Unknown"
        }
    }

    var dashboardChipSystemImage: String {
        switch status {
        case .open:
            "circle.fill"
        case .hasOffers:
            "tag.fill"
        case .booked:
            "checkmark.circle.fill"
        case .cancelled:
            "xmark.circle.fill"
        case .expired:
            "hourglass"
        case .unknown:
            "questionmark.circle"
        }
    }

    var dashboardChipTone: BeckonStatusChip.Tone {
        switch status {
        case .open:
            .customer
        case .hasOffers:
            .warning
        case .booked:
            .success
        case .cancelled, .expired, .unknown:
            .neutral
        }
    }
}

private extension GroomingRequestPetSnapshot {
    var displayEmoji: String {
        switch species.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case let value where value.contains("cat"):
            "🐱"
        case let value where value.contains("bird"):
            "🐦"
        case let value where value.contains("rabbit") || value.contains("bunny"):
            "🐰"
        default:
            "🐶"
        }
    }
}

import SwiftUI

struct CustomerRequestsView: View {
    @State private var store: CustomerRequestsStore
    @State private var pendingCancelRequest: CustomerGroomingRequest?
    @State private var selectedBookingHandoff: CustomerRequestBookingHandoff?

    init(
        customerID: UUID,
        petRepository: any CustomerPetRepository,
        requestRepository: any CustomerRequestRepository,
        bookingRepository: any BookingRepository
    ) {
        _store = State(
            initialValue: CustomerRequestsStore(
                customerID: customerID,
                petRepository: petRepository,
                requestRepository: requestRepository,
                bookingRepository: bookingRepository
            )
        )
    }

    var body: some View {
        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()

            requestsContent
        }
        .navigationTitle("Requests")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await store.load()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(store.isBusy)
            }
        }
        .safeAreaInset(edge: .bottom) {
            CustomerRequestsStatusView(store: store)
        }
        .alert("Cancel this request?", isPresented: isCancelAlertPresented) {
            Button("Keep Request", role: .cancel) {
                pendingCancelRequest = nil
            }

            Button("Cancel Request", role: .destructive) {
                guard let request = pendingCancelRequest else { return }
                pendingCancelRequest = nil
                Task {
                    await store.cancel(request)
                }
            }
        } message: {
            Text("This closes the request and any pending offers. Confirmed bookings are managed from Bookings.")
        }
        .navigationDestination(item: $selectedBookingHandoff) { handoff in
            BookingDetailView(
                bookingID: handoff.booking.id,
                role: .customer,
                store: store.bookingDetailStore(for: handoff.booking)
            )
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await store.load()
        }
    }

    private var isCancelAlertPresented: Binding<Bool> {
        Binding(
            get: {
                pendingCancelRequest != nil
            },
            set: { isPresented in
                if !isPresented {
                    pendingCancelRequest = nil
                }
            }
        )
    }

    @ViewBuilder
    private var requestsContent: some View {
        if store.isLoading, store.pets.isEmpty, store.requests.isEmpty {
            GroomlyLoadingView(
                title: "Loading Requests…",
                message: "Fetching your pet's grooming requests.",
                accent: .customer
            )
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .accessibilityIdentifier("customer.requests.loading")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    CustomerRequestsRootHeader(cardCount: visibleCardCount)

                    if visibleCardCount == 0 {
                        CustomerRequestsEmptyDashboard()
                            .accessibilityIdentifier("customer.requests.empty")
                    } else {
                        CustomerRequestProgressCarousel(
                            cards: store.visibleActionCards,
                            store: store,
                            onViewBooking: { handoff in
                                selectedBookingHandoff = handoff
                                store.acknowledgeBookingHandoff(for: handoff)
                            },
                            onCancelRequest: { request in
                                pendingCancelRequest = request
                            }
                        )
                        .accessibilityIdentifier("customer.requests.progress-carousel")
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.top, DesignTokens.Spacing.xl)
                .padding(.bottom, DesignTokens.Spacing.xl * 4)
            }
            .scrollContentBackground(.hidden)
            .refreshable {
                await store.load()
            }
            .accessibilityIdentifier("customer.requests.list")
        }
    }

    private var visibleCardCount: Int {
        store.visibleActionCards.count
    }
}

private struct CustomerRequestsRootHeader: View {
    let cardCount: Int

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Text("Your Requests")
                    .font(DesignTokens.Typography.largeTitle)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if cardCount > 0 {
                GroomlyStatusChip(
                    "\(cardCount)",
                    systemImage: cardCount == 1 ? "doc.text.fill" : "rectangle.stack.fill",
                    tone: .customer
                )
                .padding(.top, DesignTokens.Spacing.sm)
            }
        }
    }

    private var subtitle: String {
        if cardCount > 1 {
            return "Swipe between active quests and booking handoffs. Each card keeps the next action clear."
        }

        if cardCount == 1 {
            return "Track the next action for this grooming flow."
        }

        return "Open quests and newly confirmed booking handoffs will appear here."
    }
}

private struct CustomerRequestProgressCarousel: View {
    let cards: [CustomerRequestActionCardItem]
    let store: CustomerRequestsStore
    let onViewBooking: (CustomerRequestBookingHandoff) -> Void
    let onCancelRequest: (CustomerGroomingRequest) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    ForEach(cards) { card in
                        CustomerRequestProgressCard(
                            request: card.request,
                            handoff: card.handoff,
                            store: store,
                            onViewBooking: onViewBooking,
                            onCancelRequest: onCancelRequest
                        )
                        .containerRelativeFrame(.horizontal) { length, _ in
                            length
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, DesignTokens.Spacing.screenHorizontal, for: .scrollContent)
            .padding(.horizontal, -DesignTokens.Spacing.screenHorizontal)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .scrollTargetBehavior(.viewAligned)

            if cardCount > 1 {
                Label("Swipe to Review Another Request", systemImage: "arrow.left.and.right")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityIdentifier("customer.requests.carousel-hint")
            }
        }
    }

    private var cardCount: Int {
        cards.count
    }
}

struct CustomerRequestActionCardSummary: View {
    let card: CustomerRequestActionCardItem

    var body: some View {
        GroomlyCard(
            isSelected: card.isBookingHandoff,
            padding: CustomerRequestProgressCardLayout.padding
        ) {
            CustomerRequestBriefHeader(
                request: card.request,
                presentation: CustomerRequestProgressCardPresentation(
                    request: card.request,
                    handoff: card.handoff
                )
            )
        }
        .accessibilityIdentifier("customer.requests.progress-card.summary")
    }
}

private struct CustomerRequestProgressCard: View {
    let request: CustomerGroomingRequest
    let handoff: CustomerRequestBookingHandoff?
    let store: CustomerRequestsStore
    let onViewBooking: (CustomerRequestBookingHandoff) -> Void
    let onCancelRequest: (CustomerGroomingRequest) -> Void

    var body: some View {
        GroomlyCard(
            isSelected: presentation.isConfirmedHandoff,
            padding: CustomerRequestProgressCardLayout.padding
        ) {
            VStack(alignment: .leading, spacing: CustomerRequestProgressCardLayout.contentSpacing) {
                CustomerRequestBriefHeader(
                    request: request,
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
        .accessibilityIdentifier(
            isBookingHandoff
                ? "customer.requests.booking-handoff"
                : "customer.requests.progress-card"
        )
    }

    private var isBookingHandoff: Bool {
        handoff != nil
    }

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
    let chipTone: GroomlyStatusChip.Tone
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
                    text: request.locationSummary
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
                    text: request.locationSummary
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
        }
    }
}

private struct CustomerRequestBriefHeader: View {
    let request: CustomerGroomingRequest
    let presentation: CustomerRequestProgressCardPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                Text(request.petSnapshot.displayEmoji)
                    .font(.system(size: 30))
                    .frame(width: 56, height: 56)
                    .background(request.avatarBackground)
                    .clipShape(DesignTokens.Shapes.circular)
                    .accessibilityHidden(true)

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
                        .lineLimit(2)
                        .minimumScaleFactor(0.92)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                GroomlyStatusChip(
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
        .accessibilityIdentifier("customer.requests.detail")
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

private struct CustomerRequestsEmptyDashboard: View {
    var body: some View {
        GroomlyEmptyState(
            title: "No Requests Yet",
            message: "Start a grooming quest from Home. Published requests and their progress will appear here.",
            systemImage: "doc.text.magnifyingglass",
            accent: .customer
        )
    }
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
        }
    }

    var dashboardChipTone: GroomlyStatusChip.Tone {
        switch status {
        case .open:
            .customer
        case .hasOffers:
            .warning
        case .booked:
            .success
        case .cancelled, .expired:
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

struct CustomerRequestDetailView: View {
    let requestID: UUID
    let store: CustomerRequestsStore

    var body: some View {
        if let request = store.request(withID: requestID) {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        GroomlySectionHeader(
                            "Request Details",
                            subtitle: "Review the request and compare groomer offers before booking."
                        )

                        requestCard(request)
                        petSnapshotCard(request)
                        scheduleLocationCard(request)

                        CustomerOfferReviewSection(
                            request: request,
                            store: store
                        )

                        if request.status.isOpenForOffers {
                            cancellationNotice
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                    .padding(.top, DesignTokens.Spacing.lg)
                    .padding(.bottom, DesignTokens.Spacing.xl)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(request.petSnapshot.name)
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("customer.requests.detail")
            .task(id: request.id) {
                await store.loadOffers(for: request)
            }
        } else {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                GroomlyEmptyState(
                    title: "Request Unavailable",
                    message: "Refresh requests and try again.",
                    systemImage: "doc.text.magnifyingglass",
                    accent: .customer
                )
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            }
            .navigationTitle("Request")
        }
    }

    private func requestCard(_ request: CustomerGroomingRequest) -> some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DetailCardHeader(
                    title: request.serviceType,
                    subtitle: request.locationSummary,
                    systemImage: "doc.text.fill"
                ) {
                    GroomlyStatusChip(
                        request.status.title,
                        systemImage: request.status.detailSystemImage,
                        tone: request.status.detailTone
                    )
                }

                if let serviceNotes = request.serviceNotes {
                    Text(serviceNotes)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func petSnapshotCard(_ request: CustomerGroomingRequest) -> some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DetailCardHeader(
                    title: "Pet Snapshot",
                    subtitle: "Frozen request context from the selected pet.",
                    systemImage: "pawprint.fill"
                )

                DetailMetadataRow(title: "Pet", value: request.petSnapshot.name, systemImage: "heart.fill")
                DetailMetadataRow(title: "Species", value: request.petSnapshot.species, systemImage: "tag.fill")

                if let breed = request.petSnapshot.breed {
                    DetailMetadataRow(title: "Breed", value: breed, systemImage: "list.bullet")
                }

                if let size = request.petSnapshot.size {
                    DetailMetadataRow(title: "Size", value: size, systemImage: "ruler")
                }

                DetailMetadataRow(
                    title: "Photos",
                    value: "\(request.photoSnapshot.count)",
                    systemImage: "photo.on.rectangle"
                )
            }
        }
    }

    private func scheduleLocationCard(_ request: CustomerGroomingRequest) -> some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DetailCardHeader(
                    title: "Preferred Time and Location",
                    subtitle: "The window and area groomers used for this offer.",
                    systemImage: "calendar"
                )

                DetailMetadataRow(
                    title: "Start",
                    value: GroomingRequestDateFormatting.displayString(
                        from: request.preferredStart
                    ),
                    systemImage: "clock"
                )
                DetailMetadataRow(
                    title: "End",
                    value: GroomingRequestDateFormatting.displayString(
                        from: request.preferredEnd
                    ),
                    systemImage: "clock.badge.checkmark"
                )
                DetailMetadataRow(title: "City", value: request.city, systemImage: "building.2")
                DetailMetadataRow(title: "State", value: request.state, systemImage: "map")
                DetailMetadataRow(title: "ZIP", value: request.zipCode, systemImage: "number")
            }
        }
    }

    private var cancellationNotice: some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DetailCardHeader(
                    title: "Cancellation",
                    subtitle: "Unconfirmed requests can be cancelled from their Requests card before booking.",
                    systemImage: "xmark.circle.fill"
                ) {
                    GroomlyStatusChip(
                        "Available",
                        systemImage: "checkmark.circle.fill",
                        tone: .customer
                    )
                }
            }
        }
    }
}

private struct CustomerOfferReviewSection: View {
    let request: CustomerGroomingRequest
    let store: CustomerRequestsStore

    private var offers: [CustomerOfferReview] {
        store.offers(for: request)
    }

    private var pendingOffers: [CustomerOfferReview] {
        offers.filter(\.isPending)
    }

    private var historicalOffers: [CustomerOfferReview] {
        offers.filter { !$0.isPending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GroomlySectionHeader(
                "Offers",
                subtitle: "Compare pending offers and review previous offer activity."
            )

            Group {
                if store.isLoadingOffers(for: request), offers.isEmpty {
                    GroomlyLoadingView(
                        title: "Loading Offers…",
                        message: "Checking for groomer responses.",
                        accent: .customer
                    )
                        .accessibilityIdentifier("customer.offers.loading")
                } else if let errorMessage = store.offerError(for: request) {
                    GroomlyErrorBanner(
                        title: "We Could Not Load Offers",
                        message: errorMessage
                    ) {
                        Button {
                            Task {
                                await store.loadOffers(for: request)
                            }
                        } label: {
                            Label("Refresh Offers", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(GroomlySecondaryButtonStyle())
                        .disabled(store.isLoadingOffers(for: request))
                    }
                        .accessibilityIdentifier("customer.offers.error")
                } else if offers.isEmpty {
                    GroomlyEmptyState(
                        title: "No Offers Yet",
                        message: "Matched groomers can submit offers while this request is open.",
                        systemImage: "tag",
                        accent: .customer
                    )
                    .accessibilityIdentifier("customer.offers.empty")
                } else {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        if !pendingOffers.isEmpty {
                            offerGroup(
                                title: "Pending Offers",
                                offers: pendingOffers,
                                isHistorical: false
                            )
                            .accessibilityIdentifier("customer.offers.pending-list")
                        } else {
                            GroomlyCard {
                                Text("There are no pending offers for this request.")
                                    .font(DesignTokens.Typography.body)
                                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        if !historicalOffers.isEmpty {
                            offerGroup(
                                title: "Offer History",
                                offers: historicalOffers,
                                isHistorical: true
                            )
                            .accessibilityIdentifier("customer.offers.history-list")
                        }
                    }
                }
            }

            Button {
                Task {
                    await store.loadOffers(for: request)
                }
            } label: {
                Label("Refresh Offers", systemImage: "arrow.clockwise")
            }
            .buttonStyle(GroomlySecondaryButtonStyle())
            .disabled(store.isLoadingOffers(for: request))
            .accessibilityIdentifier("customer.offers.refresh")
        }
    }

    private func offerGroup(
        title: String,
        offers: [CustomerOfferReview],
        isHistorical: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .font(DesignTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .textCase(.uppercase)

            LazyVStack(spacing: DesignTokens.Spacing.md) {
                ForEach(offers) { offerReview in
                    NavigationLink {
                        CustomerOfferDetailView(
                            request: request,
                            offerID: offerReview.id,
                            store: store
                        )
                    } label: {
                        CustomerOfferSummaryRow(
                            offerReview: offerReview,
                            isHistorical: isHistorical
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct CustomerOfferSummaryRow: View {
    let offerReview: CustomerOfferReview
    var isHistorical = false

    var body: some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(offerReview.groomerTitle)
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(offerReview.groomerLocationSummary)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }

                    Spacer(minLength: DesignTokens.Spacing.md)

                    GroomlyStatusChip(
                        offerReview.offer.status.title,
                        systemImage: offerReview.offer.status.detailSystemImage,
                        tone: offerReview.offer.status.detailTone
                    )
                }

                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
                    Text(offerReview.offer.priceSummary)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(isHistorical ? DesignTokens.Colors.textSecondary : DesignTokens.Colors.textPrimary)

                    Spacer(minLength: DesignTokens.Spacing.md)

                    Text(offerReview.proposedTimeSummary)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct CustomerOfferDetailView: View {
    let request: CustomerGroomingRequest
    let offerID: UUID
    let store: CustomerRequestsStore

    private var offerReview: CustomerOfferReview? {
        store.offers(for: request).first { $0.id == offerID }
    }

    var body: some View {
        if let offerReview {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        GroomlySectionHeader(
                            "Offer",
                            subtitle: "Review the groomer proposal before accepting."
                        )

                        groomerCard(offerReview)
                        offerCard(offerReview)
                        requestCard(offerReview)
                        acceptanceCard(offerReview)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                    .padding(.top, DesignTokens.Spacing.lg)
                    .padding(.bottom, DesignTokens.Spacing.xl)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Offer")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("customer.offers.detail")
        } else {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                GroomlyEmptyState(
                    title: "Offer Unavailable",
                    message: "Refresh offers and try again.",
                    systemImage: "tag.slash",
                    accent: .customer
                )
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            }
            .navigationTitle("Offer")
        }
    }

    private func groomerCard(_ offerReview: CustomerOfferReview) -> some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DetailCardHeader(
                    title: offerReview.groomerTitle,
                    subtitle: offerReview.groomerLocationSummary,
                    systemImage: "person.crop.circle.fill"
                ) {
                    if offerReview.groomerProfile?.isVerified == true {
                        GroomlyStatusChip(
                            "Verified",
                            systemImage: "checkmark.seal.fill",
                            tone: .success
                        )
                        .accessibilityLabel("Verified groomer")
                    }
                }

                DetailMetadataRow(
                    title: "Rating",
                    value: offerReview.ratingSummary,
                    systemImage: "star.fill"
                )

                if let bio = offerReview.groomerProfile?.bio {
                    Text(bio)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func offerCard(_ offerReview: CustomerOfferReview) -> some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DetailCardHeader(
                    title: offerReview.offer.priceSummary,
                    subtitle: offerReview.proposedTimeSummary,
                    systemImage: "tag.fill"
                ) {
                    GroomlyStatusChip(
                        offerReview.offer.status.title,
                        systemImage: offerReview.offer.status.detailSystemImage,
                        tone: offerReview.offer.status.detailTone
                    )
                }

                DetailMetadataRow(
                    title: "Start",
                    value: GroomingRequestDateFormatting.displayString(
                        from: offerReview.offer.proposedStart
                    ),
                    systemImage: "clock"
                )
                DetailMetadataRow(
                    title: "End",
                    value: GroomingRequestDateFormatting.displayString(
                        from: offerReview.offer.proposedEnd
                    ),
                    systemImage: "clock.badge.checkmark"
                )

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
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DetailCardHeader(
                    title: request.petSnapshot.name,
                    subtitle: request.serviceType,
                    systemImage: "pawprint.fill"
                ) {
                    GroomlyStatusChip(
                        request.status.title,
                        systemImage: request.status.detailSystemImage,
                        tone: request.status.detailTone
                    )
                }

                DetailMetadataRow(
                    title: "Requested Time",
                    value: requestTimeSummary,
                    systemImage: "calendar"
                )
            }
        }
    }

    private func acceptanceCard(_ offerReview: CustomerOfferReview) -> some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DetailCardHeader(
                    title: "Acceptance",
                    subtitle: acceptanceMessage(for: offerReview),
                    systemImage: "checkmark.circle.fill"
                )

                if let errorMessage = store.errorMessage {
                    GroomlyErrorBanner(
                        title: "We Could Not Accept This Offer",
                        message: errorMessage
                    )
                }

                if offerReview.offer.status == .pending,
                   request.status.isOpenForOffers {
                    Button {
                        Task {
                            await store.accept(
                                offerReview: offerReview,
                                for: request
                            )
                        }
                    } label: {
                        Label(
                            store.isAcceptingOffer(offerReview.offer.id) ? "Accepting…" : "Accept Offer",
                            systemImage: "checkmark.circle"
                        )
                    }
                    .buttonStyle(GroomlyPrimaryButtonStyle())
                    .disabled(store.isAcceptingOffer(offerReview.offer.id))
                    .accessibilityIdentifier("customer.offers.accept")

                    Text("The backend creates the booking and conversation atomically. If the groomer becomes unavailable, no local booking is created.")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    GroomlyStatusChip(
                        acceptanceStatusTitle(for: offerReview),
                        systemImage: acceptanceStatusSystemImage(for: offerReview),
                        tone: acceptanceStatusTone(for: offerReview)
                    )
                }
            }
        }
    }

    private func acceptanceMessage(for offerReview: CustomerOfferReview) -> String {
        if offerReview.offer.status == .pending,
           request.status.isOpenForOffers {
            return "Accepting creates the booking and booking chat through the existing backend transaction."
        } else if offerReview.offer.status == .acceptedByCustomer {
            return "This offer has been accepted. Check the Bookings tab for the appointment."
        } else if request.status == .booked {
            return "This request is already booked."
        } else {
            return "This offer can no longer be accepted."
        }
    }

    private func acceptanceStatusTitle(for offerReview: CustomerOfferReview) -> String {
        if offerReview.offer.status == .acceptedByCustomer {
            return "Accepted"
        } else if request.status == .booked {
            return "Booked"
        } else {
            return "Unavailable"
        }
    }

    private func acceptanceStatusSystemImage(for offerReview: CustomerOfferReview) -> String {
        if offerReview.offer.status == .acceptedByCustomer || request.status == .booked {
            return "checkmark.circle.fill"
        }

        return "xmark.circle"
    }

    private func acceptanceStatusTone(for offerReview: CustomerOfferReview) -> GroomlyStatusChip.Tone {
        if offerReview.offer.status == .acceptedByCustomer || request.status == .booked {
            return .success
        }

        return .neutral
    }

    private var requestTimeSummary: String {
        "\(GroomingRequestDateFormatting.displayString(from: request.preferredStart)) – \(GroomingRequestDateFormatting.displayString(from: request.preferredEnd))"
    }
}

private struct DetailCardHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    private let trailing: Trailing

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.headline)
                .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)
                .frame(
                    width: DesignTokens.Spacing.xl + DesignTokens.Spacing.md,
                    height: DesignTokens.Spacing.xl + DesignTokens.Spacing.md
                )
                .background(DesignTokens.Colors.customerPrimary.opacity(0.14))
                .clipShape(DesignTokens.Shapes.circular)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing
        }
        .accessibilityElement(children: .combine)
    }
}

extension DetailCardHeader where Trailing == EmptyView {
    init(
        title: String,
        subtitle: String,
        systemImage: String
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        trailing = EmptyView()
    }
}

private struct DetailMetadataRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
            Label {
                Text(title)
                    .font(DesignTokens.Typography.caption.weight(.semibold))
            } icon: {
                Image(systemName: systemImage)
                    .font(DesignTokens.Typography.caption)
            }
            .foregroundStyle(DesignTokens.Colors.textSecondary)

            Spacer(minLength: DesignTokens.Spacing.md)

            Text(value)
                .font(DesignTokens.Typography.body.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}

private extension GroomingRequestStatus {
    var detailTone: GroomlyStatusChip.Tone {
        switch self {
        case .open, .hasOffers:
            .customer
        case .booked:
            .success
        case .cancelled, .expired:
            .neutral
        }
    }

    var detailSystemImage: String {
        switch self {
        case .open:
            "clock"
        case .hasOffers:
            "tag"
        case .booked:
            "checkmark.circle"
        case .cancelled:
            "xmark.circle"
        case .expired:
            "hourglass"
        }
    }
}

private extension GroomerOfferStatus {
    var detailTone: GroomlyStatusChip.Tone {
        switch self {
        case .pending:
            .customer
        case .acceptedByCustomer:
            .success
        case .declinedByCustomer, .withdrawnByGroomer, .expired:
            .neutral
        }
    }

    var detailSystemImage: String {
        switch self {
        case .pending:
            "clock"
        case .acceptedByCustomer:
            "checkmark.circle"
        case .declinedByCustomer:
            "xmark.circle"
        case .withdrawnByGroomer:
            "arrow.uturn.backward"
        case .expired:
            "hourglass"
        }
    }
}

struct CustomerRequestWizardView: View {
    @Bindable var store: CustomerRequestsStore

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        GroomlySectionHeader(
                            "Request Details",
                            subtitle: "Share the basics so matched groomers can make accurate offers."
                        )

                        petCard
                        serviceCard
                        preferredTimeCard
                        locationCard
                        reviewCard

                        if let errorMessage = store.errorMessage {
                            GroomlyErrorBanner(
                                title: "Check Request Details",
                                message: errorMessage
                            )
                            .accessibilityIdentifier("customer.requests.form-error")
                        }

                        Button {
                            publish()
                        } label: {
                            Label(
                                store.isSubmitting ? "Publishing…" : "Publish Request",
                                systemImage: "paperplane.fill"
                            )
                        }
                        .buttonStyle(GroomlyPrimaryButtonStyle())
                        .disabled(store.isSubmitting || store.pets.isEmpty)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                    .padding(.top, DesignTokens.Spacing.lg)
                    .padding(.bottom, DesignTokens.Spacing.xl)
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .tint(DesignTokens.Colors.customerPrimaryDark)
            .navigationTitle("New Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        store.cancelWizard()
                    }
                    .disabled(store.isSubmitting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Publish") {
                        publish()
                    }
                    .disabled(store.isSubmitting || store.pets.isEmpty)
                    .accessibilityIdentifier("customer.requests.publish")
                }
            }
        }
        .interactiveDismissDisabled(store.isSubmitting)
    }

    private var petCard: some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                WizardCardHeader(
                    title: "Pet",
                    subtitle: "Choose the pet this request is for.",
                    systemImage: "pawprint.fill"
                )

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Picker("Pet", selection: $store.selectedPetID) {
                        ForEach(store.pets) { pet in
                            Text(pet.name)
                                .tag(Optional(pet.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .groomlyFormField()

                    if store.pets.isEmpty {
                        GroomlyStatusChip(
                            "Add a Pet on Home First",
                            systemImage: "pawprint",
                            tone: .warning
                        )
                    }
                }
            }
        }
    }

    private var serviceCard: some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                WizardCardHeader(
                    title: "Service",
                    subtitle: "Describe the grooming help your pet needs.",
                    systemImage: "scissors"
                )

                TextField("Service Type", text: $store.serviceType)
                    .textContentType(.none)
                    .groomlyFormField()

                TextField("Notes", text: $store.serviceNotes, axis: .vertical)
                    .lineLimit(3...6)
                    .groomlyFormField()
            }
        }
    }

    private var preferredTimeCard: some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                WizardCardHeader(
                    title: "Preferred Time",
                    subtitle: "Pick the service window you want groomers to offer around.",
                    systemImage: "calendar"
                )

                DatePicker(
                    "Start",
                    selection: $store.preferredStart,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .groomlyFormField()

                DatePicker(
                    "End",
                    selection: $store.preferredEnd,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .groomlyFormField()
            }
        }
    }

    private var locationCard: some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                WizardCardHeader(
                    title: "Location",
                    subtitle: "Use the city, state, and ZIP where the appointment should happen.",
                    systemImage: "mappin.and.ellipse"
                )

                TextField("City", text: $store.city)
                    .textContentType(.addressCity)
                    .groomlyFormField()

                TextField("State", text: $store.state)
                    .textContentType(.addressState)
                    .groomlyFormField()

                TextField("ZIP Code", text: $store.zipCode)
                    .textContentType(.postalCode)
                    .keyboardType(.numbersAndPunctuation)
                    .groomlyFormField()
            }
        }
    }

    private var reviewCard: some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                WizardCardHeader(
                    title: "Review",
                    subtitle: "Check the request before publishing it to matched groomers.",
                    systemImage: "checklist"
                )

                WizardReviewRow(
                    title: "Pet",
                    value: store.selectedPet?.name ?? "Choose a pet",
                    isMissing: store.selectedPet == nil
                )

                WizardReviewRow(
                    title: "Service",
                    value: serviceSummary,
                    isMissing: serviceSummary == "Required"
                )

                WizardReviewRow(
                    title: "Location",
                    value: reviewLocation,
                    isMissing: reviewLocation == "Required"
                )
            }
        }
    }

    private var serviceSummary: String {
        let service = store.serviceType.trimmingCharacters(in: .whitespacesAndNewlines)
        return service.isEmpty ? "Required" : service
    }

    private var reviewLocation: String {
        let parts = [
            store.city.trimmingCharacters(in: .whitespacesAndNewlines),
            store.state.trimmingCharacters(in: .whitespacesAndNewlines),
            store.zipCode.trimmingCharacters(in: .whitespacesAndNewlines),
        ]
        .filter { !$0.isEmpty }

        return parts.isEmpty ? "Required" : parts.joined(separator: ", ")
    }

    private func publish() {
        Task {
            await store.publish()
        }
    }
}

private struct WizardCardHeader: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.headline)
                .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)
                .frame(width: 36, height: 36)
                .background(DesignTokens.Colors.customerPrimary.opacity(0.14))
                .clipShape(DesignTokens.Shapes.circular)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                Text(subtitle)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct WizardReviewRow: View {
    let title: String
    let value: String
    let isMissing: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
            Text(title)
                .font(DesignTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.textSecondary)

            Spacer(minLength: DesignTokens.Spacing.md)

            if isMissing {
                GroomlyStatusChip(
                    value,
                    systemImage: "exclamationmark.circle",
                    tone: .warning
                )
            } else {
                Text(value)
                    .font(DesignTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}

struct CustomerRequestsStatusView: View {
    let store: CustomerRequestsStore

    var body: some View {
        VStack(spacing: 0) {
            GroomlyNoticeForwarder(message: store.noticeMessage) { message in
                store.clearNotice(ifCurrent: message)
            }

            if hasInlineStatus {
                inlineStatus
            }
        }
    }

    private var inlineStatus: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            if store.isSubmitting {
                GroomlyStatusProgressToast(
                    "Publishing…",
                    tint: DesignTokens.Colors.customerPrimary
                )
            }

            if let errorMessage = store.errorMessage,
               !store.isShowingWizard {
                GroomlyErrorBanner(
                    title: "We Could Not Update Requests",
                    message: errorMessage
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignTokens.Spacing.standard)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .animation(.easeInOut(duration: 0.24), value: hasInlineStatus)
    }

    private var hasInlineStatus: Bool {
        store.isSubmitting
            || (store.errorMessage != nil && !store.isShowingWizard)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        CustomerRequestsView(
            customerID: UUID(),
            petRepository: CustomerRequestsPreviewPetRepository(),
            requestRepository: CustomerRequestsPreviewRequestRepository(),
            bookingRepository: CustomerRequestsPreviewBookingRepository()
        )
    }
}

@MainActor
private final class CustomerRequestsPreviewPetRepository: CustomerPetRepository {
    private let pet = CustomerPet(
        id: UUID(),
        customerID: UUID(),
        name: "Mochi",
        species: "Dog",
        breed: "Corgi",
        size: "Small",
        weightLbs: 22,
        birthday: nil,
        temperament: "Gentle",
        medicalNotes: nil,
        groomingNotes: nil,
        isActive: true
    )

    func pets(customerID: UUID) async throws -> [CustomerPet] {
        [pet]
    }

    func photos(customerID: UUID) async throws -> [CustomerPetPhoto] {
        []
    }

    func createPet(
        customerID: UUID,
        draft: CustomerPetDraft
    ) async throws -> CustomerPet {
        pet
    }

    func updatePet(
        pet: CustomerPet,
        draft: CustomerPetDraft
    ) async throws -> CustomerPet {
        pet
    }

    func softDeletePet(_ pet: CustomerPet) async throws {}

    func uploadPhoto(
        customerID: UUID,
        petID: UUID,
        data: Data,
        contentType: CustomerPetPhotoContentType,
        caption: String?
    ) async throws -> CustomerPetPhoto {
        throw CustomerPetRepositoryError.unavailable
    }

    func deletePhoto(_ photo: CustomerPetPhoto) async throws {}
}

@MainActor
private final class CustomerRequestsPreviewRequestRepository: CustomerRequestRepository {
    func requests(customerID: UUID) async throws -> [CustomerGroomingRequest] {
        [
            CustomerGroomingRequest(
                id: UUID(),
                customerID: customerID,
                petID: UUID(),
                petSnapshot: GroomingRequestPetSnapshot(
                    id: UUID(),
                    name: "Mochi",
                    species: "Dog",
                    breed: "Corgi",
                    size: "Small",
                    weightLbs: 22,
                    birthday: nil,
                    temperament: "Gentle",
                    medicalNotes: nil,
                    groomingNotes: nil,
                    snapshotAt: "2026-06-20T12:00:00Z"
                ),
                photoSnapshot: [],
                serviceType: "Full groom",
                serviceNotes: "Please be gentle around the paws.",
                preferredStart: "2026-06-22T16:00:00Z",
                preferredEnd: "2026-06-22T18:00:00Z",
                city: "Seattle",
                state: "WA",
                zipCode: "98101",
                status: .open,
                expiresAt: "2026-06-22T12:00:00Z",
                createdAt: "2026-06-20T12:00:00Z",
                updatedAt: "2026-06-20T12:00:00Z"
            ),
            CustomerGroomingRequest(
                id: UUID(),
                customerID: customerID,
                petID: UUID(),
                petSnapshot: GroomingRequestPetSnapshot(
                    id: UUID(),
                    name: "Biscuit",
                    species: "Dog",
                    breed: "Pomeranian",
                    size: "Small",
                    weightLbs: 12,
                    birthday: nil,
                    temperament: "Bright",
                    medicalNotes: nil,
                    groomingNotes: nil,
                    snapshotAt: "2026-06-18T12:00:00Z"
                ),
                photoSnapshot: [],
                serviceType: "Bath and trim",
                serviceNotes: nil,
                preferredStart: "2026-06-24T17:00:00Z",
                preferredEnd: "2026-06-24T18:30:00Z",
                city: "Seattle",
                state: "WA",
                zipCode: "98103",
                status: .booked,
                expiresAt: "2026-06-23T12:00:00Z",
                createdAt: "2026-06-18T12:00:00Z",
                updatedAt: "2026-06-21T12:00:00Z"
            ),
        ]
    }

    func offers(
        customerID: UUID,
        requestID: UUID
    ) async throws -> [CustomerOfferReview] {
        [
            CustomerOfferReview(
                offer: GroomerOffer(
                    id: UUID(),
                    requestID: requestID,
                    matchID: UUID(),
                    customerID: customerID,
                    groomerID: UUID(),
                    proposedStart: "2026-06-22T16:30:00Z",
                    proposedEnd: "2026-06-22T18:00:00Z",
                    priceEstimate: 125,
                    message: "I can do a calm full groom.",
                    status: .pending,
                    expiresAt: "2026-06-22T12:00:00Z",
                    withdrawnAt: nil,
                    createdAt: "2026-06-20T13:00:00Z",
                    updatedAt: "2026-06-20T13:00:00Z"
                ),
                groomerProfile: GroomerProfile(
                    userID: UUID(),
                    businessName: "Fresh Paws Grooming",
                    bio: "Low-stress grooming for small dogs.",
                    yearsExperience: 5,
                    baseCity: "Seattle",
                    baseState: "WA",
                    serviceRadiusMiles: 12,
                    ratingAverage: 0,
                    ratingCount: 0,
                    isActive: true,
                    isVerified: false
                )
            ),
        ]
    }

    func createRequest(
        customerID: UUID,
        draft: GroomingRequestDraft
    ) async throws -> GroomingRequestPublishResult {
        GroomingRequestPublishResult(
            requestID: UUID(),
            matchCount: 2
        )
    }

    func cancelRequest(
        requestID: UUID
    ) async throws -> CancelGroomingRequestResult {
        CancelGroomingRequestResult(
            requestID: requestID,
            requestStatus: .cancelled,
            cancelledTimestamp: "2026-06-20T14:00:00Z"
        )
    }
}

@MainActor
private final class CustomerRequestsPreviewBookingRepository: BookingRepository {
    func bookings(
        participantID: UUID,
        role: UserRole
    ) async throws -> [Booking] {
        []
    }

    func acceptOffer(
        offerID: UUID
    ) async throws -> AcceptGroomerOfferResult {
        AcceptGroomerOfferResult(
            bookingID: UUID(),
            conversationID: UUID(),
            requestID: UUID(),
            offerID: offerID,
            bookingStatus: .confirmed,
            offerStatus: .acceptedByCustomer,
            requestStatus: .booked
        )
    }

    func cancelBooking(
        bookingID: UUID
    ) async throws -> CancelBookingResult {
        throw BookingRepositoryError.unavailable
    }

    func completeBooking(
        bookingID: UUID
    ) async throws -> CompleteBookingResult {
        throw BookingRepositoryError.unavailable
    }

    func createReview(
        bookingID: UUID,
        draft: BookingReviewDraft
    ) async throws -> CreateReviewResult {
        throw BookingRepositoryError.unavailable
    }
}
#endif

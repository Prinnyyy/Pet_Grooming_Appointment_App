import Combine
import MapKit
import PhotosUI
import SwiftUI

struct CustomerRequestsView: View {
    @State private var store: CustomerRequestsStore
    @State private var pendingCancelRequest: CustomerGroomingRequest?
    @State private var selectedBookingHandoff: CustomerRequestBookingHandoff?
    @Binding private var focusedRequestID: UUID?
    private let onBookingChatSelected: (Booking) -> Void

    init(
        customerID: UUID,
        petRepository: any CustomerPetRepository,
        requestRepository: any CustomerRequestRepository,
        bookingRepository: any BookingRepository,
        focusedRequestID: Binding<UUID?> = .constant(nil),
        onBookingChatSelected: @escaping (Booking) -> Void = { _ in }
    ) {
        _focusedRequestID = focusedRequestID
        self.onBookingChatSelected = onBookingChatSelected
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
                store: store.bookingDetailStore(for: handoff.booking),
                onOpenChat: onBookingChatSelected
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
                            focusedRequestID: $focusedRequestID,
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
                                request: card.request,
                                handoff: card.handoff,
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
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, DesignTokens.Spacing.screenHorizontal, for: .scrollContent)
                .padding(.horizontal, -DesignTokens.Spacing.screenHorizontal)
                .padding(.vertical, DesignTokens.Spacing.sm)
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
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, DesignTokens.Spacing.screenHorizontal, for: .scrollContent)
            .padding(.horizontal, -DesignTokens.Spacing.screenHorizontal)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .scrollTargetBehavior(.viewAligned)

            if cards.count > 1 {
                Label("Swipe to Review Another Request", systemImage: "arrow.left.and.right")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityIdentifier("customer.requests.summary-carousel-hint")
            }
        }
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .layoutPriority(1)
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
                    title: request.serviceType.title,
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
                    subtitle: request.serviceType.title,
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

typealias CustomerRequestServiceOption = GroomingServiceType

enum CustomerRequestTimeWindowOption: String, CaseIterable, Identifiable {
    case morning
    case afternoon
    case evening
    case detailed

    var id: Self { self }

    var title: String {
        switch self {
        case .morning:
            "Morning"
        case .afternoon:
            "Afternoon"
        case .evening:
            "Evening"
        case .detailed:
            "Detailed Time"
        }
    }

    func range(
        on date: Date,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date)? {
        switch self {
        case .morning:
            Self.range(
                on: date,
                startHour: 6,
                startMinute: 0,
                endHour: 11,
                endMinute: 59,
                calendar: calendar
            )
        case .afternoon:
            Self.range(
                on: date,
                startHour: 12,
                startMinute: 0,
                endHour: 16,
                endMinute: 59,
                calendar: calendar
            )
        case .evening:
            Self.range(
                on: date,
                startHour: 17,
                startMinute: 0,
                endHour: 21,
                endMinute: 0,
                calendar: calendar
            )
        case .detailed:
            nil
        }
    }

    static func flexibleRange(
        on date: Date,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date) {
        range(
            on: date,
            startHour: 0,
            startMinute: 0,
            endHour: 23,
            endMinute: 59,
            calendar: calendar
        )
    }

    private static func range(
        on date: Date,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int,
        calendar: Calendar
    ) -> (start: Date, end: Date) {
        let start = calendar.date(
            bySettingHour: startHour,
            minute: startMinute,
            second: 0,
            of: date
        ) ?? date
        let end = calendar.date(
            bySettingHour: endHour,
            minute: endMinute,
            second: 0,
            of: date
        ) ?? start.addingTimeInterval(60 * 60)
        return (start, end)
    }
}

enum CustomerRequestTravelRange {
    static let minimumMiles = 5
    static let maximumMiles = 100

    static func clampedMiles(_ value: Double) -> Int {
        min(
            maximumMiles,
            max(minimumMiles, Int(value.rounded()))
        )
    }
}

struct CustomerRequestWizardReviewPresentation: Equatable {
    struct Row: Equatable, Identifiable {
        let title: String
        let value: String

        var id: String { title }
    }

    let rows: [Row]

    init(
        pet: String,
        service: String,
        preferredTime: String,
        location: String,
        notes: String
    ) {
        rows = [
            Row(title: "Pet", value: pet),
            Row(title: "Service", value: service),
            Row(title: "Preferred Time", value: preferredTime),
            Row(title: "Location", value: location),
            Row(title: "Notes", value: notes),
        ]
    }
}

struct CustomerRequestWizardView: View {
    @Bindable var store: CustomerRequestsStore

    private let onAddPet: (() -> Void)?
    @State private var currentStep: CustomerRequestWizardStep = .pet
    @State private var selectedServiceOption: CustomerRequestServiceOption?
    @State private var selectedDate: Date
    @State private var selectedTimeWindow: CustomerRequestTimeWindowOption = .afternoon
    @State private var isFlexibleWithTime = false
    @State private var selectedRequestPhotoItem: PhotosPickerItem?
    @State private var invalidFields: Set<CustomerRequestWizardValidationField> = []

    init(
        store: CustomerRequestsStore,
        onAddPet: (() -> Void)? = nil
    ) {
        self.store = store
        self.onAddPet = onAddPet
        _selectedDate = State(initialValue: store.preferredStart)
        _selectedServiceOption = State(
            initialValue: store.serviceType
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                        CustomerRequestWizardHeader(
                            currentStep: currentStep,
                            backAction: back
                        )

                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                            Text(currentStep.headline)
                                .font(DesignTokens.Typography.largeTitle)
                                .foregroundStyle(DesignTokens.Colors.textPrimary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.72)
                                .fixedSize(horizontal: false, vertical: true)

                            if let subtitle = currentStep.subtitle {
                                Text(subtitle)
                                    .font(DesignTokens.Typography.body)
                                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        stepContent

                        if let errorMessage = store.errorMessage {
                            GroomlyErrorBanner(
                                title: "Check Request Details",
                                message: errorMessage
                            )
                            .accessibilityIdentifier("customer.requests.form-error")
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                    .padding(.top, DesignTokens.Spacing.lg)
                    .padding(.bottom, 128)
                }
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .safeAreaInset(edge: .bottom) {
                CustomerRequestWizardBottomBar(
                    currentStep: currentStep,
                    isSubmitting: store.isSubmitting,
                    canContinue: canContinue,
                    backAction: back,
                    continueAction: continueForward
                )
            }
            .tint(DesignTokens.Colors.customerPrimaryDark)
            .toolbar(.hidden, for: .navigationBar)
        }
        .interactiveDismissDisabled(store.isSubmitting)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            applyInitialDefaults()
        }
        .onChange(of: selectedRequestPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await addPendingRequestPhoto(newItem)
            }
        }
        .accessibilityIdentifier("customer.requests.wizard")
    }

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .pet:
            petStep
        case .service:
            serviceStep
        case .time:
            timeStep
        case .details:
            detailsStep
        case .review:
            reviewStep
        }
    }

    private var petStep: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            ForEach(store.pets) { pet in
                CustomerRequestPetChoiceCard(
                    pet: pet,
                    isSelected: store.selectedPetID == pet.id,
                    isInvalid: invalidFields.contains(.pet)
                ) {
                    store.selectedPetID = pet.id
                    clearInvalidField(.pet)
                }
            }

            CustomerRequestAddPetButton {
                addPet()
            }
            .disabled(onAddPet == nil)

            if store.pets.isEmpty {
                GroomlyStatusChip(
                    "Add a Pet Before Continuing",
                    systemImage: "pawprint",
                    tone: .warning
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var serviceStep: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ForEach(CustomerRequestServiceOption.allCases) { option in
                CustomerRequestServiceOptionCard(
                    option: option,
                    isSelected: selectedServiceOption == option
                ) {
                    selectedServiceOption = option
                    store.serviceType = option
                    clearInvalidField(.service)
                }
            }
        }
    }

    private var timeStep: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            CustomerRequestDateStrip(
                selectedDate: selectedDate
            ) { date in
                selectedDate = date
                clearInvalidField(.timeWindow)
                applySelectedTimeWindow()
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Text("Time Window")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                CustomerRequestTimeWindowGrid(
                    selectedTimeWindow: selectedTimeWindow,
                    isFlexibleWithTime: isFlexibleWithTime,
                    isInvalid: invalidFields.contains(.timeWindow)
                ) { option in
                    selectedTimeWindow = option
                    isFlexibleWithTime = false
                    clearInvalidField(.timeWindow)
                    applySelectedTimeWindow()
                }

                if selectedTimeWindow == .detailed && !isFlexibleWithTime {
                    CustomerRequestDetailedTimeFields(
                        preferredStart: $store.preferredStart,
                        preferredEnd: $store.preferredEnd,
                        isInvalid: invalidFields.contains(.timeWindow)
                    )
                    .onChange(of: store.preferredStart) { _, _ in
                        clearInvalidField(.timeWindow)
                    }
                    .onChange(of: store.preferredEnd) { _, _ in
                        clearInvalidField(.timeWindow)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                CustomerRequestFlexibleTimeToggle(
                    isOn: Binding(
                        get: { isFlexibleWithTime },
                        set: { newValue in
                            isFlexibleWithTime = newValue
                            clearInvalidField(.timeWindow)
                            applySelectedTimeWindow()
                        }
                    )
                )
            }

            locationSection
        }
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Location")
                .font(DesignTokens.Typography.headline)
                .foregroundStyle(DesignTokens.Colors.textPrimary)

            ForEach(CustomerRequestLocationMode.allCases) { mode in
                CustomerRequestLocationModeCard(
                    mode: mode,
                    isSelected: store.locationMode == mode
                ) {
                    store.locationMode = mode
                }
            }

            CustomerRequestAddressFields(
                streetAddress: $store.streetAddress,
                city: $store.city,
                stateCode: $store.stateCode,
                zipCode: $store.zipCode,
                locationMode: store.locationMode,
                travelRangeMiles: $store.travelRadiusMiles,
                invalidFields: invalidFields,
                clearInvalidField: clearInvalidField
            )
        }
    }

    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Text("Notes To Groomers")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)

                TextField("Share coat goals, sensitivities, or handling notes.", text: $store.serviceNotes, axis: .vertical)
                    .lineLimit(5...8)
                    .groomlyFormField(isInvalid: invalidFields.contains(.notes))
                    .onTapGesture {
                        clearInvalidField(.notes)
                    }
                    .onChange(of: store.serviceNotes) { _, _ in
                        clearInvalidField(.notes)
                    }
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Text("Photos")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                HStack(spacing: DesignTokens.Spacing.md) {
                    let pendingPhotoCount = store.pendingRequestPhotos.count

                    if let pet = store.selectedPet {
                        CustomerRequestPhotoPreviewTile(pet: pet)
                    }

                    PhotosPicker(
                        selection: $selectedRequestPhotoItem,
                        matching: .images
                    ) {
                        CustomerRequestAddPhotoTile(
                            photoCount: pendingPhotoCount
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            GroomlyCard(padding: DesignTokens.Spacing.xl) {
                VStack(spacing: 0) {
                    ForEach(reviewPresentation.rows) { row in
                        CustomerRequestWizardReviewRow(row: row)

                        if row.id != reviewPresentation.rows.last?.id {
                            Divider()
                                .overlay(DesignTokens.Colors.borderSoft)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Label("How Matching Works", systemImage: "info.circle")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)

                Text("Your request will be shown to groomers who fit your pet, service, and preferred time. Groomers can send offers or suggest another time.")
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.Colors.customerPrimary.opacity(0.12))
            .clipShape(
                RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.card,
                    style: .continuous
                )
            )

            Label(
                "Your contact details stay hidden until you accept an offer.",
                systemImage: "lock"
            )
            .font(DesignTokens.Typography.body)
            .foregroundStyle(DesignTokens.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var canContinue: Bool {
        !store.isSubmitting && store.validateWizardStep(currentStep).isValid
    }

    private var reviewPresentation: CustomerRequestWizardReviewPresentation {
        CustomerRequestWizardReviewPresentation(
            pet: reviewPetSummary,
            service: store.serviceType.title,
            preferredTime: reviewPreferredTimeSummary,
            location: reviewLocationSummary,
            notes: notesSummary
        )
    }

    private var reviewPetSummary: String {
        guard let pet = store.selectedPet else {
            return "Choose A Pet"
        }

        let breed = pet.displayBreed?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let breed, !breed.isEmpty {
            return "\(pet.name) · \(breed)"
        }

        return "\(pet.name) · \(pet.displaySpecies)"
    }

    private var reviewPreferredTimeSummary: String {
        let day = CustomerRequestWizardDateFormatting.daySummary(selectedDate)
        if isFlexibleWithTime {
            return "\(day) · Flexible"
        }

        if selectedTimeWindow == .detailed {
            return CustomerRequestWizardDateFormatting.compactRange(
                from: store.preferredStart,
                to: store.preferredEnd
            )
        }

        return "\(day) · \(selectedTimeWindow.title)"
    }

    private var reviewLocationSummary: String {
        let location = [
            store.streetAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            store.city.trimmingCharacters(in: .whitespacesAndNewlines),
            store.stateCode?.rawValue ?? "",
            store.zipCode.trimmingCharacters(in: .whitespacesAndNewlines),
        ]
        .filter { !$0.isEmpty }
        .joined(separator: ", ")

        let prefix = store.locationMode == .groomerComesToCustomer ? "Mobile" : "Visit"
        return location.isEmpty ? "\(prefix) · Required" : "\(prefix) · \(location)"
    }

    private var notesSummary: String {
        let notes = store.serviceNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        return notes.isEmpty ? "No Notes Added" : notes
    }

    private func back() {
        guard !store.isSubmitting else { return }

        if let previous = currentStep.previous {
            currentStep = previous
        } else {
            store.cancelWizard()
        }
    }

    private func continueForward() {
        let validation = store.validateWizardStep(currentStep)
        guard validation.isValid else {
            invalidFields = validation.fields
            store.errorMessage = validation.message
            return
        }

        invalidFields = []
        store.errorMessage = nil

        if currentStep == .review {
            publish()
        } else if let next = currentStep.next {
            currentStep = next
        }
    }

    private func publish() {
        Task {
            await store.publish()
        }
    }

    private func addPet() {
        guard let onAddPet else { return }
        onAddPet()
    }

    private func addPendingRequestPhoto(_ item: PhotosPickerItem) async {
        defer { selectedRequestPhotoItem = nil }

        guard let data = try? await item.loadTransferable(type: Data.self) else {
            store.errorMessage = "We could not read that photo."
            return
        }

        let contentType = item.supportedContentTypes
            .lazy
            .compactMap(GroomingRequestPhotoContentType.init(uniformType:))
            .first ?? .jpeg

        store.addPendingPhoto(
            data: data,
            contentType: contentType
        )
    }

    private func applyInitialDefaults() {
        selectedServiceOption = store.serviceType
        applySelectedTimeWindow()
    }

    private func applySelectedTimeWindow() {
        if isFlexibleWithTime {
            let range = CustomerRequestTimeWindowOption.flexibleRange(on: selectedDate)
            store.preferredStart = range.start
            store.preferredEnd = range.end
            return
        }

        guard let range = selectedTimeWindow.range(on: selectedDate) else {
            store.preferredStart = CustomerRequestWizardDateFormatting.date(
                matchingTimeOf: store.preferredStart,
                on: selectedDate
            )
            store.preferredEnd = CustomerRequestWizardDateFormatting.date(
                matchingTimeOf: store.preferredEnd,
                on: selectedDate
            )
            return
        }

        store.preferredStart = range.start
        store.preferredEnd = range.end
    }

    private func clearInvalidField(_ field: CustomerRequestWizardValidationField) {
        guard invalidFields.remove(field) != nil else { return }

        if invalidFields.isEmpty,
           store.errorMessage == CustomerRequestWizardStepValidation.requiredFieldsMessage {
            store.errorMessage = nil
        }
    }
}

typealias CustomerRequestLocationMode = GroomingLocationMode

private enum CustomerRequestWizardDateFormatting {
    static func daySummary(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE d"
        return formatter.string(from: date)
    }

    static func compactRange(from start: Date, to end: Date) -> String {
        "\(compactDateTime(start)) - \(compactDateTime(end))"
    }

    static func compactDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }

    static func date(
        matchingTimeOf source: Date,
        on selectedDate: Date,
        calendar: Calendar = .current
    ) -> Date {
        let time = calendar.dateComponents([.hour, .minute], from: source)
        return calendar.date(
            bySettingHour: time.hour ?? 12,
            minute: time.minute ?? 0,
            second: 0,
            of: selectedDate
        ) ?? selectedDate
    }
}

private struct CustomerRequestWizardHeader: View {
    let currentStep: CustomerRequestWizardStep
    let backAction: () -> Void
    private let progressLayout = CustomerRequestWizardProgressLayout(
        backButtonWidth: 54,
        horizontalSpacing: DesignTokens.Spacing.md
    )

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(spacing: progressLayout.horizontalSpacing) {
                Button(action: backAction) {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .frame(
                            width: progressLayout.backButtonWidth,
                            height: progressLayout.backButtonWidth
                        )
                        .background(DesignTokens.Colors.surface)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: DesignTokens.CornerRadius.input,
                                style: .continuous
                            )
                        )
                        .overlay {
                            RoundedRectangle(
                                cornerRadius: DesignTokens.CornerRadius.input,
                                style: .continuous
                            )
                            .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Grooming Request")
                        .font(DesignTokens.Typography.body.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textTertiary)

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(DesignTokens.Colors.border.opacity(0.8))

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            DesignTokens.Colors.customerPrimary,
                                            DesignTokens.Colors.customerPrimary.opacity(0.6),
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: proxy.size.width * currentStep.progress)
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        ForEach(CustomerRequestWizardStep.allCases) { step in
                            Text(step.title)
                                .font(DesignTokens.Typography.caption.weight(.bold))
                                .foregroundStyle(labelColor(for: step))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.top, DesignTokens.Spacing.xs)
                }
            }
        }
    }

    private func labelColor(for step: CustomerRequestWizardStep) -> Color {
        if step == currentStep {
            return DesignTokens.Colors.customerPrimaryDark
        }

        if step.rawValue < currentStep.rawValue {
            return DesignTokens.Colors.textPrimary
        }

        return DesignTokens.Colors.textSecondary
    }
}

struct CustomerRequestWizardProgressLayout: Equatable {
    let backButtonWidth: CGFloat
    let horizontalSpacing: CGFloat

    var progressTrackLeadingOffset: CGFloat {
        backButtonWidth + horizontalSpacing
    }

    var shouldLabelRowShareProgressTrackWidth: Bool {
        true
    }
}

private struct CustomerRequestWizardBottomBar: View {
    let currentStep: CustomerRequestWizardStep
    let isSubmitting: Bool
    let canContinue: Bool
    let backAction: () -> Void
    let continueAction: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Button("Back", action: backAction)
                .buttonStyle(GroomlySecondaryButtonStyle(accent: .neutral))
                .frame(width: 132)
                .disabled(isSubmitting)

            Button(action: continueAction) {
                Text(primaryTitle)
            }
            .buttonStyle(
                CustomerRequestWizardPrimaryButtonStyle(
                    isVisuallyEnabled: canContinue && !isSubmitting
                )
            )
            .disabled(isSubmitting)
            .accessibilityIdentifier(
                currentStep == .review
                    ? "customer.requests.publish"
                    : "customer.requests.wizard.continue"
            )
        }
        .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
        .padding(.top, DesignTokens.Spacing.md)
        .padding(.bottom, DesignTokens.Spacing.md)
        .background(
            LinearGradient(
                colors: [
                    DesignTokens.Colors.background.opacity(0.2),
                    DesignTokens.Colors.background,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private var primaryTitle: String {
        if isSubmitting {
            return "Publishing..."
        }

        return currentStep == .review ? "Publish Request" : "Continue"
    }
}

private struct CustomerRequestWizardPrimaryButtonStyle: ButtonStyle {
    let isVisuallyEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignTokens.Typography.body.weight(.semibold))
            .foregroundStyle(
                isVisuallyEnabled
                    ? DesignTokens.Colors.surface
                    : DesignTokens.Colors.textTertiary
            )
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.md)
            .background {
                RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.button,
                    style: .continuous
                )
                .fill(backgroundGradient(isPressed: configuration.isPressed))
            }
            .groomlyShadow(
                DesignTokens.Shadows.primaryAction,
                isVisible: isVisuallyEnabled
            )
            .scaleEffect(configuration.isPressed && isVisuallyEnabled ? 0.98 : 1)
            .opacity(isVisuallyEnabled ? 1 : 0.72)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isVisuallyEnabled)
    }

    private func backgroundGradient(isPressed: Bool) -> LinearGradient {
        let colors: [Color]

        if isVisuallyEnabled {
            colors = isPressed
                ? [
                    DesignTokens.Colors.customerPrimaryDark,
                    DesignTokens.Colors.customerPrimary,
                ]
                : [
                    DesignTokens.Colors.customerPrimary,
                    DesignTokens.Colors.customerPrimaryDark,
                ]
        } else {
            colors = [
                DesignTokens.Colors.borderSoft,
                DesignTokens.Colors.borderSoft,
            ]
        }

        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct CustomerRequestPetChoiceCard: View {
    let pet: CustomerPet
    let isSelected: Bool
    let isInvalid: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.lg) {
                CustomerRequestWizardPetAvatar(pet: pet, size: 84)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(pet.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(subtitle)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                }

                Spacer(minLength: DesignTokens.Spacing.sm)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.surface)
                        .frame(width: 42, height: 42)
                        .background(DesignTokens.Colors.customerPrimary)
                        .clipShape(Circle())
                }
            }
            .padding(DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .leading)
            .background(DesignTokens.Colors.surface)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.card,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.card,
                    style: .continuous
                )
                .stroke(
                    borderColor,
                    lineWidth: isSelected || isInvalid ? 2 : 1
                )
            }
            .shadow(
                color: isInvalid ? DesignTokens.Colors.error.opacity(0.26) : .clear,
                radius: isInvalid ? 11 : 0,
                x: 0,
                y: 0
            )
            .groomlyShadow(DesignTokens.Shadows.smallCard)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("customer.requests.wizard.pet-card")
    }

    private var borderColor: Color {
        if isInvalid {
            return DesignTokens.Colors.error
        }

        return isSelected
            ? DesignTokens.Colors.customerPrimary
            : DesignTokens.Colors.border
    }

    private var subtitle: String {
        let breed = pet.displayBreed?.trimmingCharacters(in: .whitespacesAndNewlines)
        let breedText = breed?.isEmpty == false ? breed ?? pet.displaySpecies : pet.displaySpecies
        if let weight = pet.weightLbs {
            return "\(breedText) · \(weight.formatted(.number.precision(.fractionLength(0...1)))) lbs"
        }

        return breedText
    }
}

private struct CustomerRequestAddPetButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))

                Text("Add A New Pet")
                    .font(DesignTokens.Typography.body.weight(.bold))
            }
            .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)
            .frame(maxWidth: .infinity, minHeight: 78)
            .background(DesignTokens.Colors.surface.opacity(0.5))
            .clipShape(
                RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.card,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.card,
                    style: .continuous
                )
                .stroke(
                    DesignTokens.Colors.border,
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("customer.requests.wizard.add-pet")
    }
}

private struct CustomerRequestServiceOptionCard: View {
    let option: CustomerRequestServiceOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.lg) {
                Image(systemName: "scissors")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)
                    .frame(width: 64, height: 64)
                    .background(DesignTokens.Colors.customerPrimary.opacity(0.12))
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: DesignTokens.CornerRadius.input,
                            style: .continuous
                        )
                    )

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(option.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(option.subtitle)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: DesignTokens.Spacing.xs)
            }
            .padding(DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
            .background(DesignTokens.Colors.surface)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.card,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.card,
                    style: .continuous
                )
                .stroke(
                    isSelected ? DesignTokens.Colors.customerPrimary : DesignTokens.Colors.border,
                    lineWidth: isSelected ? 2 : 1
                )
            }
            .groomlyShadow(DesignTokens.Shadows.smallCard)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("customer.requests.wizard.service-card")
    }
}

private struct CustomerRequestDateStrip: View {
    let selectedDate: Date
    let onSelect: (Date) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: DesignTokens.Spacing.md) {
                ForEach(dateOptions, id: \.self) { date in
                    Button {
                        onSelect(date)
                    } label: {
                        VStack(spacing: DesignTokens.Spacing.xs) {
                            Text(dayName(date))
                                .font(DesignTokens.Typography.caption.weight(.bold))

                            Text(dayNumber(date))
                                .font(.title2.weight(.bold))
                        }
                        .foregroundStyle(isSelected(date) ? DesignTokens.Colors.surface : DesignTokens.Colors.textPrimary)
                        .frame(width: 76, height: 92)
                        .background(
                            RoundedRectangle(
                                cornerRadius: DesignTokens.CornerRadius.button,
                                style: .continuous
                            )
                            .fill(isSelected(date) ? DesignTokens.Colors.customerPrimary : DesignTokens.Colors.surface)
                        )
                        .overlay {
                            RoundedRectangle(
                                cornerRadius: DesignTokens.CornerRadius.button,
                                style: .continuous
                            )
                            .stroke(
                                isSelected(date) ? DesignTokens.Colors.customerPrimary : DesignTokens.Colors.border,
                                lineWidth: 1.2
                            )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, DesignTokens.Spacing.xs)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -DesignTokens.Spacing.screenHorizontal)
        .contentMargins(.horizontal, DesignTokens.Spacing.screenHorizontal, for: .scrollContent)
    }

    private var dateOptions: [Date] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: start)
        }
    }

    private func isSelected(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: selectedDate)
    }

    private func dayName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func dayNumber(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}

private struct CustomerRequestTimeWindowGrid: View {
    let selectedTimeWindow: CustomerRequestTimeWindowOption
    let isFlexibleWithTime: Bool
    let isInvalid: Bool
    let action: (CustomerRequestTimeWindowOption) -> Void

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: DesignTokens.Spacing.md),
                GridItem(.flexible(), spacing: DesignTokens.Spacing.md),
            ],
            alignment: .leading,
            spacing: DesignTokens.Spacing.md
        ) {
            ForEach(CustomerRequestTimeWindowOption.allCases) { option in
                Button {
                    action(option)
                } label: {
                    Text(option.title)
                        .font(DesignTokens.Typography.body.weight(.bold))
                        .foregroundStyle(
                            selectedTimeWindow == option && !isFlexibleWithTime
                                ? DesignTokens.Colors.surface
                                : DesignTokens.Colors.textSecondary
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .background(
                            Capsule()
                                .fill(
                                    selectedTimeWindow == option && !isFlexibleWithTime
                                        ? DesignTokens.Colors.customerPrimary
                                        : DesignTokens.Colors.surface
                                )
                        )
                        .overlay {
                            Capsule()
                                .stroke(
                                    borderColor(for: option),
                                    lineWidth: isInvalid ? 1.6 : 1
                                )
                        }
                        .shadow(
                            color: isInvalid && selectedTimeWindow == option
                                ? DesignTokens.Colors.error.opacity(0.22)
                                : .clear,
                            radius: isInvalid && selectedTimeWindow == option ? 8 : 0,
                            x: 0,
                            y: 0
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .opacity(isFlexibleWithTime ? 0.56 : 1)
    }

    private func borderColor(for option: CustomerRequestTimeWindowOption) -> Color {
        if isInvalid, selectedTimeWindow == option, !isFlexibleWithTime {
            return DesignTokens.Colors.error
        }

        return DesignTokens.Colors.border
    }
}

private struct CustomerRequestDetailedTimeFields: View {
    @Binding var preferredStart: Date
    @Binding var preferredEnd: Date
    let isInvalid: Bool

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            DatePicker(
                "Start Time",
                selection: $preferredStart,
                displayedComponents: [.hourAndMinute]
            )
            .font(DesignTokens.Typography.body.weight(.semibold))
            .groomlyFormField(isInvalid: isInvalid)

            DatePicker(
                "End Time",
                selection: $preferredEnd,
                displayedComponents: [.hourAndMinute]
            )
            .font(DesignTokens.Typography.body.weight(.semibold))
            .groomlyFormField(isInvalid: isInvalid)
        }
    }
}

private struct CustomerRequestFlexibleTimeToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("I'm Flexible With Time")
                    .font(DesignTokens.Typography.body.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                Text("Let groomers suggest nearby times")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
        }
        .tint(DesignTokens.Colors.customerPrimary)
        .padding(DesignTokens.Spacing.lg)
        .background(DesignTokens.Colors.surface)
        .clipShape(
            RoundedRectangle(
                cornerRadius: DesignTokens.CornerRadius.card,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: DesignTokens.CornerRadius.card,
                style: .continuous
            )
            .stroke(DesignTokens.Colors.border, lineWidth: 1)
        }
    }
}

private struct CustomerRequestLocationModeCard: View {
    let mode: CustomerRequestLocationMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Text(mode.icon)
                    .font(.title2)
                    .frame(width: 44)

                Text(mode.customerTitle)
                    .font(DesignTokens.Typography.body.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.surface)
                        .frame(width: 34, height: 34)
                        .background(DesignTokens.Colors.customerPrimary)
                        .clipShape(Circle())
                }
            }
            .padding(DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(DesignTokens.Colors.surface)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.card,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.card,
                    style: .continuous
                )
                .stroke(
                    isSelected ? DesignTokens.Colors.customerPrimary : DesignTokens.Colors.border,
                    lineWidth: isSelected ? 2 : 1
                )
            }
        }
        .buttonStyle(.plain)
    }
}

private struct CustomerRequestAddressFields: View {
    @Binding var streetAddress: String
    @Binding var city: String
    @Binding var stateCode: USStateCode?
    @Binding var zipCode: String
    let locationMode: CustomerRequestLocationMode
    @Binding var travelRangeMiles: Int
    let invalidFields: Set<CustomerRequestWizardValidationField>
    let clearInvalidField: (CustomerRequestWizardValidationField) -> Void
    @StateObject private var addressSearch = CustomerRequestAddressSearch()

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            TextField("Street Address", text: $streetAddress)
                .textContentType(.streetAddressLine1)
                .groomlyFormField(isInvalid: invalidFields.contains(.streetAddress))
                .onTapGesture {
                    clearInvalidField(.streetAddress)
                }
                .onChange(of: streetAddress) { _, newValue in
                    clearInvalidField(.streetAddress)
                    addressSearch.update(
                        street: newValue,
                        city: city,
                        stateCode: stateCode
                    )
                }

            if !addressSearch.suggestions.isEmpty {
                VStack(spacing: DesignTokens.Spacing.xs) {
                    ForEach(addressSearch.suggestions.prefix(4)) { suggestion in
                        Button {
                            applyAddressSuggestion(suggestion)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.title)
                                    .font(DesignTokens.Typography.caption.weight(.semibold))
                                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                                    .lineLimit(1)

                                Text(suggestion.subtitle)
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, DesignTokens.Spacing.md)
                            .padding(.vertical, DesignTokens.Spacing.sm)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(DesignTokens.Colors.surface)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: DesignTokens.CornerRadius.input,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: DesignTokens.CornerRadius.input,
                        style: .continuous
                    )
                    .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
                }
            }

            HStack(spacing: DesignTokens.Spacing.md) {
                TextField("City", text: $city)
                    .textContentType(.addressCity)
                    .groomlyFormField(isInvalid: invalidFields.contains(.city))
                    .onTapGesture {
                        clearInvalidField(.city)
                    }
                    .onChange(of: city) { _, _ in
                        clearInvalidField(.city)
                    }

                Menu {
                    ForEach(USStateCode.allCases) { state in
                        Button(state.rawValue) {
                            stateCode = state
                            clearInvalidField(.state)
                        }
                    }
                } label: {
                    HStack {
                        Text(stateCode?.rawValue ?? "State")
                            .foregroundStyle(
                                stateCode == nil
                                    ? DesignTokens.Colors.textSecondary
                                    : DesignTokens.Colors.textPrimary
                            )

                        Spacer(minLength: DesignTokens.Spacing.xs)

                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                    .groomlyFormField(isInvalid: invalidFields.contains(.state))
                }
                    .onTapGesture {
                        clearInvalidField(.state)
                    }
                    .frame(width: 92)
            }

            TextField("ZIP Code", text: $zipCode)
                .textContentType(.postalCode)
                .keyboardType(.numbersAndPunctuation)
                .groomlyFormField(isInvalid: invalidFields.contains(.zipCode))
                .onTapGesture {
                    clearInvalidField(.zipCode)
                }
                .onChange(of: zipCode) { _, _ in
                    clearInvalidField(.zipCode)
                }

            if locationMode == .customerComesToGroomer {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    HStack {
                        Text("Travel Range")
                            .font(DesignTokens.Typography.body.weight(.bold))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        Spacer()

                        Text("\(CustomerRequestTravelRange.clampedMiles(Double(travelRangeMiles))) mi")
                            .font(DesignTokens.Typography.body.weight(.bold))
                            .foregroundStyle(DesignTokens.Colors.customerPrimaryDark)
                    }

                    Slider(
                        value: Binding(
                            get: { Double(travelRangeMiles) },
                            set: { travelRangeMiles = CustomerRequestTravelRange.clampedMiles($0) }
                        ),
                        in: Double(CustomerRequestTravelRange.minimumMiles)...Double(CustomerRequestTravelRange.maximumMiles),
                        step: 1
                    )
                    .tint(DesignTokens.Colors.customerPrimary)

                    Text("Choose how far you can travel to a groomer's location.")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                .padding(DesignTokens.Spacing.lg)
                .background(DesignTokens.Colors.surface)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: DesignTokens.CornerRadius.card,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: DesignTokens.CornerRadius.card,
                        style: .continuous
                    )
                    .stroke(DesignTokens.Colors.border, lineWidth: 1)
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func applyAddressSuggestion(_ suggestion: CustomerRequestAddressSuggestion) {
        Task {
            guard let address = await addressSearch.resolve(suggestion) else { return }
            streetAddress = address.streetAddress
            city = address.city
            stateCode = address.stateCode
            zipCode = address.zipCode
            clearInvalidField(.streetAddress)
            clearInvalidField(.city)
            clearInvalidField(.state)
            clearInvalidField(.zipCode)
        }
    }
}

struct CustomerRequestAddressSuggestion: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
}

struct CustomerRequestAddressCompletion<Completion> {
    let title: String
    let subtitle: String
    let completion: Completion
}

enum CustomerRequestAddressSuggestionBuilder {
    static func build<Completion>(
        from completions: [CustomerRequestAddressCompletion<Completion>],
        limit: Int = 5
    ) -> (
        suggestions: [CustomerRequestAddressSuggestion],
        completionsByID: [String: Completion]
    ) {
        var seenKeys: Set<String> = []
        var suggestions: [CustomerRequestAddressSuggestion] = []
        var completionsByID: [String: Completion] = [:]

        for completion in completions where suggestions.count < limit {
            let title = completion.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let subtitle = completion.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }

            let key = "\(title)|\(subtitle)"
            guard seenKeys.insert(key).inserted else { continue }

            let suggestion = CustomerRequestAddressSuggestion(
                id: key,
                title: title,
                subtitle: subtitle
            )
            suggestions.append(suggestion)
            completionsByID[suggestion.id] = completion.completion
        }

        return (suggestions, completionsByID)
    }
}

private struct CustomerRequestResolvedAddress {
    let streetAddress: String
    let city: String
    let stateCode: USStateCode
    let zipCode: String
}

private final class CustomerRequestAddressSearch:
    NSObject,
    ObservableObject,
    MKLocalSearchCompleterDelegate
{
    @Published private(set) var suggestions: [CustomerRequestAddressSuggestion] = []

    private let completer = MKLocalSearchCompleter()
    private var completionsByID: [String: MKLocalSearchCompletion] = [:]
    private var lastQueryFragment = ""

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func update(
        street: String,
        city: String,
        stateCode: USStateCode?
    ) {
        let trimmedStreet = street.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedStreet.count >= 3 else {
            suggestions = []
            completionsByID = [:]
            updateQueryFragmentIfNeeded("")
            return
        }

        let query = [
            trimmedStreet,
            city.trimmingCharacters(in: .whitespacesAndNewlines),
            stateCode?.rawValue ?? "",
        ]
        .filter { !$0.isEmpty }
        .joined(separator: ", ")

        updateQueryFragmentIfNeeded(query)
    }

    private func updateQueryFragmentIfNeeded(_ query: String) {
        guard query != lastQueryFragment else { return }
        lastQueryFragment = query
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let result = CustomerRequestAddressSuggestionBuilder.build(
            from: completer.results.map { completion in
                CustomerRequestAddressCompletion(
                    title: completion.title,
                    subtitle: completion.subtitle,
                    completion: completion
                )
            }
        )

        DispatchQueue.main.async {
            self.suggestions = result.suggestions
            self.completionsByID = result.completionsByID
        }
    }

    func completer(
        _ completer: MKLocalSearchCompleter,
        didFailWithError error: any Error
    ) {
        DispatchQueue.main.async {
            self.suggestions = []
            self.completionsByID = [:]
        }
    }

    func resolve(
        _ suggestion: CustomerRequestAddressSuggestion
    ) async -> CustomerRequestResolvedAddress? {
        guard let completion = completionsByID[suggestion.id] else { return nil }

        let request = MKLocalSearch.Request(completion: completion)
        guard
            let mapItem = try? await MKLocalSearch(request: request).start().mapItems.first,
            let state = mapItem.placemark.administrativeArea,
            let stateCode = USStateCode(rawValue: state.uppercased()),
            let zipCode = mapItem.placemark.postalCode?.trimmingCharacters(in: .whitespacesAndNewlines),
            !zipCode.isEmpty
        else {
            return nil
        }

        let streetAddress = [
            mapItem.placemark.subThoroughfare,
            mapItem.placemark.thoroughfare,
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " ")

        guard !streetAddress.isEmpty else { return nil }

        return CustomerRequestResolvedAddress(
            streetAddress: streetAddress,
            city: mapItem.placemark.locality ?? "",
            stateCode: stateCode,
            zipCode: zipCode
        )
    }
}

private struct CustomerRequestPhotoPreviewTile: View {
    let pet: CustomerPet

    var body: some View {
        CustomerRequestWizardPetAvatar(pet: pet, size: 112)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.input,
                    style: .continuous
                )
            )
    }
}

private struct CustomerRequestAddPhotoTile: View {
    let photoCount: Int

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: photoCount > 0 ? "checkmark.circle.fill" : "camera")
                .font(.title2.weight(.semibold))
                .foregroundStyle(
                    photoCount > 0
                        ? DesignTokens.Colors.customerPrimaryDark
                        : DesignTokens.Colors.textTertiary
                )

            Text(photoCount > 0 ? "\(photoCount) Added" : "Add")
                .font(DesignTokens.Typography.caption.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: 112, height: 112)
        .background(DesignTokens.Colors.surface.opacity(0.4))
        .clipShape(
            RoundedRectangle(
                cornerRadius: DesignTokens.CornerRadius.input,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: DesignTokens.CornerRadius.input,
                style: .continuous
            )
            .stroke(
                DesignTokens.Colors.border,
                style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
            )
        }
    }
}

private struct CustomerRequestWizardPetAvatar: View {
    let pet: CustomerPet
    let size: CGFloat

    var body: some View {
        Text(avatar)
            .font(.system(size: size * 0.5))
            .frame(width: size, height: size)
            .background(avatarBackground)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.input,
                    style: .continuous
                )
            )
            .accessibilityHidden(true)
    }

    private var avatar: String {
        let searchText = "\(pet.displayBreed ?? "") \(pet.displaySpecies)".lowercased()
        if searchText.contains("poodle") {
            return "🐩"
        } else if searchText.contains("cat") {
            return "🐱"
        } else if searchText.contains("bird") {
            return "🐦"
        } else if searchText.contains("rabbit") {
            return "🐰"
        } else if searchText.contains("dog") {
            return "🐶"
        }

        return "🐾"
    }

    private var avatarBackground: Color {
        let palette = [
            DesignTokens.Colors.groomerAccent.opacity(0.22),
            DesignTokens.Colors.customerPrimary.opacity(0.22),
            DesignTokens.Colors.warning.opacity(0.18),
        ]
        return palette[abs(pet.name.hashValue) % palette.count]
    }
}

private struct CustomerRequestWizardReviewRow: View {
    let row: CustomerRequestWizardReviewPresentation.Row

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.lg) {
            Text(row.title)
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .frame(maxWidth: 132, alignment: .leading)

            Text(row.value)
                .font(DesignTokens.Typography.body.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, DesignTokens.Spacing.md)
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
        size: "M",
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
                    size: "M",
                    weightLbs: 22,
                    birthday: nil,
                    temperament: "Gentle",
                    medicalNotes: nil,
                    groomingNotes: nil,
                    snapshotAt: "2026-06-20T12:00:00Z"
                ),
                photoSnapshot: [],
                serviceType: .fullGroom,
                serviceNotes: "Please be gentle around the paws.",
                preferredStart: "2026-06-22T16:00:00Z",
                preferredEnd: "2026-06-22T18:00:00Z",
                locationMode: .groomerComesToCustomer,
                streetAddress: "123 Pine Street",
                city: "Seattle",
                state: "WA",
                zipCode: "98101",
                travelRadiusMiles: nil,
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
                    size: "S",
                    weightLbs: 12,
                    birthday: nil,
                    temperament: "Playful",
                    medicalNotes: nil,
                    groomingNotes: nil,
                    snapshotAt: "2026-06-18T12:00:00Z"
                ),
                photoSnapshot: [],
                serviceType: .bathAndBrush,
                serviceNotes: nil,
                preferredStart: "2026-06-24T17:00:00Z",
                preferredEnd: "2026-06-24T18:30:00Z",
                locationMode: .customerComesToGroomer,
                streetAddress: "456 Cedar Avenue",
                city: "Seattle",
                state: "WA",
                zipCode: "98103",
                travelRadiusMiles: 15,
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
                    serviceLocationMode: .groomerComesToCustomer,
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

    func uploadRequestPhoto(
        customerID: UUID,
        requestID: UUID,
        data: Data,
        contentType: GroomingRequestPhotoContentType,
        caption: String?
    ) async throws -> GroomingRequestPhoto {
        GroomingRequestPhoto(
            id: UUID(),
            requestID: requestID,
            customerID: customerID,
            storageBucket: "request-photos",
            storagePath: GroomingRequestPhotoPath.make(
                customerID: customerID,
                requestID: requestID,
                contentType: contentType
            ),
            caption: caption,
            sortOrder: 0,
            createdAt: "2026-06-20T14:00:00Z"
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

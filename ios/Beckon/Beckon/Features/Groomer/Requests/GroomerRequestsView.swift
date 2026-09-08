import SwiftUI
import UIKit

nonisolated enum GroomerOfferFocusTarget: String, CaseIterable, Hashable {
    case duration = "groomer.offers.duration.container"
    case price = "groomer.offers.price.container"
    case message = "groomer.offers.message.container"
}

nonisolated enum GroomerOfferInputFocusPolicy {
    static func target(
        afterTapping tappedTarget: GroomerOfferFocusTarget,
        current: GroomerOfferFocusTarget?
    ) -> GroomerOfferFocusTarget {
        current == tappedTarget ? current ?? tappedTarget : tappedTarget
    }
}

struct GroomerRequestsView: View {
    @Binding private var route: GroomerRequestsRoute
    @State private var requestsStore: GroomerRequestsStore
    @State private var offersStore: GroomerOffersStore
    @State private var focusedMatchID: UUID?
    @State private var focusedOfferID: UUID?

    init(
        groomerID: UUID,
        repository: any GroomerRequestRepository,
        profileRepository: (any GroomerProfileRepository)? = nil,
        route: Binding<GroomerRequestsRoute>,
        debugRecorder: AppDebugEventRecorder? = nil
    ) {
        _route = route
        _requestsStore = State(
            initialValue: GroomerRequestsStore(
                groomerID: groomerID,
                repository: repository,
                profileRepository: profileRepository,
                debugRecorder: debugRecorder
            )
        )
        _offersStore = State(
            initialValue: GroomerOffersStore(
                groomerID: groomerID,
                repository: repository
            )
        )
    }

    var body: some View {
        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    GroomerRequestsWorkspaceHeader(
                        selectedSegment: selectedSegment,
                        matchCount: requestsStore.matchedRequests.count,
                        offerCount: offersStore.offers.count
                    )

                    selectedContent
                }
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.vertical, DesignTokens.Spacing.lg)
            }
        }
        .navigationTitle("Requests")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: refresh) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isRefreshing)
            }
        }
        .background {
            GroomerRequestsStatusView(store: requestsStore)
            GroomerOffersStatusView(store: offersStore)
        }
        .foregroundRefreshable {
            await refreshAll()
        }
        .onChange(of: route) { _, _ in
            applyRouteIfAvailable()
        }
        .onChange(of: route.segment) { _, segment in
            guard segment == .offers else { return }
            Task {
                await offersStore.load()
                applyRouteIfAvailable()
            }
        }
        .navigationDestination(item: $focusedMatchID) { matchID in
            GroomerRequestDetailView(
                matchID: matchID,
                store: requestsStore
            )
        }
        .navigationDestination(item: $focusedOfferID) { offerID in
            if let item = offersStore.offers.first(where: { $0.id == offerID }) {
                GroomerOfferDetailView(item: item)
            }
        }
        .accessibilityIdentifier("groomer.requests.list")
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch route.segment {
        case .matches:
            GroomerMatchesContentView(store: requestsStore)
        case .offers:
            GroomerOffersContentView(store: offersStore)
        }
    }

    private var selectedSegment: Binding<GroomerRequestsSegment> {
        Binding(
            get: { route.segment },
            set: { segment in
                route = segment == .matches ? .matches : .offers
            }
        )
    }

    private var isRefreshing: Bool {
        requestsStore.isBusy || offersStore.isLoading || offersStore.isLoadingMore
    }

    private func refresh() {
        Task {
            await refreshAll()
        }
    }

    private func refreshAll() async {
        await requestsStore.load()
        await offersStore.load()
        applyRouteIfAvailable()
    }

    private func applyRouteIfAvailable() {
        if let requestID = route.requestID,
           let matchedRequest = requestsStore.matchedRequests.first(
               where: { $0.request.id == requestID }
           ) {
            focusedMatchID = matchedRequest.id
            route = .matches
        }

        if let offerID = route.offerID,
           offersStore.offers.contains(where: { $0.id == offerID }) {
            focusedOfferID = offerID
            route = .offers
        }
    }
}

private struct GroomerRequestsWorkspaceHeader: View {
    @Binding var selectedSegment: GroomerRequestsSegment
    let matchCount: Int
    let offerCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            Text("Review new matches and track the offers you have sent.")
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Colors.textSecondary)

            HStack(spacing: DesignTokens.Spacing.xs) {
                ForEach(GroomerRequestsSegment.allCases) { segment in
                    Button {
                        selectedSegment = segment
                    } label: {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Text(segment.title)
                            Text("\(segment.count(matches: matchCount, offers: offerCount))")
                                .font(DesignTokens.Typography.caption)
                                .monospacedDigit()
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    selectedSegment == segment
                                        ? DesignTokens.Colors.groomerAccent.opacity(0.2)
                                        : DesignTokens.Colors.borderSoft
                                )
                                .clipShape(Capsule())
                        }
                        .font(DesignTokens.Typography.body.weight(.semibold))
                        .foregroundStyle(
                            selectedSegment == segment
                                ? DesignTokens.Colors.textPrimary
                                : DesignTokens.Colors.textSecondary
                        )
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            selectedSegment == segment
                                ? DesignTokens.Colors.surface
                                : Color.clear
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: DesignTokens.CornerRadius.input,
                                style: .continuous
                            )
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(segment.accessibilityIdentifier)
                    .accessibilityAddTraits(
                        selectedSegment == segment ? .isSelected : []
                    )
                }
            }
            .padding(DesignTokens.Spacing.xs)
            .background(DesignTokens.Colors.borderSoft.opacity(0.8))
            .clipShape(
                RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.button,
                    style: .continuous
                )
            )
        }
    }
}

private struct GroomerMatchesContentView: View {
    let store: GroomerRequestsStore

    @ViewBuilder
    var body: some View {
        if store.isLoading, store.matchedRequests.isEmpty {
            BeckonLoadingView(
                title: "Loading Matched Requests…",
                message: "We are checking active customer requests that match your services.",
                accent: .groomer
            )
            .accessibilityIdentifier("groomer.requests.loading")
        } else {
            GroomerWorkspaceSection(title: "Matched requests") {
                if store.matchedRequests.isEmpty {
                    if let errorMessage = store.errorMessage {
                        requestError(message: errorMessage)
                    } else {
                        requestEmptyState
                    }
                } else {
                    GroomerGroupedSurface {
                        VStack(spacing: 0) {
                            ForEach(Array(store.matchedRequests.enumerated()), id: \.element.id) { index, matchedRequest in
                                if index > 0 {
                                    GroomerWorkspaceDivider(leadingInset: 96)
                                }

                                NavigationLink {
                                    GroomerRequestDetailView(
                                        matchID: matchedRequest.id,
                                        store: store
                                    )
                                } label: {
                                    GroomerRequestSummaryRow(
                                        matchedRequest: matchedRequest,
                                        photoData: firstPhotoData(for: matchedRequest)
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier(
                                    AppTestOpsAccessibility.identifier(
                                        prefix: "groomer.requests.row",
                                        serviceNotes: matchedRequest.request.serviceNotes
                                    ) ?? "groomer.requests.row"
                                )
                                .accessibilityValue(
                                    AppTestOpsAccessibility.requestReference(
                                        matchedRequest.request.id
                                    )
                                )
                            }
                        }
                    }

                    if let errorMessage = store.errorMessage {
                        BeckonErrorBanner(
                            title: "More Requests Unavailable",
                            message: errorMessage
                        )
                        .accessibilityIdentifier("groomer.requests.load-more-error")
                    }

                    if store.canLoadMore || store.isLoadingMore {
                        BeckonLoadMoreButton(
                            isLoading: store.isLoadingMore,
                            accent: .groomer,
                            accessibilityIdentifier: "groomer.requests.load-more"
                        ) {
                            await store.loadNextPage()
                        }
                    }
                }
            }
        }
    }

    private func firstPhotoData(
        for matchedRequest: GroomerMatchedRequest
    ) -> Data? {
        guard let photo = store.requestPhotos(for: matchedRequest).first else {
            return nil
        }
        return store.requestPhotoData(for: photo)
    }

    private func requestError(message: String) -> some View {
        BeckonErrorBanner(
            title: "Requests Unavailable",
            message: message
        ) {
            Button {
                Task { await store.load() }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(BeckonSecondaryButtonStyle(accent: .groomer))
            .disabled(store.isBusy)
        }
        .accessibilityIdentifier("groomer.requests.error")
    }

    private var requestEmptyState: some View {
        BeckonEmptyState(
            title: "No Matched Requests",
            message: "New active customer requests will appear here when they match your profile and services.",
            systemImage: "tray",
            accent: .groomer
        ) {
            Button {
                Task { await store.load() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(BeckonSecondaryButtonStyle(accent: .groomer))
            .disabled(store.isBusy)
        }
        .accessibilityIdentifier("groomer.requests.empty")
    }
}

private struct GroomerRequestSummaryRow: View {
    let matchedRequest: GroomerMatchedRequest
    let photoData: Data?

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            BeckonModuleImage(data: photoData) {
                ZStack {
                    DesignTokens.Colors.groomerAccent.opacity(0.12)
                    Image(systemName: "pawprint.fill")
                        .font(.title2)
                        .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                }
            }
            .frame(width: 64, height: 72)
            .clipShape(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
            )

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                    Text(matchedRequest.request.petSnapshot.name)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: DesignTokens.Spacing.xs)

                    BeckonStatusChip(
                        statusSummary,
                        systemImage: statusSystemImage,
                        tone: statusTone
                    )
                }

                Text("\(matchedRequest.request.petSnapshot.breed ?? "Unknown breed") · \(matchedRequest.request.serviceType.title)")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .lineLimit(1)

                Text("\(preferredDate) · \(compactLocation)")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .lineLimit(1)

                Text(fitSummary)
                    .font(DesignTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(DesignTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.textTertiary)
                .frame(height: 72)
                .accessibilityHidden(true)
        }
        .padding(DesignTokens.Spacing.md)
        .contentShape(Rectangle())
    }

    private var statusSummary: String {
        if let offer = matchedRequest.offer {
            return "Offer \(offer.evaluatedStatusTitle.lowercased())"
        }

        return matchedRequest.matchSummary
    }

    private var statusTone: BeckonStatusChip.Tone {
        if matchedRequest.offer?.status == .pending {
            return .warning
        }

        return matchedRequest.request.status.isOpenForOffers ? .groomer : .neutral
    }

    private var statusSystemImage: String {
        if matchedRequest.offer?.status == .pending {
            return "paperplane.fill"
        }

        return matchedRequest.request.status.isOpenForOffers ? "sparkles" : "checkmark"
    }

    private var preferredDate: String {
        GroomingRequestDateFormatting.displayString(
            from: matchedRequest.request.preferredStart,
            serviceTimeZoneIdentifier: matchedRequest.request.preferenceTimeZoneIdentifier
        )
    }

    private var compactLocation: String {
        "\(matchedRequest.request.city), \(matchedRequest.request.state)"
    }

    private var fitSummary: String {
        matchedRequest.fitEvidencePresentation?.listSummary
            ?? matchedRequest.matchSummary
    }
}

struct GroomerRequestDetailView: View {
    let matchID: UUID
    let store: GroomerRequestsStore

    @State private var didInitializeOfferForm = false
    @State private var activeInitializationID: UUID?
    @State private var serviceTimeZone: TimeZone?
    @State private var selectedOccurrence: Date?
    @State private var timeZoneError: String?
    @State private var activeTimeZoneLoadID: UUID?
    @State private var proposedStart = Date().addingTimeInterval(24 * 60 * 60)
    @State private var durationMinutesText = ""
    @State private var priceEstimateText = ""
    @State private var message = ""
    @FocusState private var focusedTarget: GroomerOfferFocusTarget?

    var body: some View {
        if let matchedRequest = store.matchedRequest(withID: matchID) {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                            detailHero(for: matchedRequest)
                            matchCard(for: matchedRequest)
                            requestCard(for: matchedRequest)
                            petSnapshotCard(for: matchedRequest)
                            requestPhotosCard(for: matchedRequest)
                            scheduleLocationCard(for: matchedRequest)
                            offerSection(for: matchedRequest)
                                .disabled(!didInitializeOfferForm)
                            actionsCard(for: matchedRequest)
                        }
                        .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                        .padding(.top, DesignTokens.Spacing.lg)
                        .padding(
                            .bottom,
                            matchedRequest.canCreateOffer
                                ? DesignTokens.Layout.stationaryActionContentClearance
                                : DesignTokens.Layout.pageBottomInset
                        )
                    }
                    .beckonKeyboardAvoidance(
                        focusedTarget: focusedTarget?.rawValue,
                        using: scrollProxy,
                        additionallyPreventsPresentationDismissal: store.isSubmittingOffer
                    )
                }
            }
            .navigationTitle(matchedRequest.request.petSnapshot.name)
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("groomer.requests.detail")
            .task(id: matchedRequest.request.id) {
                await initializeOfferFormIfNeeded(for: matchedRequest)
            }
            .onDisappear {
                activeInitializationID = nil
                activeTimeZoneLoadID = nil
            }
            .beckonStationaryPageAction {
                if matchedRequest.canCreateOffer {
                    submitOfferBar(for: matchedRequest)
                }
            }
        } else {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                BeckonEmptyState(
                    title: "Request Unavailable",
                    message: "Refresh matched requests and try again.",
                    systemImage: "tray",
                    accent: .groomer
                )
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            }
            .navigationTitle("Request")
        }
    }

    private func detailHero(
        for matchedRequest: GroomerMatchedRequest
    ) -> some View {
        BeckonCard {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                BeckonModuleImage(
                    data: firstPhotoData(for: matchedRequest)
                ) {
                    ZStack {
                        DesignTokens.Colors.groomerAccent.opacity(0.12)
                        Image(systemName: "pawprint.fill")
                            .font(.title)
                            .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                    }
                }
                .frame(width: 80, height: 92)
                .clipShape(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                )

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(matchedRequest.request.petSnapshot.name)
                            .font(DesignTokens.Typography.title)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        Text(matchedRequest.request.serviceType.title)
                            .font(DesignTokens.Typography.body)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    BeckonStatusChip(
                        matchedRequest.request.status.title,
                        systemImage: matchedRequest.request.status.groomerSystemImage,
                        tone: matchedRequest.request.status.groomerTone
                    )
                }

                    Text("\(matchedRequest.request.petSnapshot.species) · \(matchedRequest.request.petSnapshot.breed ?? "Unknown breed")")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .lineLimit(2)

                    Text("\(matchedRequest.request.city), \(matchedRequest.request.state)")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func matchCard(
        for matchedRequest: GroomerMatchedRequest
    ) -> some View {
        DetailShellCard(title: "Fit Evidence", subtitle: matchedRequest.matchSummary) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DetailMetadataRow(
                    title: "Status",
                    value: matchedRequest.match.status.title,
                    systemImage: matchedRequest.match.status.groomerSystemImage
                )

                if let fitEvidence = matchedRequest.fitEvidencePresentation {
                    GroomerFitEvidenceBlock(
                        presentation: fitEvidence,
                        isCompact: false
                    )
                }
            }
        }
    }

    private func requestCard(
        for matchedRequest: GroomerMatchedRequest
    ) -> some View {
        DetailShellCard(title: "Service") {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    DetailMetadataRow(
                        title: "Service",
                        value: matchedRequest.request.serviceType.title,
                        systemImage: "scissors"
                    )

                    Spacer(minLength: DesignTokens.Spacing.sm)

                    BeckonStatusChip(
                        matchedRequest.request.status.title,
                        systemImage: matchedRequest.request.status.groomerSystemImage,
                        tone: matchedRequest.request.status.groomerTone
                    )
                }

                if let notes = matchedRequest.request.serviceNotes {
                    Text(notes)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func petSnapshotCard(
        for matchedRequest: GroomerMatchedRequest
    ) -> some View {
        DetailShellCard(title: "Pet Snapshot") {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DetailMetadataRow(
                    title: "Pet",
                    value: matchedRequest.request.petSnapshot.name,
                    systemImage: "pawprint.fill"
                )
                DetailMetadataRow(
                    title: "Species",
                    value: matchedRequest.request.petSnapshot.species,
                    systemImage: "tag"
                )
                if let breed = matchedRequest.request.petSnapshot.breed {
                    DetailMetadataRow(
                        title: "Breed",
                        value: breed,
                        systemImage: "sparkles"
                    )
                }
                if let size = matchedRequest.request.petSnapshot.size {
                    DetailMetadataRow(
                        title: "Size",
                        value: size,
                        systemImage: "ruler"
                    )
                }
                DetailMetadataRow(
                    title: "Photos",
                    value: "\(matchedRequest.request.photoSnapshot.count)",
                    systemImage: "photo.on.rectangle"
                )
            }
        }
    }

    private func scheduleLocationCard(
        for matchedRequest: GroomerMatchedRequest
    ) -> some View {
        DetailShellCard(
            title: BeckonGroomingLocationModePresentation.detailSectionTitle
        ) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DetailMetadataRow(
                    title: "Start",
                    value: GroomingRequestDateFormatting.displayString(
                        from: matchedRequest.request.preferredStart,
                        serviceTimeZoneIdentifier: matchedRequest.request.preferenceTimeZoneIdentifier
                    ),
                    systemImage: "calendar"
                )
                DetailMetadataRow(
                    title: "End",
                    value: GroomingRequestDateFormatting.displayString(
                        from: matchedRequest.request.preferredEnd,
                        serviceTimeZoneIdentifier: matchedRequest.request.preferenceTimeZoneIdentifier
                    ),
                    systemImage: "clock"
                )
                Divider()
                    .overlay(DesignTokens.Colors.divider)
                DetailMetadataRow(
                    title: "City",
                    value: matchedRequest.request.city,
                    systemImage: "mappin.and.ellipse"
                )
                DetailMetadataRow(
                    title: "State",
                    value: matchedRequest.request.state,
                    systemImage: "map"
                )
                DetailMetadataRow(
                    title: "ZIP",
                    value: matchedRequest.request.zipCode,
                    systemImage: "number"
                )
                DetailMetadataRow(
                    title: BeckonGroomingLocationModePresentation.detailFieldTitle,
                    value: BeckonGroomingLocationModePresentation(
                        mode: matchedRequest.request.locationMode,
                        perspective: .groomer
                    ).title,
                    systemImage: "location.fill"
                )
                DetailMetadataRow(
                    title: "Street",
                    value: matchedRequest.request.streetAddress,
                    systemImage: "house.fill"
                )
                if matchedRequest.request.locationMode == .customerComesToGroomer,
                   let travelRadiusMiles = matchedRequest.request.travelRadiusMiles {
                    DetailMetadataRow(
                        title: "Travel Radius",
                        value: "\(travelRadiusMiles) miles",
                        systemImage: "point.topleft.down.curvedto.point.bottomright.up"
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func requestPhotosCard(
        for matchedRequest: GroomerMatchedRequest
    ) -> some View {
        let photos = store.requestPhotos(for: matchedRequest)
        if !photos.isEmpty {
            DetailShellCard(
                title: "Request Photos",
                subtitle: "\(photos.count) photo\(photos.count == 1 ? "" : "s") attached to this request."
            ) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    ForEach(photos) { photo in
                        GroomerRequestPhotoRow(
                            photo: photo,
                            data: store.requestPhotoData(for: photo)
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func offerSection(for matchedRequest: GroomerMatchedRequest) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            BeckonSectionHeader(
                "Offer",
                subtitle: offerSectionSubtitle(for: matchedRequest)
            )

            if let offer = matchedRequest.offer {
                offerStatusCard(offer, for: matchedRequest)
            }

            if matchedRequest.canCreateOffer {
                offerFormCard(for: matchedRequest)
            } else if matchedRequest.offer?.status != .pending {
                offerUnavailableCard(isChecking: matchedRequest.match.eligibilityEvaluation?.state == "pending")
            }
        }
    }

    private func offerSectionSubtitle(
        for matchedRequest: GroomerMatchedRequest
    ) -> String {
        if let offer = matchedRequest.offer {
            return offer.status.groomerDescription
        }

        if matchedRequest.canCreateOffer {
            return "Suggest a time, price, and short note for this request."
        }

        if matchedRequest.match.eligibilityEvaluation?.state == "pending" {
            return "Service and availability are being checked."
        }

        return "This request is not accepting a new offer from this account."
    }

    private func offerStatusCard(
        _ offer: GroomerOffer,
        for matchedRequest: GroomerMatchedRequest
    ) -> some View {
        BeckonCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Your Offer")
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        Text(offer.status == .pending
                            ? (offer.quoteEvaluation?.summary ?? offer.status.groomerDescription)
                            : offer.status.groomerDescription)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    BeckonStatusChip(
                        offer.evaluatedStatusTitle,
                        systemImage: offer.status.groomerSystemImage,
                        tone: offer.status.groomerTone
                    )
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    DetailMetadataRow(
                        title: "Price",
                        value: offer.priceSummary,
                        systemImage: "dollarsign.circle"
                    )
                    DetailMetadataRow(
                        title: "Proposed Start",
                        value: GroomingRequestDateFormatting.displayString(
                            from: offer.proposedStart,
                            serviceTimeZoneIdentifier: offer.serviceTimeZoneIdentifier
                        ),
                        systemImage: "calendar"
                    )
                    DetailMetadataRow(
                        title: "Proposed End",
                        value: GroomingRequestDateFormatting.displayString(
                            from: offer.proposedEnd,
                            serviceTimeZoneIdentifier: offer.serviceTimeZoneIdentifier
                        ),
                        systemImage: "clock"
                    )
                }

                if let message = offer.message {
                    OfferMessageBlock(message: message)
                }

                if offer.status == .pending {
                    if offer.requiresTimingUpdate {
                        BeckonErrorBanner(
                            title: "Updated Offer Required",
                            message: "This offer is missing confirmed timing details. Withdraw it and send a new offer."
                        )
                    }
                    Button(role: .destructive) {
                        Task {
                            await store.withdrawOffer(for: matchedRequest)
                        }
                    } label: {
                        Label("Withdraw Offer", systemImage: "arrow.uturn.backward.circle")
                    }
                    .buttonStyle(BeckonSecondaryButtonStyle(accent: .neutral))
                    .disabled(store.isWithdrawingOffer)
                    .accessibilityIdentifier("groomer.offers.withdraw")
                }
            }
        }
    }

    private func offerFormCard(
        for matchedRequest: GroomerMatchedRequest
    ) -> some View {
        BeckonCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Make an Offer")
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        Text(CustomerRequestMatchingCopy.groomerOfferGuidance)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    BeckonStatusChip(
                        "Draft",
                        systemImage: "pencil",
                        tone: .groomer
                    )
                }

                if let serviceTimeZone {
                    OfferDatePickerField(
                        title: "Proposed Start",
                        selection: Binding(get: { proposedStart }, set: {
                            proposedStart = $0
                            selectedOccurrence = nil
                        })
                    )
                    .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                    .environment(\.calendar, Calendar(identifier: .gregorian))
                    .accessibilityIdentifier("groomer.offers.start-input")
                    DetailMetadataRow(title: "Service Time Zone", value: serviceTimeZone.identifier,
                        systemImage: "globe")
                    .accessibilityIdentifier("groomer.offers.service-time-zone")
                    if case let .ambiguous(first, last) = proposedStartResolution {
                        Picker("Start occurrence", selection: $selectedOccurrence) {
                            Text("Choose occurrence").tag(Optional<Date>.none)
                            ForEach([first, last], id: \.self) { date in
                                Text(date.formatted(Date.FormatStyle(timeZone: serviceTimeZone)
                                    .hour().minute().timeZone(.iso8601(.short))))
                                    .tag(Optional(date))
                            }
                        }
                        .accessibilityIdentifier("groomer.offers.start-occurrence")
                    }
                    if proposedStartResolution == .nonexistent {
                        Text("This local time does not exist. Choose another start time.")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .accessibilityIdentifier("groomer.offers.nonexistent-start")
                    }
                } else if isLoadingTimeZone || !didInitializeOfferForm {
                    ProgressView("Loading service time zone")
                        .accessibilityIdentifier("groomer.offers.time-zone-loading")
                } else if matchedRequest.request.locationMode == .groomerComesToCustomer {
                    Text("This request has no confirmed service time zone. The customer needs to publish a new request with a confirmed address.")
                        .font(DesignTokens.Typography.caption)
                        .accessibilityIdentifier("groomer.offers.request-time-zone-missing")
                } else {
                    Text(timeZoneError ?? "Confirm the service address time zone before making an offer.")
                        .font(DesignTokens.Typography.caption)
                    Button("Retry", systemImage: "arrow.clockwise") {
                        Task { await loadServiceTimeZone(for: matchedRequest) }
                    }
                    .disabled(isInitializingOfferForm)
                    .accessibilityIdentifier("groomer.offers.time-zone-retry")
                }

                GroomerOfferTextField(
                    title: "Duration (minutes)",
                    text: $durationMinutesText,
                    keyboardType: .numberPad,
                    focusTarget: .duration,
                    focusedTarget: $focusedTarget
                )

                if let proposedEnd, let serviceTimeZone {
                    DetailMetadataRow(
                        title: "Proposed End",
                        value: GroomingRequestDateFormatting.displayString(
                            from: GroomingRequestDateFormatting.serverString(from: proposedEnd),
                            serviceTimeZoneIdentifier: serviceTimeZone.identifier),
                        systemImage: "clock"
                    )
                    .accessibilityIdentifier("groomer.offers.proposed-end")
                }

                GroomerOfferTextField(
                    title: "Price Estimate",
                    text: $priceEstimateText,
                    keyboardType: .decimalPad,
                    focusTarget: .price,
                    focusedTarget: $focusedTarget
                )

                GroomerOfferTextField(
                    title: "Message",
                    text: $message,
                    isMultiline: true,
                    focusTarget: .message,
                    focusedTarget: $focusedTarget
                )

            }
        }
    }

    private func submitOfferBar(
        for matchedRequest: GroomerMatchedRequest
    ) -> some View {
        Button {
            guard let proposedEnd, let start = resolvedProposedStart else { return }
            Task {
                await store.submitOffer(
                    for: matchedRequest,
                    proposedStart: start,
                    proposedEnd: proposedEnd,
                    priceEstimateText: priceEstimateText,
                    message: message
                )
            }
        } label: {
            if store.isSubmittingOffer {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    ProgressView()
                        .tint(DesignTokens.Colors.surface)
                    Text("Submitting Offer…")
                }
            } else {
                Label("Submit Offer", systemImage: "paperplane")
            }
        }
        .buttonStyle(BeckonPrimaryButtonStyle(accent: .groomer))
        .disabled(store.isSubmittingOffer || !didInitializeOfferForm || proposedEnd == nil || serviceTimeZone == nil)
        .accessibilityIdentifier("groomer.offers.submit")
        .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
        .padding(.top, DesignTokens.Spacing.sm)
        .padding(.bottom, DesignTokens.Spacing.sm)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            GroomerWorkspaceDivider()
        }
    }

    private func firstPhotoData(
        for matchedRequest: GroomerMatchedRequest
    ) -> Data? {
        guard let photo = store.requestPhotos(for: matchedRequest).first else {
            return nil
        }
        return store.requestPhotoData(for: photo)
    }

    private func offerUnavailableCard(isChecking: Bool) -> some View {
        BeckonCard {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                Image(systemName: isChecking ? "clock.arrow.circlepath" : "lock.fill")
                    .font(DesignTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .frame(
                        width: DesignTokens.Spacing.xl,
                        height: DesignTokens.Spacing.xl
                    )
                    .background(DesignTokens.Colors.borderSoft.opacity(0.55))
                    .clipShape(DesignTokens.Shapes.circular)
                    .accessibilityHidden(true)

                Text(isChecking ? "Service and availability are being checked."
                    : "This request can no longer receive a new offer from this account.")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func actionsCard(
        for matchedRequest: GroomerMatchedRequest
    ) -> some View {
        DetailShellCard(title: "Actions") {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Button(role: .destructive) {
                    Task {
                        await store.dismiss(matchedRequest)
                    }
                } label: {
                    Label("Dismiss Match", systemImage: "xmark.circle")
                }
                .buttonStyle(BeckonSecondaryButtonStyle(accent: .neutral))
                .disabled(
                    store.isDismissing || !matchedRequest.match.status.isDismissible
                )
                .accessibilityIdentifier("groomer.requests.dismiss")

                if !matchedRequest.match.status.isDismissible {
                    Text("Matches with an active or completed offer cannot be dismissed.")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var proposedEnd: Date? {
        guard let start = resolvedProposedStart else { return nil }
        return GroomerRequestsStore.proposedEnd(start: start, durationText: durationMinutesText)
    }

    private var proposedStartResolution: GroomingWallTimeResolution? {
        guard let serviceTimeZone else { return nil }
        return try? GroomingServiceTiming.resolveWallInput(proposedStart,
            timeZoneIdentifier: serviceTimeZone.identifier)
    }

    private var resolvedProposedStart: Date? {
        switch proposedStartResolution {
        case let .unique(date): return date
        case let .ambiguous(first, last):
            return selectedOccurrence == first || selectedOccurrence == last ? selectedOccurrence : nil
        case .nonexistent, nil: return nil
        }
    }

    private var isInitializingOfferForm: Bool { activeInitializationID != nil }
    private var isLoadingTimeZone: Bool { activeTimeZoneLoadID != nil }

    private func loadServiceTimeZone(for matchedRequest: GroomerMatchedRequest) async {
        let loadID = UUID()
        activeTimeZoneLoadID = loadID
        timeZoneError = nil
        defer {
            if activeTimeZoneLoadID == loadID { activeTimeZoneLoadID = nil }
        }
        do {
            let zone = try await store.serviceTimeZoneForOffer(for: matchedRequest.request)
            guard !Task.isCancelled, activeTimeZoneLoadID == loadID else { return }
            if serviceTimeZone == nil, let zone {
                proposedStart = try GroomingServiceTiming.wallInput(for: proposedStart,
                    timeZoneIdentifier: zone.identifier)
            }
            serviceTimeZone = zone
        } catch {
            guard !Task.isCancelled, activeTimeZoneLoadID == loadID else { return }
            timeZoneError = "Service time zone could not be loaded. Try again."
        }
    }

    private func initializeOfferFormIfNeeded(
        for matchedRequest: GroomerMatchedRequest
    ) async {
        guard !didInitializeOfferForm else { return }
        let initializationID = UUID()
        activeInitializationID = initializationID
        defer {
            if activeInitializationID == initializationID { activeInitializationID = nil }
        }
        guard matchedRequest.canCreateOffer else {
            didInitializeOfferForm = true
            return
        }
        let service = await store.serviceForOffer(for: matchedRequest.request)
        guard !Task.isCancelled, activeInitializationID == initializationID else { return }
        let range = GroomerRequestsStore.defaultOfferRange(
            for: matchedRequest.request,
            durationMinutes: service?.durationMinutes
        )
        serviceTimeZone = nil
        selectedOccurrence = nil
        proposedStart = range?.start ?? max(
            GroomingRequestDateFormatting.parsedDate(from: matchedRequest.request.preferredStart) ?? Date(),
            Date().addingTimeInterval(GroomerRequestsStore.minimumProposedStartLeadTime)
        )
        await loadServiceTimeZone(for: matchedRequest)
        guard !Task.isCancelled, activeInitializationID == initializationID else { return }
        if durationMinutesText.isEmpty, let service {
            durationMinutesText = String(service.durationMinutes)
        }
        if priceEstimateText.isEmpty, let service {
            priceEstimateText = String(service.basePrice)
        }
        didInitializeOfferForm = true
    }
}

private struct GroomerFitEvidenceBlock: View {
    let presentation: GroomerMatchFitPresentation
    let isCompact: Bool

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            Image(systemName: "sparkles")
                .font(DesignTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                .frame(
                    width: DesignTokens.Spacing.xl,
                    height: DesignTokens.Spacing.xl
                )
                .background(DesignTokens.Colors.groomerAccent.opacity(0.14))
                .clipShape(DesignTokens.Shapes.circular)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                    Text("Fit Evidence")
                        .font(DesignTokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(DesignTokens.Colors.groomerAccentDark)

                    if let scoreText = presentation.scoreText {
                        Text(scoreText)
                            .font(DesignTokens.Typography.caption.weight(.semibold))
                            .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                            .padding(.horizontal, DesignTokens.Spacing.sm)
                            .padding(.vertical, 3)
                            .background(DesignTokens.Colors.groomerAccent.opacity(0.14))
                            .clipShape(Capsule())
                    }
                }

                Text(presentation.listSummary)
                    .font(isCompact ? DesignTokens.Typography.caption : DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .lineLimit(isCompact ? 2 : nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignTokens.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
                .fill(DesignTokens.Colors.groomerAccent.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
                .stroke(DesignTokens.Colors.groomerAccent.opacity(0.24), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct DetailShellCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            BeckonSectionHeader(title, subtitle: subtitle)

            BeckonCard {
                content
            }
        }
    }
}

private struct DetailMetadataRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                .frame(
                    width: DesignTokens.Spacing.xl,
                    height: DesignTokens.Spacing.xl
                )
                .background(DesignTokens.Colors.groomerAccent.opacity(0.14))
                .clipShape(DesignTokens.Shapes.circular)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)

                Text(value)
                    .font(DesignTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct GroomerRequestPhotoRow: View {
    let photo: GroomingRequestPhoto
    let data: Data?

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            GroomerRequestPhotoThumbnail(data: data)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(photo.caption ?? photo.fileName)
                    .font(DesignTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .lineLimit(1)

                if photo.caption != nil {
                    Text(photo.fileName)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct GroomerRequestPhotoThumbnail: View {
    let data: Data?

    var body: some View {
        BeckonModuleImage(data: data) {
            Image(systemName: "photo")
                .font(DesignTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DesignTokens.Colors.groomerAccent.opacity(0.14))
        }
        .frame(width: 58, height: 58)
        .clipShape(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .accessibilityHidden(true)
    }
}

private struct OfferDatePickerField: View {
    let title: String
    @Binding var selection: Date

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)

            DatePicker(
                title,
                selection: $selection,
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .tint(DesignTokens.Colors.groomerAccentDark)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
                .fill(DesignTokens.Colors.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
                .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct GroomerOfferTextField: View {
    let title: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var isMultiline = false
    let focusTarget: GroomerOfferFocusTarget
    @FocusState.Binding var focusedTarget: GroomerOfferFocusTarget?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)

            TextField(
                title,
                text: $text,
                axis: isMultiline ? .vertical : .horizontal
            )
            .focused($focusedTarget, equals: focusTarget)
            .keyboardType(keyboardType)
            .lineLimit(isMultiline ? 3...6 : 1...1)
            .beckonFormField()
            .tint(DesignTokens.Colors.groomerAccentDark)
            .accessibilityIdentifier(accessibilityIdentifier)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                focusedTarget = GroomerOfferInputFocusPolicy.target(
                    afterTapping: focusTarget,
                    current: focusedTarget
                )
            }
        )
        .beckonKeyboardFocusTarget(focusTarget.rawValue)
    }

    private var accessibilityIdentifier: String {
        switch focusTarget {
        case .duration:
            "groomer.offers.duration"
        case .price:
            "groomer.offers.price"
        case .message:
            "groomer.offers.message"
        }
    }
}

private struct OfferMessageBlock: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Label("Message", systemImage: "text.bubble")
                .font(DesignTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.groomerAccentDark)

            Text(message)
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.Spacing.lg)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
                .fill(DesignTokens.Colors.borderSoft.opacity(0.35))
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
                .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private extension GroomingRequestStatus {
    var groomerTone: BeckonStatusChip.Tone {
        isOpenForOffers ? .groomer : .neutral
    }

    var groomerSystemImage: String {
        isOpenForOffers ? "clock" : "checkmark"
    }
}

private extension RequestMatchStatus {
    var groomerSystemImage: String {
        isDismissible ? "sparkles" : "checkmark"
    }
}

private extension GroomerOfferStatus {
    var groomerTone: BeckonStatusChip.Tone {
        switch self {
        case .pending:
            .warning
        case .acceptedByCustomer:
            .success
        case .declinedByCustomer, .expired:
            .error
        case .withdrawnByGroomer, .unknown:
            .neutral
        }
    }

    var groomerSystemImage: String {
        switch self {
        case .pending:
            "paperplane.fill"
        case .acceptedByCustomer:
            "checkmark.seal.fill"
        case .declinedByCustomer:
            "xmark.circle.fill"
        case .withdrawnByGroomer:
            "arrow.uturn.backward.circle"
        case .expired:
            "clock.badge.exclamationmark"
        case .unknown:
            "questionmark.circle"
        }
    }

    var groomerDescription: String {
        switch self {
        case .pending:
            "Your offer is waiting for customer confirmation."
        case .acceptedByCustomer:
            "This offer was accepted and is ready for booking follow-up."
        case .declinedByCustomer:
            "The customer declined this offer."
        case .withdrawnByGroomer:
            "You withdrew this offer."
        case .expired:
            "This offer expired before the customer accepted it."
        case .unknown:
            "The current offer status is unavailable. Refresh before taking action."
        }
    }
}

private struct GroomerRequestsStatusView: View {
    let store: GroomerRequestsStore

    var body: some View {
        BeckonGlobalFeedbackForwarder(
            noticeMessage: store.noticeMessage,
            clearNotice: { message in
                guard store.noticeMessage == message else { return }
                store.noticeMessage = nil
            },
            error: errorPrompt,
            progress: progressPrompt
        )
    }

    private var errorPrompt: BeckonGlobalFeedbackError? {
        guard let errorMessage = store.errorMessage else { return nil }
        return BeckonGlobalFeedbackError(
            scope: .page("groomer.requests"),
            sourceKey: "groomer.requests.error",
            title: "Request Update Failed",
            message: errorMessage
        )
    }

    private var progressPrompt: BeckonGlobalFeedbackProgress? {
        if store.isDismissing {
            return BeckonGlobalFeedbackProgress(
                scope: .operation("groomer.requests.dismiss"),
                sourceKey: "groomer.requests.dismiss-progress",
                title: "Dismissing…",
                tone: .groomer
            )
        }

        if store.isSubmittingOffer {
            return BeckonGlobalFeedbackProgress(
                scope: .operation("groomer.requests.offer"),
                sourceKey: "groomer.requests.offer-progress",
                title: "Submitting Offer…",
                tone: .groomer
            )
        }

        if store.isWithdrawingOffer {
            return BeckonGlobalFeedbackProgress(
                scope: .operation("groomer.requests.withdraw"),
                sourceKey: "groomer.requests.withdraw-progress",
                title: "Withdrawing Offer…",
                tone: .groomer
            )
        }

        return nil
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        GroomerRequestsView(
            groomerID: UUID(),
            repository: GroomerRequestsPreviewRepository(),
            route: .constant(.matches)
        )
    }
}

@MainActor
private final class GroomerRequestsPreviewRepository: GroomerRequestRepository {
    private var matches = [
        GroomerMatchedRequest(
            match: GroomerRequestMatch(
                id: UUID(),
                requestID: UUID(),
                groomerID: UUID(),
                customerID: UUID(),
                matchScore: 100,
                matchReason: "Same city and service location. Pet-fit evidence: curly coats with positive reviews.",
                dismissReason: nil,
                status: .visible,
                viewedAt: nil,
                dismissedAt: nil,
                createdAt: "2026-06-20T12:00:00Z",
                updatedAt: "2026-06-20T12:00:00Z"
            ),
            request: GroomerMatchedGroomingRequest(
                id: UUID(),
                customerID: UUID(),
                petID: UUID(),
                petSnapshot: GroomingRequestPetSnapshot(
                    id: UUID(),
                    name: "Mochi",
                    species: "Dog",
                    breed: "Corgi",
                    coatType: nil,
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
                serviceNotes: "Sensitive paws.",
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
            offer: nil
        )
    ]

    func matchedRequests(groomerID: UUID) async throws -> [GroomerMatchedRequest] {
        matches
    }

    func dismiss(
        matchID: UUID,
        reason: String?
    ) async throws -> DismissRequestMatchResult {
        matches.removeAll { $0.match.id == matchID }
        return DismissRequestMatchResult(
            matchID: matchID,
            status: .dismissed,
            dismissedAt: "2026-06-20T13:00:00Z"
        )
    }

    func createOffer(
        draft: GroomerOfferDraft
    ) async throws -> CreateGroomerOfferResult {
        CreateGroomerOfferResult(
            offerID: UUID(),
            offerStatus: .pending,
            requestStatus: .hasOffers
        )
    }

    func withdrawOffer(
        offerID: UUID
    ) async throws -> WithdrawGroomerOfferResult {
        WithdrawGroomerOfferResult(
            offerID: offerID,
            offerStatus: .withdrawnByGroomer,
            withdrawnTimestamp: "2026-06-20T14:00:00Z",
            requestStatus: .open
        )
    }
}
#endif

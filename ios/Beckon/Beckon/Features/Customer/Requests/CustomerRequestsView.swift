import SwiftUI

import Combine

import PhotosUI

import SwiftUI

import UIKit

enum CustomerRequestMatchingCopy {
    static let customerReviewInfo =
        "Your preferred time helps us find groomers with availability on that day. Groomers will send offers with a real appointment time for you to review."

    static let groomerOfferGuidance =
        "Start from the customer's preferred window, then choose a time that is actually available on your schedule."
}

nonisolated enum CustomerRequestWizardPresentationOwnership {
    static func shouldPresent(storeRequested: Bool, isActiveTab: Bool) -> Bool {
        storeRequested && isActiveTab
    }
}

struct CustomerRequestsView: View {
    @State private var store: CustomerRequestsStore
    @State private var pendingCancelRequest: CustomerGroomingRequest?
    @State private var selectedBookingHandoff: CustomerRequestBookingHandoff?
    @Binding private var focusedRequestID: UUID?
    private let customerProfileRepository: (any CustomerProfileRepository)?
    private let isActiveTab: Bool
    private let managesRefresh: Bool
    private let onBookingChatSelected: (Booking) -> Void

    init(
        customerID: UUID,
        petRepository: any CustomerPetRepository,
        requestRepository: any CustomerRequestRepository,
        bookingRepository: any BookingRepository,
        customerProfileRepository: (any CustomerProfileRepository)? = nil,
        isActiveTab: Bool = true,
        managesRefresh: Bool = true,
        debugRecorder: AppDebugEventRecorder? = nil,
        focusedRequestID: Binding<UUID?> = .constant(nil),
        onBookingChatSelected: @escaping (Booking) -> Void = { _ in },
        store: CustomerRequestsStore? = nil
    ) {
        _focusedRequestID = focusedRequestID
        self.customerProfileRepository = customerProfileRepository
        self.isActiveTab = isActiveTab
        self.managesRefresh = managesRefresh
        self.onBookingChatSelected = onBookingChatSelected
        _store = State(
            initialValue: store ?? CustomerRequestsStore(
                customerID: customerID,
                petRepository: petRepository,
                requestRepository: requestRepository,
                bookingRepository: bookingRepository,
                debugRecorder: debugRecorder
            )
        )
    }

    var body: some View {
        @Bindable var store = store

        ZStack {
            BeckonExpressiveBackdrop()

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
        .background {
            CustomerRequestsStatusView(store: store)
        }
        .designAlertDialog(item: $pendingCancelRequest) { request in
            .destructive(title: "Cancel this request?",
                message: "This closes the request and any pending offers. Confirmed bookings are managed from Bookings.",
                systemImage: "xmark.circle.fill", keepTitle: "Keep Request", confirmTitle: "Cancel request",
                confirmSystemImage: "xmark.circle") { Task { await store.cancel(request) } }
        }
        .sheet(isPresented: wizardPresentationBinding) {
            CustomerRequestWizardView(
                store: store,
                customerProfileRepository: customerProfileRepository
            )
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
        .environment(\.beckonCustomerDesign, true)
        .foregroundRefreshable(isEnabled: managesRefresh && isActiveTab && !store.isShowingWizard && store.discoveryFlow == nil,
            nextDeadline: store.nextDistributionDeadline) {
            await store.load()
        }
        .sheet(item: Binding(get: { store.isShowingWizard ? nil : store.discoveryFlow }, set: { store.discoveryFlow = $0 })) { flow in
            if let marketplace = store.marketplace {
                NavigationStack { CustomerGroomerDiscoveryView(flow: flow, requests: store, marketplace: marketplace) }
                    .presentationDragIndicator(.visible)
                    .foregroundRefreshable(nextDeadline: marketplace.distribution.nextDeadline(requestIDs: flow.requestID.map { [$0] } ?? [])) {
                        if let id = flow.requestID { await store.refreshDistributionProgress(requestIDs: [id]) }
                    }
            }
        }
    }

    private var wizardPresentationBinding: Binding<Bool> {
        Binding(
            get: {
                CustomerRequestWizardPresentationOwnership.shouldPresent(
                    storeRequested: store.isShowingWizard,
                    isActiveTab: isActiveTab
                )
            },
            set: { isPresented in
                guard isActiveTab else { return }
                store.setWizardPresentation(isPresented)
            }
        )
    }

    private var requestsContent: some View {
        ScrollView {
            // These bounded sections include a variable-height horizontal carousel.
            BeckonCascade(spacing: DesignTokens.Layout.sectionSpacing) {
                CustomerRequestsHeader(
                    cardCount: visibleCardCount,
                    isCreateDisabled: store.pets.isEmpty,
                    createRequest: store.startCreate
                )

                dashboardContent
            }
            .beckonPageInsets()
        }
            .beckonTracksScroll()
        .scrollContentBackground(.hidden)
        .refreshable {
            await store.load()
        }
        .accessibilityIdentifier("customer.requests.list")
    }

    @ViewBuilder
    private var dashboardContent: some View {
        switch dashboardPresentation.state {
        case .loading:
            BeckonLoadingView(
                title: "Loading requests…",
                message: "Fetching your pet's grooming requests.",
                accent: .customer
            )
            .accessibilityIdentifier("customer.requests.loading")

        case .error(let message):
            CustomerRequestLoadFailureBanner(message: message) {
                Task {
                    await store.load()
                }
            }

        case .empty:
            CustomerRequestsEmptyDashboard()
                .accessibilityIdentifier("customer.requests.empty")

        case .loaded:
            loadedDashboardContent
        }
    }

    @ViewBuilder
    private var loadedDashboardContent: some View {
        CustomerRequestPhotoUploadRetryList(store: store)

        if visibleCardCount == 0 {
            CustomerRequestsEmptyDashboard()
                .accessibilityIdentifier("customer.requests.empty")
        } else {
            CustomerRequestCardCarousel(
                cards: store.visibleActionCards,
                store: store,
                focusedRequestID: $focusedRequestID,
                onViewBooking: { handoff in
                    selectedBookingHandoff = handoff
                    Task {
                        await store.acknowledgeBookingHandoff(for: handoff)
                    }
                },
                onCancelRequest: { request in
                    pendingCancelRequest = request
                }
            )
            .accessibilityIdentifier("customer.requests.progress-carousel")
        }

        // Closed requests are not on this page: Request history below is where they live.
        NavigationLink {
            CustomerRequestHistoryView(store: store)
        } label: {
            HStack(spacing: DesignTokens.Spacing.md) {
                DesignIconDisc(systemImage: "clock.arrow.circlepath", font: DesignTokens.Typography.Expressive.glyph)
                Text("Request history")
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(DesignTokens.Typography.Expressive.label)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(DesignTokens.Spacing.md)
        }
        .buttonStyle(BeckonLedgeButtonStyle(.card))
        .accessibilityIdentifier("customer.requests.history")

        if store.canLoadMoreRequests || store.isLoadingMoreRequests {
            BeckonLoadMoreButton(
                isLoading: store.isLoadingMoreRequests,
                accent: .customer,
                accessibilityIdentifier: "customer.requests.load-more"
            ) {
                await store.loadNextRequestsPage()
            }
        }
    }

    private var dashboardPresentation: CustomerRequestsDashboardPresentation {
        CustomerRequestsDashboardPresentation(
            activeCardCount: visibleCardCount,
            closedRequestCount: cancelledRequests.count,
            photoRetryCount: store.requestPhotoUploadRetries.count,
            isLoading: store.isLoading,
            loadErrorMessage: store.errorMessage
        )
    }

    private var visibleCardCount: Int {
        store.visibleActionCards.count
    }

    private var cancelledRequests: [CustomerGroomingRequest] {
        store.requests.recentClosedRequests(limit: 3)
    }
}

private struct CustomerRequestHistoryView: View {
    let store: CustomerRequestsStore

    var body: some View {
        // A list page: the heading leads, the closed requests follow one by one.
        DesignPage(rhythm: .list, cascades: false) {
            let closed = store.requests.recentClosedRequests(limit: .max)
            let after = 2 + min(closed.count, 4)
            if !closed.isEmpty {
                CustomerClosedRequestsSection(requests: closed, store: store,
                    onRepublishRequest: { store.startRepublish(from: $0) }, title: "Closed requests")
            } else if !store.canLoadMoreRequests {
                ContentUnavailableView("No Closed Requests", systemImage: "clock.arrow.circlepath")
                    .beckonEntrance(0)
            }
            if let error = store.errorMessage { BeckonInlineError(error).beckonEntrance(after) }
            if store.canLoadMoreRequests || store.isLoadingMoreRequests {
                BeckonLoadMoreButton(isLoading: store.isLoadingMoreRequests, accent: .customer,
                    accessibilityIdentifier: "customer.requests.history.load-more") {
                    await store.loadNextRequestsPage()
                }
                .beckonEntrance(after)
            }
        }
        .navigationTitle("Request history")
        .accessibilityIdentifier("customer.requests.history-list")
    }
}

extension Array where Element == CustomerGroomingRequest {
    func recentClosedRequests(limit: Int = 5) -> [CustomerGroomingRequest] {
        guard limit > 0 else { return [] }

        return filter { $0.status == .cancelled || $0.status == .expired }
            .sorted { lhs, rhs in
                if lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt > rhs.updatedAt
                }

                return lhs.id.uuidString < rhs.id.uuidString
            }
            .prefix(limit)
            .map { $0 }
    }
}

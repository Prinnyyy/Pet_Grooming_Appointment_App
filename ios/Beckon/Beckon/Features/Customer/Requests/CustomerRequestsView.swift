import SwiftUI

import Combine
import MapKit
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
    private let onBookingChatSelected: (Booking) -> Void

    init(
        customerID: UUID,
        petRepository: any CustomerPetRepository,
        requestRepository: any CustomerRequestRepository,
        bookingRepository: any BookingRepository,
        customerProfileRepository: (any CustomerProfileRepository)? = nil,
        isActiveTab: Bool = true,
        debugRecorder: AppDebugEventRecorder? = nil,
        focusedRequestID: Binding<UUID?> = .constant(nil),
        onBookingChatSelected: @escaping (Booking) -> Void = { _ in },
        store: CustomerRequestsStore? = nil
    ) {
        _focusedRequestID = focusedRequestID
        self.customerProfileRepository = customerProfileRepository
        self.isActiveTab = isActiveTab
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
        .background {
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
        .foregroundRefreshable {
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

    @ViewBuilder
    private var requestsContent: some View {
        if store.isLoading, store.pets.isEmpty, store.requests.isEmpty {
            BeckonLoadingView(
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

                    if !cancelledRequests.isEmpty {
                        CustomerCancelledRequestsSection(
                            requests: cancelledRequests,
                            store: store,
                            onRepublishRequest: { request in
                                store.startRepublish(from: request)
                            }
                        )
                        .accessibilityIdentifier("customer.requests.cancelled-section")
                    }

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

    private var cancelledRequests: [CustomerGroomingRequest] {
        store.requests.recentClosedRequests(limit: 3)
    }
}

extension Array where Element == CustomerGroomingRequest {
    func recentClosedRequests(limit: Int = 5) -> [CustomerGroomingRequest] {
        guard limit > 0 else { return [] }

        return filter { $0.status == .cancelled }
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

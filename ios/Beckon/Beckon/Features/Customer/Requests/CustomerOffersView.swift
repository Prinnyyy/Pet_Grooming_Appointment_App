import SwiftUI

struct CustomerRequestOffersView: View {
    let requestID: UUID
    let store: CustomerRequestsStore

    var body: some View {
        if let request = store.request(withID: requestID) {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    CustomerOfferReviewSection(
                        request: request,
                        store: store
                    )
                    .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                    .padding(.top, DesignTokens.Spacing.lg)
                    .padding(.bottom, DesignTokens.Spacing.xl)
                }
                .scrollIndicators(.hidden)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Offers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort", selection: Binding(get: { store.offerSort }, set: { mode in
                            Task { await store.changeOfferSort(to: mode, for: request) }
                        })) {
                            ForEach(CustomerOfferSort.allCases, id: \.self) { mode in Text(mode.title).tag(mode) }
                        }
                    } label: { Label("Sort", systemImage: "arrow.up.arrow.down") }
                    .accessibilityIdentifier("customer.offers.sort")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await store.loadOffers(for: request) } } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(store.isLoadingOffers(for: request))
                }
            }
            .accessibilityIdentifier("customer.offers.list")
            .task(id: request.id) {
                await store.loadOffers(for: request)
            }
        } else {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                BeckonEmptyState(
                    title: "Request Unavailable",
                    message: "Refresh requests and try again.",
                    systemImage: "doc.text.magnifyingglass",
                    accent: .customer
                )
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            }
            .navigationTitle("Offers")
        }
    }
}

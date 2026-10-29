// What is over, for the Grooming tab (S-058): the old "Request history" page, now for the whole grooming. Closed requests
// (cancelled, expired) and bookings that are finished or cancelled, newest first, one compact row each. The Grooming page reaches it
// with one History row under its cards, as the Requests tab did. Both pages open the same destinations, so they share them here.
import SwiftUI


enum GroomingDestination: Hashable {
    case request(UUID)
    case closedRequest(UUID)
    case offers(UUID)
    case booking(UUID)
    case handoff(CustomerRequestBookingHandoff)
}


struct GroomingPastEntry: Identifiable {
    let content: GroomingPastContent
    let destination: GroomingDestination
    let date: Double

    var id: UUID { content.id }
}


extension GroomingFeed {
    /// Everything that is not in progress: bookings that are over (and not just booked from an offer), and closed requests.
    static func pastEntries(cards: [CustomerRequestActionCardItem], bookings: [Booking], closedRequests: [CustomerGroomingRequest],
                            avatar: (UUID?) -> Data?, now: Date = Date()) -> [GroomingPastEntry] {
        let current = canonicalBookings(cards: cards, bookings: bookings)
        let bookedRequests = Set(current.map(\.requestID))
        var rows: [GroomingPastEntry] = current
            .filter { !isActive($0, now: now) }
            .map { booking in
                GroomingPastEntry(content: .booking(booking, avatar: avatar(booking.requestPetSnapshot?.id), now: now),
                    destination: .booking(booking.id),
                    date: GroomingRequestDateFormatting.parsedDate(from: booking.scheduledStart)?.timeIntervalSince1970 ?? 0)
            }
        rows += closedRequests.filter { !bookedRequests.contains($0.id) }.map { request in
            GroomingPastEntry(content: .closedRequest(request, avatar: avatar(request.petID)),
                destination: .closedRequest(request.id),
                date: GroomingRequestDateFormatting.parsedDate(from: request.updatedAt)?.timeIntervalSince1970 ?? 0)
        }
        return rows.sorted { $0.date > $1.date }
    }
}


private struct GroomingDestinations: ViewModifier {
    @Binding var destination: GroomingDestination?
    let requestStore: CustomerRequestsStore
    let bookingsStore: BookingsStore
    let onOpenChat: (Booking) -> Void

    func body(content: Content) -> some View {
        content.navigationDestination(item: $destination) { destination in
            switch destination {
            case .request(let id), .closedRequest(let id):
                GroomingDetailView(target: .request(id), requestStore: requestStore, bookingsStore: bookingsStore,
                    onOpenChat: onOpenChat)
            case .offers(let id):
                CustomerRequestOffersView(requestID: id, store: requestStore)
            case .booking(let id):
                GroomingDetailView(target: .booking(id), requestStore: requestStore, bookingsStore: bookingsStore,
                    onOpenChat: onOpenChat)
            case .handoff(let handoff):
                GroomingDetailView(target: .booking(handoff.booking.id), requestStore: requestStore,
                    bookingsStore: requestStore.bookingDetailStore(for: handoff.booking), onOpenChat: onOpenChat,
                    celebratesNewBooking: true)
            }
        }
    }
}


extension View {
    /// The pages a card or a row of the Grooming tab opens.
    func groomingDestinations(_ destination: Binding<GroomingDestination?>, requestStore: CustomerRequestsStore,
                                       bookingsStore: BookingsStore, onOpenChat: @escaping (Booking) -> Void) -> some View {
        modifier(GroomingDestinations(destination: destination, requestStore: requestStore, bookingsStore: bookingsStore,
            onOpenChat: onOpenChat))
    }
}


/// The History page: a list page, the rows arrive one by one.
struct GroomingHistoryView: View {
    let requestStore: CustomerRequestsStore
    let bookingsStore: BookingsStore
    let onOpenChat: (Booking) -> Void
    @State private var destination: GroomingDestination?

    private var entries: [GroomingPastEntry] {
        GroomingFeed.pastEntries(cards: requestStore.visibleActionCards, bookings: bookingsStore.bookings,
            closedRequests: requestStore.requests.recentClosedRequests(limit: .max),
            avatar: { requestStore.primaryPetPhotoData(petID: $0) })
    }

    private var canLoadMore: Bool { requestStore.canLoadMoreRequests || bookingsStore.canLoadMore }
    private var isLoadingMore: Bool { requestStore.isLoadingMoreRequests || bookingsStore.isLoadingMore }

    var body: some View {
        DesignPage(rhythm: .list, cascades: false) {
            let rows = entries
            let after = 2 + min(rows.count, 4)
            if rows.isEmpty, !canLoadMore {
                ContentUnavailableView("No past grooming", systemImage: "clock.arrow.circlepath",
                    description: Text("Completed, cancelled and expired grooming will appear here."))
                    .beckonEntrance(0)
            } else {
                VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
                    BeckonLedgeHeading(title: "Past grooming", systemImage: "clock.arrow.circlepath", count: rows.count)
                        .beckonEntrance(0)
                    LazyVStack(spacing: DesignTokens.Spacing.md) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                            GroomingPastRow(content: row.content) { destination = row.destination }
                                .beckonEntrance(1 + min(index, 4))
                        }
                    }
                }
            }
            if let error = requestStore.errorMessage { BeckonInlineError(error).beckonEntrance(after) }
            if canLoadMore || isLoadingMore {
                BeckonLoadMoreButton(isLoading: isLoadingMore, accent: .customer,
                    accessibilityIdentifier: "customer.grooming.history.load-more") {
                    if requestStore.canLoadMoreRequests { await requestStore.loadNextRequestsPage() }
                    if bookingsStore.canLoadMore { await bookingsStore.loadNextPage() }
                }
                .beckonEntrance(after)
            }
        }
        .navigationTitle("History")
        .groomingDestinations($destination, requestStore: requestStore, bookingsStore: bookingsStore, onOpenChat: onOpenChat)
        .accessibilityIdentifier("customer.grooming.history-list")
    }
}

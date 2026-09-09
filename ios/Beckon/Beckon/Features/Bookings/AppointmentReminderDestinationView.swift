import SwiftUI

struct AppointmentReminderDestinationView: View {
    let target: AppointmentReminderTap
    @State private var store: BookingsStore

    init(target: AppointmentReminderTap, repository: any BookingRepository) {
        self.target = target
        _store = State(initialValue: BookingsStore(participantID: target.accountID,
            role: target.role, repository: repository))
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.bookingReadStates[target.bookingID] == .complete {
                    BookingDetailView(bookingID: target.bookingID, role: target.role, store: store)
                } else if store.bookingReadStates[target.bookingID] == .failed {
                    ContentUnavailableView {
                        Label("Appointment Unavailable", systemImage: "calendar.badge.exclamationmark")
                    } description: {
                        Text("The current appointment could not be loaded.")
                    } actions: {
                        Button("Retry", systemImage: "arrow.clockwise") {
                            Task { await load() }
                        }
                    }
                } else { ProgressView().accessibilityLabel("Loading appointment") }
            }
            .task(id: target.id) { await load() }
        }
    }

    private func load() async { await store.resolveBooking(id: target.bookingID, forceRefresh: true) }
}

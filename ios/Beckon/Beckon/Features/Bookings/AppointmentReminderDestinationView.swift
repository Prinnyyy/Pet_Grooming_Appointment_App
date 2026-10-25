import SwiftUI

struct AppointmentReminderDestinationView: View {
    let target: AppointmentReminderTap
    @State private var store: BookingsStore

    #if DEBUG
    init(sandbox: CustomerSandboxSession) {
        target = .init(accountID: CustomerSandboxFixtures.customerID, bookingID: CustomerSandboxFixtures.bookingID, role: .customer)
        _store = State(initialValue: sandbox.bookings)
    }
    #endif

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
                    if target.role == .customer {
                        DesignPage(cascades: false) {
                            BeckonLedgeNote(systemImage: "calendar.badge.exclamationmark",
                                text: "Appointment unavailable. The current appointment could not be loaded.")
                            Button { Task { await load() } } label: {
                                DesignActionLabel(title: "Retry", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(BeckonLedgeButtonStyle(.pill))
                        }
                    } else {
                    ContentUnavailableView {
                        Label("Appointment unavailable", systemImage: "calendar.badge.exclamationmark")
                    } description: {
                        Text("The current appointment could not be loaded.")
                    } actions: {
                        Button("Retry", systemImage: "arrow.clockwise") {
                            Task { await load() }
                        }
                    }
                    }
                } else if target.role == .customer {
                    DesignPage(cascades: false) {
                        BeckonLoadingView(title: "Loading appointment…", message: "Checking this reminder.", accent: .customer)
                    }
                } else { ProgressView().accessibilityLabel("Loading appointment") }
            }
            .environment(\.beckonCustomerDesign, target.role == .customer)
            .task(id: target.id) { await load() }
        }
    }

    private func load() async { await store.resolveBooking(id: target.bookingID, forceRefresh: true) }
}

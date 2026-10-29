import SwiftUI

/// The shell replaces the selection stack with one booking after successful confirmation.
enum GroomingRoute: Hashable {
    case request(UUID)
    case booking(UUID)
    case newBooking(UUID)
}

private struct BookingConfirmedKey: EnvironmentKey {
    static let defaultValue: (@MainActor (CustomerRequestBookingHandoff) -> Void)? = nil
}
private struct CustomerGroomingRequestStoreKey: EnvironmentKey {
    static let defaultValue: CustomerRequestsStore? = nil
}
extension EnvironmentValues {
    var bookingConfirmed: (@MainActor (CustomerRequestBookingHandoff) -> Void)? {
        get { self[BookingConfirmedKey.self] }
        set { self[BookingConfirmedKey.self] = newValue }
    }
    var customerGroomingRequestStore: CustomerRequestsStore? {
        get { self[CustomerGroomingRequestStoreKey.self] }
        set { self[CustomerGroomingRequestStoreKey.self] = newValue }
    }
}

private struct CustomerRequestFlowHostedKey: EnvironmentKey {
    static let defaultValue = false
}
extension EnvironmentValues {
    var customerRequestFlowHosted: Bool {
        get { self[CustomerRequestFlowHostedKey.self] }
        set { self[CustomerRequestFlowHostedKey.self] = newValue }
    }
}

/// One modal owner for request actions reached from any customer tab, including chat and reminders.
/// Standalone previews can keep their own existing presenter.
struct CustomerRequestFlowPresenter: ViewModifier {
    let store: CustomerRequestsStore?
    let profileRepository: (any CustomerProfileRepository)?

    func body(content: Content) -> some View {
        content
            .environment(\.customerRequestFlowHosted, true)
            .sheet(isPresented: Binding(get: { store?.isShowingWizard ?? false },
                set: { store?.setWizardPresentation($0) })) {
                if let store { CustomerRequestWizardView(store: store, customerProfileRepository: profileRepository) }
            }
            .sheet(item: Binding(get: { store?.isShowingWizard == true ? nil : store?.discoveryFlow },
                set: { store?.discoveryFlow = $0 })) { flow in
                if let store, let marketplace = store.marketplace {
                    NavigationStack { CustomerGroomerDiscoveryView(flow: flow, requests: store, marketplace: marketplace) }
                        .designSheetStyle()
                        .foregroundRefreshable(nextDeadline: marketplace.distribution.nextDeadline(requestIDs: flow.requestID.map { [$0] } ?? [])) {
                            if let id = flow.requestID { await store.refreshDistributionProgress(requestIDs: [id]) }
                        }
                }
            }
    }
}

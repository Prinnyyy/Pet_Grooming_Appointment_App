#if DEBUG
import SwiftUI

struct GroomerFlowSandbox: View {
    @State private var session: GroomerSandboxSession
    let startsOn: GroomerTab
    let route: GroomerRequestsRoute

    init(state: GroomerSandboxState = .loaded, startsOn: GroomerTab = .home, route: GroomerRequestsRoute = .matches) {
        _session = State(initialValue: GroomerSandboxSession(state: state))
        self.startsOn = startsOn
        self.route = route
    }

    var body: some View {
        GroomerTabView(sandbox: session, initialTab: startsOn, initialRoute: route)
            .overlay(alignment: .bottomTrailing) {
                if session.state == .loading {
                    Button("Show loaded content") { session.boundary.release() }
                        .buttonStyle(BeckonLedgeButtonStyle(.pill))
                }
            }
    }
}

#Preview("Groomer Home") { GroomerFlowSandbox() }
#Preview("Groomer busy day") { GroomerFlowSandbox(state: .busyDay) }
#Preview("New groomer") { GroomerFlowSandbox(state: .empty) }
#Preview("Groomer loading") { GroomerFlowSandbox(state: .loading) }
#Preview("Groomer skills full") { GroomerFlowSandbox(state: .slotsFull, startsOn: .account) }
#endif

#if DEBUG
import SwiftUI

struct ChatBookingCardStates: View {
    private let all = GroomerSandboxFixtures.bookings()

    private func named(_ pet: String) -> Booking {
        all.first { $0.requestPetSnapshot?.name == pet } ?? all[0]
    }

    private var longNames: Booking {
        GroomerSandboxFixtures.booking(40,
            pet: GroomerSandboxFixtures.pet(40, name: "Maximilian Bartholomew Fitzgerald", breed: "Bernese Mountain Dog", size: "L",
                weight: 95, temperament: "Calm"),
            service: .bathAndBrush, start: GroomerSandboxFixtures.slot(day: 12, hour: 9, minutes: 120).start,
            end: GroomerSandboxFixtures.slot(day: 12, hour: 9, minutes: 120).end, price: 1_250, mode: .customerComesToGroomer,
            street: "5 Cedar Court", zip: "98107")
    }

    var body: some View {
        let bella = named("Bella")
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            row("Groomer reads it: confirmed (coral)", bella, role: .groomer)
            row("Customer reads it: confirmed (mint)", bella, role: .customer)
            row("Completed", named("Milo"), role: .customer)
            row("Cancelled by the customer", named("Luna"), role: .groomer)
            row("Cancelled by the groomer", bella.replacing(status: .cancelledByGroomer, cancelledBy: bella.groomerID,
                cancelledAt: bella.updatedAt), role: .customer)
            row("Service not confirmed", bella.replacing(status: .unfulfilled, cancelledBy: nil, cancelledAt: nil), role: .groomer)
            row("A long name, a far date, a big price, at the groomer's place", longNames, role: .customer)
            caption("The store has no such booking")
            ChatBookingUnavailableCard()
        }
        .padding(DesignTokens.Layout.pageHorizontalInset)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(DesignTokens.Colors.appBackground)
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(DesignTokens.Typography.Expressive.chip)
            .foregroundStyle(DesignTokens.Colors.textTertiary)
    }

    private func row(_ title: String, _ booking: Booking, role: UserRole) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            caption(title)
            Button {} label: { ChatBookingMessageCard(booking: booking, role: role) }
                .buttonStyle(BeckonLedgeButtonStyle(.card))
        }
        .environment(\.beckonRole, role == .groomer ? .groomer : .customer)
    }
}


/// The owner's thread as the customer sandbox holds it: two bubbles and the card the groomer posted.
private struct ChatCustomerThreadPreview: View {
    @State private var session = CustomerSandboxSession(screen: .tabs, state: .loaded)
    @State private var conversation: ChatConversation?

    var body: some View {
        NavigationStack {
            if let conversation {
                ChatThreadView(participantID: session.customerID, role: .customer, conversation: conversation,
                    store: session.chat)
            } else {
                ProgressView()
            }
        }
        .environment(\.beckonFeedbackCenter, session.feedback)
        .task {
            try? await session.prepare()
            await session.chat.loadConversations()
            conversation = session.chat.conversations.first
        }
    }
}


#Preview("Chat: the booking message card, every state, a still", traits: .fixedLayout(width: 393, height: 1720)) {
    ChatBookingCardStates().id("chatBookingCardStates")
}
#Preview("Customer chat thread: the booking message card in a conversation") {
    ChatCustomerThreadPreview().id("chatCustomerThread")
}
#endif

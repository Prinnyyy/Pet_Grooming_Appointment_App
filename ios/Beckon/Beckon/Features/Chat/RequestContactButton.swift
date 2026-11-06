import SwiftUI

/// Counterpart consent is evaluated by the server, including revocation before the first message.
struct RequestContactButton: View {
    let requestID: UUID
    let groomerID: UUID
    let authorizationRevision: String
    @Environment(\.requestChatContext) private var context
    @Environment(\.beckonFeedbackCenter) private var feedback
    @State private var contact: RequestChatContact?
    @Environment(\.openRequestChat) private var openRequestChat
    @State private var opening = false

    var body: some View {
        Group {
            if contact?.canMessage == true {
                Button { Task { await open() } } label: {
                    Label("Message groomer", systemImage: "message.fill")
                }
                .buttonStyle(BeckonSecondaryButtonStyle(accent: .customer))
                .disabled(opening)
            }
        }
        .task(id: authorizationRevision) {
            guard let context else { return }
            let value = try? await context.repository.requestContact(requestID: requestID, groomerID: groomerID)
            guard !Task.isCancelled, context.isCurrent() else { return }
            contact = value
        }

    }

    private func open() async {
        guard let context, context.isCurrent(), !opening else { return }
        opening = true
        defer { opening = false }
        do {
            let id = try await context.repository.openRequestConversation(requestID: requestID, groomerID: groomerID)
            guard !Task.isCancelled, context.isCurrent() else { return }
            openRequestChat?(id)
        } catch {
            contact = nil
            feedback?.showNotice("This conversation could not be opened. Refresh the offer and try again.")
        }
    }
}

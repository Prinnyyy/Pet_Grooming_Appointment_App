import SwiftUI

/// Eligibility and the counterpart name are projected by the server, never inferred from a fixture.
struct GroomerVisitRequestContact: View {
    let requestID: UUID
    let groomerID: UUID
    let authorizationRevision: String
    @Environment(\.groomerGroomingWorkspace) private var workspace
    @Environment(\.beckonFeedbackCenter) private var feedback
    @State private var contact: RequestChatContact?
    @Environment(\.openRequestChat) private var openRequestChat
    @State private var opening = false

    var body: some View {
        Group {
            if let contact, contact.canMessage, let workspace {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    GroomerVisitRequestFactRow(systemImage: "person.fill", title: "Your customer",
                        value: contact.displayName ?? "Customer")
                    GroomerVisitNavigationButton { Task { await open(workspace) } } label: {
                        Label("Message", systemImage: "message.fill")
                    }
                    .buttonStyle(BeckonSecondaryButtonStyle(accent: .groomer, isFullWidth: false))
                    .fixedSize(horizontal: true, vertical: true)
                    .disabled(opening)
                }
            }
        }
        .task(id: authorizationRevision) {
            guard let session = workspace?.session else { return }
            let value = try? await session.chatRepository.requestContact(requestID: requestID, groomerID: groomerID)
            guard !Task.isCancelled, session.isCurrent() else { return }
            contact = value
        }

    }

    private func open(_ workspace: GroomerGroomingWorkspace) async {
        guard !opening, workspace.session.isCurrent() else { return }
        opening = true
        defer { opening = false }
        do {
            let repository = workspace.session.chatRepository
            let id = try await repository.openRequestConversation(requestID: requestID, groomerID: groomerID)
            guard !Task.isCancelled, workspace.session.isCurrent() else { return }
            openRequestChat?(id)
        } catch {
            contact = nil
            feedback?.showNotice("This conversation could not be opened. Refresh the request and try again.")
        }
    }
}

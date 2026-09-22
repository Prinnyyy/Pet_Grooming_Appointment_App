import SwiftUI

struct GroomerCandidateActionsView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let id: UUID
    let isFavorite: Bool
    let invitation: RequestInvitationState
    let disabled: Bool
    let onFavorite: () -> Void
    let onSend: () -> Void
    var publicationConfirmation: String? = nil

    var body: some View {
        actionLayout {
            Button(action: onFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart").frame(width: 44, height: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isFavorite ? "Remove favorite" : "Add favorite")
            .accessibilityIdentifier("discovery.favorite.\(id.uuidString)")
            .help(isFavorite ? "Remove favorite" : "Add favorite")
            if invitation == .notSent {
                CustomerRequestSendButton(title: "Send Request", confirmation: publicationConfirmation, action: onSend)
                    .buttonStyle(BeckonPrimaryButtonStyle(accent: .customer))
                    .accessibilityIdentifier("discovery.send.\(id.uuidString)")
            } else {
                Label(invitation.title, systemImage: "checkmark.circle")
                    .font(DesignTokens.Typography.supporting).frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .tint(DesignTokens.Colors.customerAccentStrong)
        .disabled(disabled)
    }

    private var actionLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.sm))
            : AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.md))
    }
}

struct CustomerRequestSendButton: View {
    let title: String
    let confirmation: String?
    let action: () -> Void
    @State private var isConfirming = false
    @State private var confirmedSummary = ""

    var body: some View {
        Button(title, systemImage: "paperplane") {
            if let confirmation {
                confirmedSummary = confirmation
                isConfirming = true
            } else { action() }
        }
        .alert("Send this request?", isPresented: $isConfirming) {
            Button("Confirm Send", action: action).accessibilityIdentifier("discovery.confirm-send")
            Button("Cancel", role: .cancel) {}
        } message: { Text(confirmedSummary) }
    }
}

extension RequestInvitationState {
    var title: String {
        switch self {
        case .notSent: "Not sent"
        case .awaitingResponse: "Awaiting response"
        case .offered: "Offer received"
        case .declined: "Declined"
        case .withdrawn: "Invitation withdrawn"
        case .expired: "Invitation expired"
        case .closed: "Request closed"
        }
    }
}

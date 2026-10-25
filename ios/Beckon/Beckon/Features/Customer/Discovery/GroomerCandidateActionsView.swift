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
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(DesignTokens.Typography.Expressive.glyph)
                    .foregroundStyle(DesignTokens.Colors.customerDeep)
                    .frame(width: DesignTokens.Metrics.ledgeRoundControl, height: DesignTokens.Metrics.ledgeRoundControl)
            }
            .buttonStyle(BeckonLedgeButtonStyle(.round))
            .accessibilityLabel(isFavorite ? "Remove favorite" : "Add favorite")
            .accessibilityIdentifier("discovery.favorite.\(id.uuidString)")
            if invitation == .notSent {
                CustomerRequestSendButton(title: "Send request", confirmation: publicationConfirmation, action: onSend)
                    .accessibilityIdentifier("discovery.send.\(id.uuidString)")
            } else {
                BeckonMetaChip(text: invitation.title, systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .tint(DesignTokens.Colors.customerDeep)
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
        Button {
            if let confirmation {
                confirmedSummary = confirmation
                isConfirming = true
            } else { action() }
        } label: {
            DesignActionLabel(title: title, systemImage: "paperplane.fill")
        }
        .buttonStyle(BeckonLedgeButtonStyle(.pill))
        .sendRequestDialog(isPresented: $isConfirming, summary: confirmedSummary, send: action)
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

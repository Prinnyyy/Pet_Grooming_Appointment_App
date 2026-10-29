// Who has heard about a request, in three views: the distribution card (sandbox screen "requestProgress" only), the reach summary
// and the groomers card on the request detail page. Moved out of
// the Grooming detail page (it was the request detail page) in S-037. Stores and fixtures stay shared.
import Foundation
import SwiftUI


/// Who has the request, in words: the invited groomers as overlapping initials (a people icon when nobody is invited yet), a
/// headline that says what it means, and one line of detail. The summary folds "open to all matching
/// groomers" into the words; the detail page passes `invitationsOnly` because it shows that state on its own row.
struct CustomerRequestReachSummary: View {
    let requestID: UUID
    let store: CustomerRequestDistributionStore
    var invitationsOnly = false
    @Environment(\.dynamicTypeSize) private var typeSize

    private struct Facts {
        var initials: [String] = []
        var extra = 0
        var headline = "Checking who has your request"
        var detail: String?
    }

    var body: some View {
        let facts = facts()
        (typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.sm))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DesignTokens.Spacing.md))) {
            avatars(facts)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(facts.headline)
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = facts.detail {
                    Text(detail)
                        .designSupportingText()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func avatars(_ facts: Facts) -> some View {
        if facts.initials.isEmpty {
            DesignIconDisc(systemImage: "person.2.fill", size: .touch, isDecorative: false)
        } else {
            HStack(spacing: -DesignTokens.Spacing.md) {
                ForEach(Array(facts.initials.enumerated()), id: \.offset) { index, letter in
                    bubble(letter, fill: DesignTokens.Colors.customerTint, ink: DesignTokens.Colors.customerDeep)
                        .zIndex(Double(facts.initials.count - index))
                }
                if facts.extra > 0 {
                    bubble("+\(facts.extra)", fill: DesignTokens.Colors.customerFill, ink: DesignTokens.Colors.customerInk)
                }
            }
        }
    }

    private func bubble(_ text: String, fill: Color, ink: Color) -> some View {
        Text(text)
            .font(DesignTokens.Typography.Expressive.emphasis)
            .foregroundStyle(ink)
            .frame(width: DesignTokens.Metrics.minimumTouchTarget, height: DesignTokens.Metrics.minimumTouchTarget)
            .background(fill, in: Circle())
            .overlay(Circle().strokeBorder(DesignTokens.Colors.surface, lineWidth: DesignTokens.Ledge.edgeWidth))
    }

    private func facts() -> Facts {
        guard let progress = store.progressByRequestID[requestID] else { return Facts() }
        let invited = progress.invitations
        let waiting = invited.filter {
            store.state(requestID: requestID, groomerID: $0.groomerID, seed: $0.state) == .awaitingResponse
        }.count
        let names = invited.prefix(3).map { String(($0.profile?.displayName ?? "?").prefix(1)).uppercased() }
        var facts = Facts(initials: Array(names), extra: max(0, invited.count - 3))
        switch (invited.isEmpty, progress.poolEnabled) {
        case (true, false):
            facts.headline = "Nobody invited yet"
            facts.detail = "Invite groomers you like to get offers."
        case (true, true):
            facts.headline = invitationsOnly ? "Nobody invited yet" : "Open to all matching groomers"
            facts.detail = invitationsOnly ? nil : "Any matching groomer can send offers."
        case (false, _):
            facts.headline = "\(invited.count) groomer\(invited.count == 1 ? "" : "s") invited"
            var parts: [String] = []
            if waiting > 0 { parts.append("\(waiting) not replied yet") }
            if progress.validOfferCount > 0 {
                parts.append("\(progress.validOfferCount) offer\(progress.validOfferCount == 1 ? "" : "s") in")
            }
            if progress.poolEnabled, !invitationsOnly { parts.append("open to all matching groomers") }
            facts.detail = parts.isEmpty ? "No replies pending" : parts.joined(separator: " · ")
        }
        return facts
    }
}


/// One short line for the request card: who can see the request. The initials and the detail sentence are on the detail page.
enum CustomerRequestReachLine {
    static func text(requestID: UUID, store: CustomerRequestDistributionStore) -> String {
        guard let progress = store.progressByRequestID[requestID] else { return "Checking invitations" }
        let count = progress.invitations.count
        if count > 0 { return "\(count) groomer\(count == 1 ? "" : "s") invited" }
        return progress.poolEnabled ? "Open to all matching groomers" : "Nobody invited yet"
    }
}


/// The groomers module of the request detail page: who was invited, whether the request is open to every matching groomer (a row
/// of its own, so that state is seen, not read out of a sentence), and one labelled button. The pool switch, withdraw and the list
/// live in the sheet the button (or the open-state row) opens.
struct CustomerRequestReachCard: View {
    let requestID: UUID
    let store: CustomerRequestDistributionStore
    let onInvite: () -> Void

    private var progress: CustomerRequestProgress? { store.progressByRequestID[requestID] }
    private var hasInvitations: Bool { !(progress?.invitations.isEmpty ?? true) }
    private var isOpenToAll: Bool { progress?.poolEnabled == true }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            BeckonLedgeHeading(title: "Groomers", systemImage: "person.2.fill")
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                CustomerRequestReachSummary(requestID: requestID, store: store, invitationsOnly: true)
                openStateRow
                Button(action: onInvite) {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "person.badge.plus")
                        Text(hasInvitations ? "Invite more groomers" : "Invite groomers")
                    }
                    .font(DesignTokens.Typography.Expressive.headline)
                    .foregroundStyle(DesignTokens.Colors.customerInk)
                    .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.minimumTouchTarget)
                }
                .buttonStyle(BeckonLedgeButtonStyle(.pill))
                .accessibilityIdentifier("customer.requests.invite")
            }
            .designCardBody()
        }
    }

    /// Mint and filled when every matching groomer can see the request; an outline when only the invited ones can. Tapping it
    /// opens the groomers sheet, where the switch is.
    private var openStateRow: some View {
        Button(action: onInvite) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: isOpenToAll ? "person.3.fill" : "lock.fill")
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
                Text(isOpenToAll ? "Open to all matching groomers" : "Only groomers you invite")
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(isOpenToAll ? "On" : "Off")
                    .font(DesignTokens.Typography.Expressive.label)
                    .accessibilityHidden(true)
            }
            .font(DesignTokens.Typography.Expressive.emphasis)
            .foregroundStyle(isOpenToAll ? DesignTokens.Colors.customerInk : DesignTokens.Colors.textSecondary)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.minimumTouchTarget)
            .background(isOpenToAll ? DesignTokens.Colors.customerTint : Color.clear,
                in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.pill, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.pill, style: .continuous)
                    .strokeBorder(DesignTokens.Colors.border, lineWidth: DesignTokens.Ledge.edgeWidth)
                    .opacity(isOpenToAll ? 0 : 1)
            }
            .animation(DesignTokens.Motion.morph, value: isOpenToAll)
            .contentShape(Rectangle())
        }
        .buttonStyle(BeckonGuardedPlainButtonStyle())
        .accessibilityLabel(isOpenToAll ? "Open to all matching groomers, on" : "Only groomers you invite")
        .accessibilityHint("Opens the groomers sheet, where you can change who can see this request.")
        .accessibilityIdentifier("customer.requests.open-state")
    }
}

struct CustomerRequestReachRow: View {
    let requestID: UUID
    let store: CustomerRequestDistributionStore
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        (typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.sm))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DesignTokens.Spacing.md))) {
            CustomerRequestReachSummary(requestID: requestID, store: store)
            BeckonMetaChip(text: "Invite", systemImage: "plus")
        }
        .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
        .contentShape(Rectangle())
    }
}

/// The groomers module of the request detail page: who was invited, whether the request is open to every matching groomer (a row
/// of its own, so that state is seen, not read out of a sentence), and one labelled button. The pool switch, withdraw and the list
/// live in the sheet the button (or the open-state row) opens.

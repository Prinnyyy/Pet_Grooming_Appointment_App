// "Choose groomers", plan A (Claude sandbox design S-009): the customer ticks groomers in one list and sends once from a
// bottom bar. Replaces the swipe deck, the per-card Send buttons and the separate "all groomers" page.
import SwiftUI

/// Groomers ticked on "Choose groomers", keyed by id. Names ride along so the send confirmation can list them.
struct GroomerSelection: Equatable {
    /// A request can have five invitations out at once (waiting for an answer, or with an offer still open).
    static let invitationLimit = 5

    private var namesByID: [UUID: String] = [:]
    /// The page lowers this by the invitations already using a spot.
    var limit = GroomerSelection.invitationLimit

    var count: Int { namesByID.count }
    var isEmpty: Bool { namesByID.isEmpty }
    var isFull: Bool { count >= limit }
    var remaining: Int { max(0, limit - count) }
    var ids: [UUID] { sortedPairs.map(\.key) }
    var names: [String] { sortedPairs.map(\.value) }

    func contains(_ id: UUID) -> Bool { namesByID[id] != nil }
    func canTick(_ id: UUID) -> Bool { contains(id) || !isFull }

    mutating func toggle(_ id: UUID, name: String) {
        if namesByID.removeValue(forKey: id) == nil, !isFull { namesByID[id] = name }
    }

    /// Drops ids that are no longer on offer after a full reload.
    mutating func keep(_ ids: Set<UUID>) {
        namesByID = namesByID.filter { ids.contains($0.key) }
    }

    mutating func removeAll() { namesByID = [:] }

    private var sortedPairs: [(key: UUID, value: String)] {
        namesByID.sorted { ($0.value, $0.key.uuidString) < ($1.value, $1.key.uuidString) }
    }
}

/// A snapshot hint, never permission to send. SQL rechecks the five-slot limit
/// atomically. An offered-but-unselectable quote does not consume a slot.
struct GroomerInvitationCapacity: Equatable {
    let remaining: Int?
    let selectionLimit: Int

    init(progress: CustomerRequestProgress?, offers: [CustomerOfferReview], completeOffers: Bool,
         now: Date = Date()) {
        guard let progress else {
            remaining = nil
            selectionLimit = GroomerSelection.invitationLimit
            return
        }
        guard progress.status.isOpenForOffers, progress.expiresAt > now else {
            remaining = 0; selectionLimit = 0; return
        }
        let waiting = Set(progress.invitations.filter {
            $0.state == .awaitingResponse && $0.replyBy > now
        }.map(\.groomerID))
        let hasOffers = progress.invitations.contains { $0.state == .offered }
        let unknownQuote = offers.contains { $0.offer.status == .pending && $0.offer.quoteEvaluation == nil }
        guard !hasOffers || (completeOffers && !unknownQuote) else {
            remaining = nil
            selectionLimit = max(0, GroomerSelection.invitationLimit - waiting.count)
            return
        }
        let invited = Set(progress.invitations.map(\.groomerID))
        let selectable = Set(offers.filter {
            invited.contains($0.offer.groomerID) && $0.isCurrentProposal(now: now)
                && $0.offer.quoteEvaluation?.selectable == true
        }.map(\.offer.groomerID))
        let free = max(0, GroomerSelection.invitationLimit - waiting.union(selectable).count)
        remaining = free
        selectionLimit = free
    }
}

/// Heart toggle that keeps a groomer in the customer's saved list.
struct GroomerFavoriteButton: View {
    let isFavorite: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(DesignTokens.Typography.Expressive.glyph)
                .foregroundStyle(DesignTokens.Colors.customerDeep)
                .frame(width: DesignTokens.Metrics.ledgePrimaryButtonHeight - 8,
                    height: DesignTokens.Metrics.ledgePrimaryButtonHeight - 8)
                .background(DesignTokens.Colors.customerTint, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(BeckonGuardedPlainButtonStyle())
        .accessibilityLabel(isFavorite ? "Remove favorite" : "Add favorite")
    }
}

/// The one action on a groomer card: a white "Select" pill that turns mint when ticked. Once the groomer has been
/// invited it becomes the invitation's status instead, with the reply deadline and a way to take the invitation back.
///
/// When every spot is used the pill stays tappable but muted: the page answers the tap with an explanation and a way
/// forward instead of leaving a dead, disabled button.
struct GroomerSelectionControl: View {
    let name: String
    let isSelected: Bool
    let invitation: RequestInvitationState
    var canSelect = true
    var replyBy: Date?
    var onWithdraw: (() -> Void)?
    let action: () -> Void

    var body: some View {
        if invitation != .notSent {
            invitedStatus
        } else {
            Button(action: action) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(DesignTokens.Typography.Expressive.glyph)
                    Text(isSelected ? "Selected" : "Select")
                        .font(DesignTokens.Typography.Expressive.headline)
                }
                .foregroundStyle(isSelected ? DesignTokens.Colors.customerInk : DesignTokens.Colors.textPrimary)
                .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.ledgePrimaryButtonHeight - 8)
            }
            .buttonStyle(BeckonLedgeButtonStyle(isSelected ? .pill : .card))
            .opacity(canSelect ? 1 : 0.55)
            .accessibilityLabel("Select \(name)")
            .accessibilityHint(isSelected ? "Removes this groomer from your request."
                : canSelect ? "Adds this groomer to your request."
                : "All your invitation spots are in use. Opens your options.")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }

    private var isWaiting: Bool { invitation == .awaitingResponse }

    private var statusText: String { isWaiting ? "Waiting for a reply" : invitation.title }

    private var statusIcon: String {
        switch invitation {
        case .awaitingResponse: "clock.fill"
        case .offered: "checkmark.circle.fill"
        default: "xmark.circle.fill"
        }
    }

    private var invitedStatus: some View {
        let status = BeckonMetaChip(text: statusText, systemImage: statusIcon)
        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    status
                    Spacer(minLength: 0)
                    withdrawButton
                }
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    status
                    withdrawButton
                }
            }
            if isWaiting, let replyBy {
                Text("Replies by \(replyBy.formatted(date: .abbreviated, time: .shortened))")
                    .font(DesignTokens.Typography.Expressive.chip)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var withdrawButton: some View {
        if isWaiting, let onWithdraw {
            Button(action: onWithdraw) {
                Text("Withdraw")
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.customerDeep)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(BeckonGuardedPlainButtonStyle())
            .accessibilityLabel("Withdraw invitation to \(name)")
            .accessibilityHint("Frees a spot. You can't invite this groomer again for this request.")
        }
    }
}

/// Answers a tap on "Select" when every invitation spot is used: why there is a limit, and the ways to reach more groomers. A modal,
/// not an alert: nothing is being decided, the person is told something and may take a way out.
private struct GroomerLimitDialog: ViewModifier {
    @Binding var isPresented: Bool
    let isNewRequest: Bool
    let poolEnabled: Binding<Bool>?

    private var poolIsOpen: Bool { poolEnabled?.wrappedValue == true }

    private var message: String {
        if !isNewRequest {
            return "Groomers waiting to reply and offers you can still accept use a spot. A spot opens when an invitation closes or an offer is no longer available. Availability is checked again when you send."
        }
        if poolIsOpen {
            return "Every invitation sends the groomer a notification, so we keep it to \(GroomerSelection.invitationLimit) at a time. Your request is already open to all matching groomers, so they can still send offers without an invitation."
        }
        return "Every invitation sends the groomer a notification, so we keep it to \(GroomerSelection.invitationLimit) at a time. To reach more groomers, open your request to everyone who matches, or invite more once some have replied."
    }

    private var actions: [DesignDialogAction] {
        if isNewRequest, let poolEnabled, !poolEnabled.wrappedValue {
            return [.primary("Open to all matching groomers", systemImage: "person.3.fill", identifier: "discovery.limit.open-pool") {
                poolEnabled.wrappedValue = true
            }, .quiet("OK", systemImage: "checkmark", identifier: "discovery.limit.ok")]
        }
        return [.primary("OK", identifier: "discovery.limit.ok")]
    }

    func body(content: Content) -> some View {
        content.designModal(isPresented: $isPresented) {
            DesignModal(systemImage: "person.2.fill",
                title: "You can invite \(GroomerSelection.invitationLimit) groomers at once", message: message, actions: actions)
        }
    }
}

extension View {
    /// `poolEnabled` is offered as a way out on a new request; pass nil when inviting more on an existing one.
    func groomerLimitDialog(isPresented: Binding<Bool>, isNewRequest: Bool, poolEnabled: Binding<Bool>?) -> some View {
        modifier(GroomerLimitDialog(isPresented: isPresented, isNewRequest: isNewRequest, poolEnabled: poolEnabled))
    }

    /// "Send this request?" with a summary of what is about to go out: the one confirmation before a request reaches groomers.
    func sendRequestDialog(isPresented: Binding<Bool>, summary: String, send: @escaping @MainActor () -> Void) -> some View {
        designAlertDialog(isPresented: isPresented) {
            .confirmation(title: "Send this request?", message: summary, systemImage: "paperplane.fill",
                confirmTitle: "Confirm Send", confirmSystemImage: "paperplane.fill",
                confirmIdentifier: "discovery.confirm-send", confirm: send)
        }
    }
}

/// Heart and select pill, side by side (stacked at accessibility text sizes). Shared by list rows and the profile card.
struct GroomerSelectionActions: View {
    let id: UUID
    let name: String
    let isFavorite: Bool
    let invitation: RequestInvitationState
    let isSelected: Bool
    var canSelect = true
    var replyBy: Date?
    var onWithdraw: (() -> Void)?
    let disabled: Bool
    let onFavorite: () -> Void
    let onToggle: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        (typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.sm))
            : AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.md))) {
            GroomerFavoriteButton(isFavorite: isFavorite, action: onFavorite)
                .accessibilityIdentifier("discovery.favorite.\(id.uuidString)")
            GroomerSelectionControl(name: name, isSelected: isSelected, invitation: invitation, canSelect: canSelect,
                replyBy: replyBy, onWithdraw: onWithdraw, action: onToggle)
                .accessibilityIdentifier("discovery.select.\(id.uuidString)")
        }
        .disabled(disabled)
    }
}

/// One groomer in the list: tap the top for the profile, tap "Select" to add them to the request.
struct GroomerChoiceRow: View {
    let candidate: DiscoveredGroomer
    let avatarData: Data?
    let isFavorite: Bool
    let invitation: RequestInvitationState
    let isSelected: Bool
    var canSelect = true
    var replyBy: Date?
    var onWithdraw: (() -> Void)?
    let isLocked: Bool
    let onDetails: () -> Void
    let onFavorite: () -> Void
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Button(action: onDetails) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                    GroomerCandidateSummaryView(profile: candidate.profile, avatarData: avatarData,
                        candidate: candidate, compact: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(DesignTokens.Typography.Expressive.label)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .padding(.top, DesignTokens.Spacing.sm)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(BeckonGuardedPlainButtonStyle())
            .accessibilityHint("Opens the groomer profile.")
            .accessibilityIdentifier("discovery.profile.\(candidate.id.uuidString)")

            GroomerSelectionActions(id: candidate.id, name: candidate.profile.displayName, isFavorite: isFavorite,
                invitation: invitation, isSelected: isSelected, canSelect: canSelect, replyBy: replyBy, onWithdraw: onWithdraw,
                disabled: isLocked, onFavorite: onFavorite, onToggle: onToggle)
        }
        .designCardBody()
        .overlay {
            if isSelected {
                // The ledge pads its bottom by the lip depth; the ring follows the face only.
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous)
                    .strokeBorder(DesignTokens.Colors.customerDeep, lineWidth: 3)
                    .padding(.bottom, DesignTokens.Ledge.card)
                    .allowsHitTesting(false)
            }
        }
    }
}

/// Also show the request to every eligible groomer (the request pool): the choice on a new request, and the switch on a sent
/// one. It sits at the top of the list because it answers the same question as the list, "who gets this request", and it
/// keeps the bottom bar down to Back and Send.
struct GroomerPoolCard: View {
    @Binding var isOn: Bool
    var isLocked = false
    var identifier = "discovery.pool-consent"

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                DesignIconDisc(systemImage: "person.3.fill", size: .touch, font: DesignTokens.Typography.Expressive.glyph)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Open to all matching groomers")
                        .font(DesignTokens.Typography.Expressive.emphasis)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(isOn ? "Every eligible groomer can see this request and send offers."
                        : "Off: only the groomers you pick will see this request.")
                        .font(DesignTokens.Typography.Expressive.chip)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(DesignTokens.Colors.customerDeep)
        .disabled(isLocked)
        .designCardBody()
        .accessibilityIdentifier(identifier)
    }
}

import SwiftUI

/// Matches, Offers and Bookings use the same time rail, pet header, price slot and status strip.
struct GroomerGroomingListCard: View {
    let model: GroomerGroomingCardContent
    var customerName: String? = nil
    let decision: String?
    var status: GroomerVisitCardStatus? = nil
    let onOpen: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    private var content: GroomerRequestRowContent { model.row }
    private var stacks: Bool { typeSize.isAccessibilitySize }

    var body: some View {
        GroomerVisitNavigationButton(action: onOpen) {
            VStack(spacing: 0) {
                GroomerGroomingCardBody {
                    if let date = model.archiveDay {
                        compactTimeColumn(caption: date.year, value: date.month.uppercased(), detail: date.day)
                    }
                    else if let when = content.when { timeColumn(when) }
                    else { Text("—").foregroundStyle(DesignTokens.Colors.textSecondary) }
                } avatar: {
                    GroomerPetAvatar(species: content.species, data: content.photo, size: DesignTokens.Metrics.petAvatarSmall)
                } details: {
                    lines
                }
                if let decision { GroomerVisitStatusFootNote(text: "Needs action · " + decision, systemImage: "exclamationmark.circle.fill", tone: .action) }
                else if let status {
                    GroomerVisitStatusFootNote(text: status.listTitle ?? status.title, systemImage: status.symbol, tone: status.resolvedTone)
                }
                else if let note = content.note, note.compactDeadline == nil { BeckonFootNote(text: note.text, systemImage: note.systemImage, tone: note.tone) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // The note runs edge to edge: the card's corners cut it.
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous))
        }
        .buttonStyle(GroomerVisitGroomingCardStyle(needsAction: decision != nil))
        .accessibilityLabel([content.summary, model.archiveDay?.spoken, customerName.map { "For " + $0 },
            decision.map { "Needs action. " + $0 }].compactMap { $0 }.joined(separator: ", "))
    }

    // MARK: Parts

    @ViewBuilder
    private func timeColumn(_ when: BeckonWhen) -> some View {
        if stacks {
            Text(when.full)
                .font(DesignTokens.Typography.Expressive.emphasis)
                .foregroundStyle(DesignTokens.Colors.customerDeep)
                .fixedSize(horizontal: false, vertical: true)
        } else if let separator = when.day.range(of: ", ") {
            // BeckonWhen uses "MMM d, yyyy" for a different year. Reflow its label without recalculating the date.
            compactTimeColumn(caption: String(when.day[separator.upperBound...]),
                value: String(when.day[..<separator.lowerBound]), detail: when.start)
                .allowsTightening(true)
                .minimumScaleFactor(0.85)
        } else {
            let clock = when.start.split(whereSeparator: { $0.isWhitespace })
            compactTimeColumn(caption: when.day, value: clock.first.map(String.init) ?? when.start,
                detail: clock.dropFirst().first.map(String.init))
        }
    }

    private func compactTimeColumn(caption: String, value: String, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(caption)
                .textCase(.uppercase)
                .font(DesignTokens.Typography.Expressive.chip)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .offset(y: -DesignTokens.Spacing.xs / 2)
            Text(value)
                .font(DesignTokens.Typography.Expressive.emphasis)
                .monospacedDigit()
            if let detail {
                Text(detail)
                    .font(DesignTokens.Typography.Expressive.chip.weight(.semibold))
            }
        }
        .foregroundStyle(DesignTokens.Colors.customerDeep)
        .lineLimit(1)
        .accessibilityHidden(true)
    }

    private var lines: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs / 2) {
            nameLine
            if let customerName {
                line("For " + customerName, tail: content.breed, tailWins: false, color: DesignTokens.Colors.textSecondary)
            } else {
                line(content.breed, tail: content.weight, tailWins: true, color: DesignTokens.Colors.textSecondary)
            }
            line(content.service, tail: content.place, tailWins: false, color: DesignTokens.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Two facts on one line. When the line is too long the one that matters less is cut at its end (the breed before the weight,
    /// the city before the service); at accessibility sizes the line wraps and nothing is cut.
    @ViewBuilder
    private func line(_ head: String, tail: String?, tailWins: Bool, color: Color) -> some View {
        let parts = [head, tail].compactMap { $0 }.filter { !$0.isEmpty }
        if stacks {
            Text(parts.joined(separator: " · "))
                .font(DesignTokens.Typography.Expressive.supporting)
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
        } else if parts.count == 2, let tail {
            HStack(spacing: 0) {
                Text(head).lineLimit(1).layoutPriority(tailWins ? 0 : 1)
                Text(" · \(tail)").lineLimit(1).fixedSize(horizontal: tailWins, vertical: false).layoutPriority(tailWins ? 1 : 0)
            }
            .font(DesignTokens.Typography.Expressive.supporting)
            .foregroundStyle(color)
        } else if let only = parts.first {
            Text(only)
                .font(DesignTokens.Typography.Expressive.supporting)
                .foregroundStyle(color)
                .lineLimit(1)
        }
    }

    private var nameLine: some View {
        let layout = stacks
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.xs))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DesignTokens.Spacing.sm))
        return layout {
            nameText
            if content.price != nil || content.note?.compactDeadline != nil {
                if !stacks { Spacer(minLength: 0) }
                trailingFacts
            }
        }
    }

    private var nameText: some View {
        Text(content.name)
            .font(DesignTokens.Typography.Expressive.title)
            .foregroundStyle(DesignTokens.Colors.textPrimary)
            .lineLimit(stacks ? nil : 1)
    }

    private var trailingFacts: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.xs) {
            if let price = content.price {
                Text(price)
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.customerDeep)
                    .monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false)
            }
            if let deadline = content.note?.compactDeadline {
                Text(deadline)
                    .font(DesignTokens.Typography.Expressive.micro)
                    .foregroundStyle(DesignTokens.Colors.statusWarningText)
                    .padding(.horizontal, DesignTokens.Spacing.xs)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(DesignTokens.Colors.statusWarningFill, in: Capsule())
                    .fixedSize()
                    .accessibilityHidden(true) // Full deadline is already in the row's accessible summary.
            }
        }
    }

}



private struct GroomerGroomingCardBody<Time: View, Avatar: View, Details: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .subheadline) private var railWidth = DesignTokens.Metrics.timeColumnWidth
    @ViewBuilder let time: () -> Time
    @ViewBuilder let avatar: () -> Avatar
    @ViewBuilder let details: () -> Details

    var body: some View {
        let stacked = typeSize.isAccessibilitySize
        let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.md))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DesignTokens.Spacing.md))
        HStack(alignment: .center, spacing: DesignTokens.Spacing.sm) {
            layout {
                time().frame(width: stacked ? nil : railWidth, alignment: .leading)
                avatar()
                details().frame(maxWidth: .infinity, alignment: .leading)
            }
            Image(systemName: "chevron.right")
                .font(DesignTokens.Typography.Expressive.label)
                .foregroundStyle(DesignTokens.Colors.customerDeep)
                .accessibilityHidden(true)
        }
        .padding(DesignTokens.Spacing.md)
    }
}

struct GroomerGroomingListCardSkeleton: View {
    let hasPriceAndStatus: Bool
    let label: String
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(spacing: 0) {
            GroomerGroomingCardBody {
                if typeSize.isAccessibilitySize {
                    DesignSkeletonLine(width: 0.7, font: DesignTokens.Typography.Expressive.emphasis)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        DesignSkeletonLine(width: 0.7, font: DesignTokens.Typography.Expressive.chip)
                        DesignSkeletonLine(width: 0.9, font: DesignTokens.Typography.Expressive.emphasis)
                        DesignSkeletonLine(width: 0.5, font: DesignTokens.Typography.Expressive.chip)
                    }
                }
            } avatar: {
                DesignSkeletonDisc().frame(width: DesignTokens.Metrics.petAvatarSmall, height: DesignTokens.Metrics.petAvatarSmall)
            } details: {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs / 2) {
                    let header = typeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.xs))
                        : AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.sm))
                    header {
                        DesignSkeletonLine(width: 0.5, font: DesignTokens.Typography.Expressive.title)
                        if hasPriceAndStatus {
                            Text("$00.00").font(DesignTokens.Typography.Expressive.emphasis).monospacedDigit().hidden()
                                .overlay { DesignSkeletonLine(font: DesignTokens.Typography.Expressive.emphasis) }
                        }
                    }
                    DesignSkeletonLine(width: 0.7)
                    DesignSkeletonLine(width: 0.6)
                }
            }
            if hasPriceAndStatus {
                DesignSkeletonLine(width: 0.6, font: DesignTokens.Typography.Expressive.chip)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(DesignTokens.Colors.statusNeutralFill)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous))
        .designSkeleton(label: label)
        .beckonLedge(.card)
        .padding(.bottom, DesignTokens.Ledge.room - DesignTokens.Ledge.card)
    }
}

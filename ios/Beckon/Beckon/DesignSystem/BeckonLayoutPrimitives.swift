import SwiftUI

enum BeckonRoleAccent {
    case customer
    case groomer
    case neutral

    var color: Color {
        switch self {
        case .customer:
            DesignTokens.Colors.customerFill
        case .groomer:
            DesignTokens.Colors.groomerFill
        case .neutral:
            DesignTokens.Colors.border
        }
    }

    var darkColor: Color {
        deep
    }

    var ink: Color {
        switch self {
        case .customer: DesignTokens.Colors.customerInk
        case .groomer: DesignTokens.Colors.groomerInk
        case .neutral: DesignTokens.Colors.textPrimary
        }
    }

    var tint: Color {
        switch self {
        case .customer: DesignTokens.Colors.customerTint
        case .groomer: DesignTokens.Colors.groomerTint
        case .neutral: DesignTokens.Colors.iconTileFill
        }
    }

    var deep: Color {
        switch self {
        case .customer:
            DesignTokens.Colors.customerDeep
        case .groomer:
            DesignTokens.Colors.groomerDeep
        case .neutral:
            DesignTokens.Colors.textPrimary
        }
    }
}

enum BeckonAccountLayoutPolicy {
    static let identityAvatarSize: CGFloat = 76
    static let identityAvatarCornerRadius: CGFloat = identityAvatarSize / 2
    static let pageSectionSpacing = DesignTokens.Layout.sectionSpacing
    static let groupedRowDividerLeadingInset =
        DesignTokens.Layout.rowHorizontalInset
        + DesignTokens.Metrics.settingsIconSlot
        + DesignTokens.Spacing.md
}

struct BeckonCountBadge: View {
    let count: Int
    let accent: BeckonRoleAccent
    var hasMore = false

    var body: some View {
        if let label = BeckonBadgeLabel.text(for: count) {
            Text(hasMore && count < 100 ? "\(label)+" : label)
                .font(DesignTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(accent.deep)
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, DesignTokens.Spacing.xs)
                .background(accent.tint, in: Capsule())
                .accessibilityLabel(hasMore ? "At least \(count)" : "\(count)")
        }
    }
}

struct BeckonRoleBadge: View {
    let title: String
    var systemImage: String? = nil
    let accent: BeckonRoleAccent

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            if let systemImage { Image(systemName: systemImage).accessibilityHidden(true) }
            Text(title).fixedSize(horizontal: false, vertical: true)
        }
        .font(DesignTokens.Typography.status)
        .foregroundStyle(accent.deep)
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(accent.tint, in: Capsule())
    }
}

extension View {
    func beckonPageInsets(
        bottom: CGFloat = DesignTokens.Layout.pageBottomInset
    ) -> some View {
        padding(.horizontal, DesignTokens.Layout.pageHorizontalInset)
            .padding(.top, DesignTokens.Layout.pageTopInset)
            .padding(.bottom, bottom)
    }
}

struct BeckonPageTitle: View {
    @Environment(\.beckonCustomerDesign) private var customerDesign

    private let title: String

    init(_ title: String) {
        self.title = title
    }

    @ViewBuilder var body: some View {
        if customerDesign { customerBody } else { existingBody }
    }

    private var customerBody: some View {
        Text(title)
            .font(DesignTokens.Typography.Expressive.display)
            .foregroundStyle(DesignTokens.Colors.textPrimary)
            .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.tabTitleRowHeight, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }

    private var existingBody: some View {
        Text(title)
            .font(DesignTokens.Typography.pageTitle)
            .foregroundStyle(DesignTokens.Colors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

struct BeckonSection<Content: View, Trailing: View>: View {
    private let title: String
    private let subtitle: String?
    private let content: Content
    private let trailing: Trailing

    init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
        self.trailing = trailing()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            BeckonSectionHeading(title: title, subtitle: subtitle) {
                trailing
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension BeckonSection where Trailing == EmptyView {
    init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(title, subtitle: subtitle, content: content) {
            EmptyView()
        }
    }
}

struct BeckonGroupedSurface<Content: View>: View {
    @Environment(\.beckonCustomerDesign) private var customerDesign

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    @ViewBuilder var body: some View {
        if customerDesign { customerBody } else { existingBody }
    }

    private var customerBody: some View {
        content
            .clipShape(
                RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.card,
                    style: .continuous
                )
            )
            .beckonLedge(.card)
    }

    private var existingBody: some View {
        content
            .background(DesignTokens.Colors.surface)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.card,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.card,
                    style: .continuous
                )
                .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
            }
    }
}

struct BeckonGroupedDivider: View {
    var leadingInset: CGFloat = 0

    var body: some View {
        Divider()
            .overlay(DesignTokens.Colors.divider)
            .padding(.leading, leadingInset)
    }
}

struct BeckonAccountIdentityHeader<Avatar: View>: View {
    @Environment(\.beckonCustomerDesign) private var customerDesign

    let displayName: String
    let detailText: String
    let roleTitle: String
    let roleSystemImage: String?
    let roleAccent: BeckonRoleAccent
    private let avatar: Avatar

    init(
        displayName: String,
        detailText: String,
        roleTitle: String,
        roleSystemImage: String? = nil,
        roleAccent: BeckonRoleAccent,
        @ViewBuilder avatar: () -> Avatar
    ) {
        self.displayName = displayName
        self.detailText = detailText
        self.roleTitle = roleTitle
        self.roleSystemImage = roleSystemImage
        self.roleAccent = roleAccent
        self.avatar = avatar()
    }

    @ViewBuilder var body: some View {
        if customerDesign { customerBody } else { existingBody }
    }

    private var customerBody: some View {
        HStack(spacing: DesignTokens.Spacing.lg) {
            avatar
                .frame(
                    width: BeckonAccountLayoutPolicy.identityAvatarSize,
                    height: BeckonAccountLayoutPolicy.identityAvatarSize
                )
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(DesignTokens.Colors.surface, lineWidth: 4))

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(displayName)
                    .font(DesignTokens.Typography.Expressive.title)
                    .foregroundStyle(DesignTokens.Colors.customerInk)
                    .fixedSize(horizontal: false, vertical: true)

                Text(detailText)
                    .font(DesignTokens.Typography.Expressive.supporting)
                    .foregroundStyle(DesignTokens.Colors.customerInk)
                    .fixedSize(horizontal: false, vertical: true)

                BeckonRoleBadge(
                    title: roleTitle,
                    systemImage: roleSystemImage,
                    accent: roleAccent
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .designBanner()
        .accessibilityElement(children: .combine)
    }

    private var existingBody: some View {
        HStack(spacing: DesignTokens.Spacing.lg) {
            avatar
                .frame(
                    width: BeckonAccountLayoutPolicy.identityAvatarSize,
                    height: BeckonAccountLayoutPolicy.identityAvatarSize
                )

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(displayName)
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(detailText)
                    .font(DesignTokens.Typography.supporting)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                BeckonRoleBadge(
                    title: roleTitle,
                    systemImage: roleSystemImage,
                    accent: roleAccent
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The Account banner while the profile is on its way (design): the real banner (the mint, its lip, the white ring of the avatar) with
/// the avatar as a disc, the name and the detail as lines, and the role badge as a pill the exact size of the real badge (the badge
/// itself, hidden, gives the size). Same height as `BeckonAccountIdentityHeader`, so the real one takes its place.
struct BeckonAccountIdentitySkeleton: View {
    let roleTitle: String
    var roleSystemImage: String? = nil
    let roleAccent: BeckonRoleAccent

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.lg) {
            DesignSkeletonDisc()
                .frame(
                    width: BeckonAccountLayoutPolicy.identityAvatarSize,
                    height: BeckonAccountLayoutPolicy.identityAvatarSize
                )
                .overlay(Circle().strokeBorder(DesignTokens.Colors.surface, lineWidth: 4))

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                DesignSkeletonLine(width: 0.55, font: DesignTokens.Typography.Expressive.title)
                DesignSkeletonLine(width: 0.85)
                BeckonRoleBadge(title: roleTitle, systemImage: roleSystemImage, accent: roleAccent)
                    .hidden()
                    .overlay {
                        DesignSkeletonBlock(cornerRadius: DesignTokens.CornerRadius.pill)
                    }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .designSkeleton(label: "Loading your account")
        .designBanner()
    }
}


/// A settings row as bars: the icon as a disc, the title (and a summary) as lines, in the real row's padding and least height.
struct BeckonSettingsRowSkeleton: View {
    var hasSummary = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            DesignSkeletonDisc()
                .frame(width: DesignTokens.Metrics.ledgeIconTile, height: DesignTokens.Metrics.ledgeIconTile)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                DesignSkeletonLine(width: 0.4, font: DesignTokens.Typography.Expressive.emphasis)
                if hasSummary {
                    DesignSkeletonLine(width: 0.7, font: DesignTokens.Typography.Expressive.chip)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .designSkeleton(label: nil)
        .padding(.horizontal, DesignTokens.Layout.rowHorizontalInset)
        .padding(.vertical, DesignTokens.Layout.rowVerticalInset)
        .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
    }
}


/// A titled section of grouped rows as bars: the heading as a line on the page, the real grouped card (and its dividers) with a
/// skeleton row for each entry. `summaries` says which rows have a second line.
struct BeckonSettingsSectionSkeleton: View {
    let summaries: [Bool]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            DesignSkeletonLine(width: 0.3, font: DesignTokens.Typography.Expressive.section)
                .designSkeletonOnPage()
                .designSkeleton(label: nil)

            BeckonGroupedSurface {
                VStack(spacing: 0) {
                    ForEach(Array(summaries.enumerated()), id: \.offset) { index, hasSummary in
                        if index > 0 {
                            BeckonGroupedDivider(leadingInset: BeckonAccountLayoutPolicy.groupedRowDividerLeadingInset)
                        }
                        BeckonSettingsRowSkeleton(hasSummary: hasSummary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


struct BeckonSettingsRowLabel: View {
    @Environment(\.beckonCustomerDesign) private var customerDesign

    let title: String
    let summary: String?
    let systemImage: String
    let accent: BeckonRoleAccent
    let trailingSystemImage: String

    init(
        title: String,
        summary: String? = nil,
        systemImage: String,
        accent: BeckonRoleAccent,
        trailingSystemImage: String = "chevron.right"
    ) {
        self.title = title
        self.summary = summary
        self.systemImage = systemImage
        self.accent = accent
        self.trailingSystemImage = trailingSystemImage
    }

    @ViewBuilder var body: some View {
        if customerDesign { customerBody } else { existingBody }
    }

    private var customerBody: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.Expressive.glyph)
                .foregroundStyle(accent.darkColor)
                .frame(width: DesignTokens.Metrics.ledgeIconTile, height: DesignTokens.Metrics.ledgeIconTile)
                .background(accent.tint, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                if let summary {
                    Text(summary)
                        .font(DesignTokens.Typography.Expressive.chip)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: trailingSystemImage)
                .font(DesignTokens.Typography.Expressive.label)
                .foregroundStyle(DesignTokens.Colors.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, DesignTokens.Layout.rowHorizontalInset)
        .padding(.vertical, DesignTokens.Layout.rowVerticalInset)
        .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
        .contentShape(Rectangle())
    }

    private var existingBody: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.cardTitle)
                .foregroundStyle(accent.darkColor)
                .frame(width: DesignTokens.Metrics.settingsIconSlot)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.action)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                if let summary {
                    Text(summary)
                        .font(DesignTokens.Typography.supporting)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: trailingSystemImage)
                .font(DesignTokens.Typography.status)
                .foregroundStyle(DesignTokens.Colors.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, DesignTokens.Layout.rowHorizontalInset)
        .padding(.vertical, DesignTokens.Layout.rowVerticalInset)
        .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
        .contentShape(Rectangle())
    }
}

struct BeckonSettingsNavigationRow<Destination: View>: View {
    let title: String
    let summary: String?
    let systemImage: String
    let accent: BeckonRoleAccent
    private let destination: Destination

    init(
        title: String,
        summary: String? = nil,
        systemImage: String,
        accent: BeckonRoleAccent,
        @ViewBuilder destination: () -> Destination
    ) {
        self.title = title
        self.summary = summary
        self.systemImage = systemImage
        self.accent = accent
        self.destination = destination()
    }

    var body: some View {
        NavigationLink {
            destination
        } label: {
            BeckonSettingsRowLabel(
                title: title,
                summary: summary,
                systemImage: systemImage,
                accent: accent
            )
        }
        .buttonStyle(BeckonGuardedPlainButtonStyle())
    }
}

struct BeckonSectionHeading<Trailing: View>: View {
    @Environment(\.beckonCustomerDesign) private var customerDesign

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    let subtitle: String?
    let trailing: Trailing

    init(
        title: String,
        subtitle: String?,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    @ViewBuilder var body: some View {
        if customerDesign { customerBody } else { existingBody }
    }

    private var customerBody: some View {
        headingLayout {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.Expressive.section)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                if let subtitle {
                    Text(subtitle)
                        .font(DesignTokens.Typography.Expressive.supporting)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing
        }
        .accessibilityElement(children: .contain)
    }

    private var existingBody: some View {
        headingLayout {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                if let subtitle {
                    Text(subtitle)
                        .font(DesignTokens.Typography.supporting)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing
        }
        .accessibilityElement(children: .contain)
    }

    private var headingLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.sm))
            : AnyLayout(HStackLayout(alignment: .top, spacing: DesignTokens.Spacing.md))
    }
}

/// Chips that sit side by side and wrap to the next line when the row is full (S-072): each one as wide as its own words (a chip
/// longer than the row gets the whole row and wraps inside), every row starting at the leading edge, one gap between chips and one
/// between rows. A grid of equal cells (`LazyVGrid(.adaptive)`) puts a long chip in a short cell and leaves holes after it.
struct BeckonFlowLayout: Layout {
    var spacing: CGFloat
    var rowSpacing: CGFloat

    // `Layout` is not main-actor, the tokens are: the defaults are read where the layout is made, in a view's body.
    @MainActor
    init(spacing: CGFloat = DesignTokens.Spacing.sm, rowSpacing: CGFloat = DesignTokens.Spacing.sm) {
        self.spacing = spacing
        self.rowSpacing = rowSpacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arranged(in: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.reduce(0) { $0 + $1.height } + rowSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width.map { min($0, max(width, 0)) } ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arranged(in: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for item in row.items {
                subviews[item.index].place(at: CGPoint(x: x, y: y), anchor: .topLeading,
                    proposal: ProposedViewSize(width: item.size.width, height: item.size.height))
                x += item.size.width + spacing
            }
            y += row.height + rowSpacing
        }
    }

    private struct Row {
        var items: [(index: Int, size: CGSize)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arranged(in maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows = [Row()]
        for index in subviews.indices {
            var size = subviews[index].sizeThatFits(.unspecified)
            if size.width > maxWidth { size = subviews[index].sizeThatFits(ProposedViewSize(width: maxWidth, height: nil)) }
            let gap = rows[rows.count - 1].items.isEmpty ? 0 : spacing
            if rows[rows.count - 1].width + gap + size.width > maxWidth, !rows[rows.count - 1].items.isEmpty { rows.append(Row()) }
            let last = rows.count - 1
            rows[last].width += (rows[last].items.isEmpty ? 0 : spacing) + size.width
            rows[last].height = max(rows[last].height, size.height)
            rows[last].items.append((index, size))
        }
        return rows
    }
}

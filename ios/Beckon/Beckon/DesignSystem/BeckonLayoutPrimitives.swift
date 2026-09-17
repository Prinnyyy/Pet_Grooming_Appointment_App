import SwiftUI

enum BeckonRoleAccent {
    case customer
    case groomer
    case neutral

    var color: Color {
        switch self {
        case .customer:
            DesignTokens.Colors.customerAccent
        case .groomer:
            DesignTokens.Colors.groomerAccent
        case .neutral:
            DesignTokens.Colors.border
        }
    }

    var darkColor: Color {
        switch self {
        case .customer:
            DesignTokens.Colors.customerAccentStrong
        case .groomer:
            DesignTokens.Colors.groomerAccentDark
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
    private let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
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
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
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
    let displayName: String
    let detailText: String
    let roleTitle: String
    let roleSystemImage: String?
    let roleTone: BeckonStatusChip.Tone
    private let avatar: Avatar

    init(
        displayName: String,
        detailText: String,
        roleTitle: String,
        roleSystemImage: String? = nil,
        roleTone: BeckonStatusChip.Tone,
        @ViewBuilder avatar: () -> Avatar
    ) {
        self.displayName = displayName
        self.detailText = detailText
        self.roleTitle = roleTitle
        self.roleSystemImage = roleSystemImage
        self.roleTone = roleTone
        self.avatar = avatar()
    }

    var body: some View {
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

                BeckonStatusChip(
                    roleTitle,
                    systemImage: roleSystemImage,
                    tone: roleTone
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

struct BeckonSettingsRowLabel: View {
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

    var body: some View {
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
        .buttonStyle(.plain)
    }
}

struct BeckonSectionHeading<Trailing: View>: View {
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

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                if let subtitle {
                    Text(subtitle)
                        .font(DesignTokens.Typography.supporting)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing
        }
        .accessibilityElement(children: .contain)
    }
}

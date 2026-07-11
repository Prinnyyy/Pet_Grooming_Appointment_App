import SwiftUI
import UIKit

struct GroomerAccountHomeView: View {
    @Bindable var store: GroomerProfileStore
    let accountContent: AnyView?
    let onSignOut: (() -> Void)?

    var body: some View {
        let presentation = GroomerAccountPresentation(
            city: store.profile?.baseCity,
            state: store.profile?.baseState,
            fallbackDetail: store.profileDetailText,
            hasProfile: store.profile != nil,
            isProfileActive: store.profile?.isActive ?? false,
            serviceCount: store.services.count,
            activeServiceCount: store.services.filter(\.isActive).count,
            portfolioPhotoCount: store.portfolioPhotos.count,
            enabledAvailabilityDayCount: store.availabilityWindows.filter(\.isEnabled).count,
            selectedFitSignalCount: store.selectedFitClaimIDs.count,
            evidenceSignalCount: store.petFitEvidenceSummary.count
        )

        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            Text("Account")
                .font(DesignTokens.Typography.largeTitle)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            GroomerAccountProfileHeader(
                displayName: store.profileDisplayName,
                detailText: presentation.identitySubtitle,
                avatarPhotoData: store.avatarPhotoData
            )

            GroomerWorkspaceSection(title: "Business") {
                GroomerAccountMenuSurface {
                    GroomerAccountMenuLink(
                        title: "Edit Profile",
                        summary: presentation.profileSummary,
                        systemImage: "pencil",
                        accessibilityIdentifier: "groomer.account.edit-profile"
                    ) {
                        GroomerProfileEditorView(store: store)
                    }

                    GroomerWorkspaceDivider(leadingInset: 64)

                    GroomerAccountMenuLink(
                        title: "Services",
                        summary: presentation.servicesSummary,
                        systemImage: "scissors",
                        accessibilityIdentifier: "groomer.account.services"
                    ) {
                        GroomerServicesEditorView(store: store)
                    }

                    GroomerWorkspaceDivider(leadingInset: 64)

                    GroomerAccountMenuLink(
                        title: "Portfolio",
                        summary: presentation.portfolioSummary,
                        systemImage: "photo.on.rectangle",
                        accessibilityIdentifier: "groomer.account.portfolio"
                    ) {
                        GroomerPortfolioEditorView(store: store)
                    }
                }
            }

            GroomerWorkspaceSection(title: "Matching & Schedule") {
                GroomerAccountMenuSurface {
                    GroomerAccountMenuLink(
                        title: "Availability",
                        summary: presentation.availabilitySummary,
                        systemImage: "calendar",
                        accessibilityIdentifier: "groomer.account.availability"
                    ) {
                        GroomerAvailabilityEditorView(store: store)
                    }

                    GroomerWorkspaceDivider(leadingInset: 64)

                    GroomerAccountMenuLink(
                        title: "Fit Signals",
                        summary: presentation.fitSignalsSummary,
                        systemImage: "sparkles",
                        accessibilityIdentifier: "groomer.account.fit-signals"
                    ) {
                        GroomerFitSignalsEditorView(store: store)
                    }

                    GroomerWorkspaceDivider(leadingInset: 64)

                    GroomerAccountMenuLink(
                        title: "Evidence",
                        summary: presentation.evidenceSummary,
                        systemImage: "chart.bar.xaxis",
                        accessibilityIdentifier: "groomer.account.evidence"
                    ) {
                        GroomerEvidenceDashboardView(store: store)
                    }
                }
            }

            GroomerWorkspaceSection(title: "Support") {
                GroomerAccountSupportSurface()
            }

            signOutControl
        }
    }

    @ViewBuilder
    private var signOutControl: some View {
        if let onSignOut {
            Button(role: .destructive) {
                onSignOut()
            } label: {
                Text("Sign Out")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.error)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.Spacing.md)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("groomer.account.sign-out")
        } else if let accountContent {
            NavigationLink {
                accountContent
            } label: {
                Text("Sign Out")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.error)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.Spacing.md)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct GroomerAccountProfileHeader: View {
    let displayName: String
    let detailText: String
    let avatarPhotoData: Data?

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.lg) {
            BeckonProfileAvatar(
                data: avatarPhotoData,
                tone: .groomer,
                size: 76,
                cornerRadius: 38,
                placeholderSize: 30
            )

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(displayName)
                    .font(DesignTokens.Typography.title)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(detailText)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)

                BeckonStatusChip(
                    "Groomer",
                    systemImage: "scissors",
                    tone: .groomer
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct GroomerAccountMenuSurface<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        GroomerGroupedSurface {
            VStack(spacing: 0) {
                content()
            }
        }
    }
}

private struct GroomerAccountMenuLink<Destination: View>: View {
    let title: String
    let summary: String
    let systemImage: String
    let accessibilityIdentifier: String
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .frame(width: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DesignTokens.Typography.body.weight(.semibold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)

                    Text(summary)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct GroomerAccountSupportSurface: View {
    var body: some View {
        GroomerGroupedSurface {
            VStack(spacing: 0) {
                GroomerAccountExternalLink(
                    title: "Privacy Policy",
                    systemImage: "hand.raised",
                    destination: AppReleaseLinks.privacyPolicy,
                    accessibilityIdentifier: "account.privacy-policy"
                )

                GroomerWorkspaceDivider(leadingInset: 64)

                GroomerAccountExternalLink(
                    title: "Support",
                    systemImage: "questionmark.circle",
                    destination: AppReleaseLinks.support,
                    accessibilityIdentifier: "account.support"
                )
            }
        }
    }
}

private struct GroomerAccountExternalLink: View {
    let title: String
    let systemImage: String
    let destination: URL
    let accessibilityIdentifier: String

    var body: some View {
        Link(destination: destination) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .frame(width: 28)
                    .accessibilityHidden(true)

                Text(title)
                    .font(DesignTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

enum GroomerAvatarImageEncoder {
    static func displayablePayload(
        from data: Data,
        preferredContentType: GroomerAvatarPhotoContentType
    ) -> (data: Data, contentType: GroomerAvatarPhotoContentType)? {
        guard let image = UIImage(data: data) else { return nil }

        if preferredContentType == .png,
           let pngData = image.pngData(),
           UIImage(data: pngData) != nil {
            return (pngData, .png)
        }

        guard let jpegData = image.jpegData(compressionQuality: 0.88),
              UIImage(data: jpegData) != nil else {
            return nil
        }

        return (jpegData, .jpeg)
    }
}

struct ProfileBadges: View {
    let profile: GroomerProfile

    var body: some View {
        if profile.ratingCount > 0 || profile.isVerified {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if profile.ratingCount > 0 {
                    BeckonStatusChip(
                        "\(profile.ratingAverage.formatted(.number.precision(.fractionLength(2)))) from \(profile.ratingCount) review\(profile.ratingCount == 1 ? "" : "s")",
                        systemImage: "star.fill",
                        tone: .warning
                    )
                }

                if profile.isVerified {
                    BeckonStatusChip(
                        "Verified",
                        systemImage: "checkmark.seal.fill",
                        tone: .success
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

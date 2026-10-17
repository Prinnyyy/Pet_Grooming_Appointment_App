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
            selectedFitSignalCount: store.fitClaims.filter(\.isActive).count,
            evidenceSignalCount: store.petFitEvidenceSummary.count
        )

        LazyVStack(alignment: .leading, spacing: BeckonAccountLayoutPolicy.pageSectionSpacing) {
            BeckonPageTitle("Account")

            BeckonAccountIdentityHeader(
                displayName: store.profileDisplayName,
                detailText: presentation.identitySubtitle,
                roleTitle: "Groomer",
                roleSystemImage: "scissors",
                roleAccent: .groomer
            ) {
                BeckonProfileAvatar(
                    data: store.avatarPhotoData,
                    tone: .groomer,
                    size: BeckonAccountLayoutPolicy.identityAvatarSize,
                    cornerRadius: BeckonAccountLayoutPolicy.identityAvatarCornerRadius,
                    placeholderSize: 30
                )
            }

            BeckonSection("Business") {
                BeckonGroupedSurface {
                    VStack(spacing: 0) {
                        BeckonSettingsNavigationRow(
                            title: "Profile settings",
                            summary: presentation.profileSummary,
                            systemImage: "person.crop.circle",
                            accent: .groomer
                        ) {
                            GroomerProfileEditorView(store: store)
                        }
                        .accessibilityIdentifier("groomer.account.edit-profile")

                        BeckonGroupedDivider(
                            leadingInset: BeckonAccountLayoutPolicy.groupedRowDividerLeadingInset
                        )

                        BeckonSettingsNavigationRow(
                            title: "Services",
                            summary: presentation.servicesSummary,
                            systemImage: "scissors",
                            accent: .groomer
                        ) {
                            GroomerServicesEditorView(store: store)
                        }
                        .accessibilityIdentifier("groomer.account.services")

                        BeckonGroupedDivider(
                            leadingInset: BeckonAccountLayoutPolicy.groupedRowDividerLeadingInset
                        )

                        BeckonSettingsNavigationRow(
                            title: "Portfolio",
                            summary: presentation.portfolioSummary,
                            systemImage: "photo.on.rectangle",
                            accent: .groomer
                        ) {
                            GroomerPortfolioEditorView(store: store)
                        }
                        .accessibilityIdentifier("groomer.account.portfolio")
                    }
                }
            }

            BeckonSection("Matching & schedule") {
                BeckonGroupedSurface {
                    VStack(spacing: 0) {
                        BeckonSettingsNavigationRow(
                            title: "Availability",
                            summary: presentation.availabilitySummary,
                            systemImage: "calendar",
                            accent: .groomer
                        ) {
                            GroomerAvailabilityEditorView(store: store)
                        }
                        .accessibilityIdentifier("groomer.account.availability")

                        BeckonGroupedDivider(
                            leadingInset: BeckonAccountLayoutPolicy.groupedRowDividerLeadingInset
                        )

                        BeckonSettingsNavigationRow(
                            title: "Fit signals",
                            summary: presentation.fitSignalsSummary,
                            systemImage: "sparkles",
                            accent: .groomer
                        ) {
                            GroomerFitSignalsEditorView(store: store)
                        }
                        .accessibilityIdentifier("groomer.account.fit-signals")

                        BeckonGroupedDivider(
                            leadingInset: BeckonAccountLayoutPolicy.groupedRowDividerLeadingInset
                        )

                        BeckonSettingsNavigationRow(
                            title: "Evidence",
                            summary: presentation.evidenceSummary,
                            systemImage: "chart.bar.xaxis",
                            accent: .groomer
                        ) {
                            GroomerEvidenceDashboardView(store: store)
                        }
                        .accessibilityIdentifier("groomer.account.evidence")
                    }
                }
            }

            BeckonSection("Support") {
                AccountReleaseLinksSection(accent: .groomer)
            }

            BeckonSection("Account access") {
                signOutControl
            }
        }
    }

    @ViewBuilder
    private var signOutControl: some View {
        if let onSignOut {
            Button(role: .destructive) {
                onSignOut()
            } label: {
                GroomerSignOutRowLabel()
            }
            .buttonStyle(BeckonDestructiveButtonStyle())
            .accessibilityIdentifier("groomer.account.sign-out")
        } else if let accountContent {
            NavigationLink {
                accountContent
            } label: {
                GroomerSignOutRowLabel()
            }
            .buttonStyle(BeckonDestructiveButtonStyle())
        }
    }
}

private struct GroomerSignOutRowLabel: View {
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "rectangle.portrait.and.arrow.right")
                .font(DesignTokens.Typography.action)
                .foregroundStyle(DesignTokens.Colors.statusErrorText)
                .frame(width: DesignTokens.Metrics.settingsIconSlot)
                .accessibilityHidden(true)

            Text("Sign out")
                .font(DesignTokens.Typography.action)
                .foregroundStyle(DesignTokens.Colors.statusErrorText)

            Spacer(minLength: 0)
        }
        .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
        .contentShape(Rectangle())
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let profile: GroomerProfile

    var body: some View {
        if profile.ratingCount > 0 || profile.isVerified {
            badgeLayout {
                if let average = profile.exactRatingAverage {
                    BeckonStatusChip(.rating(average: average, count: profile.ratingCount))
                }

                if profile.isVerified {
                    BeckonStatusChip(.verified)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var badgeLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.sm))
            : AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.sm))
    }
}

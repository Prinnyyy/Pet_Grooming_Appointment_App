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

        LazyVStack(alignment: .leading, spacing: BeckonAccountLayoutPolicy.pageSectionSpacing) {
            BeckonPageTitle("Account")

            BeckonAccountIdentityHeader(
                displayName: store.profileDisplayName,
                detailText: presentation.identitySubtitle,
                roleTitle: "Groomer",
                roleSystemImage: "scissors",
                roleTone: .groomer
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
                            title: "Profile Settings",
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

            BeckonSection("Matching & Schedule") {
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
                            title: "Fit Signals",
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

            BeckonSection("Account Access") {
                BeckonGroupedSurface {
                    signOutControl
                }
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
            .buttonStyle(.plain)
            .accessibilityIdentifier("groomer.account.sign-out")
        } else if let accountContent {
            NavigationLink {
                accountContent
            } label: {
                GroomerSignOutRowLabel()
            }
            .buttonStyle(.plain)
        }
    }
}

private struct GroomerSignOutRowLabel: View {
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "rectangle.portrait.and.arrow.right")
                .font(DesignTokens.Typography.action)
                .foregroundStyle(DesignTokens.Colors.error)
                .frame(width: DesignTokens.Metrics.settingsIconSlot)
                .accessibilityHidden(true)

            Text("Sign Out")
                .font(DesignTokens.Typography.action)
                .foregroundStyle(DesignTokens.Colors.error)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DesignTokens.Layout.rowHorizontalInset)
        .padding(.vertical, DesignTokens.Layout.rowVerticalInset)
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

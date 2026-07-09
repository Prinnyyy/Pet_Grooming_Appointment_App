import SwiftUI
import UIKit

struct GroomerAccountHomeView: View {
    @Bindable var store: GroomerProfileStore
    let accountContent: AnyView?
    let onSignOut: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            Text("Account")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, DesignTokens.Spacing.sm)

            GroomerAccountProfileCard(
                displayName: store.profileDisplayName,
                detailText: store.profileDetailText,
                avatarPhotoData: store.avatarPhotoData
            )

            VStack(spacing: 0) {
                GroomerAccountMenuLink(
                    title: "Edit Profile",
                    systemImage: "pencil",
                    isFirst: true
                ) {
                    GroomerProfileEditorView(store: store)
                }

                Divider()
                    .overlay(DesignTokens.Colors.divider)
                    .padding(.leading, 72)

                GroomerAccountMenuLink(
                    title: "Services",
                    systemImage: "scissors"
                ) {
                    GroomerServicesEditorView(store: store)
                }

                Divider()
                    .overlay(DesignTokens.Colors.divider)
                    .padding(.leading, 72)

                GroomerAccountMenuLink(
                    title: "Availability",
                    systemImage: "calendar"
                ) {
                    GroomerAvailabilityEditorView(store: store)
                }

                Divider()
                    .overlay(DesignTokens.Colors.divider)
                    .padding(.leading, 72)

                GroomerAccountMenuLink(
                    title: "Fit Signals",
                    systemImage: "sparkles"
                ) {
                    GroomerFitSignalsEditorView(store: store)
                }

                Divider()
                    .overlay(DesignTokens.Colors.divider)
                    .padding(.leading, 72)

                GroomerAccountMenuLink(
                    title: "Portfolio",
                    systemImage: "photo.on.rectangle"
                ) {
                    GroomerPortfolioEditorView(store: store)
                }

                Divider()
                    .overlay(DesignTokens.Colors.divider)
                    .padding(.leading, 72)

                GroomerAccountMenuLink(
                    title: "Evidence Dashboard",
                    systemImage: "chart.bar.xaxis",
                    isLast: true
                ) {
                    GroomerEvidenceDashboardView(store: store)
                }
            }
            .background(DesignTokens.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
            }

            AccountReleaseLinksSection()
                .padding(.top, DesignTokens.Spacing.lg)

            signOutControl
                .padding(.top, DesignTokens.Spacing.lg)
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

private struct GroomerAccountProfileCard: View {
    let displayName: String
    let detailText: String
    let avatarPhotoData: Data?

    var body: some View {
        GroomlyCard(padding: DesignTokens.Spacing.lg) {
            HStack(spacing: DesignTokens.Spacing.lg) {
                GroomerAvatarImage(
                    data: avatarPhotoData,
                    size: 84,
                    cornerRadius: 24,
                    placeholderSize: 34
                )

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(displayName)
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(detailText)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)

                    GroomlyStatusChip(
                        "Groomer",
                        systemImage: "scissors",
                        tone: .groomer
                    )
                    .padding(.top, DesignTokens.Spacing.xs)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct GroomerAccountMenuLink<Destination: View>: View {
    let title: String
    let systemImage: String
    var isFirst = false
    var isLast = false
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                    .frame(width: 36)
                    .accessibilityHidden(true)

                Text(title)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct GroomerAvatarImage: View {
    let data: Data?
    let size: CGFloat
    let cornerRadius: CGFloat
    let placeholderSize: CGFloat

    var body: some View {
        GroomlyModuleImage(data: data) {
            GroomlyDefaultProfileAvatar(
                tone: .groomer,
                symbolSize: placeholderSize
            )
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
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
                    GroomlyStatusChip(
                        "\(profile.ratingAverage.formatted(.number.precision(.fractionLength(2)))) from \(profile.ratingCount) review\(profile.ratingCount == 1 ? "" : "s")",
                        systemImage: "star.fill",
                        tone: .warning
                    )
                }

                if profile.isVerified {
                    GroomlyStatusChip(
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

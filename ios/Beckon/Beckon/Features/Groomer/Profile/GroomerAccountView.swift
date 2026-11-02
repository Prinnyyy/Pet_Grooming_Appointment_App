// The groomer's Account, built from the same pieces as the customer's (design, made one page with it in design). Same job as
// GroomerProfileManagementView and GroomerAccountHomeView in Features/Groomer/Profile: who the groomer is (name, place, photo), the
// business pages (profile, services, portfolio), the matching and schedule pages (availability, fit signals, evidence), support
// links and signing out. The store (`GroomerProfileStore`), the summaries (`GroomerAccountPresentation`), the route that Home's
// Availability card uses and every id are the real ones. The page follows `CustomerAccountView` block for block: the
// banner, two shortcut tiles for what a groomer opens most (Services and Availability, each saying its count), then plain headings
// over grouped cards of rows, Help, Account access; the colour is the role's, set once by the tab view.
import SwiftUI


struct GroomerAccountView: View {
    @Bindable var store: GroomerProfileStore
    @Binding var requestedRoute: GroomerProfileRoute?
    let onSignOut: () -> Void
    @State private var activeRoute: GroomerProfileRoute?
    /// The first load is over (answered, or a saved profile can be shown): until then everything under the title is bars.
    @State private var settled = false

    var body: some View {
        ZStack {
            BeckonExpressiveBackdrop()

            ScrollView {
                BeckonCascade(spacing: DesignTokens.Layout.sectionSpacing) {
                    BeckonPageTitle("Account")
                    if store.profile == nil, let error = store.loadErrorMessage, !store.isLoading {
                        unavailable(error)
                    } else {
                        content
                    }
                }
                .beckonPageInsets()
            }
            .scrollContentBackground(.hidden)
            .beckonTracksScroll()
            .refreshable { await store.load() }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await store.load()
            guard !Task.isCancelled else { return }
            settled = true
            activateRequestedRouteIfReady()
        }
        .onChange(of: requestedRoute) { _, _ in activateRequestedRouteIfReady() }
        .background { GroomerProfileStatusView(store: store) }
        .navigationDestination(item: $activeRoute) { route in
            switch route {
            case .availability: GroomerAvailabilityEditorView(store: store)
            }
        }
        .accessibilityIdentifier("groomer.account.home")
    }

    private func activateRequestedRouteIfReady() {
        guard let route = GroomerProfileRoute.activatedRoute(requested: requestedRoute, isProfileLoaded: store.profile != nil) else { return }
        requestedRoute = nil
        activeRoute = route
    }

    private var presentation: GroomerAccountPresentation {
        GroomerAccountPresentation(
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
    }

    // MARK: Content

    /// One block that waits for the profile: its bars until the first load is over, then the block, all blocks together.
    @ViewBuilder
    private var content: some View {
        if let error = store.optionalLoadError {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                DesignInfoLine(systemImage: "exclamationmark.triangle.fill", text: error)
                Button { Task { await store.load() } } label: {
                    DesignQuietAction(title: "Retry details", systemImage: "arrow.clockwise")
                }
                .buttonStyle(BeckonGuardedPlainButtonStyle())
                .disabled(store.isLoadingOptionalMetadata)
            }
        }

        waits {
            BeckonAccountIdentityHeader(displayName: store.profileDisplayName, detailText: presentation.identitySubtitle,
                roleTitle: "Groomer", roleSystemImage: "scissors", roleAccent: .groomer) {
                BeckonProfileAvatar(data: store.avatarPhotoData, tone: .groomer,
                    size: BeckonAccountLayoutPolicy.identityAvatarSize,
                    cornerRadius: BeckonAccountLayoutPolicy.identityAvatarSize / 2, placeholderSize: 30)
            }
        } placeholder: {
            BeckonAccountIdentitySkeleton(roleTitle: "Groomer", roleSystemImage: "scissors", roleAccent: .groomer)
        }

        // What a groomer changes every week, as two tiles: the menu and prices, and the days that are open.
        waits {
            DesignShortcutRow {
                DesignShortcutTile(title: "Services", summary: presentation.servicesSummary, systemImage: "scissors") {
                    GroomerServicesEditorView(store: store)
                }
                .accessibilityIdentifier("groomer.account.services")
                DesignShortcutTile(title: "Availability", summary: presentation.availabilitySummary, systemImage: "calendar") {
                    GroomerAvailabilityEditorView(store: store)
                }
                .accessibilityIdentifier("groomer.account.availability")
            }
        } placeholder: {
            DesignShortcutRow {
                DesignShortcutTileSkeleton()
                DesignShortcutTileSkeleton()
            }
        }

        waits {
            section("Your profile") {
                row("Profile settings", presentation.profileSummary, "person.crop.circle", "groomer.account.edit-profile") {
                    GroomerProfileEditorView(store: store)
                }
                divider
                row("Portfolio", presentation.portfolioSummary, "photo.on.rectangle", "groomer.account.portfolio") {
                    GroomerPortfolioEditorView(store: store)
                }
            }
        } placeholder: {
            BeckonSettingsSectionSkeleton(summaries: [true, true])
        }

        waits {
            section("Pet fit") {
                row("Fit signals", presentation.fitSignalsSummary, "sparkles", "groomer.account.fit-signals") {
                    GroomerFitSignalsEditorView(store: store)
                }
                divider
                row("Evidence", presentation.evidenceSummary, "chart.bar.xaxis", "groomer.account.evidence") {
                    GroomerEvidenceDashboardView(store: store)
                }
            }
        } placeholder: {
            BeckonSettingsSectionSkeleton(summaries: [true, true])
        }

        waits {
            BeckonSection("Help") {
                AccountReleaseLinksSection(accent: .groomer)
            }
        } placeholder: {
            BeckonSettingsSectionSkeleton(summaries: [false, false])
        }

        waits {
            BeckonSection("Account access") {
                Button(action: onSignOut) {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "rectangle.portrait.and.arrow.right").accessibilityHidden(true)
                        Text("Sign out")
                    }
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.ledgePrimaryButtonHeight)
                }
                .buttonStyle(BeckonLedgeButtonStyle(.card))
                .accessibilityIdentifier("groomer.account.sign-out")
            }
        } placeholder: {
            VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
                DesignSkeletonLine(width: 0.4, font: DesignTokens.Typography.Expressive.section)
                    .designSkeletonOnPage()
                    .designSkeleton(label: nil)
                AccountDangerActionsSkeleton(showsDelete: false)
            }
        }
    }

    private func waits<Content: View, Placeholder: View>(@ViewBuilder _ content: () -> Content,
                                                         @ViewBuilder placeholder: () -> Placeholder) -> some View {
        DesignReveal(isLoading: !settled && store.profile == nil && store.cachedProfileSnapshot == nil, content: content, placeholder: placeholder)
    }

    /// A plain heading over one grouped card of rows, as the customer's Help and Account access.
    private func section<Rows: View>(_ title: String, @ViewBuilder rows: () -> Rows) -> some View {
        BeckonSection(title) {
            BeckonGroupedSurface {
                VStack(spacing: 0) { rows() }
            }
        }
    }

    private var divider: some View {
        BeckonGroupedDivider(leadingInset: BeckonAccountLayoutPolicy.groupedRowDividerLeadingInset)
    }

    private func row<Destination: View>(_ title: String, _ summary: String, _ systemImage: String, _ identifier: String,
                                        @ViewBuilder destination: @escaping () -> Destination) -> some View {
        BeckonSettingsNavigationRow(title: title, summary: summary, systemImage: systemImage, accent: .groomer) {
            destination()
        }
        .accessibilityIdentifier(identifier)
    }

    /// The profile could not be read at all: say so, and offer to try again or leave.
    private func unavailable(_ message: String) -> some View {
        BeckonErrorBanner(title: "Account unavailable", message: message) {
            VStack(spacing: DesignTokens.Spacing.sm) {
                Button { Task { await store.load() } } label: {
                    DesignQuietAction(title: "Try again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(BeckonGuardedPlainButtonStyle())
                .disabled(store.isBusy)
                Button(action: onSignOut) {
                    DesignQuietAction(title: "Sign out", systemImage: "rectangle.portrait.and.arrow.right", isDestructive: true)
                }
                .buttonStyle(BeckonGuardedPlainButtonStyle())
            }
        }
        .accessibilityIdentifier("groomer.account.error")
    }
}

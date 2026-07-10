import SwiftUI

struct GroomerOffersContentView: View {
    let store: GroomerOffersStore

    @ViewBuilder
    var body: some View {
        if store.isLoading, store.offers.isEmpty {
            BeckonLoadingView(
                title: "Loading Offers…",
                message: "We are collecting your pending and past customer offers.",
                accent: .groomer
            )
            .accessibilityIdentifier("groomer.offers.loading")
        } else {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                if store.offers.isEmpty {
                    emptyOrErrorState
                } else {
                    ForEach(store.sections) { section in
                        GroomerOfferSectionView(section: section)
                    }

                    if let errorMessage = store.errorMessage {
                        BeckonErrorBanner(
                            title: "More Offers Unavailable",
                            message: errorMessage
                        )
                        .accessibilityIdentifier("groomer.offers.load-more-error")
                    }

                    if store.canLoadMore || store.isLoadingMore {
                        BeckonLoadMoreButton(
                            isLoading: store.isLoadingMore,
                            accent: .groomer,
                            accessibilityIdentifier: "groomer.offers.load-more"
                        ) {
                            await store.loadNextPage()
                        }
                    }
                }
            }
            .accessibilityIdentifier("groomer.offers.list")
        }
    }

    @ViewBuilder
    private var emptyOrErrorState: some View {
        if let errorMessage = store.errorMessage {
            BeckonErrorBanner(
                title: "Offers Unavailable",
                message: errorMessage
            ) {
                Button {
                    Task {
                        await store.load()
                    }
                } label: {
                    Label("Try Again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(BeckonSecondaryButtonStyle(accent: .groomer))
                .disabled(store.isLoading)
            }
            .accessibilityIdentifier("groomer.offers.error")
        } else {
            BeckonEmptyState(
                title: "No Offers Yet",
                message: "Offers you submit from matched requests will appear here with their latest customer status.",
                systemImage: "tag",
                accent: .groomer
            ) {
                Button {
                    Task {
                        await store.load()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(BeckonSecondaryButtonStyle(accent: .groomer))
                .disabled(store.isLoading)
            }
            .accessibilityIdentifier("groomer.offers.empty")
        }
    }
}

private struct GroomerOfferSectionView: View {
    let section: GroomerOfferListSection

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text(section.status.sectionTitle)
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                Spacer()

                Text("\(section.offers.count)")
                    .font(DesignTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .monospacedDigit()
            }

            GroomerGroupedSurface {
                VStack(spacing: 0) {
                    ForEach(Array(section.offers.enumerated()), id: \.element.id) { index, item in
                        if index > 0 {
                            GroomerWorkspaceDivider(leadingInset: DesignTokens.Spacing.lg)
                        }

                        NavigationLink {
                            GroomerOfferDetailView(item: item)
                        } label: {
                            GroomerOfferRow(item: item)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("groomer.offers.row")
                    }
                }
            }
        }
    }
}

private struct GroomerOfferRow: View {
    let item: GroomerOfferListItem

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                    Text(item.title)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: DesignTokens.Spacing.xs)

                    BeckonStatusChip(
                        item.offer.status.title,
                        systemImage: item.offer.status.offerListSystemImage,
                        tone: item.offer.status.offerListTone
                    )
                }

                Text(item.subtitle)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .lineLimit(1)

                Text(item.timeSummary)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .lineLimit(1)

                Text("\(item.offer.priceSummary) · \(item.offer.status.offerListDescription)")
                    .font(DesignTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(DesignTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.textTertiary)
                .frame(minHeight: 72)
                .accessibilityHidden(true)
        }
        .padding(DesignTokens.Spacing.md)
        .contentShape(Rectangle())
    }
}

struct GroomerOfferDetailView: View {
    let item: GroomerOfferListItem

    var body: some View {
        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    GroomerOfferHero(item: item)
                    GroomerOfferFactsCard(item: item)

                    if let request = item.request {
                        GroomerOfferRequestCard(request: request)
                    }

                    if let booking = item.booking {
                        GroomerOfferBookingCard(booking: booking)
                    }

                    if let message = item.offer.message,
                       !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        GroomerOfferMessageCard(message: message)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.vertical, DesignTokens.Spacing.lg)
            }
        }
        .navigationTitle("Offer")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("groomer.offers.detail")
    }
}

private struct GroomerOfferHero: View {
    let item: GroomerOfferListItem

    var body: some View {
        BeckonCard {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(item.title)
                        .font(DesignTokens.Typography.title)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Offer \(item.offer.referenceCode)")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                BeckonStatusChip(
                    item.offer.status.title,
                    systemImage: item.offer.status.offerListSystemImage,
                    tone: item.offer.status.offerListTone
                )
            }
        }
    }
}

private struct GroomerOfferFactsCard: View {
    let item: GroomerOfferListItem

    var body: some View {
        BeckonCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Text("Offer Details")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                GroomerOfferFactRow(
                    title: "Price",
                    value: item.offer.priceSummary,
                    systemImage: "dollarsign.circle"
                )
                GroomerOfferFactRow(
                    title: "Proposed Start",
                    value: GroomingRequestDateFormatting.displayString(
                        from: item.offer.proposedStart
                    ),
                    systemImage: "calendar"
                )
                GroomerOfferFactRow(
                    title: "Proposed End",
                    value: GroomingRequestDateFormatting.displayString(
                        from: item.offer.proposedEnd
                    ),
                    systemImage: "clock"
                )
                GroomerOfferFactRow(
                    title: "Status",
                    value: item.offer.status.title,
                    systemImage: item.offer.status.offerListSystemImage
                )
                if let createdAt = item.offer.createdAt {
                    GroomerOfferFactRow(
                        title: "Submitted",
                        value: GroomingRequestDateFormatting.displayString(from: createdAt),
                        systemImage: "paperplane"
                    )
                }
            }
        }
    }
}

private struct GroomerOfferRequestCard: View {
    let request: GroomerMatchedGroomingRequest

    var body: some View {
        BeckonCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Text("Request")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                GroomerOfferFactRow(
                    title: "Pet",
                    value: request.petSnapshot.name,
                    systemImage: "pawprint.fill"
                )
                GroomerOfferFactRow(
                    title: "Service",
                    value: request.serviceType.title,
                    systemImage: "scissors"
                )
                GroomerOfferFactRow(
                    title: "Location",
                    value: request.locationSummary,
                    systemImage: "mappin.and.ellipse"
                )
                GroomerOfferFactRow(
                    title: "Request Status",
                    value: request.status.title,
                    systemImage: "tray.full"
                )
            }
        }
    }
}

private struct GroomerOfferBookingCard: View {
    let booking: Booking

    var body: some View {
        BeckonCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Text("Booking")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                GroomerOfferFactRow(
                    title: "Booking Ref",
                    value: booking.referenceCode,
                    systemImage: "checkmark.seal"
                )
                GroomerOfferFactRow(
                    title: "Schedule",
                    value: booking.scheduledTimeSummary,
                    systemImage: "calendar"
                )
                GroomerOfferFactRow(
                    title: "Booking Status",
                    value: booking.status.title,
                    systemImage: "clock"
                )
            }
        }
    }
}

private struct GroomerOfferMessageCard: View {
    let message: String

    var body: some View {
        BeckonCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Message")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                Text(message)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct GroomerOfferFactRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                .frame(
                    width: DesignTokens.Spacing.xl,
                    height: DesignTokens.Spacing.xl
                )
                .background(DesignTokens.Colors.groomerAccent.opacity(0.14))
                .clipShape(DesignTokens.Shapes.circular)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)

                Text(value)
                    .font(DesignTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

struct GroomerOffersStatusView: View {
    let store: GroomerOffersStore

    var body: some View {
        BeckonGlobalFeedbackForwarder(error: errorPrompt)
    }

    private var errorPrompt: BeckonGlobalFeedbackError? {
        guard let errorMessage = store.errorMessage else { return nil }
        return BeckonGlobalFeedbackError(
            scope: .page("groomer.requests.offers"),
            sourceKey: "groomer.requests.offers.error",
            title: "Offers Unavailable",
            message: errorMessage
        )
    }
}

private extension GroomerOfferStatus {
    var sectionTitle: String {
        switch self {
        case .pending:
            "Pending"
        case .acceptedByCustomer:
            "Accepted"
        case .declinedByCustomer:
            "Declined"
        case .withdrawnByGroomer:
            "Withdrawn"
        case .expired:
            "Expired"
        case .unknown:
            "Unknown"
        }
    }

    var offerListTone: BeckonStatusChip.Tone {
        switch self {
        case .pending:
            .warning
        case .acceptedByCustomer:
            .success
        case .declinedByCustomer, .expired:
            .error
        case .withdrawnByGroomer, .unknown:
            .neutral
        }
    }

    var offerListSystemImage: String {
        switch self {
        case .pending:
            "paperplane.fill"
        case .acceptedByCustomer:
            "checkmark.seal.fill"
        case .declinedByCustomer:
            "xmark.circle.fill"
        case .withdrawnByGroomer:
            "arrow.uturn.backward.circle"
        case .expired:
            "clock.badge.exclamationmark"
        case .unknown:
            "questionmark.circle"
        }
    }

    var offerListDescription: String {
        switch self {
        case .pending:
            "Waiting for customer confirmation."
        case .acceptedByCustomer:
            "Accepted by the customer."
        case .declinedByCustomer:
            "Declined by the customer."
        case .withdrawnByGroomer:
            "Withdrawn by you."
        case .expired:
            "Expired before customer acceptance."
        case .unknown:
            "Status unavailable. Refresh before taking action."
        }
    }
}

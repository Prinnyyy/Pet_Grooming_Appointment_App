// What the Grooming page and Home's Next up share: the load-failure banner, the photo-upload retries, the empty copy, the
// reminder notice.
import Foundation

import SwiftUI


/// What a list of requests is showing: loading, a load error, nothing, or the cards. Home's Next up section uses it.
enum GroomingCollectionState: Equatable {
    case loading
    case empty
    case error(String)
    case loaded
}


struct GroomingCollectionPresentation: Equatable {
    let activeCardCount: Int
    let closedRequestCount: Int
    let photoRetryCount: Int
    let isLoading: Bool
    let loadErrorMessage: String?

    var state: GroomingCollectionState {
        if activeCardCount > 0 || closedRequestCount > 0 || photoRetryCount > 0 {
            return .loaded
        }
        if isLoading {
            return .loading
        }
        if let message = loadErrorMessage?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !message.isEmpty {
            return .error(message)
        }
        return .empty
    }
}

struct GroomingLoadFailureBanner: View {
    let message: String
    var accessibilityIdentifier = "customer.requests.load-error"
    let retry: () -> Void

    var body: some View {
        BeckonErrorBanner(
            title: "Grooming didn't load",
            message: message,
            systemImage: "arrow.clockwise.circle"
        ) {
            Button(action: retry) {
                Text("Try again")
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
            }
            .buttonStyle(BeckonLedgeButtonStyle(.card))
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}


struct GroomingPhotoUploadRetryPresentation: Equatable {
    let title: String
    let message: String
    let retryTitle = "Retry Upload"
    let discardTitle = "Remove Photos"

    init(photoCount: Int) {
        let count = max(1, photoCount)
        if count == 1 {
            title = "1 request photo needs uploading"
            message = "The request was published, but this photo was not uploaded."
        } else {
            title = "\(count) request photos need uploading"
            message = "The request was published, but these photos were not uploaded."
        }
    }
}


struct GroomingPhotoUploadRetryBanner: View {
    let retry: CustomerRequestPhotoUploadRetry
    let isRetrying: Bool
    let retryAction: () -> Void
    let discardAction: () -> Void

    var body: some View {
        let presentation = GroomingPhotoUploadRetryPresentation(
            photoCount: retry.photos.count
        )
        BeckonErrorBanner(
            title: presentation.title,
            message: presentation.message,
            systemImage: "photo.badge.exclamationmark"
        ) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    actions(presentation: presentation)
                }

                VStack(spacing: DesignTokens.Spacing.sm) {
                    actions(presentation: presentation)
                }
            }
        }
        .accessibilityIdentifier(
            "customer.requests.photo-retry.\(retry.requestID.uuidString)"
        )
    }

    @ViewBuilder
    private func actions(
        presentation: GroomingPhotoUploadRetryPresentation
    ) -> some View {
        Button(action: retryAction) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if isRetrying {
                    ProgressView().tint(DesignTokens.Colors.customerInk)
                    Text("Uploading...")
                } else {
                    Image(systemName: "arrow.clockwise")
                    Text(presentation.retryTitle)
                }
            }
            .font(DesignTokens.Typography.Expressive.emphasis)
            .foregroundStyle(DesignTokens.Colors.customerInk)
            .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.minimumTouchTarget)
        }
        .buttonStyle(BeckonLedgeButtonStyle(.pill))
        .disabled(isRetrying)

        Button(role: .destructive, action: discardAction) {
            DesignQuietAction(title: presentation.discardTitle, systemImage: "trash", isDestructive: true)
        }
        .buttonStyle(BeckonGuardedPlainButtonStyle())
        .disabled(isRetrying)
    }
}


struct GroomingPhotoUploadRetryList: View {
    let store: CustomerRequestsStore

    var body: some View {
        ForEach(store.requestPhotoUploadRetries) { retry in
            GroomingPhotoUploadRetryBanner(
                retry: retry,
                isRetrying: store.isRetryingRequestPhotos(
                    for: retry.requestID
                ),
                retryAction: {
                    Task {
                        await store.retryRequestPhotos(
                            for: retry.requestID
                        )
                    }
                },
                discardAction: {
                    store.discardRequestPhotoUploadRetry(
                        for: retry.requestID
                    )
                }
            )
        }
    }
}


enum GroomingEmptyCopy {
    static let title = "No active grooming"
    static let message = "Your requests and booked appointments will appear here."
}




/// "Reminders are off" as one slim row: what is wrong in four words, what to do in one line, and the button that does it (iOS
/// Settings). The store's sentence is long and says the same thing twice, so it is only shown as is for a message we do not know.
struct GroomingReminderNotice: View {
    let message: String
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var typeSize

    private var isOff: Bool { message.hasPrefix("Appointment reminders are off") }

    var body: some View {
        (typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.sm))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DesignTokens.Spacing.md))) {
            HStack(spacing: DesignTokens.Spacing.md) {
                DesignIconDisc(systemImage: "bell.slash.fill")
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(isOff ? "Reminders are off" : "Reminders")
                        .font(DesignTokens.Typography.Expressive.emphasis)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                    Text(isOff ? "Allow notifications to get alerts before appointments." : message)
                        .font(DesignTokens.Typography.Expressive.chip)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if isOff {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } label: {
                    Text("Settings")
                        .font(DesignTokens.Typography.Expressive.emphasis)
                        .foregroundStyle(DesignTokens.Colors.customerDeep)
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
                        .background(DesignTokens.Colors.customerTint, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(BeckonGuardedPlainButtonStyle())
                .accessibilityHint("Opens iOS Settings so you can allow notifications.")
            }
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .beckonLedge(.card)
        .accessibilityElement(children: .contain)
    }
}

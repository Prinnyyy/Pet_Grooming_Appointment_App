import Combine
import MapKit
import PhotosUI
import SwiftUI
import UIKit

struct GroomerProfileManagementView: View {
    @State private var store: GroomerProfileStore
    let accountContent: AnyView?
    let onSignOut: (() -> Void)?

    init(
        groomerID: UUID,
        repository: any GroomerProfileRepository,
        accountContent: AnyView? = nil,
        onSignOut: (() -> Void)? = nil
    ) {
        _store = State(
            initialValue: GroomerProfileStore(
                groomerID: groomerID,
                repository: repository
            )
        )
        self.accountContent = accountContent
        self.onSignOut = onSignOut
    }

    var body: some View {
        @Bindable var store = store

        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()

            if store.isLoading, store.profile == nil {
                GroomlyLoadingView(
                    title: "Loading Groomer Profile…",
                    message: "We are preparing your profile, services, and portfolio settings.",
                    accent: .groomer
                )
                .accessibilityIdentifier("groomer.profile.loading")
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        GroomerAccountHomeView(
                            store: store,
                            accountContent: accountContent,
                            onSignOut: onSignOut
                        )
                    }
                    .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                    .padding(.top, DesignTokens.Spacing.xl)
                    .padding(.bottom, 120)
                }
                .accessibilityIdentifier("groomer.account.home")
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            GroomerProfileStatusView(store: store)
        }
        .sheet(isPresented: $store.isShowingServiceForm) {
            GroomerServiceFormView(store: store)
        }
        .task {
            await store.load()
        }
    }
}

private struct GroomerAccountHomeView: View {
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
                profile: store.profile,
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
    let profile: GroomerProfile?
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
                    Text(profile?.businessName ?? "Groomer Profile")
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(ratingSummary)
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

    private var ratingSummary: String {
        guard let profile, profile.ratingCount > 0 else {
            return "★ New profile"
        }

        return "★ \(profile.ratingAverage.formatted(.number.precision(.fractionLength(1)))) · \(profile.ratingCount) review\(profile.ratingCount == 1 ? "" : "s")"
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

private struct GroomerAvatarImage: View {
    let data: Data?
    let size: CGFloat
    let cornerRadius: CGFloat
    let placeholderSize: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    DesignTokens.Colors.groomerAccent.opacity(0.28),
                    DesignTokens.Colors.customerPrimary.opacity(0.34),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text("👩🏻")
                    .font(.system(size: placeholderSize))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }

    private var image: UIImage? {
        guard let data else { return nil }
        return UIImage(data: data)
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

private struct GroomerProfileEditorView: View {
    @Bindable var store: GroomerProfileStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                GroomlySectionHeader(
                    "Profile Details",
                    subtitle: "Update the public details customers see before they book."
                )

                GroomerAvatarEditorSection(store: store)
                GroomerProfileFormSection(store: store)
            }
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.top, DesignTokens.Spacing.lg)
            .padding(.bottom, 120)
        }
        .background(DesignTokens.Colors.background.ignoresSafeArea())
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            GroomerProfileStatusView(store: store)
        }
        .accessibilityIdentifier("groomer.profile.edit")
    }
}

private struct GroomerServicesEditorView: View {
    @Bindable var store: GroomerProfileStore

    var body: some View {
        ScrollView {
            GroomerServicesSection(store: store)
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.top, DesignTokens.Spacing.lg)
                .padding(.bottom, 120)
        }
        .background(DesignTokens.Colors.background.ignoresSafeArea())
        .navigationTitle("Services")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("groomer.services.edit")
    }
}

private struct GroomerPortfolioEditorView: View {
    @Bindable var store: GroomerProfileStore

    var body: some View {
        ScrollView {
            GroomerPortfolioSection(store: store)
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.top, DesignTokens.Spacing.lg)
                .padding(.bottom, 120)
        }
        .background(DesignTokens.Colors.background.ignoresSafeArea())
        .navigationTitle("Portfolio")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("groomer.portfolio.edit")
    }
}

private struct GroomerFitSignalsEditorView: View {
    @Bindable var store: GroomerProfileStore
    @State private var successNoticeMessage: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                GroomlySectionHeader(
                    "Fit Signals",
                    subtitle: "Keep your core skills focused while size experience stays separate."
                )

                GroomerFitSignalOverviewCard(store: store)

                if let errorMessage = store.errorMessage {
                    GroomlyErrorBanner(
                        title: "Fit Signals Could Not Be Saved",
                        message: errorMessage
                    )
                    .accessibilityIdentifier("groomer.fit-signals.error")
                }

                ForEach(Self.visibleGroups) { group in
                    GroomerFitSignalGroupSection(
                        group: group,
                        signals: signals(for: group),
                        store: store
                    )
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.top, DesignTokens.Spacing.lg)
            .padding(.bottom, 156)
        }
        .background(DesignTokens.Colors.background.ignoresSafeArea())
        .navigationTitle("Fit Signals")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.ensureSizeBandFitClaimRange()
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: DesignTokens.Spacing.sm) {
                if let successNoticeMessage {
                    GroomlyNoticeToast(message: successNoticeMessage)
                        .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task(id: successNoticeMessage) {
                            await dismissSuccessNotice(successNoticeMessage)
                        }
                }

                GroomerFitSignalsSaveBar(store: store) { message in
                    withAnimation(.easeInOut(duration: 0.24)) {
                        successNoticeMessage = message
                    }
                    guard store.noticeMessage == message else { return }
                    store.noticeMessage = nil
                }
            }
        }
        .accessibilityIdentifier("groomer.fit-signals.edit")
    }

    private func dismissSuccessNotice(_ message: String) async {
        try? await Task.sleep(
            nanoseconds: GroomlyFeedbackCenter.noticeDismissDelayNanoseconds
        )
        guard !Task.isCancelled else { return }

        await MainActor.run {
            guard successNoticeMessage == message else { return }
            withAnimation(.easeInOut(duration: 0.24)) {
                successNoticeMessage = nil
            }
        }
    }

    private static var visibleGroups: [PetFitSignal.Group] {
        [.coatType, .careFlag, .serviceFit].filter { group in
            GroomerFitClaim.availableSignals.contains(where: {
                $0.group == group
            })
        }
    }

    private func signals(for group: PetFitSignal.Group) -> [PetFitSignal] {
        GroomerFitClaim.availableSignals.filter { $0.group == group }
    }
}

private struct GroomerFitSignalOverviewCard: View {
    @Bindable var store: GroomerProfileStore

    var body: some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(DesignTokens.Colors.surface)
                        .frame(width: 44, height: 44)
                        .background(DesignTokens.Colors.groomerAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Selection Balance")
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        Text("Core skills drive starter matching. Size bands add experience context without using that limit.")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
                        Text("Core Skills")
                            .font(DesignTokens.Typography.body.weight(.bold))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        Spacer(minLength: DesignTokens.Spacing.md)

                        Text("\(store.selectedCoreFitClaimCount)/\(GroomerFitClaim.maximumActiveClaims)")
                            .font(DesignTokens.Typography.body.weight(.bold))
                            .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    ProgressView(
                        value: Double(store.selectedCoreFitClaimCount),
                        total: Double(GroomerFitClaim.maximumActiveClaims)
                    )
                    .tint(DesignTokens.Colors.groomerAccent)

                    Text("Coat, handling, and service strengths")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                GroomerSizeExperienceRangeControl(store: store)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct GroomerSizeExperienceRangeControl: View {
    @Bindable var store: GroomerProfileStore

    private let sizeCodes = CustomerPetSizeCode.allCases

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Size Experience")
                        .font(DesignTokens.Typography.body.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)

                    Text("Acceptable pet size range")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(store.sizeBandFitClaimRangeTitle)
                    .font(DesignTokens.Typography.caption.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(DesignTokens.Colors.groomerAccent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityIdentifier("groomer.fit-signals.size-range-title")
            }

            GroomerSizeRangeSlider(
                lowerIndex: Binding(
                    get: { store.selectedSizeBandRange.lowerBound },
                    set: { newValue in
                        store.setSizeBandFitClaimRange(
                            lowerIndex: newValue,
                            upperIndex: store.selectedSizeBandRange.upperBound
                        )
                    }
                ),
                upperIndex: Binding(
                    get: { store.selectedSizeBandRange.upperBound },
                    set: { newValue in
                        store.setSizeBandFitClaimRange(
                            lowerIndex: store.selectedSizeBandRange.lowerBound,
                            upperIndex: newValue
                        )
                    }
                ),
                optionCount: sizeCodes.count,
                rangeTitle: store.sizeBandFitClaimRangeTitle
            )

            HStack(spacing: 0) {
                ForEach(sizeCodes) { code in
                    Text(code.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

private struct GroomerSizeRangeSlider: View {
    @Binding var lowerIndex: Int
    @Binding var upperIndex: Int
    let optionCount: Int
    let rangeTitle: String
    var accessibilityIdentifier = "groomer.fit-signals.size-range-slider"

    @State private var lowerDragStartIndex: Int?
    @State private var upperDragStartIndex: Int?

    private let thumbSize: CGFloat = 30
    private let hitSize: CGFloat = 48
    private let trackHeight: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            let trackWidth = max(proxy.size.width - thumbSize, 1)
            let lowerCenterX = centerX(for: lowerIndex, trackWidth: trackWidth)
            let upperCenterX = centerX(for: upperIndex, trackWidth: trackWidth)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DesignTokens.Colors.borderSoft)
                    .frame(width: trackWidth, height: trackHeight)
                    .offset(x: thumbSize / 2)

                Capsule()
                    .fill(DesignTokens.Colors.groomerAccent)
                    .frame(
                        width: max(upperCenterX - lowerCenterX, trackHeight),
                        height: trackHeight
                    )
                    .offset(x: lowerCenterX)

                ForEach(0..<optionCount, id: \.self) { index in
                    Circle()
                        .fill(
                            index >= lowerIndex && index <= upperIndex
                                ? DesignTokens.Colors.groomerAccentDark
                                : DesignTokens.Colors.textTertiary.opacity(0.45)
                        )
                        .frame(width: 6, height: 6)
                        .offset(
                            x: centerX(for: index, trackWidth: trackWidth) - 3,
                            y: 0
                        )
                        .accessibilityHidden(true)
                }

                GroomerSizeRangeThumb()
                    .frame(width: hitSize, height: hitSize)
                    .position(x: lowerCenterX, y: hitSize / 2)
                    .gesture(lowerThumbDrag(trackWidth: trackWidth))
                    .accessibilityLabel("Minimum size")
                    .accessibilityValue(rangeTitle)

                GroomerSizeRangeThumb()
                    .frame(width: hitSize, height: hitSize)
                    .position(x: upperCenterX, y: hitSize / 2)
                    .gesture(upperThumbDrag(trackWidth: trackWidth))
                    .accessibilityLabel("Maximum size")
                    .accessibilityValue(rangeTitle)
            }
        }
        .frame(height: hitSize)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func centerX(for index: Int, trackWidth: CGFloat) -> CGFloat {
        let maximumIndex = max(optionCount - 1, 1)
        let clampedIndex = min(max(index, 0), maximumIndex)
        return thumbSize / 2 + CGFloat(clampedIndex) / CGFloat(maximumIndex) * trackWidth
    }

    private func index(for centerX: CGFloat, trackWidth: CGFloat) -> Int {
        let maximumIndex = max(optionCount - 1, 1)
        let normalized = (centerX - thumbSize / 2) / trackWidth
        return min(max(Int((normalized * CGFloat(maximumIndex)).rounded()), 0), maximumIndex)
    }

    private func lowerThumbDrag(trackWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let startIndex = lowerDragStartIndex ?? lowerIndex
                lowerDragStartIndex = startIndex
                let startX = centerX(for: startIndex, trackWidth: trackWidth)
                let proposedIndex = index(
                    for: startX + value.translation.width,
                    trackWidth: trackWidth
                )
                lowerIndex = min(proposedIndex, upperIndex)
            }
            .onEnded { _ in
                lowerDragStartIndex = nil
            }
    }

    private func upperThumbDrag(trackWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let startIndex = upperDragStartIndex ?? upperIndex
                upperDragStartIndex = startIndex
                let startX = centerX(for: startIndex, trackWidth: trackWidth)
                let proposedIndex = index(
                    for: startX + value.translation.width,
                    trackWidth: trackWidth
                )
                upperIndex = max(proposedIndex, lowerIndex)
            }
            .onEnded { _ in
                upperDragStartIndex = nil
            }
    }
}

private struct GroomerSizeRangeThumb: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(DesignTokens.Colors.surface)
                .frame(width: 30, height: 30)
                .groomlyShadow(DesignTokens.Shadows.smallCard)

            Circle()
                .stroke(DesignTokens.Colors.groomerAccent, lineWidth: 3)
                .frame(width: 30, height: 30)

            Capsule()
                .fill(DesignTokens.Colors.groomerAccentDark)
                .frame(width: 4, height: 14)
        }
        .frame(width: 48, height: 48)
        .contentShape(Circle())
    }
}

private struct GroomerEvidenceDashboardView: View {
    @Bindable var store: GroomerProfileStore

    private var summaries: [GroomerPetFitEvidenceSummary] {
        store.sortedPetFitEvidenceSummary()
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                GroomlySectionHeader(
                    "Evidence Dashboard",
                    subtitle: "Completed bookings and structured reviews by pet-fit signal."
                ) {
                    GroomlyStatusChip(
                        "\(summaries.count) signal\(summaries.count == 1 ? "" : "s")",
                        systemImage: "sparkles",
                        tone: .groomer
                    )
                }

                GroomerEvidenceDashboardSummaryCard(summaries: summaries)

                if summaries.isEmpty {
                    GroomlyEmptyState(
                        title: "No Evidence Yet",
                        message: "Completed bookings and structured reviews will appear here as they accumulate.",
                        systemImage: "chart.bar.xaxis",
                        accent: .groomer
                    )
                    .accessibilityIdentifier("groomer.evidence.empty")
                } else {
                    ForEach(summaries) { summary in
                        GroomerEvidenceSummaryRow(summary: summary)
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.top, DesignTokens.Spacing.lg)
            .padding(.bottom, 120)
        }
        .background(DesignTokens.Colors.background.ignoresSafeArea())
        .navigationTitle("Evidence")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("groomer.evidence.dashboard")
    }
}

private struct GroomerEvidenceDashboardSummaryCard: View {
    let summaries: [GroomerPetFitEvidenceSummary]

    var body: some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                        .frame(width: 48, height: 48)
                        .background(DesignTokens.Colors.groomerAccent.opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Evidence Summary")
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        Text("Aggregate counts from completed care history")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: DesignTokens.Spacing.md) {
                    GroomerEvidenceMetricView(
                        value: totalCompletedBookings,
                        label: "Completed"
                    )

                    GroomerEvidenceMetricView(
                        value: totalPositiveOutcomes,
                        label: "Positive"
                    )

                    GroomerEvidenceMetricView(
                        value: highConfidenceCount,
                        label: "High Tier"
                    )
                }
            }
        }
    }

    private var totalCompletedBookings: Int {
        summaries.reduce(0) { $0 + $1.completedBookingCount }
    }

    private var totalPositiveOutcomes: Int {
        summaries.reduce(0) { $0 + $1.positiveReviewOutcomeCount }
    }

    private var highConfidenceCount: Int {
        summaries.filter { $0.confidenceTier == .high }.count
    }
}

private struct GroomerEvidenceMetricView: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(value.formatted())
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.76)

            Text(label)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct GroomerEvidenceSummaryRow: View {
    let summary: GroomerPetFitEvidenceSummary

    var body: some View {
        GroomlyCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    Image(systemName: iconName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                        .frame(width: 46, height: 46)
                        .background(DesignTokens.Colors.groomerAccent.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(summary.signal.title)
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(summary.signal.groupTitle)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    GroomlyStatusChip(
                        "\(summary.confidenceTier.title) confidence",
                        systemImage: confidenceIconName,
                        tone: confidenceTone
                    )
                }

                VStack(spacing: DesignTokens.Spacing.sm) {
                    GroomerEvidenceCountLine(
                        title: "Completed bookings",
                        value: summary.completedBookingCount
                    )
                    GroomerEvidenceCountLine(
                        title: "Positive review outcomes",
                        value: summary.positiveReviewOutcomeCount
                    )
                    GroomerEvidenceCountLine(
                        title: "Negative review outcomes",
                        value: summary.negativeReviewOutcomeCount
                    )
                    GroomerEvidenceCountLine(
                        title: "Structured review outcomes",
                        value: summary.structuredReviewOutcomeCount
                    )
                }

                if let updatedAt = summary.evidenceUpdatedAt {
                    Text("Updated \(GroomingRequestDateFormatting.displayString(from: updatedAt))")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var iconName: String {
        switch summary.signal.group {
        case .coatType:
            "comb"
        case .breedGroup:
            "pawprint.fill"
        case .sizeBand:
            "ruler"
        case .careFlag:
            "heart.fill"
        case .serviceFit:
            "scissors"
        }
    }

    private var confidenceIconName: String {
        switch summary.confidenceTier {
        case .high:
            "checkmark.seal.fill"
        case .medium:
            "checkmark.circle.fill"
        case .low:
            "circle"
        }
    }

    private var confidenceTone: GroomlyStatusChip.Tone {
        switch summary.confidenceTier {
        case .high:
            .success
        case .medium:
            .groomer
        case .low:
            .neutral
        }
    }
}

private struct GroomerEvidenceCountLine: View {
    let title: String
    let value: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
            Text(title)
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: DesignTokens.Spacing.md)

            Text(value.formatted())
                .font(DesignTokens.Typography.body.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
        }
    }
}

private struct GroomerFitSignalGroupSection: View {
    let group: PetFitSignal.Group
    let signals: [PetFitSignal]
    @Bindable var store: GroomerProfileStore

    var body: some View {
        GroomlyCard(padding: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    Image(systemName: iconName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                        .frame(width: 42, height: 42)
                        .background(DesignTokens.Colors.groomerAccent.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(title)
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(subtitle)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    GroomlyStatusChip(
                        statusText,
                        systemImage: statusIconName,
                        tone: group == .sizeBand ? .neutral : .groomer
                    )
                }

                VStack(spacing: 0) {
                    ForEach(signals) { signal in
                        GroomerFitSignalRow(
                            signal: signal,
                            isSelected: store.isFitClaimSelected(signal)
                        ) {
                            store.toggleFitClaim(signal)
                        }

                        if signal.id != signals.last?.id {
                            Divider()
                                .padding(.leading, DesignTokens.Spacing.sm)
                        }
                    }
                }
                .accessibilityElement(children: .contain)
            }
        }
    }

    private var selectedCount: Int {
        store.selectedFitClaimCount(in: group)
    }

    private var title: String {
        switch group {
        case .coatType:
            "Coat Skills"
        case .breedGroup:
            "Breed Groups"
        case .sizeBand:
            "Size Experience"
        case .careFlag:
            "Handling Needs"
        case .serviceFit:
            "Service Strengths"
        }
    }

    private var subtitle: String {
        switch group {
        case .coatType:
            "Coat structures you handle reliably."
        case .breedGroup:
            "Breed contexts kept for compatibility."
        case .sizeBand:
            "Body-size ranges you are comfortable grooming. These do not use core skill slots."
        case .careFlag:
            "Care situations you accept."
        case .serviceFit:
            "Service work that matches your setup."
        }
    }

    private var statusText: String {
        if group == .sizeBand {
            return selectedCount == 1 ? "1 extra" : "\(selectedCount) extra"
        }
        return selectedCount == 1 ? "1 selected" : "\(selectedCount) selected"
    }

    private var statusIconName: String {
        group == .sizeBand ? "plus.circle" : "checkmark.circle"
    }

    private var iconName: String {
        switch group {
        case .coatType:
            "comb"
        case .breedGroup:
            "pawprint.fill"
        case .sizeBand:
            "ruler"
        case .careFlag:
            "heart.fill"
        case .serviceFit:
            "scissors"
        }
    }
}

private struct GroomerFitSignalRow: View {
    let signal: PetFitSignal
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: DesignTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(signal.title)
                        .font(DesignTokens.Typography.body.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(
                        isSelected
                            ? DesignTokens.Colors.groomerAccent
                            : DesignTokens.Colors.textTertiary
                    )
                    .accessibilityHidden(true)
            }
            .padding(.vertical, DesignTokens.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(signal.title) fit signal")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

private struct GroomerFitSignalsSaveBar: View {
    @Bindable var store: GroomerProfileStore
    let onSaved: (String) -> Void

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("\(store.selectedCoreFitClaimCount)/\(GroomerFitClaim.maximumActiveClaims) core skills")
                        .font(DesignTokens.Typography.caption.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(sizeBandSummaryText)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    Task {
                        if let noticeMessage = await store.saveFitClaims() {
                            onSaved(noticeMessage)
                        }
                    }
                } label: {
                    if store.isSaving {
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            ProgressView()
                                .tint(DesignTokens.Colors.surface)
                            Text("Saving...")
                        }
                    } else {
                        Text("Save")
                    }
                }
                .buttonStyle(GroomlyPrimaryButtonStyle(accent: .groomer, isFullWidth: false))
                .disabled(store.isBusy)
                .accessibilityIdentifier("groomer.fit-signals.save")
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
        .padding(.top, DesignTokens.Spacing.md)
        .padding(.bottom, DesignTokens.Spacing.md)
        .background {
            Rectangle()
                .fill(DesignTokens.Colors.surfaceRaised)
                .ignoresSafeArea()
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(DesignTokens.Colors.borderSoft)
                        .frame(height: 1)
                }
        }
    }

    private var sizeBandSummaryText: String {
        store.sizeBandFitClaimRangeTitle
    }
}

private struct GroomerAvailabilityEditorView: View {
    @Bindable var store: GroomerProfileStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .bottom) {
            DesignTokens.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(DesignTokens.Colors.textPrimary)
                                .frame(width: 54, height: 54)
                                .background(DesignTokens.Colors.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
                                }
                        }
                        .accessibilityLabel("Back")

                        Text("Availability")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                    }
                    .padding(.top, DesignTokens.Spacing.md)

                    GroomerAvailabilityActiveCard(isActive: $store.isActive)

                    GroomerAvailabilityWeeklyHoursSection(dayStates: $store.availabilityDayStates)

                    GroomerBookingPreferencesSection(autoAcceptBookings: $store.autoAcceptBookings)

                    GroomerTimeOffSection(store: store)

                    if let errorMessage = store.errorMessage {
                        GroomlyErrorBanner(
                            title: "Availability Could Not Be Saved",
                            message: errorMessage
                        )
                        .accessibilityIdentifier("groomer.availability.error")
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.bottom, 132)
            }

            Button {
                Task {
                    await store.saveAvailability()
                }
            } label: {
                if store.isSaving {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        ProgressView()
                            .tint(DesignTokens.Colors.surface)
                        Text("Saving...")
                    }
                } else {
                    Text("Save Availability")
                }
            }
            .buttonStyle(GroomlyPrimaryButtonStyle(accent: .groomer))
            .disabled(store.isBusy)
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.bottom, DesignTokens.Spacing.lg)
            .background(
                LinearGradient(
                    colors: [
                        DesignTokens.Colors.background.opacity(0),
                        DesignTokens.Colors.background,
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea(edges: .bottom)
            )
            .accessibilityIdentifier("groomer.availability.save")
        }
        .sheet(isPresented: $store.isShowingTimeOffForm) {
            GroomerTimeOffFormView(store: store)
                .presentationDetents([.medium])
        }
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
        .accessibilityIdentifier("groomer.availability.edit")
    }
}

private struct GroomerAvailabilityActiveCard: View {
    @Binding var isActive: Bool

    var body: some View {
        GroomlyCard {
            HStack(spacing: DesignTokens.Spacing.lg) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isActive ? DesignTokens.Colors.success : DesignTokens.Colors.textSecondary)
                    .frame(width: 54, height: 54)
                    .background((isActive ? DesignTokens.Colors.success : DesignTokens.Colors.borderSoft).opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Available for requests")
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Matching requests can be sent to you during available windows.")
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Toggle("Available for requests", isOn: $isActive)
                    .labelsHidden()
                    .tint(DesignTokens.Colors.success)
            }
        }
    }
}

private struct GroomerAvailabilityWeeklyHoursSection: View {
    @Binding var dayStates: [GroomerAvailabilityDayState]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                Text("Weekly Hours")
                    .font(DesignTokens.Typography.caption.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .textCase(.uppercase)

                Spacer()

                Text("\(dayStates.filter(\.isEnabled).count) days open")
                    .font(DesignTokens.Typography.caption.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.groomerAccent)
            }

            GroomlyCard(padding: DesignTokens.Spacing.md) {
                VStack(spacing: 0) {
                    ForEach($dayStates) { $dayState in
                        GroomerAvailabilityDayRow(dayState: $dayState)

                        if dayState.weekday != dayStates.last?.weekday {
                            Divider()
                                .padding(.leading, 78)
                        }
                    }
                }
            }

            Text("Tap a time to adjust your hours for that day.")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary.opacity(0.76))
                .padding(.horizontal, DesignTokens.Spacing.sm)
        }
    }
}

private struct GroomerAvailabilityDayRow: View {
    @Binding var dayState: GroomerAvailabilityDayState

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Text(dayState.weekday.shortTitle)
                .font(DesignTokens.Typography.body.weight(.bold))
                .foregroundStyle(dayState.isEnabled ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textSecondary)
                .frame(width: 42, alignment: .leading)

            if dayState.isEnabled {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    GroomerAvailabilityTimeMenu(minutes: $dayState.startMinutes)

                    Text("-")
                        .font(DesignTokens.Typography.body.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .frame(width: 10)

                    GroomerAvailabilityTimeMenu(minutes: $dayState.endMinutes)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Unavailable")
                    .font(DesignTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Toggle(dayState.weekday.title, isOn: $dayState.isEnabled)
                .labelsHidden()
                .tint(DesignTokens.Colors.groomerAccent)
        }
        .frame(minHeight: 72)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .animation(.easeInOut(duration: 0.18), value: dayState.isEnabled)
    }
}

private struct GroomerAvailabilityTimeMenu: View {
    @Binding var minutes: Int

    var body: some View {
        Menu {
            ForEach(Self.timeOptions, id: \.self) { option in
                Button(GroomerAvailabilityWindow.displayTime(fromMinutes: option)) {
                    minutes = option
                }
            }
        } label: {
            Text(GroomerAvailabilityWindow.displayTime(fromMinutes: minutes))
                .font(DesignTokens.Typography.body.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .frame(width: 78, alignment: .center)
                .frame(minHeight: 54)
                .background(DesignTokens.Colors.borderSoft.opacity(0.42))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private static let timeOptions: [Int] = stride(
        from: 6 * 60,
        through: 22 * 60,
        by: 30
    )
    .map { $0 }
}

private struct GroomerBookingPreferencesSection: View {
    @Binding var autoAcceptBookings: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Request Preferences")
                .font(DesignTokens.Typography.caption.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .textCase(.uppercase)

            GroomlyCard {
                HStack(spacing: DesignTokens.Spacing.md) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Auto-ready during open hours")
                            .font(DesignTokens.Typography.body.weight(.bold))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        Text("Use your open hours when checking request and offer availability.")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Toggle("Auto-ready during open hours", isOn: $autoAcceptBookings)
                        .labelsHidden()
                        .tint(DesignTokens.Colors.groomerAccent)
                }
            }
        }
    }
}

private struct GroomerTimeOffSection: View {
    @Bindable var store: GroomerProfileStore

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Time Off")
                .font(DesignTokens.Typography.caption.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .textCase(.uppercase)

            VStack(spacing: DesignTokens.Spacing.md) {
                ForEach(store.timeOffWindows) { window in
                    GroomerTimeOffRow(window: window) {
                        Task {
                            await store.deleteTimeOff(window)
                        }
                    }
                }

                Button {
                    store.startCreateTimeOff()
                } label: {
                    Label("Add time off", systemImage: "plus")
                        .font(DesignTokens.Typography.body.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.Spacing.lg)
                        .background(DesignTokens.Colors.background)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous)
                                .stroke(
                                    DesignTokens.Colors.border.opacity(0.55),
                                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
                                )
                        }
                }
                .buttonStyle(.plain)
                .disabled(store.isBusy)
            }
        }
    }
}

private struct GroomerTimeOffRow: View {
    let window: GroomerTimeOffWindow
    let onDelete: () -> Void

    var body: some View {
        GroomlyCard {
            HStack(spacing: DesignTokens.Spacing.md) {
                Text(icon)
                    .font(.system(size: 24))
                    .frame(width: 54, height: 54)
                    .background(DesignTokens.Colors.borderSoft.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(window.title)
                        .font(DesignTokens.Typography.body.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)

                    Text(window.dateSummary)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("Remove \(window.title)")
            }
        }
    }

    private var icon: String {
        window.title.localizedCaseInsensitiveContains("workshop") ? "📚" : "🏖️"
    }
}

private struct GroomerTimeOffFormView: View {
    @Bindable var store: GroomerProfileStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Time Off") {
                    TextField("Title", text: $store.timeOffTitle)
                    DatePicker(
                        "Start Date",
                        selection: $store.timeOffStartDate,
                        displayedComponents: .date
                    )
                    DatePicker(
                        "End Date",
                        selection: $store.timeOffEndDate,
                        displayedComponents: .date
                    )
                }

                if let errorMessage = store.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(DesignTokens.Colors.error)
                    }
                }
            }
            .navigationTitle("Add time off")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        store.cancelTimeOffForm()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            await store.createTimeOff()
                            if !store.isShowingTimeOffForm {
                                dismiss()
                            }
                        }
                    }
                    .disabled(store.isBusy)
                }
            }
        }
    }
}

private struct GroomerAvatarEditorSection: View {
    @Bindable var store: GroomerProfileStore
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        let hasSavedPhoto = store.profile?.avatarPath != nil
        let photoStatusText = hasSavedPhoto ? "Photo saved to your profile." : "Add a clear face photo."
        let photoActionTitle = hasSavedPhoto ? "Replace Photo" : "Upload Photo"
        let isBusy = store.isBusy

        GroomlyCard {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.lg) {
                ZStack(alignment: .bottomTrailing) {
                    GroomerAvatarImage(
                        data: store.avatarPhotoData,
                        size: 94,
                        cornerRadius: 28,
                        placeholderSize: 38
                    )

                    if hasSavedPhoto {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(DesignTokens.Colors.success)
                            .background(Circle().fill(DesignTokens.Colors.surface))
                            .accessibilityLabel("Profile photo saved")
                    }
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Profile Photo")
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        Text(photoStatusText)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(
                            photoActionTitle,
                            systemImage: "camera"
                        )
                    }
                    .buttonStyle(GroomlySecondaryButtonStyle(accent: .groomer))
                    .disabled(isBusy)
                    .accessibilityIdentifier("groomer.profile.avatar.upload")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await upload(newItem)
            }
        }
    }

    private func upload(_ item: PhotosPickerItem) async {
        defer { selectedPhotoItem = nil }

        guard let data = try? await item.loadTransferable(type: Data.self) else {
            store.errorMessage = "We could not read that photo."
            return
        }

        let contentType = item.supportedContentTypes
            .lazy
            .compactMap(GroomerAvatarPhotoContentType.init(uniformType:))
            .first ?? .jpeg

        guard let payload = GroomerAvatarImageEncoder.displayablePayload(
            from: data,
            preferredContentType: contentType
        ) else {
            store.errorMessage = "We could not read that photo."
            return
        }

        await store.uploadAvatarPhoto(
            data: payload.data,
            contentType: payload.contentType
        )
    }
}

private struct GroomerProfileFormSection: View {
    @Bindable var store: GroomerProfileStore

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                GroomlySectionHeader(
                    "Marketplace Profile",
                    subtitle: "Complete these fields before making your profile active."
                ) {
                    if let profile = store.profile {
                        GroomlyStatusChip(
                            profile.isActive ? "Active" : "Hidden",
                            systemImage: profile.isActive ? "checkmark.circle.fill" : "eye.slash",
                            tone: profile.isActive ? .success : .neutral
                        )
                    }
                }

                GroomlyCard {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        GroomerProfileTextField(
                            title: "Business Name",
                            text: $store.businessName,
                            prompt: "Business Name"
                        )
                        .textContentType(.organizationName)

                        GroomerProfileTextField(
                            title: "Biography",
                            text: $store.bio,
                            prompt: "Biography",
                            axis: .vertical
                        )
                        .lineLimit(3...6)

                        GroomerExperiencePicker(selection: $store.yearsExperience)
                    }
                }
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                GroomlySectionHeader(
                    "Address",
                    subtitle: "Use the address customers visit, or your base address for mobile appointments."
                )

                GroomlyCard {
                    GroomerProfileAddressFields(
                        streetAddress: $store.baseStreetAddress,
                        city: $store.baseCity,
                        stateCode: $store.baseStateCode,
                        zipCode: $store.baseZipCode
                    )
                }
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                GroomlySectionHeader(
                    "Service Settings",
                    subtitle: "Choose where you work and how far you travel."
                )

                GroomlyCard {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        GroomerProfileRadiusSlider(radius: $store.serviceRadiusMiles)
                        GroomerProfileLocationModePicker(selection: $store.serviceLocationModes)
                    }
                }
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                GroomlySectionHeader(
                    "Profile Visibility",
                    subtitle: "Turn this on when your profile is ready to receive customers."
                )

                GroomlyCard {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        GroomlyToggleRow(
                            title: "Visible to Authenticated Customers",
                            subtitle: "Customers can discover and receive offers from active groomer profiles.",
                            systemImage: "eye",
                            isOn: $store.isActive
                        )

                        if let profile = store.profile {
                            ProfileBadges(profile: profile)
                        }
                    }
                }
            }

            Button {
                Task {
                    await store.saveProfile()
                }
            } label: {
                if store.isSaving {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        ProgressView()
                            .tint(DesignTokens.Colors.surface)
                        Text("Saving…")
                    }
                } else {
                    Label("Save Profile", systemImage: "checkmark.circle")
                }
            }
            .buttonStyle(GroomlyPrimaryButtonStyle(accent: .groomer))
            .disabled(store.isBusy)
            .accessibilityIdentifier("groomer.profile.save")

            if store.profile == nil {
                Text("Save your profile once these details are ready.")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct GroomerServicesSection: View {
    @Bindable var store: GroomerProfileStore

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GroomlySectionHeader(
                "Services",
                subtitle: "Services inherit Fit Signals size experience unless a custom service range is enabled."
            ) {
                Button {
                    store.startCreateService()
                } label: {
                    Label("Add Service", systemImage: "plus")
                }
                .buttonStyle(GroomlySecondaryButtonStyle(accent: .groomer, isFullWidth: false))
                .disabled(store.isBusy)
                .accessibilityIdentifier("groomer.services.add")
            }

            if store.services.isEmpty {
                GroomlyEmptyState(
                    title: "No Services Yet",
                    message: "Add services before responding to future requests.",
                    systemImage: "scissors",
                    accent: .groomer
                ) {
                    Button {
                        store.startCreateService()
                    } label: {
                        Label("Add Service", systemImage: "plus")
                    }
                    .buttonStyle(GroomlySecondaryButtonStyle(accent: .groomer))
                    .disabled(store.isBusy)
                }
                .accessibilityIdentifier("groomer.services.empty")
            } else {
                VStack(spacing: DesignTokens.Spacing.md) {
                    ForEach(store.services) { service in
                        GroomerServiceRow(
                            service: service,
                            store: store
                        )
                    }
                }
            }
        }
    }
}

private struct GroomerServiceRow: View {
    let service: GroomerService
    @Bindable var store: GroomerProfileStore

    var body: some View {
        GroomlyCard {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text(service.title)
                                .font(DesignTokens.Typography.headline)
                                .foregroundStyle(DesignTokens.Colors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("$\(service.basePrice, specifier: "%.2f") • \(service.durationMinutes) min")
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(DesignTokens.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        GroomlyStatusChip(
                            service.isActive ? "Visible" : "Hidden",
                            systemImage: service.isActive ? "eye.fill" : "eye.slash",
                            tone: service.isActive ? .success : .neutral
                        )
                    }

                    Label(store.serviceSizePolicySummary(for: service), systemImage: "ruler")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let description = service.description {
                        Text(description)
                            .font(DesignTokens.Typography.body)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Menu {
                    Button("Edit") {
                        store.startEditService(service)
                    }

                    Button("Delete", role: .destructive) {
                        Task {
                            await store.deleteService(service)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(DesignTokens.Typography.title)
                        .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                        .accessibilityLabel("Service actions")
                }
                .disabled(store.isBusy)
            }
        }
    }
}

private struct GroomerProfileTextField: View {
    let title: String
    @Binding var text: String
    let prompt: String
    let axis: Axis

    init(
        title: String,
        text: Binding<String>,
        prompt: String,
        axis: Axis = .horizontal
    ) {
        self.title = title
        _text = text
        self.prompt = prompt
        self.axis = axis
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)

            TextField(prompt, text: $text, axis: axis)
                .groomlyFormField()
                .tint(DesignTokens.Colors.groomerAccentDark)
        }
    }
}

private struct GroomerExperiencePicker: View {
    @Binding var selection: Int

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Years Of Experience")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)

            Menu {
                ForEach(0...5, id: \.self) { years in
                    Button(label(for: years)) {
                        selection = years
                    }
                }
            } label: {
                HStack {
                    Text(label(for: selection))
                        .font(DesignTokens.Typography.body.weight(.semibold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)

                    Spacer(minLength: DesignTokens.Spacing.xs)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                .groomlyFormField()
            }
        }
    }

    private func label(for years: Int) -> String {
        years >= 5 ? "5+ Years" : "\(max(0, years)) Year\(years == 1 ? "" : "s")"
    }
}

private struct GroomerProfileRadiusSlider: View {
    @Binding var radius: Int

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text("Service Radius")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)

                Spacer()

                Text(radius >= 50 ? "50+ mi" : "\(radius) mi")
                    .font(DesignTokens.Typography.body.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
            }

            Slider(
                value: Binding(
                    get: { Double(radius) },
                    set: { radius = min(max(Int($0.rounded()), 5), 50) }
                ),
                in: 5...50,
                step: 1
            )
            .tint(DesignTokens.Colors.groomerAccent)

            Text("Use 50+ when you cover a wider service area.")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.borderSoft.opacity(0.32))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous))
    }
}

private struct GroomerProfileStatePicker: View {
    let title: String
    @Binding var selection: USStateCode?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)

            Menu {
                ForEach(USStateCode.allCases) { state in
                    Button(state.rawValue) {
                        selection = state
                    }
                }
            } label: {
                HStack {
                    Text(selection?.rawValue ?? "State")
                        .foregroundStyle(
                            selection == nil
                                ? DesignTokens.Colors.textSecondary
                                : DesignTokens.Colors.textPrimary
                        )

                    Spacer(minLength: DesignTokens.Spacing.xs)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                .groomlyFormField()
            }
        }
    }
}

private struct GroomerProfileAddressFields: View {
    @Binding var streetAddress: String
    @Binding var city: String
    @Binding var stateCode: USStateCode?
    @Binding var zipCode: String
    @StateObject private var addressSearch = GroomerProfileAddressSearch()

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GroomerProfileTextField(
                title: "Street Address",
                text: $streetAddress,
                prompt: "Street Address"
            )
            .textContentType(.streetAddressLine1)
            .onChange(of: streetAddress) { _, newValue in
                addressSearch.update(
                    street: newValue,
                    city: city,
                    stateCode: stateCode
                )
            }

            if !addressSearch.suggestions.isEmpty {
                VStack(spacing: DesignTokens.Spacing.xs) {
                    ForEach(addressSearch.suggestions.prefix(4)) { suggestion in
                        Button {
                            applyAddressSuggestion(suggestion)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.title)
                                    .font(DesignTokens.Typography.caption.weight(.semibold))
                                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                                    .lineLimit(1)

                                Text(suggestion.subtitle)
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, DesignTokens.Spacing.md)
                            .padding(.vertical, DesignTokens.Spacing.sm)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(DesignTokens.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
                        .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
                }
            }

            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                GroomerProfileTextField(
                    title: "City",
                    text: $city,
                    prompt: "City"
                )
                .textContentType(.addressCity)

                GroomerProfileStatePicker(
                    title: "State",
                    selection: $stateCode
                )
                .frame(width: 100)
            }

            GroomerProfileTextField(
                title: "ZIP Code",
                text: $zipCode,
                prompt: "ZIP Code"
            )
            .textContentType(.postalCode)
            .keyboardType(.numbersAndPunctuation)
        }
    }

    private func applyAddressSuggestion(_ suggestion: GroomerProfileAddressSuggestion) {
        Task {
            guard let address = await addressSearch.resolve(suggestion) else { return }
            streetAddress = address.streetAddress
            city = address.city
            stateCode = address.stateCode
            zipCode = address.zipCode
        }
    }
}

private struct GroomerProfileLocationModePicker: View {
    @Binding var selection: Set<GroomingLocationMode>

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Service Location")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)

            VStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(GroomingLocationMode.allCases) { mode in
                    Button {
                        if selection.contains(mode) {
                            selection.remove(mode)
                        } else {
                            selection.insert(mode)
                        }
                    } label: {
                        let isSelected = selection.contains(mode)
                        HStack(spacing: DesignTokens.Spacing.md) {
                            Text(mode.icon)
                                .font(.title3)
                                .frame(width: 30)

                            Text(mode.groomerTitle)
                                .font(DesignTokens.Typography.body.weight(.semibold))
                                .foregroundStyle(DesignTokens.Colors.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                            }
                        }
                        .padding(DesignTokens.Spacing.md)
                        .background(DesignTokens.Colors.surface)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: DesignTokens.CornerRadius.input,
                                style: .continuous
                            )
                        )
                        .overlay {
                            RoundedRectangle(
                                cornerRadius: DesignTokens.CornerRadius.input,
                                style: .continuous
                            )
                            .stroke(
                                isSelected
                                    ? DesignTokens.Colors.groomerAccent
                                    : DesignTokens.Colors.borderSoft,
                                lineWidth: isSelected ? 2 : 1
                            )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct GroomerProfileAddressSuggestion: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
}

private struct GroomerProfileAddressCompletion<Completion> {
    let title: String
    let subtitle: String
    let completion: Completion
}

private enum GroomerProfileAddressSuggestionBuilder {
    static func build<Completion>(
        from completions: [GroomerProfileAddressCompletion<Completion>],
        limit: Int = 5
    ) -> (
        suggestions: [GroomerProfileAddressSuggestion],
        completionsByID: [String: Completion]
    ) {
        var seenKeys: Set<String> = []
        var suggestions: [GroomerProfileAddressSuggestion] = []
        var completionsByID: [String: Completion] = [:]

        for completion in completions where suggestions.count < limit {
            let title = completion.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let subtitle = completion.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }

            let key = "\(title)|\(subtitle)"
            guard seenKeys.insert(key).inserted else { continue }

            let suggestion = GroomerProfileAddressSuggestion(
                id: key,
                title: title,
                subtitle: subtitle
            )
            suggestions.append(suggestion)
            completionsByID[suggestion.id] = completion.completion
        }

        return (suggestions, completionsByID)
    }
}

private struct GroomerProfileResolvedAddress {
    let streetAddress: String
    let city: String
    let stateCode: USStateCode
    let zipCode: String
}

private final class GroomerProfileAddressSearch:
    NSObject,
    ObservableObject,
    MKLocalSearchCompleterDelegate
{
    @Published private(set) var suggestions: [GroomerProfileAddressSuggestion] = []

    private let completer = MKLocalSearchCompleter()
    private var completionsByID: [String: MKLocalSearchCompletion] = [:]
    private var lastQueryFragment = ""

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func update(
        street: String,
        city: String,
        stateCode: USStateCode?
    ) {
        let trimmedStreet = street.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedStreet.count >= 3 else {
            suggestions = []
            completionsByID = [:]
            updateQueryFragmentIfNeeded("")
            return
        }

        let query = [
            trimmedStreet,
            city.trimmingCharacters(in: .whitespacesAndNewlines),
            stateCode?.rawValue ?? "",
        ]
        .filter { !$0.isEmpty }
        .joined(separator: ", ")

        updateQueryFragmentIfNeeded(query)
    }

    private func updateQueryFragmentIfNeeded(_ query: String) {
        guard query != lastQueryFragment else { return }
        lastQueryFragment = query
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let result = GroomerProfileAddressSuggestionBuilder.build(
            from: completer.results.map { completion in
                GroomerProfileAddressCompletion(
                    title: completion.title,
                    subtitle: completion.subtitle,
                    completion: completion
                )
            }
        )

        DispatchQueue.main.async {
            self.suggestions = result.suggestions
            self.completionsByID = result.completionsByID
        }
    }

    func completer(
        _ completer: MKLocalSearchCompleter,
        didFailWithError error: any Error
    ) {
        DispatchQueue.main.async {
            self.suggestions = []
            self.completionsByID = [:]
        }
    }

    func resolve(
        _ suggestion: GroomerProfileAddressSuggestion
    ) async -> GroomerProfileResolvedAddress? {
        guard let completion = completionsByID[suggestion.id] else { return nil }

        let request = MKLocalSearch.Request(completion: completion)
        guard
            let mapItem = try? await MKLocalSearch(request: request).start().mapItems.first,
            let state = mapItem.placemark.administrativeArea,
            let stateCode = USStateCode(rawValue: state.uppercased()),
            let zipCode = mapItem.placemark.postalCode?.trimmingCharacters(in: .whitespacesAndNewlines),
            !zipCode.isEmpty
        else {
            return nil
        }

        let streetAddress = [
            mapItem.placemark.subThoroughfare,
            mapItem.placemark.thoroughfare,
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " ")

        guard !streetAddress.isEmpty else { return nil }

        return GroomerProfileResolvedAddress(
            streetAddress: streetAddress,
            city: mapItem.placemark.locality ?? "",
            stateCode: stateCode,
            zipCode: zipCode
        )
    }
}

private struct GroomlyToggleRow: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    @Binding var isOn: Bool

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        isOn: Binding<Bool>
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        _isOn = isOn
    }

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
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
                    .font(DesignTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .tint(DesignTokens.Colors.groomerAccent)
        }
        .padding(DesignTokens.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
                .fill(DesignTokens.Colors.borderSoft.opacity(0.35))
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
                .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct GroomerServiceTypePicker: View {
    @Binding var selection: GroomingServiceType

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Service Menu")
                .font(DesignTokens.Typography.caption.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .textCase(.uppercase)

            GroomlyCard(padding: DesignTokens.Spacing.sm) {
                VStack(spacing: 0) {
                    ForEach(GroomingServiceType.allCases) { type in
                        Button {
                            selection = type
                        } label: {
                            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                                    Text(type.title)
                                        .font(DesignTokens.Typography.body.weight(.bold))
                                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Text(serviceEditorSubtitle(for: type))
                                        .font(DesignTokens.Typography.caption)
                                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Image(systemName: selection == type ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(
                                        selection == type
                                            ? DesignTokens.Colors.groomerAccent
                                            : DesignTokens.Colors.textTertiary
                                    )
                                    .accessibilityHidden(true)
                            }
                            .padding(.horizontal, DesignTokens.Spacing.sm)
                            .padding(.vertical, DesignTokens.Spacing.md)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(type.title)
                        .accessibilityValue(selection == type ? "Selected" : "Not selected")

                        if type != GroomingServiceType.allCases.last {
                            Divider()
                                .overlay(DesignTokens.Colors.divider)
                        }
                    }
                }
            }
        }
    }

    private func serviceEditorSubtitle(for type: GroomingServiceType) -> String {
        switch type {
        case .fullGroom:
            "Bath, coat cut, nails, ears, and finish"
        case .bathAndBrush:
            "Wash, dry, brush-out, and tidy touchups"
        case .haircutOnly:
            "Coat shaping for pets that do not need a bath"
        case .nailTrim:
            "Clip, grind, and paw handling"
        case .deShedding:
            "Undercoat release, blow-out, and brush work"
        case .customRequest:
            "Special-care appointment scoped in your offer"
        }
    }
}

private struct ProfileBadges: View {
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

private struct GroomerPortfolioSection: View {
    @Bindable var store: GroomerProfileStore
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GroomlySectionHeader(
                "Portfolio",
                subtitle: "Images upload to the private groomer-portfolio bucket and stay metadata-only here."
            ) {
                addPhotoPicker(isFullWidth: false)
            }

            if store.isUploading {
                GroomerPortfolioUpdatingCard()
            }

            if store.portfolioPhotos.isEmpty {
                GroomlyEmptyState(
                    title: "No Portfolio Photos",
                    message: "Add work examples after completing your profile. This screen shows stored metadata only.",
                    systemImage: "photo.on.rectangle",
                    accent: .groomer
                )
                .accessibilityIdentifier("groomer.portfolio.empty")
            } else {
                VStack(spacing: DesignTokens.Spacing.md) {
                    ForEach(store.sortedPortfolioPhotos()) { photo in
                        GroomerPortfolioPhotoRow(
                            photo: photo,
                            store: store
                        )
                    }
                }
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await upload(newItem)
            }
        }
    }

    private func upload(_ item: PhotosPickerItem) async {
        defer { selectedPhotoItem = nil }

        guard let data = try? await item.loadTransferable(type: Data.self) else {
            store.errorMessage = "We could not read that photo."
            return
        }

        let contentType = item.supportedContentTypes
            .lazy
            .compactMap(GroomerPortfolioPhotoContentType.init(uniformType:))
            .first ?? .jpeg

        await store.uploadPortfolioPhoto(
            data: data,
            contentType: contentType
        )
    }

    private func addPhotoPicker(isFullWidth: Bool) -> some View {
        PhotosPicker(
            selection: $selectedPhotoItem,
            matching: .images
        ) {
            Label("Add Photo", systemImage: "plus")
        }
        .buttonStyle(GroomlySecondaryButtonStyle(accent: .groomer, isFullWidth: isFullWidth))
        .disabled(store.isBusy)
        .accessibilityIdentifier("groomer.portfolio.add")
    }
}

private struct GroomerPortfolioUpdatingCard: View {
    var body: some View {
        GroomlyCard(padding: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.md) {
                ProgressView()
                    .tint(DesignTokens.Colors.groomerAccent)

                Text("Updating portfolio metadata…")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }
}

private struct GroomerPortfolioPhotoRow: View {
    let photo: GroomerPortfolioPhoto
    @Bindable var store: GroomerProfileStore

    var body: some View {
        GroomlyCard(padding: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    GroomerPortfolioPhotoThumbnail(
                        data: store.portfolioPhotoData(for: photo)
                    )

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(photo.fileName)
                            .font(DesignTokens.Typography.body.weight(.semibold))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .lineLimit(1)

                        if let caption = photo.caption {
                            Text(caption)
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(DesignTokens.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("No Caption Metadata")
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(DesignTokens.Colors.textTertiary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button(role: .destructive) {
                        Task {
                            await store.deletePortfolioPhoto(photo)
                        }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .font(DesignTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.error)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(DesignTokens.Colors.error.opacity(0.08))
                    .overlay {
                        DesignTokens.Shapes.chip
                            .stroke(DesignTokens.Colors.error.opacity(0.26), lineWidth: 1)
                    }
                    .clipShape(DesignTokens.Shapes.chip)
                    .disabled(store.isBusy)
                }

                Divider()
                    .overlay(DesignTokens.Colors.divider)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    GroomerPortfolioMetadataRow(
                        title: "Bucket",
                        value: photo.storageBucket,
                        systemImage: "shippingbox"
                    )

                    GroomerPortfolioMetadataRow(
                        title: "Storage Path",
                        value: photo.storagePath,
                        systemImage: "folder"
                    )

                    GroomerPortfolioMetadataRow(
                        title: "Sort Order",
                        value: "\(photo.sortOrder)",
                        systemImage: "arrow.up.arrow.down"
                    )
                }

                Divider()
                    .overlay(DesignTokens.Colors.divider)

                GroomerPortfolioFitTagsSection(
                    photo: photo,
                    store: store
                )
            }
        }
    }
}

private struct GroomerPortfolioPhotoThumbnail: View {
    let data: Data?

    var body: some View {
        Group {
            if let data,
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo.on.rectangle")
                    .font(DesignTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DesignTokens.Colors.groomerAccent.opacity(0.14))
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 8,
                style: .continuous
            )
        )
        .accessibilityHidden(true)
    }
}

private struct GroomerPortfolioFitTagsSection: View {
    let photo: GroomerPortfolioPhoto
    @Bindable var store: GroomerProfileStore

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text("Fit Tags")
                    .font(DesignTokens.Typography.body.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                GroomlyStatusChip(
                    "\(selectedCount)/\(GroomerPortfolioFitTag.maximumTagsPerPhoto)",
                    systemImage: "tag",
                    tone: .groomer
                )
            }

            ForEach(Self.visibleGroups) { group in
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text(group.title)
                        .font(DesignTokens.Typography.caption.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .textCase(.uppercase)

                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 132), spacing: DesignTokens.Spacing.sm),
                        ],
                        alignment: .leading,
                        spacing: DesignTokens.Spacing.sm
                    ) {
                        ForEach(signals(for: group)) { signal in
                            GroomerPortfolioFitTagChip(
                                signal: signal,
                                isSelected: store.isPortfolioFitTagSelected(
                                    signal,
                                    for: photo
                                )
                            ) {
                                store.togglePortfolioFitTag(signal, for: photo)
                            }
                        }
                    }
                }
            }

            Button {
                Task {
                    await store.savePortfolioFitTags(for: photo)
                }
            } label: {
                Label("Save Tags", systemImage: "checkmark")
            }
            .buttonStyle(GroomlySecondaryButtonStyle(accent: .groomer, isFullWidth: true))
            .disabled(store.isBusy)
            .accessibilityIdentifier("groomer.portfolio.tags.save")
        }
    }

    private var selectedCount: Int {
        store.selectedPortfolioFitTagIDsByPhotoID[photo.id]?.count ?? 0
    }

    private static var visibleGroups: [PetFitSignal.Group] {
        [.coatType, .careFlag, .serviceFit].filter { group in
            GroomerPortfolioFitTag.availableSignals.contains(where: {
                $0.group == group
            })
        }
    }

    private func signals(for group: PetFitSignal.Group) -> [PetFitSignal] {
        GroomerPortfolioFitTag.availableSignals.filter { $0.group == group }
    }
}

private struct GroomerPortfolioFitTagChip: View {
    let signal: PetFitSignal
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: iconName)
                    .font(.system(size: 13, weight: .bold))
                    .accessibilityHidden(true)

                Text(signal.title)
                    .font(DesignTokens.Typography.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .semibold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(
                isSelected
                    ? DesignTokens.Colors.surface
                    : DesignTokens.Colors.textPrimary
            )
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .frame(height: 38)
            .background(
                isSelected
                    ? DesignTokens.Colors.groomerAccent
                    : DesignTokens.Colors.background
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected
                            ? DesignTokens.Colors.groomerAccent
                            : DesignTokens.Colors.borderSoft,
                        lineWidth: 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(signal.title) portfolio fit tag")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }

    private var iconName: String {
        switch signal.group {
        case .coatType:
            "comb"
        case .breedGroup:
            "pawprint.fill"
        case .sizeBand:
            "ruler"
        case .careFlag:
            "heart.fill"
        case .serviceFit:
            "scissors"
        }
    }
}

private struct GroomerPortfolioMetadataRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textTertiary)
                .frame(width: DesignTokens.Spacing.lg)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                Text(value)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct GroomerServiceFormView: View {
    @Bindable var store: GroomerProfileStore

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        GroomlySectionHeader(
                            store.serviceFormTitle,
                            subtitle: "Set one offer-ready service with clear price, duration, visibility, and pet-size policy."
                        )

                        GroomerServiceTypePicker(selection: $store.serviceType)

                        GroomlyCard {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                                GroomerProfileTextField(
                                    title: "Description",
                                    text: $store.serviceDescription,
                                    prompt: "What is included",
                                    axis: .vertical
                                )
                                .lineLimit(2...4)

                                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                                    GroomerProfileTextField(
                                        title: "Base Price",
                                        text: $store.serviceBasePrice,
                                        prompt: "Price"
                                    )
                                    .keyboardType(.decimalPad)

                                    GroomerProfileTextField(
                                        title: "Minutes",
                                        text: $store.serviceDurationMinutes,
                                        prompt: "Duration"
                                    )
                                    .keyboardType(.numberPad)
                                }

                                GroomlyToggleRow(
                                    title: "Visible to Customers",
                                    subtitle: "Hidden services stay saved but do not appear as active options.",
                                    systemImage: "eye",
                                    isOn: $store.serviceIsActive
                                )
                            }
                        }

                        GroomerServiceAcceptedPetSizeSection(store: store)

                        if let errorMessage = store.errorMessage {
                            GroomlyErrorBanner(
                                title: "Service Could Not Be Saved",
                                message: errorMessage
                            )
                            .accessibilityIdentifier("groomer.services.form-error")
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                    .padding(.vertical, DesignTokens.Spacing.lg)
                }
            }
            .navigationTitle(store.serviceFormTitle)
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        store.cancelServiceForm()
                    }
                    .disabled(store.isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await store.saveService()
                        }
                    }
                    .disabled(store.isSaving)
                }
            }
        }
        .interactiveDismissDisabled(store.isSaving)
    }
}

private struct GroomerServiceAcceptedPetSizeSection: View {
    @Bindable var store: GroomerProfileStore

    private let serviceSizes = GroomerServicePetSize.allCases

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GroomlySectionHeader(
                "Accepted Pet Size",
                subtitle: "Default follows your Fit Signals size experience."
            )

            GroomlyCard {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text("Custom Service Range")
                                .font(DesignTokens.Typography.body.weight(.bold))
                                .foregroundStyle(DesignTokens.Colors.textPrimary)

                            Text(sizePolicySubtitle)
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(DesignTokens.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Toggle(
                            "Custom Service Range",
                            isOn: Binding(
                                get: { store.serviceUsesCustomSizeRange },
                                set: { store.setServiceUsesCustomSizeRange($0) }
                            )
                        )
                        .labelsHidden()
                        .tint(DesignTokens.Colors.groomerAccent)
                    }

                    if store.serviceUsesCustomSizeRange {
                        Divider()
                            .overlay(DesignTokens.Colors.divider)

                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
                                Text("Service Range")
                                    .font(DesignTokens.Typography.body.weight(.bold))
                                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                                Spacer(minLength: DesignTokens.Spacing.md)

                                Text(store.serviceSizeRangeTitle)
                                    .font(DesignTokens.Typography.caption.weight(.bold))
                                    .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                                    .padding(.horizontal, DesignTokens.Spacing.sm)
                                    .padding(.vertical, DesignTokens.Spacing.xs)
                                    .background(DesignTokens.Colors.groomerAccent.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .accessibilityIdentifier("groomer.services.size-range-title")
                            }

                            GroomerSizeRangeSlider(
                                lowerIndex: Binding(
                                    get: { store.selectedServiceSizeRange.lowerBound },
                                    set: { newValue in
                                        store.setServiceAcceptedPetSizeRange(
                                            lowerIndex: newValue,
                                            upperIndex: store.selectedServiceSizeRange.upperBound
                                        )
                                    }
                                ),
                                upperIndex: Binding(
                                    get: { store.selectedServiceSizeRange.upperBound },
                                    set: { newValue in
                                        store.setServiceAcceptedPetSizeRange(
                                            lowerIndex: store.selectedServiceSizeRange.lowerBound,
                                            upperIndex: newValue
                                        )
                                    }
                                ),
                                optionCount: serviceSizes.count,
                                rangeTitle: store.serviceSizeRangeTitle,
                                accessibilityIdentifier: "groomer.services.size-range-slider"
                            )

                            HStack(spacing: 0) {
                                ForEach(serviceSizes) { size in
                                    Text(size.title)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.72)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: store.serviceUsesCustomSizeRange)
            }
        }
    }

    private var sizePolicySubtitle: String {
        if store.serviceUsesCustomSizeRange {
            return store.serviceSizeRangeTitle
        }
        return "Following \(store.sizeBandFitClaimRangeTitle)"
    }
}

private struct GroomerProfileStatusView: View {
    let store: GroomerProfileStore

    var body: some View {
        VStack(spacing: 0) {
            GroomlyNoticeForwarder(message: store.noticeMessage) { message in
                guard store.noticeMessage == message else { return }
                store.noticeMessage = nil
            }

            if hasInlineStatus {
                inlineStatus
            }
        }
    }

    private var inlineStatus: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            if store.isSaving || store.isUploading {
                GroomlyStatusProgressToast(
                    store.isUploading ? "Uploading…" : "Saving…",
                    tint: DesignTokens.Colors.groomerAccent
                )
            }

            if let errorMessage = store.errorMessage,
               !store.isShowingServiceForm {
                GroomlyErrorBanner(
                    title: "Profile Update Failed",
                    message: errorMessage
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .animation(.easeInOut(duration: 0.24), value: hasInlineStatus)
    }

    private var hasInlineStatus: Bool {
        store.isSaving ||
            store.isUploading ||
            (store.errorMessage != nil && !store.isShowingServiceForm)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        GroomerProfileManagementView(
            groomerID: UUID(),
            repository: GroomerProfilePreviewRepository()
        )
    }
}

@MainActor
private final class GroomerProfilePreviewRepository: GroomerProfileRepository {
    private let groomerID = UUID()
    private var storedProfile: GroomerProfile
    private var storedServices: [GroomerService]
    private var storedPhotos: [GroomerPortfolioPhoto] = []
    private var storedPortfolioFitTags: [GroomerPortfolioFitTag] = []
    private var storedAvailability: [GroomerAvailabilityWindow] = []
    private var storedBookingPreferences: GroomerBookingPreferences
    private var storedTimeOff: [GroomerTimeOffWindow] = []
    private var storedPetFitEvidenceSummary: [GroomerPetFitEvidenceSummary] = []

    init() {
        storedProfile = GroomerProfile(
            userID: groomerID,
            businessName: "Fresh Coat Grooming",
            bio: "Calm, one-on-one grooming for small and medium dogs.",
            yearsExperience: 5,
            baseStreetAddress: "123 Pine Street",
            baseCity: "Seattle",
            baseState: "WA",
            baseZipCode: "98101",
            serviceRadiusMiles: 12,
            serviceLocationMode: .groomerComesToCustomer,
            serviceLocationModes: [.groomerComesToCustomer, .customerComesToGroomer],
            ratingAverage: 0,
            ratingCount: 0,
            isActive: false,
            isVerified: false
        )
        storedServices = [
            GroomerService(
                id: UUID(),
                groomerID: groomerID,
                serviceType: .fullGroom,
                title: "Full Groom",
                description: "Bath, haircut, nails, and ear cleaning.",
                basePrice: 95,
                durationMinutes: 120,
                acceptedPetSizes: [.xs, .s, .m],
                isActive: true
            ),
        ]
        storedBookingPreferences = GroomerBookingPreferences(
            groomerID: groomerID,
            maxAppointmentsPerDay: 4,
            minimumAdvanceNoticeDays: 0,
            autoAcceptBookings: false
        )
        storedTimeOff = [
            GroomerTimeOffWindow(
                id: UUID(),
                groomerID: groomerID,
                title: "Long weekend away",
                startDate: "2026-07-04",
                endDate: "2026-07-06"
            ),
            GroomerTimeOffWindow(
                id: UUID(),
                groomerID: groomerID,
                title: "Grooming workshop",
                startDate: "2026-08-12",
                endDate: "2026-08-12"
            ),
        ]
        storedAvailability = [
            GroomerAvailabilityWindow(
                id: UUID(),
                groomerID: groomerID,
                weekday: .monday,
                startMinutes: 9 * 60,
                endMinutes: 17 * 60,
                isEnabled: true,
                timezone: TimeZone.current.identifier
            ),
            GroomerAvailabilityWindow(
                id: UUID(),
                groomerID: groomerID,
                weekday: .tuesday,
                startMinutes: 9 * 60,
                endMinutes: 17 * 60,
                isEnabled: true,
                timezone: TimeZone.current.identifier
            ),
        ]
        storedPetFitEvidenceSummary = [
            GroomerPetFitEvidenceSummary(
                groomerID: groomerID,
                signal: .breedGroup(.poodle),
                completedBookingCount: 5,
                positiveReviewOutcomeCount: 3,
                negativeReviewOutcomeCount: 0,
                structuredReviewOutcomeCount: 3,
                lastCompletedAt: "2026-06-21T17:00:00Z",
                lastReviewOutcomeAt: "2026-06-22T18:00:00Z",
                evidenceUpdatedAt: "2026-06-22T18:00:00Z",
                confidenceTier: .high
            ),
            GroomerPetFitEvidenceSummary(
                groomerID: groomerID,
                signal: .serviceFit(.gentleHandling),
                completedBookingCount: 2,
                positiveReviewOutcomeCount: 1,
                negativeReviewOutcomeCount: 0,
                structuredReviewOutcomeCount: 1,
                lastCompletedAt: "2026-06-18T16:00:00Z",
                lastReviewOutcomeAt: "2026-06-19T16:30:00Z",
                evidenceUpdatedAt: "2026-06-19T16:30:00Z",
                confidenceTier: .medium
            ),
        ]
    }

    func profile(groomerID: UUID) async throws -> GroomerProfile {
        storedProfile
    }

    func services(groomerID: UUID) async throws -> [GroomerService] {
        storedServices
    }

    func portfolioPhotos(groomerID: UUID) async throws -> [GroomerPortfolioPhoto] {
        storedPhotos
    }

    func portfolioFitTags(groomerID: UUID) async throws -> [GroomerPortfolioFitTag] {
        storedPortfolioFitTags
    }

    func fitClaims(groomerID: UUID) async throws -> [GroomerFitClaim] {
        []
    }

    func petFitEvidenceSummary(groomerID: UUID) async throws -> [GroomerPetFitEvidenceSummary] {
        storedPetFitEvidenceSummary
    }

    func availabilityWindows(groomerID: UUID) async throws -> [GroomerAvailabilityWindow] {
        storedAvailability
    }

    func bookingPreferences(groomerID: UUID) async throws -> GroomerBookingPreferences {
        storedBookingPreferences
    }

    func timeOffWindows(groomerID: UUID) async throws -> [GroomerTimeOffWindow] {
        storedTimeOff
    }

    func updateProfile(
        groomerID: UUID,
        draft: GroomerProfileDraft
    ) async throws -> GroomerProfile {
        storedProfile = GroomerProfile(
            userID: groomerID,
            businessName: draft.businessName,
            bio: draft.bio,
            yearsExperience: draft.yearsExperience,
            baseStreetAddress: draft.baseStreetAddress,
            baseCity: draft.baseCity,
            baseState: draft.baseStateCode?.rawValue,
            baseZipCode: draft.baseZipCode,
            serviceRadiusMiles: draft.serviceRadiusMiles,
            serviceLocationMode: draft.serviceLocationMode,
            serviceLocationModes: draft.serviceLocationModes,
            ratingAverage: storedProfile.ratingAverage,
            ratingCount: storedProfile.ratingCount,
            isActive: draft.isActive,
            isVerified: storedProfile.isVerified
        )
        return storedProfile
    }

    func createService(
        groomerID: UUID,
        draft: GroomerServiceDraft
    ) async throws -> GroomerService {
        let service = GroomerService(
            id: UUID(),
            groomerID: groomerID,
            serviceType: draft.serviceType,
            title: draft.title,
            description: draft.description,
            basePrice: draft.basePrice,
            durationMinutes: draft.durationMinutes,
            acceptedPetSizes: draft.acceptedPetSizes,
            isActive: draft.isActive
        )
        storedServices.insert(service, at: 0)
        return service
    }

    func updateService(
        service: GroomerService,
        draft: GroomerServiceDraft
    ) async throws -> GroomerService {
        GroomerService(
            id: service.id,
            groomerID: service.groomerID,
            serviceType: draft.serviceType,
            title: draft.title,
            description: draft.description,
            basePrice: draft.basePrice,
            durationMinutes: draft.durationMinutes,
            acceptedPetSizes: draft.acceptedPetSizes,
            isActive: draft.isActive
        )
    }

    func deleteService(_ service: GroomerService) async throws {}

    func uploadPortfolioPhoto(
        groomerID: UUID,
        data: Data,
        contentType: GroomerPortfolioPhotoContentType,
        caption: String?
    ) async throws -> GroomerPortfolioPhoto {
        let photo = GroomerPortfolioPhoto(
            id: UUID(),
            groomerID: groomerID,
            storageBucket: "groomer-portfolio",
            storagePath: GroomerPortfolioPhotoPath.make(
                groomerID: groomerID,
                contentType: contentType
            ),
            caption: caption,
            sortOrder: 0
        )
        storedPhotos.append(photo)
        return photo
    }

    func deletePortfolioPhoto(_ photo: GroomerPortfolioPhoto) async throws {
        storedPhotos.removeAll { $0.id == photo.id }
        storedPortfolioFitTags.removeAll { $0.portfolioPhotoID == photo.id }
    }

    func replaceFitClaims(
        groomerID: UUID,
        drafts: [GroomerFitClaimDraft]
    ) async throws -> [GroomerFitClaim] {
        drafts.map {
            GroomerFitClaim(
                id: UUID(),
                groomerID: groomerID,
                signal: $0.signal,
                isActive: $0.isActive
            )
        }
    }

    func replacePortfolioFitTags(
        groomerID: UUID,
        photoID: UUID,
        drafts: [GroomerPortfolioFitTagDraft]
    ) async throws -> [GroomerPortfolioFitTag] {
        let tags = drafts.map {
            GroomerPortfolioFitTag(
                id: UUID(),
                portfolioPhotoID: photoID,
                groomerID: groomerID,
                signal: $0.signal
            )
        }
        storedPortfolioFitTags.removeAll { $0.portfolioPhotoID == photoID }
        storedPortfolioFitTags.append(contentsOf: tags)
        return tags
    }

    func uploadAvatarPhoto(
        groomerID: UUID,
        data: Data,
        contentType: GroomerAvatarPhotoContentType
    ) async throws -> String {
        let path = GroomerAvatarPhotoPath.make(
            groomerID: groomerID,
            contentType: contentType
        )
        storedProfile.avatarPath = path
        return path
    }

    func avatarPhotoData(storagePath: String) async throws -> Data {
        Data()
    }

    func replaceAvailability(
        groomerID: UUID,
        drafts: [GroomerAvailabilityDraft]
    ) async throws -> [GroomerAvailabilityWindow] {
        storedAvailability = drafts.map {
            GroomerAvailabilityWindow(
                id: UUID(),
                groomerID: groomerID,
                weekday: $0.weekday,
                startMinutes: $0.startMinutes,
                endMinutes: $0.endMinutes,
                isEnabled: $0.isEnabled,
                timezone: $0.timezone
            )
        }
        return storedAvailability
    }

    func updateBookingPreferences(
        groomerID: UUID,
        draft: GroomerBookingPreferencesDraft
    ) async throws -> GroomerBookingPreferences {
        storedBookingPreferences = GroomerBookingPreferences(
            groomerID: groomerID,
            maxAppointmentsPerDay: draft.maxAppointmentsPerDay,
            minimumAdvanceNoticeDays: draft.minimumAdvanceNoticeDays,
            autoAcceptBookings: draft.autoAcceptBookings
        )
        return storedBookingPreferences
    }

    func createTimeOff(
        groomerID: UUID,
        draft: GroomerTimeOffDraft
    ) async throws -> GroomerTimeOffWindow {
        let window = GroomerTimeOffWindow(
            id: UUID(),
            groomerID: groomerID,
            title: draft.title,
            startDate: draft.startDate,
            endDate: draft.endDate
        )
        storedTimeOff.append(window)
        return window
    }

    func deleteTimeOff(_ window: GroomerTimeOffWindow) async throws {
        storedTimeOff.removeAll { $0.id == window.id }
    }
}
#endif

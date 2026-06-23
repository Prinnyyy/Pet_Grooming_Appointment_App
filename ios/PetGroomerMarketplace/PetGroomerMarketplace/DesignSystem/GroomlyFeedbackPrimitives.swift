import SwiftUI

struct GroomlyErrorBanner<Action: View>: View {
    private let title: String
    private let message: String?
    private let systemImage: String?
    private let showsAction: Bool
    private let action: Action

    init(
        title: String,
        message: String? = nil,
        systemImage: String? = "exclamationmark.triangle.fill",
        @ViewBuilder action: () -> Action
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        showsAction = true
        self.action = action()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(DesignTokens.Typography.body.weight(.semibold))
                        .foregroundStyle(DesignTokens.Colors.error)
                        .frame(
                            width: DesignTokens.Spacing.xl + DesignTokens.Spacing.sm,
                            height: DesignTokens.Spacing.xl + DesignTokens.Spacing.sm
                        )
                        .background(DesignTokens.Colors.error.opacity(0.12))
                        .clipShape(DesignTokens.Shapes.circular)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(title)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)

                    if let message {
                        Text(message)
                            .font(DesignTokens.Typography.body)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)

            if showsAction {
                action
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous)
                .fill(DesignTokens.Colors.surfaceRaised)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous)
                .stroke(DesignTokens.Colors.error.opacity(0.28), lineWidth: 1)
        }
        .groomlyShadow(DesignTokens.Shadows.smallCard)
    }
}

extension GroomlyErrorBanner where Action == EmptyView {
    init(
        title: String,
        message: String? = nil,
        systemImage: String? = "exclamationmark.triangle.fill"
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        showsAction = false
        action = EmptyView()
    }
}

struct GroomlyFeedbackNotice: Equatable, Identifiable {
    let id: UUID
    let message: String
}

@MainActor
@Observable
final class GroomlyFeedbackCenter {
    static let noticeDismissDelayNanoseconds: UInt64 = 2_000_000_000

    var notice: GroomlyFeedbackNotice?

    @discardableResult
    func showNotice(_ message: String) -> UUID {
        let id = UUID()
        notice = GroomlyFeedbackNotice(id: id, message: message)
        return id
    }

    func clearNotice(id: UUID) {
        guard notice?.id == id else { return }
        notice = nil
    }
}

private struct GroomlyFeedbackCenterKey: EnvironmentKey {
    static let defaultValue: GroomlyFeedbackCenter? = nil
}

extension EnvironmentValues {
    var groomlyFeedbackCenter: GroomlyFeedbackCenter? {
        get { self[GroomlyFeedbackCenterKey.self] }
        set { self[GroomlyFeedbackCenterKey.self] = newValue }
    }
}

struct GroomlyNoticeForwarder: View {
    @Environment(\.groomlyFeedbackCenter) private var feedbackCenter

    private let message: String?
    private let clear: (String) -> Void

    init(message: String?, clear: @escaping (String) -> Void) {
        self.message = message
        self.clear = clear
    }

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .task(id: message) {
                forward(message)
            }
    }

    @MainActor
    private func forward(_ message: String?) {
        guard let message, let feedbackCenter else { return }
        feedbackCenter.showNotice(message)
        clear(message)
    }
}

struct GroomlyGlobalFeedbackOverlay: View {
    static let bottomTabBarClearance = DesignTokens.Spacing.xl * 3 + DesignTokens.Spacing.sm

    let center: GroomlyFeedbackCenter

    var body: some View {
        if let notice = center.notice {
            GroomlyNoticeToast(message: notice.message)
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.bottom, Self.bottomTabBarClearance)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .allowsHitTesting(false)
                .task(id: notice.id) {
                    await dismissNotice(id: notice.id)
                }
        }
    }

    private func dismissNotice(id: UUID) async {
        try? await Task.sleep(
            nanoseconds: GroomlyFeedbackCenter.noticeDismissDelayNanoseconds
        )
        guard !Task.isCancelled else { return }

        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.28)) {
                center.clearNotice(id: id)
            }
        }
    }
}

struct GroomlyNoticeToast: View {
    private let message: String

    init(message: String) {
        self.message = message
    }

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            Image(systemName: "checkmark")
                .font(.footnote.weight(.heavy))
                .foregroundStyle(DesignTokens.Colors.surface)
                .frame(width: 32, height: 32)
                .background(DesignTokens.Colors.success)
                .clipShape(DesignTokens.Shapes.circular)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignTokens.Typography.body.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if let detail {
                    Text(detail)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous)
                .stroke(DesignTokens.Colors.success.opacity(0.24), lineWidth: 1)
        }
        .groomlyShadow(DesignTokens.Shadows.smallCard)
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        Self.titleCase(parts.title)
    }

    private var detail: String? {
        parts.detail
    }

    private var parts: (title: String, detail: String?) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let split = trimmed.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: true)
        guard let first = split.first else {
            return (trimmed, nil)
        }

        let title = String(first)
        guard split.count > 1 else {
            return (title, nil)
        }

        let detail = String(split[1]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (title, detail.isEmpty ? nil : detail)
    }

    private static func titleCase(_ value: String) -> String {
        value
            .split(separator: " ")
            .map { word in
                let lowercased = word.lowercased()
                guard let first = lowercased.first else { return "" }
                return first.uppercased() + lowercased.dropFirst()
            }
            .joined(separator: " ")
    }
}

struct GroomlyStatusProgressToast: View {
    private let title: String
    private let tint: Color

    init(_ title: String, tint: Color) {
        self.title = title
        self.tint = tint
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            ProgressView()
                .tint(tint)

            Text(title)
                .font(DesignTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous)
                .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
        }
        .groomlyShadow(DesignTokens.Shadows.smallCard)
        .accessibilityElement(children: .combine)
    }
}

struct GroomlyLoadingView: View {
    enum Accent {
        case customer
        case groomer

        fileprivate var tint: Color {
            switch self {
            case .customer:
                DesignTokens.Colors.customerPrimary
            case .groomer:
                DesignTokens.Colors.groomerAccent
            }
        }
    }

    private let title: String
    private let message: String?
    private let accent: Accent

    init(
        title: String,
        message: String? = nil,
        accent: Accent = .customer
    ) {
        self.title = title
        self.message = message
        self.accent = accent
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ProgressView()
                .tint(accent.tint)

            VStack(spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                if let message {
                    Text(message)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DesignTokens.Spacing.xl)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous)
                .fill(DesignTokens.Colors.surfaceRaised)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous)
                .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
        }
        .groomlyShadow(DesignTokens.Shadows.smallCard)
        .accessibilityElement(children: .combine)
    }
}

struct GroomlyEmptyState<Action: View>: View {
    enum Accent {
        case customer
        case groomer

        fileprivate var foreground: Color {
            switch self {
            case .customer:
                DesignTokens.Colors.customerPrimaryDark
            case .groomer:
                DesignTokens.Colors.groomerAccentDark
            }
        }

        fileprivate var background: Color {
            switch self {
            case .customer:
                DesignTokens.Colors.customerPrimary.opacity(0.14)
            case .groomer:
                DesignTokens.Colors.groomerAccent.opacity(0.14)
            }
        }
    }

    private let title: String
    private let message: String
    private let systemImage: String?
    private let accent: Accent
    private let showsAction: Bool
    private let action: Action

    init(
        title: String,
        message: String,
        systemImage: String? = "tray",
        accent: Accent = .customer,
        @ViewBuilder action: () -> Action
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.accent = accent
        showsAction = true
        self.action = action()
    }

    var body: some View {
        GroomlyCard(padding: DesignTokens.Spacing.xl) {
            VStack(spacing: DesignTokens.Spacing.md) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(DesignTokens.Typography.largeTitle)
                        .foregroundStyle(accent.foreground)
                        .frame(
                            width: DesignTokens.Spacing.xl + DesignTokens.Spacing.xl,
                            height: DesignTokens.Spacing.xl + DesignTokens.Spacing.xl
                        )
                        .background(accent.background)
                        .clipShape(DesignTokens.Shapes.circular)
                        .accessibilityHidden(true)
                }

                VStack(spacing: DesignTokens.Spacing.sm) {
                    Text(title)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)

                    Text(message)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)

                if showsAction {
                    action
                        .padding(.top, DesignTokens.Spacing.xs)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

extension GroomlyEmptyState where Action == EmptyView {
    init(
        title: String,
        message: String,
        systemImage: String? = "tray",
        accent: Accent = .customer
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.accent = accent
        showsAction = false
        action = EmptyView()
    }
}

struct GroomlySectionHeader<Trailing: View>: View {
    private let title: String
    private let subtitle: String?
    private let showsTrailing: Bool
    private let trailing: Trailing

    init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        showsTrailing = true
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsTrailing {
                trailing
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xs)
        .accessibilityElement(children: .contain)
    }
}

extension GroomlySectionHeader where Trailing == EmptyView {
    init(
        _ title: String,
        subtitle: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        showsTrailing = false
        trailing = EmptyView()
    }
}

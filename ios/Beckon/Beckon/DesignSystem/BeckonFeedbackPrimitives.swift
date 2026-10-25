import SwiftUI
import UIKit

struct BeckonInlineError: View {
    let message: String

    init(_ message: String) { self.message = message }

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(DesignTokens.Typography.status)
            .foregroundStyle(DesignTokens.Colors.statusErrorText)
            .fixedSize(horizontal: false, vertical: true)
            .padding(DesignTokens.Spacing.sm)
            .background(DesignTokens.Colors.statusErrorFill)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input))
            .accessibilityElement(children: .combine)
    }
}

struct BeckonErrorBanner<Action: View>: View {
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
                        .foregroundStyle(DesignTokens.Colors.statusErrorText)
                        .frame(
                            width: DesignTokens.Spacing.xl + DesignTokens.Spacing.sm,
                            height: DesignTokens.Spacing.xl + DesignTokens.Spacing.sm
                        )
                        .background(DesignTokens.Colors.statusErrorFill)
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
                .stroke(DesignTokens.Colors.statusErrorBorder, lineWidth: 1)
        }
        .beckonShadow(DesignTokens.Shadows.smallCard)
    }
}

extension BeckonErrorBanner where Action == EmptyView {
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

struct BeckonFeedbackNotice: Equatable, Identifiable {
    let id: UUID
    let message: String
}

enum BeckonFeedbackScope: Equatable, Hashable, Sendable {
    case global
    case page(String)
    case module(String)
    case operation(String)

    var clearsWhenSourceDisappears: Bool {
        switch self {
        case .page, .module:
            true
        case .global, .operation:
            false
        }
    }

    var debugKey: String {
        switch self {
        case .global:
            "global"
        case let .page(value),
             let .module(value),
             let .operation(value):
            value
        }
    }
}

enum BeckonFeedbackTone: Equatable, Sendable {
    case customer
    case groomer
    case neutral

    var tint: Color {
        switch self {
        case .customer:
            DesignTokens.Colors.customerDeep
        case .groomer:
            DesignTokens.Colors.groomerDeep
        case .neutral:
            DesignTokens.Colors.textSecondary
        }
    }
}

struct BeckonGlobalFeedbackError: Equatable, Identifiable {
    let id: UUID
    let scope: BeckonFeedbackScope
    let sourceKey: String
    let title: String
    let message: String?

    init(
        id: UUID = UUID(),
        scope: BeckonFeedbackScope = .global,
        sourceKey: String? = nil,
        title: String,
        message: String? = nil
    ) {
        self.id = id
        self.scope = scope
        self.sourceKey = sourceKey ?? Self.defaultSourceKey(title: title, message: message)
        self.title = title
        self.message = message
    }

    var contentKey: ContentKey {
        ContentKey(
            scope: scope,
            sourceKey: sourceKey,
            title: title,
            message: message
        )
    }

    struct ContentKey: Equatable, Hashable, Sendable {
        let scope: BeckonFeedbackScope
        let sourceKey: String
        let title: String
        let message: String?
    }

    static func == (
        lhs: BeckonGlobalFeedbackError,
        rhs: BeckonGlobalFeedbackError
    ) -> Bool {
        lhs.contentKey == rhs.contentKey
    }

    private static func defaultSourceKey(title: String, message: String?) -> String {
        [title, message].compactMap { $0 }.joined(separator: "|")
    }
}

struct BeckonGlobalFeedbackProgress: Equatable, Identifiable {
    let id: UUID
    let scope: BeckonFeedbackScope
    let sourceKey: String
    let title: String
    let tone: BeckonFeedbackTone

    init(
        id: UUID = UUID(),
        scope: BeckonFeedbackScope = .global,
        sourceKey: String? = nil,
        title: String,
        tone: BeckonFeedbackTone = .neutral
    ) {
        self.id = id
        self.scope = scope
        self.sourceKey = sourceKey ?? title
        self.title = title
        self.tone = tone
    }

    var contentKey: ContentKey {
        ContentKey(
            scope: scope,
            sourceKey: sourceKey,
            title: title,
            tone: tone
        )
    }

    struct ContentKey: Equatable, Sendable {
        let scope: BeckonFeedbackScope
        let sourceKey: String
        let title: String
        let tone: BeckonFeedbackTone
    }

    static func == (
        lhs: BeckonGlobalFeedbackProgress,
        rhs: BeckonGlobalFeedbackProgress
    ) -> Bool {
        lhs.contentKey == rhs.contentKey
    }
}

struct BeckonPersistentFeedbackError: Equatable, Identifiable {
    let id: UUID
    let scope: BeckonFeedbackScope
    let sourceKey: String
    let title: String
    let message: String
    let actionTitle: String?

    init(
        id: UUID = UUID(),
        scope: BeckonFeedbackScope,
        sourceKey: String,
        title: String,
        message: String,
        actionTitle: String? = nil
    ) {
        self.id = id
        self.scope = scope
        self.sourceKey = sourceKey
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
    }

    var identityKey: IdentityKey {
        IdentityKey(scope: scope, sourceKey: sourceKey)
    }

    struct IdentityKey: Equatable, Hashable, Sendable {
        let scope: BeckonFeedbackScope
        let sourceKey: String
    }
}

struct BeckonFeedbackDebugPromptSnapshot: Equatable, Identifiable {
    let id: String
    let kind: String
    let scope: String?
    let sourceKey: String?
    let title: String
    let message: String?
}

struct BeckonFeedbackDebugSnapshot: Equatable {
    let active: BeckonFeedbackDebugPromptSnapshot?
    let queued: [BeckonFeedbackDebugPromptSnapshot]
}

struct BeckonPersistentErrorView<Action: View>: View {
    private let error: BeckonPersistentFeedbackError
    private let systemImage: String
    private let showsAction: Bool
    private let action: Action

    init(
        _ error: BeckonPersistentFeedbackError,
        systemImage: String = "exclamationmark.triangle.fill",
        @ViewBuilder action: () -> Action
    ) {
        self.error = error
        self.systemImage = systemImage
        showsAction = true
        self.action = action()
    }

    var body: some View {
        BeckonCard(padding: DesignTokens.Spacing.xl) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    Image(systemName: systemImage)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.statusErrorText)
                        .frame(width: 52, height: 52)
                        .background(DesignTokens.Colors.statusErrorFill)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(error.title)
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(error.message)
                            .font(DesignTokens.Typography.body)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .combine)

                if showsAction {
                    action
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous)
                .stroke(DesignTokens.Colors.statusErrorBorder, lineWidth: 1)
        }
        .accessibilityIdentifier("beckon.persistent-error")
    }
}

extension BeckonPersistentErrorView where Action == EmptyView {
    init(
        _ error: BeckonPersistentFeedbackError,
        systemImage: String = "exclamationmark.triangle.fill"
    ) {
        self.error = error
        self.systemImage = systemImage
        showsAction = false
        action = EmptyView()
    }
}

struct BeckonBottomPrompt<Content: View>: View {
    private let borderColor: Color
    private let content: Content

    init(
        borderColor: Color = DesignTokens.Colors.borderSoft,
        @ViewBuilder content: () -> Content
    ) {
        self.borderColor = borderColor
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.md)
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            }
            .beckonShadow(DesignTokens.Shadows.smallCard)
            .accessibilityElement(children: .combine)
    }
}

struct BeckonBottomPromptStack<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let horizontalPadding: CGFloat
    private let topPadding: CGFloat
    private let bottomPadding: CGFloat
    private let animationValue: AnyHashable
    private let content: Content

    init(
        horizontalPadding: CGFloat = DesignTokens.Spacing.screenHorizontal,
        topPadding: CGFloat = DesignTokens.Spacing.sm,
        bottomPadding: CGFloat = DesignTokens.Spacing.sm,
        animationValue: AnyHashable = false,
        @ViewBuilder content: () -> Content
    ) {
        self.horizontalPadding = horizontalPadding
        self.topPadding = topPadding
        self.bottomPadding = bottomPadding
        self.animationValue = animationValue
        self.content = content()
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            content
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, horizontalPadding)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: animationValue)
    }
}

struct BeckonBottomPromptArea<Content: View>: View {
    private let isPresented: Bool
    private let noticeMessage: String?
    private let horizontalPadding: CGFloat
    private let animationValue: AnyHashable
    private let clearNotice: ((String) -> Void)?
    private let content: Content

    init(
        isPresented: Bool,
        noticeMessage: String? = nil,
        horizontalPadding: CGFloat = DesignTokens.Spacing.screenHorizontal,
        animationValue: AnyHashable = false,
        clearNotice: ((String) -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.isPresented = isPresented
        self.noticeMessage = noticeMessage
        self.horizontalPadding = horizontalPadding
        self.animationValue = animationValue
        self.clearNotice = clearNotice
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            if let clearNotice {
                BeckonNoticeForwarder(message: noticeMessage, clear: clearNotice)
            }

            if isPresented {
                BeckonBottomPromptStack(
                    horizontalPadding: horizontalPadding,
                    animationValue: animationValue
                ) {
                    content
                }
            }
        }
    }
}

@MainActor
@Observable
final class BeckonFeedbackCenter {
    // Compatibility floors for existing callers; actual prompts use their own reading time below.
    static let noticeDismissDelayNanoseconds: UInt64 = 4_000_000_000
    static let errorDismissDelayNanoseconds: UInt64 = 5_000_000_000
    static let queuedPromptAdvanceDelayNanoseconds: UInt64 = 280_000_000

    private var debugRecorder: AppDebugEventRecorder?
    private(set) var notice: BeckonFeedbackNotice?
    private(set) var error: BeckonGlobalFeedbackError?
    private(set) var progress: BeckonGlobalFeedbackProgress?
    private var queuedPrompts: [QueuedPrompt] = []
    private var dismissedErrorKeys: Set<BeckonGlobalFeedbackError.ContentKey> = []
    private var isWaitingToShowQueuedPrompt = false
    private var queuedPromptAdvanceTask: Task<Void, Never>?
    private var promptDismissTask: Task<Void, Never>?
    private(set) var promptExpiresAt: Date?
    private var hasAnnouncedActivePrompt = false

    init(debugRecorder: AppDebugEventRecorder? = nil) {
        self.debugRecorder = debugRecorder
    }

    func setDebugRecorder(_ recorder: AppDebugEventRecorder?) {
        debugRecorder = recorder
    }

    @discardableResult
    func showNotice(_ message: String) -> UUID {
        let id = UUID()
        enqueue(.notice(BeckonFeedbackNotice(id: id, message: message)))
        return id
    }

    func showError(_ error: BeckonGlobalFeedbackError) {
        enqueue(.error(error))
    }

    func showProgress(_ progress: BeckonGlobalFeedbackProgress) {
        enqueue(.progress(progress))
    }

    func clearNotice(id: UUID) {
        if notice?.id == id {
            dismissActivePrompt()
        } else {
            queuedPrompts.removeAll { $0.isNotice(id: id) }
        }
    }

    func clearError(matching error: BeckonGlobalFeedbackError) {
        dismissedErrorKeys.remove(error.contentKey)

        if self.error?.contentKey == error.contentKey {
            dismissActivePrompt()
        } else {
            queuedPrompts.removeAll { $0.isError(matching: error) }
        }
    }

    func clearProgress(matching progress: BeckonGlobalFeedbackProgress) {
        if self.progress?.contentKey == progress.contentKey {
            dismissActivePrompt()
        } else {
            queuedPrompts.removeAll { $0.isProgress(matching: progress) }
        }
    }

    func clearTransientPrompts(in scope: BeckonFeedbackScope) {
        var removedPromptCount = 0
        queuedPrompts.removeAll { prompt in
            if let error = prompt.error(in: scope) {
                dismissedErrorKeys.insert(error.contentKey)
                removedPromptCount += 1
                return true
            }

            if prompt.scope == scope {
                removedPromptCount += 1
                return true
            }

            return false
        }

        guard activePrompt?.scope == scope else {
            recordFeedbackEvent(
                source: "BeckonFeedbackCenter.clearedScope",
                level: .debug,
                scope: scope,
                message: "cleared scope",
                metadata: ["removedCount": "\(removedPromptCount)"]
            )
            return
        }

        if let error = activePrompt?.error(in: scope) {
            dismissedErrorKeys.insert(error.contentKey)
        }

        removedPromptCount += 1
        dismissActivePrompt()
        recordFeedbackEvent(
            source: "BeckonFeedbackCenter.clearedScope",
            level: .debug,
            scope: scope,
            message: "cleared scope",
            metadata: ["removedCount": "\(removedPromptCount)"]
        )
    }

    var hasVisiblePrompt: Bool {
        notice != nil || error != nil || progress != nil
    }

    var remainingPromptSeconds: TimeInterval? {
        promptExpiresAt.map { max(0, $0.timeIntervalSinceNow) }
    }

    var accessibilityAnnouncement: String? {
        if let notice { return notice.message }
        if let error { return [error.title, error.message].compactMap { $0 }.joined(separator: ". ") }
        return progress?.title
    }

    func consumeAccessibilityAnnouncement() -> String? {
        guard !hasAnnouncedActivePrompt, let announcement = accessibilityAnnouncement else { return nil }
        hasAnnouncedActivePrompt = true
        return announcement
    }

    var animationKey: String {
        [
            progress?.id.uuidString ?? "no-progress",
            error?.id.uuidString ?? "no-error",
            notice?.id.uuidString ?? "no-notice"
        ].joined(separator: ":")
    }

    var debugSnapshot: BeckonFeedbackDebugSnapshot {
        BeckonFeedbackDebugSnapshot(
            active: activePrompt?.debugSnapshot(index: 0),
            queued: queuedPrompts.enumerated().map { index, prompt in
                prompt.debugSnapshot(index: index)
            }
        )
    }

    private var activePrompt: QueuedPrompt? {
        if let notice {
            .notice(notice)
        } else if let error {
            .error(error)
        } else if let progress {
            .progress(progress)
        } else {
            nil
        }
    }

    private func enqueue(_ prompt: QueuedPrompt) {
        guard !isDismissedError(prompt) else {
            recordFeedbackEvent(
                source: "BeckonFeedbackCenter.suppressedStale",
                level: .debug,
                prompt: prompt,
                message: "suppressed stale prompt"
            )
            return
        }
        guard !containsEquivalentPrompt(prompt) else {
            recordFeedbackEvent(
                source: "BeckonFeedbackCenter.suppressedDuplicate",
                level: .debug,
                prompt: prompt,
                message: "suppressed duplicate prompt"
            )
            return
        }

        recordFeedbackEvent(
            source: "BeckonFeedbackCenter.enqueue",
            level: .info,
            prompt: prompt,
            message: "queued prompt"
        )
        if activePrompt == nil, !isWaitingToShowQueuedPrompt {
            present(prompt)
        } else {
            queuedPrompts.append(prompt)
        }
    }

    private func containsEquivalentPrompt(_ prompt: QueuedPrompt) -> Bool {
        activePrompt?.isEquivalent(to: prompt) == true
            || queuedPrompts.contains { $0.isEquivalent(to: prompt) }
    }

    private func isDismissedError(_ prompt: QueuedPrompt) -> Bool {
        if case let .error(error) = prompt {
            dismissedErrorKeys.contains(error.contentKey)
        } else {
            false
        }
    }

    private func present(_ prompt: QueuedPrompt) {
        hasAnnouncedActivePrompt = false
        cancelPromptDismissTask()
        notice = nil
        error = nil
        progress = nil

        switch prompt {
        case let .notice(notice):
            self.notice = notice
            schedulePromptDismiss(after: FeedbackTimingPolicy.seconds(.notice, notice.message)) { center in
                guard center.notice?.id == notice.id else { return }
                center.clearNotice(id: notice.id)
            }
        case let .error(error):
            self.error = error
            schedulePromptDismiss(after: FeedbackTimingPolicy.seconds(.error, error.title, error.message)) { center in
                center.dismissActiveErrorIfNeeded(matching: error.contentKey)
            }
        case let .progress(progress):
            self.progress = progress
        }

        recordFeedbackEvent(
            source: "BeckonFeedbackCenter.presented",
            level: .info,
            prompt: prompt,
            message: "presented prompt"
        )
    }

    private func dismissActivePrompt() {
        let dismissedPrompt = activePrompt
        cancelPromptDismissTask()
        notice = nil
        error = nil
        progress = nil
        if let dismissedPrompt {
            recordFeedbackEvent(
                source: "BeckonFeedbackCenter.dismissed",
                level: .info,
                prompt: dismissedPrompt,
                message: "dismissed prompt"
            )
        }
        scheduleQueuedPromptAdvanceIfNeeded()
    }

    private func dismissActiveErrorIfNeeded(matching contentKey: BeckonGlobalFeedbackError.ContentKey) {
        guard error?.contentKey == contentKey else { return }
        dismissedErrorKeys.insert(contentKey)
        dismissActivePrompt()
    }

    private func schedulePromptDismiss(after seconds: TimeInterval, dismiss: @escaping @MainActor (BeckonFeedbackCenter) -> Void) {
        promptExpiresAt = Date().addingTimeInterval(seconds)
        promptDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            guard let self else { return }
            dismiss(self)
        }
    }

    private func cancelPromptDismissTask() {
        promptDismissTask?.cancel()
        promptDismissTask = nil
        promptExpiresAt = nil
    }

    private func scheduleQueuedPromptAdvanceIfNeeded() {
        queuedPromptAdvanceTask?.cancel()
        queuedPromptAdvanceTask = nil

        guard !queuedPrompts.isEmpty else {
            isWaitingToShowQueuedPrompt = false
            return
        }

        isWaitingToShowQueuedPrompt = true
        queuedPromptAdvanceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.queuedPromptAdvanceDelayNanoseconds)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self else { return }
                self.isWaitingToShowQueuedPrompt = false
                self.queuedPromptAdvanceTask = nil
                self.presentNextQueuedPromptIfIdle()
            }
        }
    }

    private func presentNextQueuedPromptIfIdle() {
        guard activePrompt == nil, !queuedPrompts.isEmpty else { return }
        present(queuedPrompts.removeFirst())
    }

    private func recordFeedbackEvent(
        source: String,
        level: AppDebugEventLevel,
        prompt: QueuedPrompt,
        message: String
    ) {
        let snapshot = prompt.debugSnapshot(index: 0)
        var metadata = [
            "kind": snapshot.kind,
            "title": snapshot.title,
        ]
        if let sourceKey = snapshot.sourceKey {
            metadata["sourceKey"] = sourceKey
        }
        if let detail = snapshot.message {
            metadata["message"] = detail
        }

        recordFeedbackEvent(
            source: source,
            level: level,
            scope: prompt.scope,
            message: message,
            metadata: metadata
        )
    }

    private func recordFeedbackEvent(
        source: String,
        level: AppDebugEventLevel,
        scope: BeckonFeedbackScope?,
        message: String,
        metadata: [String: String]
    ) {
        debugRecorder?.record(
            level: level,
            category: .feedback,
            source: source,
            scope: scope?.debugKey,
            message: message,
            metadata: metadata
        )
    }

    private enum QueuedPrompt {
        case notice(BeckonFeedbackNotice)
        case error(BeckonGlobalFeedbackError)
        case progress(BeckonGlobalFeedbackProgress)

        var scope: BeckonFeedbackScope? {
            switch self {
            case .notice:
                nil
            case let .error(error):
                error.scope
            case let .progress(progress):
                progress.scope
            }
        }

        func isEquivalent(to other: QueuedPrompt) -> Bool {
            switch (self, other) {
            case let (.notice(lhs), .notice(rhs)):
                lhs.message == rhs.message
            case let (.error(lhs), .error(rhs)):
                lhs.contentKey == rhs.contentKey
            case let (.progress(lhs), .progress(rhs)):
                lhs.contentKey == rhs.contentKey
            default:
                false
            }
        }

        func isNotice(id: UUID) -> Bool {
            if case let .notice(notice) = self {
                notice.id == id
            } else {
                false
            }
        }

        func isError(matching error: BeckonGlobalFeedbackError) -> Bool {
            if case let .error(queuedError) = self {
                queuedError.contentKey == error.contentKey
            } else {
                false
            }
        }

        func isProgress(matching progress: BeckonGlobalFeedbackProgress) -> Bool {
            if case let .progress(queuedProgress) = self {
                queuedProgress.contentKey == progress.contentKey
            } else {
                false
            }
        }

        func error(in scope: BeckonFeedbackScope) -> BeckonGlobalFeedbackError? {
            if case let .error(error) = self, error.scope == scope {
                error
            } else {
                nil
            }
        }

        func debugSnapshot(index: Int) -> BeckonFeedbackDebugPromptSnapshot {
            switch self {
            case let .notice(notice):
                BeckonFeedbackDebugPromptSnapshot(
                    id: "notice-\(notice.id.uuidString)-\(index)",
                    kind: "notice",
                    scope: nil,
                    sourceKey: nil,
                    title: "Notice",
                    message: notice.message
                )
            case let .error(error):
                BeckonFeedbackDebugPromptSnapshot(
                    id: "error-\(error.sourceKey)-\(index)",
                    kind: "error",
                    scope: error.scope.debugKey,
                    sourceKey: error.sourceKey,
                    title: error.title,
                    message: error.message
                )
            case let .progress(progress):
                BeckonFeedbackDebugPromptSnapshot(
                    id: "progress-\(progress.sourceKey)-\(index)",
                    kind: "progress",
                    scope: progress.scope.debugKey,
                    sourceKey: progress.sourceKey,
                    title: progress.title,
                    message: nil
                )
            }
        }
    }
}

private struct BeckonFeedbackCenterKey: EnvironmentKey {
    static let defaultValue: BeckonFeedbackCenter? = nil
}

extension EnvironmentValues {
    var beckonFeedbackCenter: BeckonFeedbackCenter? {
        get { self[BeckonFeedbackCenterKey.self] }
        set { self[BeckonFeedbackCenterKey.self] = newValue }
    }
}

struct BeckonNoticeForwarder: View {
    @Environment(\.beckonFeedbackCenter) private var feedbackCenter

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
            .onAppear {
                forward(message)
            }
            .onChange(of: message) { _, newMessage in
                forward(newMessage)
            }
    }

    @MainActor
    private func forward(_ message: String?) {
        guard let message, let feedbackCenter else { return }
        feedbackCenter.showNotice(message)
        clear(message)
    }
}

struct BeckonGlobalFeedbackForwarder: View {
    @Environment(\.beckonFeedbackCenter) private var feedbackCenter
    @State private var forwardedError: BeckonGlobalFeedbackError?
    @State private var forwardedProgress: BeckonGlobalFeedbackProgress?

    private let noticeMessage: String?
    private let clearNotice: ((String) -> Void)?
    private let error: BeckonGlobalFeedbackError?
    private let progress: BeckonGlobalFeedbackProgress?

    init(
        noticeMessage: String? = nil,
        clearNotice: ((String) -> Void)? = nil,
        error: BeckonGlobalFeedbackError? = nil,
        progress: BeckonGlobalFeedbackProgress? = nil
    ) {
        self.noticeMessage = noticeMessage
        self.clearNotice = clearNotice
        self.error = error
        self.progress = progress
    }

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onAppear {
                forwardNotice(noticeMessage)
                forwardError(error)
                forwardProgress(progress)
            }
            .onChange(of: noticeMessage) { _, newNoticeMessage in
                forwardNotice(newNoticeMessage)
            }
            .onChange(of: error) { _, newError in
                forwardError(newError)
            }
            .onChange(of: progress) { _, newProgress in
                forwardProgress(newProgress)
            }
            .onDisappear {
                clearScopedPromptsOnDisappear()
            }
    }

    @MainActor
    private func forwardNotice(_ message: String?) {
        guard let message, let feedbackCenter else { return }
        feedbackCenter.showNotice(message)
        clearNotice?(message)
    }

    @MainActor
    private func forwardError(_ error: BeckonGlobalFeedbackError?) {
        guard let feedbackCenter else { return }

        if let error {
            feedbackCenter.showError(error)
            forwardedError = error
        } else if let forwardedError {
            feedbackCenter.clearError(matching: forwardedError)
            self.forwardedError = nil
        }
    }

    @MainActor
    private func forwardProgress(_ progress: BeckonGlobalFeedbackProgress?) {
        guard let feedbackCenter else { return }

        if let progress {
            feedbackCenter.showProgress(progress)
            forwardedProgress = progress
        } else if let forwardedProgress {
            feedbackCenter.clearProgress(matching: forwardedProgress)
            self.forwardedProgress = nil
        }
    }

    @MainActor
    private func clearScopedPromptsOnDisappear() {
        guard let feedbackCenter else { return }

        if let scope = forwardedError?.scope,
           scope.clearsWhenSourceDisappears {
            feedbackCenter.clearTransientPrompts(in: scope)
        }

        if let scope = forwardedProgress?.scope,
           scope.clearsWhenSourceDisappears {
            feedbackCenter.clearTransientPrompts(in: scope)
        }
    }
}

enum BeckonToastTone {
    case success
    case error
    case neutral

    var disc: Color {
        switch self {
        case .success: DesignTokens.Colors.customerFill
        case .error: DesignTokens.Colors.statusErrorFill
        case .neutral: DesignTokens.Colors.iconTileFill
        }
    }

    var glyph: Color {
        switch self {
        case .success: DesignTokens.Colors.customerInk
        case .error: DesignTokens.Colors.statusErrorText
        case .neutral: DesignTokens.Colors.customerDeep
        }
    }

    var track: Color {
        switch self {
        case .success, .neutral: DesignTokens.Colors.customerTint
        case .error: DesignTokens.Colors.statusErrorFill
        }
    }

    var bar: Color {
        switch self {
        case .success, .neutral: DesignTokens.Colors.customerFill
        case .error: DesignTokens.Colors.statusErrorText
        }
    }
}


/// The one message layout, shared by toasts and the snackbar (`DesignSnackbar`): round icon, title (and an optional
/// second line), an optional trailing control (the snackbar's action), and for self-dismissing messages a countdown bar along the
/// bottom of the card. At accessibility sizes the trailing control drops under the text instead of squeezing it.
struct BeckonToastCard<Icon: View, Trailing: View>: View {
    let title: String
    let detail: String?
    let tone: BeckonToastTone
    let duration: TimeInterval?
    let icon: Icon
    let trailing: Trailing
    let hasTrailing: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    init(title: String, detail: String? = nil, tone: BeckonToastTone, duration: TimeInterval? = nil,
         @ViewBuilder icon: () -> Icon, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.detail = detail
        self.tone = tone
        self.duration = duration
        self.icon = icon()
        self.trailing = trailing()
        hasTrailing = true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(alignment: typeSize.isAccessibilitySize ? .top : .center, spacing: DesignTokens.Spacing.md) {
                icon
                    .dynamicTypeSize(.large)
                    .frame(width: DesignTokens.Metrics.ledgeIconTile, height: DesignTokens.Metrics.ledgeIconTile)
                    .background(tone.disc, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(title)
                        .font(DesignTokens.Typography.Expressive.emphasis)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let detail {
                        Text(detail)
                            .font(DesignTokens.Typography.Expressive.chip)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if hasTrailing, !typeSize.isAccessibilitySize { trailing }
            }

            if hasTrailing, typeSize.isAccessibilitySize { trailing }

            if let duration {
                BeckonToastCountdown(duration: duration, tone: tone)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .beckonLedge(.card)
        // A toast with a control keeps it a separate element for VoiceOver; the others read as one sentence.
        .accessibilityElement(children: hasTrailing ? .contain : .combine)
    }
}


extension BeckonToastCard where Trailing == EmptyView {
    init(title: String, detail: String? = nil, tone: BeckonToastTone, duration: TimeInterval? = nil,
         @ViewBuilder icon: () -> Icon) {
        self.title = title
        self.detail = detail
        self.tone = tone
        self.duration = duration
        self.icon = icon()
        trailing = EmptyView()
        hasTrailing = false
    }
}


/// A rounded bar that drains from full to empty over `duration`, anchored at the leading edge so it empties toward the icon. It
/// starts when it appears, so a toast that is replaced (new `id`) starts a fresh bar. Hidden from VoiceOver: the toast
/// is announced when it appears and the bar only repeats what the clock does anyway.
private struct BeckonToastCountdown: View {
    let duration: TimeInterval
    let tone: BeckonToastTone
    @State private var remaining: CGFloat = 1

    private let height: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(tone.track)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(tone.bar)
                        .frame(width: proxy.size.width * remaining)
                }
        }
        .frame(height: height)
        .onAppear {
            withAnimation(.linear(duration: duration)) { remaining = 0 }
        }
        .accessibilityHidden(true)
    }
}


struct BeckonNoticeToast: View {
    private let message: String
    private let duration: TimeInterval?

    init(message: String, duration: TimeInterval? = nil) {
        self.message = message
        self.duration = duration
    }

    var body: some View {
        let parts = Self.split(message)
        BeckonToastCard(title: parts.title, detail: parts.detail, tone: .success, duration: duration) {
            Image(systemName: "checkmark")
                .font(DesignTokens.Typography.Expressive.label.weight(.heavy))
                .foregroundStyle(DesignTokens.Colors.customerInk)
        }
    }

    /// "Changes saved. Your edits are live." reads as a title and a second line; a message without a sentence break is only a
    /// title, without its closing full stop.
    static func split(_ message: String) -> (title: String, detail: String?) {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = trimmed.range(of: ". ") {
            let detail = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (String(trimmed[..<range.lowerBound]), detail.isEmpty ? nil : detail)
        }
        return (trimmed.hasSuffix(".") ? String(trimmed.dropLast()) : trimmed, nil)
    }
}


struct BeckonBottomErrorPrompt: View {
    private let title: String
    private let message: String?
    private let duration: TimeInterval?

    init(title: String, message: String? = nil, duration: TimeInterval? = nil) {
        self.title = title
        self.message = message
        self.duration = duration
    }

    var body: some View {
        BeckonToastCard(title: title, detail: message, tone: .error, duration: duration) {
            Image(systemName: "exclamationmark")
                .font(DesignTokens.Typography.Expressive.label.weight(.heavy))
                .foregroundStyle(DesignTokens.Colors.statusErrorText)
        }
    }
}


/// Work in progress: a spinner instead of a check and no countdown, because it ends when the work does, not on a timer.
struct BeckonStatusProgressToast: View {
    private let title: String
    private let tint: Color

    init(_ title: String, tint: Color) {
        self.title = title
        self.tint = tint
    }

    var body: some View {
        BeckonToastCard(title: title, tone: .neutral) {
            ProgressView()
                .tint(tint)
        }
    }
}


/// Tap a button, watch the real overlay: slide in, countdown, slide out. Runs the shared `BeckonFeedbackCenter`, so the queue is the
/// one the app uses; the times are the reading times of `FeedbackTimingPolicy` (about 4 s for a short notice, 8 s for the long one).
struct BeckonLoadingView: View {
    enum Accent {
        case customer
        case groomer

        fileprivate var tint: Color {
            switch self {
            case .customer:
                DesignTokens.Colors.customerDeep
            case .groomer:
                DesignTokens.Colors.groomerDeep
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
        .beckonShadow(DesignTokens.Shadows.smallCard)
        .accessibilityElement(children: .combine)
    }
}

struct BeckonEmptyState<Action: View>: View {
    enum Accent {
        case customer
        case groomer

        fileprivate var foreground: Color {
            switch self {
            case .customer:
                DesignTokens.Colors.customerDeep
            case .groomer:
                DesignTokens.Colors.groomerDeep
            }
        }

        fileprivate var background: Color {
            switch self {
            case .customer:
                DesignTokens.Colors.customerTint
            case .groomer:
                DesignTokens.Colors.groomerTint
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
        BeckonCard(padding: DesignTokens.Spacing.xl) {
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

extension BeckonEmptyState where Action == EmptyView {
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

struct BeckonSectionHeader<Trailing: View>: View {
    private let title: String
    private let subtitle: String?
    private let trailing: Trailing

    init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        BeckonSectionHeading(title: title, subtitle: subtitle) {
            trailing
        }
        .padding(.horizontal, DesignTokens.Spacing.xs)
    }
}

extension BeckonSectionHeader where Trailing == EmptyView {
    init(
        _ title: String,
        subtitle: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        trailing = EmptyView()
    }
}

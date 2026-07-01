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

enum GroomlyFeedbackScope: Equatable, Hashable, Sendable {
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

enum GroomlyFeedbackTone: Equatable, Sendable {
    case customer
    case groomer
    case neutral

    var tint: Color {
        switch self {
        case .customer:
            DesignTokens.Colors.customerPrimary
        case .groomer:
            DesignTokens.Colors.groomerAccent
        case .neutral:
            DesignTokens.Colors.textSecondary
        }
    }
}

struct GroomlyGlobalFeedbackError: Equatable, Identifiable {
    let id: UUID
    let scope: GroomlyFeedbackScope
    let sourceKey: String
    let title: String
    let message: String?

    init(
        id: UUID = UUID(),
        scope: GroomlyFeedbackScope = .global,
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
        let scope: GroomlyFeedbackScope
        let sourceKey: String
        let title: String
        let message: String?
    }

    static func == (
        lhs: GroomlyGlobalFeedbackError,
        rhs: GroomlyGlobalFeedbackError
    ) -> Bool {
        lhs.contentKey == rhs.contentKey
    }

    private static func defaultSourceKey(title: String, message: String?) -> String {
        [title, message].compactMap { $0 }.joined(separator: "|")
    }
}

struct GroomlyGlobalFeedbackProgress: Equatable, Identifiable {
    let id: UUID
    let scope: GroomlyFeedbackScope
    let sourceKey: String
    let title: String
    let tone: GroomlyFeedbackTone

    init(
        id: UUID = UUID(),
        scope: GroomlyFeedbackScope = .global,
        sourceKey: String? = nil,
        title: String,
        tone: GroomlyFeedbackTone = .neutral
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
        let scope: GroomlyFeedbackScope
        let sourceKey: String
        let title: String
        let tone: GroomlyFeedbackTone
    }

    static func == (
        lhs: GroomlyGlobalFeedbackProgress,
        rhs: GroomlyGlobalFeedbackProgress
    ) -> Bool {
        lhs.contentKey == rhs.contentKey
    }
}

struct GroomlyPersistentFeedbackError: Equatable, Identifiable {
    let id: UUID
    let scope: GroomlyFeedbackScope
    let sourceKey: String
    let title: String
    let message: String
    let actionTitle: String?

    init(
        id: UUID = UUID(),
        scope: GroomlyFeedbackScope,
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
        let scope: GroomlyFeedbackScope
        let sourceKey: String
    }
}

struct GroomlyFeedbackDebugPromptSnapshot: Equatable, Identifiable {
    let id: String
    let kind: String
    let scope: String?
    let sourceKey: String?
    let title: String
    let message: String?
}

struct GroomlyFeedbackDebugSnapshot: Equatable {
    let active: GroomlyFeedbackDebugPromptSnapshot?
    let queued: [GroomlyFeedbackDebugPromptSnapshot]
}

struct GroomlyPersistentErrorView<Action: View>: View {
    private let error: GroomlyPersistentFeedbackError
    private let systemImage: String
    private let showsAction: Bool
    private let action: Action

    init(
        _ error: GroomlyPersistentFeedbackError,
        systemImage: String = "exclamationmark.triangle.fill",
        @ViewBuilder action: () -> Action
    ) {
        self.error = error
        self.systemImage = systemImage
        showsAction = true
        self.action = action()
    }

    var body: some View {
        GroomlyCard(padding: DesignTokens.Spacing.xl) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    Image(systemName: systemImage)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.error)
                        .frame(width: 52, height: 52)
                        .background(DesignTokens.Colors.error.opacity(0.12))
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
                .stroke(DesignTokens.Colors.error.opacity(0.24), lineWidth: 1)
        }
        .accessibilityIdentifier("groomly.persistent-error")
    }
}

extension GroomlyPersistentErrorView where Action == EmptyView {
    init(
        _ error: GroomlyPersistentFeedbackError,
        systemImage: String = "exclamationmark.triangle.fill"
    ) {
        self.error = error
        self.systemImage = systemImage
        showsAction = false
        action = EmptyView()
    }
}

struct GroomlyBottomPrompt<Content: View>: View {
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
            .groomlyShadow(DesignTokens.Shadows.smallCard)
            .accessibilityElement(children: .combine)
    }
}

struct GroomlyBottomPromptStack<Content: View>: View {
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
        .animation(.easeInOut(duration: 0.24), value: animationValue)
    }
}

struct GroomlyBottomPromptArea<Content: View>: View {
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
                GroomlyNoticeForwarder(message: noticeMessage, clear: clearNotice)
            }

            if isPresented {
                GroomlyBottomPromptStack(
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
final class GroomlyFeedbackCenter {
    static let noticeDismissDelayNanoseconds: UInt64 = 2_000_000_000
    static let errorDismissDelayNanoseconds: UInt64 = 2_000_000_000
    static let queuedPromptAdvanceDelayNanoseconds: UInt64 = 280_000_000

    private var debugRecorder: AppDebugEventRecorder?
    private(set) var notice: GroomlyFeedbackNotice?
    private(set) var error: GroomlyGlobalFeedbackError?
    private(set) var progress: GroomlyGlobalFeedbackProgress?
    private var queuedPrompts: [QueuedPrompt] = []
    private var dismissedErrorKeys: Set<GroomlyGlobalFeedbackError.ContentKey> = []
    private var isWaitingToShowQueuedPrompt = false
    private var queuedPromptAdvanceTask: Task<Void, Never>?
    private var errorDismissTask: Task<Void, Never>?

    init(debugRecorder: AppDebugEventRecorder? = nil) {
        self.debugRecorder = debugRecorder
    }

    func setDebugRecorder(_ recorder: AppDebugEventRecorder?) {
        debugRecorder = recorder
    }

    @discardableResult
    func showNotice(_ message: String) -> UUID {
        let id = UUID()
        enqueue(.notice(GroomlyFeedbackNotice(id: id, message: message)))
        return id
    }

    func showError(_ error: GroomlyGlobalFeedbackError) {
        enqueue(.error(error))
    }

    func showProgress(_ progress: GroomlyGlobalFeedbackProgress) {
        enqueue(.progress(progress))
    }

    func clearNotice(id: UUID) {
        if notice?.id == id {
            dismissActivePrompt()
        } else {
            queuedPrompts.removeAll { $0.isNotice(id: id) }
        }
    }

    func clearError(matching error: GroomlyGlobalFeedbackError) {
        dismissedErrorKeys.remove(error.contentKey)

        if self.error?.contentKey == error.contentKey {
            dismissActivePrompt()
        } else {
            queuedPrompts.removeAll { $0.isError(matching: error) }
        }
    }

    func clearProgress(matching progress: GroomlyGlobalFeedbackProgress) {
        if self.progress?.contentKey == progress.contentKey {
            dismissActivePrompt()
        } else {
            queuedPrompts.removeAll { $0.isProgress(matching: progress) }
        }
    }

    func clearTransientPrompts(in scope: GroomlyFeedbackScope) {
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
                source: "GroomlyFeedbackCenter.clearedScope",
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
            source: "GroomlyFeedbackCenter.clearedScope",
            level: .debug,
            scope: scope,
            message: "cleared scope",
            metadata: ["removedCount": "\(removedPromptCount)"]
        )
    }

    var hasVisiblePrompt: Bool {
        notice != nil || error != nil || progress != nil
    }

    var animationKey: String {
        [
            progress?.id.uuidString ?? "no-progress",
            error?.id.uuidString ?? "no-error",
            notice?.id.uuidString ?? "no-notice"
        ].joined(separator: ":")
    }

    var debugSnapshot: GroomlyFeedbackDebugSnapshot {
        GroomlyFeedbackDebugSnapshot(
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
                source: "GroomlyFeedbackCenter.suppressedStale",
                level: .debug,
                prompt: prompt,
                message: "suppressed stale prompt"
            )
            return
        }
        guard !containsEquivalentPrompt(prompt) else {
            recordFeedbackEvent(
                source: "GroomlyFeedbackCenter.suppressedDuplicate",
                level: .debug,
                prompt: prompt,
                message: "suppressed duplicate prompt"
            )
            return
        }

        recordFeedbackEvent(
            source: "GroomlyFeedbackCenter.enqueue",
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
        cancelErrorDismissTask()
        notice = nil
        error = nil
        progress = nil

        switch prompt {
        case let .notice(notice):
            self.notice = notice
        case let .error(error):
            self.error = error
            scheduleErrorDismiss(for: error)
        case let .progress(progress):
            self.progress = progress
        }

        recordFeedbackEvent(
            source: "GroomlyFeedbackCenter.presented",
            level: .info,
            prompt: prompt,
            message: "presented prompt"
        )
    }

    private func dismissActivePrompt() {
        let dismissedPrompt = activePrompt
        cancelErrorDismissTask()
        notice = nil
        error = nil
        progress = nil
        if let dismissedPrompt {
            recordFeedbackEvent(
                source: "GroomlyFeedbackCenter.dismissed",
                level: .info,
                prompt: dismissedPrompt,
                message: "dismissed prompt"
            )
        }
        scheduleQueuedPromptAdvanceIfNeeded()
    }

    private func dismissActiveErrorIfNeeded(matching contentKey: GroomlyGlobalFeedbackError.ContentKey) {
        guard error?.contentKey == contentKey else { return }
        dismissedErrorKeys.insert(contentKey)
        dismissActivePrompt()
    }

    private func scheduleErrorDismiss(for error: GroomlyGlobalFeedbackError) {
        let contentKey = error.contentKey
        errorDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.errorDismissDelayNanoseconds)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.28)) {
                    self?.dismissActiveErrorIfNeeded(matching: contentKey)
                }
            }
        }
    }

    private func cancelErrorDismissTask() {
        errorDismissTask?.cancel()
        errorDismissTask = nil
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
        scope: GroomlyFeedbackScope?,
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
        case notice(GroomlyFeedbackNotice)
        case error(GroomlyGlobalFeedbackError)
        case progress(GroomlyGlobalFeedbackProgress)

        var scope: GroomlyFeedbackScope? {
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

        func isError(matching error: GroomlyGlobalFeedbackError) -> Bool {
            if case let .error(queuedError) = self {
                queuedError.contentKey == error.contentKey
            } else {
                false
            }
        }

        func isProgress(matching progress: GroomlyGlobalFeedbackProgress) -> Bool {
            if case let .progress(queuedProgress) = self {
                queuedProgress.contentKey == progress.contentKey
            } else {
                false
            }
        }

        func error(in scope: GroomlyFeedbackScope) -> GroomlyGlobalFeedbackError? {
            if case let .error(error) = self, error.scope == scope {
                error
            } else {
                nil
            }
        }

        func debugSnapshot(index: Int) -> GroomlyFeedbackDebugPromptSnapshot {
            switch self {
            case let .notice(notice):
                GroomlyFeedbackDebugPromptSnapshot(
                    id: "notice-\(notice.id.uuidString)-\(index)",
                    kind: "notice",
                    scope: nil,
                    sourceKey: nil,
                    title: "Notice",
                    message: notice.message
                )
            case let .error(error):
                GroomlyFeedbackDebugPromptSnapshot(
                    id: "error-\(error.sourceKey)-\(index)",
                    kind: "error",
                    scope: error.scope.debugKey,
                    sourceKey: error.sourceKey,
                    title: error.title,
                    message: error.message
                )
            case let .progress(progress):
                GroomlyFeedbackDebugPromptSnapshot(
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

struct GroomlyGlobalFeedbackForwarder: View {
    @Environment(\.groomlyFeedbackCenter) private var feedbackCenter
    @State private var forwardedError: GroomlyGlobalFeedbackError?
    @State private var forwardedProgress: GroomlyGlobalFeedbackProgress?

    private let noticeMessage: String?
    private let clearNotice: ((String) -> Void)?
    private let error: GroomlyGlobalFeedbackError?
    private let progress: GroomlyGlobalFeedbackProgress?

    init(
        noticeMessage: String? = nil,
        clearNotice: ((String) -> Void)? = nil,
        error: GroomlyGlobalFeedbackError? = nil,
        progress: GroomlyGlobalFeedbackProgress? = nil
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
    private func forwardError(_ error: GroomlyGlobalFeedbackError?) {
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
    private func forwardProgress(_ progress: GroomlyGlobalFeedbackProgress?) {
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

struct GroomlyGlobalFeedbackOverlay: View {
    static let bottomTabBarClearance = DesignTokens.Spacing.xl * 3 + DesignTokens.Spacing.sm

    let center: GroomlyFeedbackCenter

    var body: some View {
        if center.hasVisiblePrompt {
            GroomlyBottomPromptStack(
                bottomPadding: Self.bottomTabBarClearance,
                animationValue: center.animationKey
            ) {
                if let progress = center.progress {
                    GroomlyStatusProgressToast(
                        progress.title,
                        tint: progress.tone.tint
                    )
                }

                if let error = center.error {
                    GroomlyBottomErrorPrompt(
                        title: error.title,
                        message: error.message
                    )
                }

                if let notice = center.notice {
                    GroomlyNoticeToast(message: notice.message)
                        .task(id: notice.id) {
                            await dismissNotice(id: notice.id)
                        }
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .allowsHitTesting(false)
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
        GroomlyBottomPrompt(borderColor: DesignTokens.Colors.success.opacity(0.24)) {
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
        }
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

struct GroomlyBottomErrorPrompt: View {
    private let title: String
    private let message: String?

    init(title: String, message: String? = nil) {
        self.title = title
        self.message = message
    }

    var body: some View {
        GroomlyBottomPrompt(borderColor: DesignTokens.Colors.error.opacity(0.28)) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(DesignTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.error)
                    .frame(
                        width: DesignTokens.Spacing.xl + DesignTokens.Spacing.sm,
                        height: DesignTokens.Spacing.xl + DesignTokens.Spacing.sm
                    )
                    .background(DesignTokens.Colors.error.opacity(0.12))
                    .clipShape(DesignTokens.Shapes.circular)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(title)
                        .font(DesignTokens.Typography.body.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)

                    if let message {
                        Text(message)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
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
        GroomlyBottomPrompt {
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
        }
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

import SwiftUI

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
            DesignTokens.Colors.customerPrimary
        case .groomer:
            DesignTokens.Colors.groomerAccent
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
    static let noticeDismissDelayNanoseconds: UInt64 = 2_000_000_000
    static let errorDismissDelayNanoseconds: UInt64 = 2_000_000_000
    static let queuedPromptAdvanceDelayNanoseconds: UInt64 = 280_000_000

    private var debugRecorder: AppDebugEventRecorder?
    private(set) var notice: BeckonFeedbackNotice?
    private(set) var error: BeckonGlobalFeedbackError?
    private(set) var progress: BeckonGlobalFeedbackProgress?
    private var queuedPrompts: [QueuedPrompt] = []
    private var dismissedErrorKeys: Set<BeckonGlobalFeedbackError.ContentKey> = []
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
            source: "BeckonFeedbackCenter.presented",
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

    private func scheduleErrorDismiss(for error: BeckonGlobalFeedbackError) {
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

struct BeckonGlobalFeedbackOverlay: View {
    static let bottomTabBarClearance = DesignTokens.Spacing.xl * 3 + DesignTokens.Spacing.sm
    static let sheetBottomClearance = DesignTokens.Spacing.xl

    let center: BeckonFeedbackCenter
    let bottomPadding: CGFloat

    init(
        center: BeckonFeedbackCenter,
        bottomPadding: CGFloat = Self.bottomTabBarClearance
    ) {
        self.center = center
        self.bottomPadding = bottomPadding
    }

    var body: some View {
        if center.hasVisiblePrompt {
            BeckonBottomPromptStack(
                bottomPadding: bottomPadding,
                animationValue: center.animationKey
            ) {
                if let progress = center.progress {
                    BeckonStatusProgressToast(
                        progress.title,
                        tint: progress.tone.tint
                    )
                }

                if let error = center.error {
                    BeckonBottomErrorPrompt(
                        title: error.title,
                        message: error.message
                    )
                }

                if let notice = center.notice {
                    BeckonNoticeToast(message: notice.message)
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
            nanoseconds: BeckonFeedbackCenter.noticeDismissDelayNanoseconds
        )
        guard !Task.isCancelled else { return }

        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.28)) {
                center.clearNotice(id: id)
            }
        }
    }
}

struct BeckonNoticeToast: View {
    private let message: String

    init(message: String) {
        self.message = message
    }

    var body: some View {
        BeckonBottomPrompt(borderColor: DesignTokens.Colors.success.opacity(0.24)) {
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

struct BeckonBottomErrorPrompt: View {
    private let title: String
    private let message: String?

    init(title: String, message: String? = nil) {
        self.title = title
        self.message = message
    }

    var body: some View {
        BeckonBottomPrompt(borderColor: DesignTokens.Colors.error.opacity(0.28)) {
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

struct BeckonStatusProgressToast: View {
    private let title: String
    private let tint: Color

    init(_ title: String, tint: Color) {
        self.title = title
        self.tint = tint
    }

    var body: some View {
        BeckonBottomPrompt {
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

struct BeckonLoadingView: View {
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

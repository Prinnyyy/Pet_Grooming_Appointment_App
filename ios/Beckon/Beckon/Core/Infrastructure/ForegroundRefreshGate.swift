import Foundation
import SwiftUI

nonisolated enum ForegroundRefreshReason: Equatable, Sendable {
    case initialLoad
    case sceneBecameActive
    case realtimeFallback
    case deadlineReached
}

@MainActor
final class ForegroundRefreshGate {
    static let defaultMinimumForegroundRefreshInterval: TimeInterval = 5
    static let defaultRealtimeFallbackInterval: TimeInterval = 45

    let minimumForegroundRefreshInterval: TimeInterval
    let realtimeFallbackInterval: TimeInterval

    private(set) var isRefreshing = false
    private(set) var lastRefreshAt: Date?
    private(set) var lastSuppressedReason: ForegroundRefreshReason?

    init(
        minimumForegroundRefreshInterval: TimeInterval = ForegroundRefreshGate.defaultMinimumForegroundRefreshInterval,
        realtimeFallbackInterval: TimeInterval = ForegroundRefreshGate.defaultRealtimeFallbackInterval
    ) {
        self.minimumForegroundRefreshInterval = minimumForegroundRefreshInterval
        self.realtimeFallbackInterval = realtimeFallbackInterval
    }

    func refresh(
        reason: ForegroundRefreshReason,
        now: Date = Date(),
        fallbackOperation: (@MainActor () async -> Void)? = nil,
        operation: @MainActor () async -> Void
    ) async {
        guard shouldStartRefresh(reason: reason, now: now) else {
            lastSuppressedReason = reason
            return
        }

        isRefreshing = true
        lastSuppressedReason = nil
        defer {
            isRefreshing = false
        }

        if let fallbackOperation, reason == .realtimeFallback || reason == .deadlineReached {
            await fallbackOperation()
        } else {
            await operation()
        }
        lastRefreshAt = now
    }

    private func shouldStartRefresh(
        reason: ForegroundRefreshReason,
        now: Date
    ) -> Bool {
        guard !isRefreshing else { return false }

        guard let lastRefreshAt else { return true }

        switch reason {
        case .deadlineReached:
            return true
        case .initialLoad:
            return false
        case .sceneBecameActive:
            return now.timeIntervalSince(lastRefreshAt) >= minimumForegroundRefreshInterval
        case .realtimeFallback:
            return now.timeIntervalSince(lastRefreshAt) >= realtimeFallbackInterval
        }
    }
}

private struct ForegroundRefreshModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @State private var gate: ForegroundRefreshGate

    private let realtimeFallbackInterval: TimeInterval
    private let isEnabled: Bool
    private let nextDeadline: Date?
    private let fallbackAction: (@MainActor () async -> Void)?
    private let refreshAction: @MainActor () async -> Void

    init(
        minimumForegroundRefreshInterval: TimeInterval,
        realtimeFallbackInterval: TimeInterval,
        isEnabled: Bool,
        nextDeadline: Date?,
        fallbackAction: (@MainActor () async -> Void)?,
        refreshAction: @escaping @MainActor () async -> Void
    ) {
        self.realtimeFallbackInterval = realtimeFallbackInterval
        self.isEnabled = isEnabled
        self.nextDeadline = nextDeadline
        self.fallbackAction = fallbackAction
        self.refreshAction = refreshAction
        _gate = State(
            initialValue: ForegroundRefreshGate(
                minimumForegroundRefreshInterval: minimumForegroundRefreshInterval,
                realtimeFallbackInterval: realtimeFallbackInterval
            )
        )
    }

    func body(content: Content) -> some View {
        content
            .task(id: isEnabled) {
                guard isEnabled else { return }
                await refresh(reason: gate.lastRefreshAt == nil ? .initialLoad : .sceneBecameActive)
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active, isEnabled else { return }

                Task {
                    await refresh(reason: .sceneBecameActive)
                }
            }
            .task(id: scenePhase == .active && isEnabled) {
                guard scenePhase == .active, isEnabled else { return }

                await runRealtimeFallbackLoop()
            }
            .task(id: scenePhase == .active && isEnabled ? nextDeadline : nil) {
                guard scenePhase == .active, isEnabled, let nextDeadline else { return }
                let delay = max(0, nextDeadline.timeIntervalSinceNow)
                do { try await Task.sleep(for: .seconds(delay)) } catch { return }
                await refresh(reason: .deadlineReached)
            }
    }

    private func runRealtimeFallbackLoop() async {
        while !Task.isCancelled {
            let nanoseconds = UInt64(realtimeFallbackInterval * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }

            await refresh(reason: .realtimeFallback)
        }
    }

    private func refresh(reason: ForegroundRefreshReason) async {
        guard isEnabled, !Task.isCancelled else { return }
        await gate.refresh(reason: reason, fallbackOperation: fallbackAction) {
            await refreshAction()
        }
    }
}

extension View {
    func foregroundRefreshable(
        minimumForegroundRefreshInterval: TimeInterval = ForegroundRefreshGate.defaultMinimumForegroundRefreshInterval,
        realtimeFallbackInterval: TimeInterval = ForegroundRefreshGate.defaultRealtimeFallbackInterval,
        isEnabled: Bool = true,
        nextDeadline: Date? = nil,
        fallbackAction: (@MainActor () async -> Void)? = nil,
        refreshAction: @escaping @MainActor () async -> Void
    ) -> some View {
        modifier(
            ForegroundRefreshModifier(
                minimumForegroundRefreshInterval: minimumForegroundRefreshInterval,
                realtimeFallbackInterval: realtimeFallbackInterval,
                isEnabled: isEnabled,
                nextDeadline: nextDeadline,
                fallbackAction: fallbackAction,
                refreshAction: refreshAction
            )
        )
    }
}

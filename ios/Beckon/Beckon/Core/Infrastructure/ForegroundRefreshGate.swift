import Foundation
import SwiftUI

nonisolated enum ForegroundRefreshReason: Equatable, Sendable {
    case initialLoad
    case sceneBecameActive
    case realtimeFallback
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

        await operation()
        lastRefreshAt = now
    }

    private func shouldStartRefresh(
        reason: ForegroundRefreshReason,
        now: Date
    ) -> Bool {
        guard !isRefreshing else { return false }

        guard let lastRefreshAt else { return true }

        switch reason {
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
    private let refreshAction: @MainActor () async -> Void

    init(
        minimumForegroundRefreshInterval: TimeInterval,
        realtimeFallbackInterval: TimeInterval,
        refreshAction: @escaping @MainActor () async -> Void
    ) {
        self.realtimeFallbackInterval = realtimeFallbackInterval
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
            .task {
                await refresh(reason: .initialLoad)
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }

                Task {
                    await refresh(reason: .sceneBecameActive)
                }
            }
            .task(id: scenePhase == .active) {
                guard scenePhase == .active else { return }

                await runRealtimeFallbackLoop()
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
        await gate.refresh(reason: reason) {
            await refreshAction()
        }
    }
}

extension View {
    func foregroundRefreshable(
        minimumForegroundRefreshInterval: TimeInterval = ForegroundRefreshGate.defaultMinimumForegroundRefreshInterval,
        realtimeFallbackInterval: TimeInterval = ForegroundRefreshGate.defaultRealtimeFallbackInterval,
        refreshAction: @escaping @MainActor () async -> Void
    ) -> some View {
        modifier(
            ForegroundRefreshModifier(
                minimumForegroundRefreshInterval: minimumForegroundRefreshInterval,
                realtimeFallbackInterval: realtimeFallbackInterval,
                refreshAction: refreshAction
            )
        )
    }
}

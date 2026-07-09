import Foundation
import Testing
@testable import PetGroomerMarketplace

struct ForegroundRefreshGateTests {
    @Test @MainActor
    func initialRefreshRunsAndRecordsTimestamp() async {
        let gate = ForegroundRefreshGate(
            minimumForegroundRefreshInterval: 5,
            realtimeFallbackInterval: 30
        )
        let now = Date(timeIntervalSince1970: 100)
        var refreshCount = 0

        await gate.refresh(reason: .initialLoad, now: now) {
            refreshCount += 1
        }

        #expect(refreshCount == 1)
        #expect(gate.lastRefreshAt == now)
    }

    @Test @MainActor
    func foregroundRefreshIsSuppressedWhenRecent() async {
        let gate = ForegroundRefreshGate(
            minimumForegroundRefreshInterval: 5,
            realtimeFallbackInterval: 30
        )
        var refreshCount = 0

        await gate.refresh(reason: .initialLoad, now: Date(timeIntervalSince1970: 100)) {
            refreshCount += 1
        }
        await gate.refresh(reason: .sceneBecameActive, now: Date(timeIntervalSince1970: 103)) {
            refreshCount += 1
        }

        #expect(refreshCount == 1)
        #expect(gate.lastSuppressedReason == .sceneBecameActive)
    }

    @Test @MainActor
    func foregroundRefreshRunsAfterMinimumInterval() async {
        let gate = ForegroundRefreshGate(
            minimumForegroundRefreshInterval: 5,
            realtimeFallbackInterval: 30
        )
        var refreshCount = 0

        await gate.refresh(reason: .initialLoad, now: Date(timeIntervalSince1970: 100)) {
            refreshCount += 1
        }
        await gate.refresh(reason: .sceneBecameActive, now: Date(timeIntervalSince1970: 106)) {
            refreshCount += 1
        }

        #expect(refreshCount == 2)
        #expect(gate.lastRefreshAt == Date(timeIntervalSince1970: 106))
    }

    @Test @MainActor
    func realtimeFallbackUsesLongerInterval() async {
        let gate = ForegroundRefreshGate(
            minimumForegroundRefreshInterval: 5,
            realtimeFallbackInterval: 30
        )
        var refreshCount = 0

        await gate.refresh(reason: .initialLoad, now: Date(timeIntervalSince1970: 100)) {
            refreshCount += 1
        }
        await gate.refresh(reason: .realtimeFallback, now: Date(timeIntervalSince1970: 120)) {
            refreshCount += 1
        }
        await gate.refresh(reason: .realtimeFallback, now: Date(timeIntervalSince1970: 131)) {
            refreshCount += 1
        }

        #expect(refreshCount == 2)
        #expect(gate.lastRefreshAt == Date(timeIntervalSince1970: 131))
    }

    @Test @MainActor
    func concurrentRefreshesAreDeduplicated() async {
        let gate = ForegroundRefreshGate(
            minimumForegroundRefreshInterval: 0,
            realtimeFallbackInterval: 0
        )
        let probe = ForegroundRefreshProbe()

        async let first: Void = gate.refresh(
            reason: .sceneBecameActive,
            now: Date(timeIntervalSince1970: 100)
        ) {
            probe.increment()
            try? await Task.sleep(for: .milliseconds(20))
        }
        async let second: Void = gate.refresh(
            reason: .realtimeFallback,
            now: Date(timeIntervalSince1970: 101)
        ) {
            probe.increment()
        }
        _ = await (first, second)

        #expect(probe.refreshCount == 1)
        #expect(gate.lastSuppressedReason == .realtimeFallback)
    }
}

@MainActor
private final class ForegroundRefreshProbe {
    private(set) var refreshCount = 0

    func increment() {
        refreshCount += 1
    }
}

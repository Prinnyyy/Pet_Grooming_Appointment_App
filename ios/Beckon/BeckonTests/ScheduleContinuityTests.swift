import SwiftUI
import Testing
import XCTest
@testable import Beckon

@MainActor struct ScheduleContinuityTests {
    @Test func calendarAndHoursRemainVisibleDuringTransientRefreshButAccessLossRevokesThem() async {
        let owner = UUID()
        let hours = GroomerAvailabilityWeekday.allCases.map { GroomerAvailabilityWindow(id: UUID(), groomerID: owner,
            weekday: $0, startMinutes: 540, endMinutes: 1020, isEnabled: true, timezone: "America/Los_Angeles") }
        let profile = GroomerProfileRepositoryFake(availabilityResult: .success(hours))
        let store = BookingsStore(participantID: owner, role: .groomer, repository: BookingRepositoryFake(),
            groomerProfileRepository: profile, appointmentReminderScheduler: AppointmentReminderSchedulerFake())
        await store.load()
        #expect(store.scheduleCalendar != nil)
        #expect(store.scheduleCalendarReadState == .complete)
        profile.onRead = { name in
            guard name == "availability" else { return }
            #expect(store.scheduleCalendar != nil)
            #expect(store.scheduleAvailabilityWindows == hours)
        }
        profile.availabilityResult = .failure(.networkUnavailable)
        await store.load()
        #expect(store.scheduleCalendar != nil)
        #expect(store.scheduleAvailabilityWindows == hours)
        #expect(store.scheduleCalendarReadState == .stale)
        profile.onRead = nil
        profile.availabilityResult = .failure(.notAllowed)
        await store.load()
        #expect(store.scheduleCalendar == nil)
        #expect(store.scheduleAvailabilityWindows.isEmpty)
        #expect(store.scheduleCalendarReadState == .failed)
    }

    @Test func knownWeekKeepsItsContentDuringRefreshAndChangedScopeWaits() {
        let known = GroomerScheduleReadPresentation(scopeMatches: true, verifiedAt: Date(), state: .loading, calendarState: .loading)
        #expect(known.hasSnapshot && !known.showsPlaceholder && !known.showsVerificationWarning)
        let unknown = GroomerScheduleReadPresentation(scopeMatches: true, verifiedAt: nil, state: .loading, calendarState: .complete)
        #expect(!unknown.hasSnapshot && unknown.showsPlaceholder)
        let anotherWeek = GroomerScheduleReadPresentation(scopeMatches: false, verifiedAt: Date(), state: .complete, calendarState: .complete)
        #expect(!anotherWeek.hasSnapshot && anotherWeek.showsPlaceholder)
        let stale = GroomerScheduleReadPresentation(scopeMatches: true, verifiedAt: Date(), state: .complete, calendarState: .stale)
        #expect(stale.hasSnapshot && !stale.showsPlaceholder && stale.showsVerificationWarning)
    }

    @Test func quickAutomaticReturnReusesSnapshotWhileManualRefreshStillReads() async {
        let interval = DateInterval(start: Date(), duration: 86400)
        let repository = BookingRepositoryFake()
        let store = BookingsStore(participantID: UUID(), role: .groomer, repository: repository)
        await store.loadSchedule(interval: interval)
        await store.loadSchedule(interval: interval, forceRefresh: false)
        #expect(repository.datePageRequests.count == 1)
        await store.loadSchedule(interval: interval, forceRefresh: true)
        #expect(repository.datePageRequests.count == 2)
    }

    @Test func cancelledRangeRefreshRetainsThePriorReadState() async {
        let interval = DateInterval(start: Date(), duration: 86400)
        let repository = BookingRepositoryFake()
        let store = BookingsStore(participantID: UUID(), role: .groomer, repository: repository)
        await store.loadSchedule(interval: interval)
        let verifiedAt = store.scheduleVerifiedAt
        repository.dateRead = { _, _ in throw BookingRepositoryError.cancelled }
        await store.loadSchedule(interval: interval)
        #expect(store.scheduleReadState == .complete && store.scheduleVerifiedAt == verifiedAt)
    }

    @Test func concurrentSameScopeReadsCoalesceAndLateSessionDataIsDiscarded() async throws {
        let interval = DateInterval(start: Date(), duration: 86400)
        var release: CheckedContinuation<ListPage<Booking>, any Error>?
        var active = true
        let repository = BookingRepositoryFake()
        repository.dateRead = { _, page in
            if repository.datePageRequests.count == 1 {
                return try await withCheckedThrowingContinuation { release = $0 }
            }
            return ListPage(items: [], request: page)
        }
        let store = BookingsStore(participantID: UUID(), role: .groomer, repository: repository,
            sessionIsCurrent: { active })
        let first = Task { await store.loadSchedule(interval: interval) }
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while release == nil, ContinuousClock.now < deadline { await Task.yield() }
        let continuation = try #require(release)
        await store.loadSchedule(interval: interval)
        #expect(repository.datePageRequests.count == 1)
        active = false
        continuation.resume(returning: ListPage(items: [], request: .first))
        await first.value
        #expect(store.scheduleVerifiedAt == nil)
        #expect(store.scheduleReadState != .complete)
    }
}

@MainActor final class SkeletonParityTests: XCTestCase {
    func testClosingDeadlineDoesNotAddARequestRowFooter() {
        func row(_ note: GroomerRequestRowContent.Note?) -> some View {
            GroomerRequestRow(content: GroomerRequestRowContent(species: "Dog", photo: nil, name: "Milo",
                when: BeckonWhen(start: "2026-11-03T10:00:00Z", end: "2026-11-03T11:00:00Z",
                    zoneIdentifier: "America/Los_Angeles", now: Date()),
                breed: "Corgi", weight: "22 lb", service: "Full groom", place: "Seattle", price: nil,
                marks: [.invited(source: "Invited")], note: note), onOpen: {})
        }
        for width: CGFloat in [320, 380] {
            let plain = height(row(nil), width: width, size: .large)
            let closing = height(row(.init(text: "Closes in 1 day", systemImage: "hourglass", tone: .warm,
                compactDeadline: "24h left")), width: width, size: .large)
            XCTAssertEqual(plain, closing, accuracy: 0.5)
            XCTAssertEqual(closing, height(GroomerRequestRowSkeleton(), width: width, size: .large), accuracy: 0.5)
        }
    }

    func testScheduleHeaderMaskKeepsNativeTextAndAccessibilitySizing() {
        let date = Date()
        let calendar = Calendar.current
        for size: DynamicTypeSize in [.large, .xxxLarge, .accessibility3] {
            for width: CGFloat in [320, 380] {
                let actual = GroomerScheduleDayHeader(date: date, calendar: calendar, isToday: true,
                    summary: "2 appointments · 2 hr · $120")
                let placeholder = GroomerScheduleDayHeader(date: date, calendar: calendar, isToday: true,
                    summary: "2 appointments · 2 hr · $120", isLoading: true)
                XCTAssertEqual(height(placeholder, width: width, size: size), height(actual, width: width, size: size),
                    accuracy: 0.5, "\(width) / \(size)")
            }
        }
        let empty = GroomerScheduleDayHeader(date: date, calendar: calendar, isToday: true, summary: nil)
        let booked = GroomerScheduleDayHeader(date: date, calendar: calendar, isToday: true, summary: "2 appointments")
        XCTAssertEqual(height(empty, width: 380, size: .large), height(booked, width: 380, size: .large), accuracy: 0.5)
    }

    func testScheduleTitleKeepsTheCalendarControlFootprintBeforeCalendarReadiness() async {
        let session = GroomerSandboxSession(state: .empty)
        let view = GroomerScheduleView(store: session.bookings, focusedBooking: .constant(nil),
            isActiveTab: false, onOpenChat: { _ in })
        func width() -> CGFloat {
            let host = UIHostingController(rootView: view.titleRow.fixedSize(horizontal: true, vertical: false))
            return host.sizeThatFits(in: CGSize(width: 1000, height: 500)).width
        }
        let unknown = width()
        await session.bookings.load()
        XCTAssertNotNil(session.bookings.scheduleCalendar)
        XCTAssertEqual(width(), unknown, accuracy: 0.5, "Calendar readiness must not insert a new control")
    }

    func testHomeTileSkeletonUsesTheActualTileFootprint() {
        for size: DynamicTypeSize in [.large, .xxxLarge, .accessibility3] {
            for width: CGFloat in [110, 180, 350] {
                let actual = height(GroomerHomeTile(title: "Pending offers", systemImage: "tag.fill", count: 12,
                    hasMore: false, isLoading: false, identifier: "test.tile", action: {}), width: width, size: size)
                let placeholder = height(GroomerHomeTileSkeleton(), width: width, size: size)
                XCTAssertEqual(placeholder, actual, accuracy: 0.5, "\(width) / \(size)")
            }
        }
    }

    func testOneLineSkeletonDoesNotWrapItsHiddenMeasuringText() {
        for size: DynamicTypeSize in [.large, .accessibility3] {
            let line = DesignSkeletonLine(font: DesignTokens.Typography.Expressive.display)
            XCTAssertEqual(height(line, width: 20, size: size), height(line, width: 350, size: size), accuracy: 0.5)
        }
    }

    func testKnownAccountShortcutCopyKeepsItsActualFootprint() {
        for (title, summary) in [("Profile settings", "Photo, nickname, contact, and address"),
            ("Saved groomers", "Groomers you have hearted")] {
            for size: DynamicTypeSize in [.large, .accessibility3] {
                let actual = DesignShortcutRow {
                    DesignShortcutTile(title: title, summary: summary, systemImage: "heart", action: {}) { EmptyView() }
                }
                let placeholder = DesignShortcutRow { DesignShortcutTileSkeleton(title: title, summary: summary) }
                XCTAssertEqual(height(placeholder, width: 170, size: size), height(actual, width: 170, size: size), accuracy: 0.5)
            }
        }
    }

    func testScheduleDayStripSkeletonUsesTheSameScaledTileAndLip() {
        let calendar = Calendar(identifier: .gregorian)
        let days = (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date()))!
            return GroomerScheduleDay(id: "\(offset)", date: date, isToday: offset == 0)
        }
        for size: DynamicTypeSize in [.large, .xxxLarge, .accessibility3] {
            let actual = height(GroomerDayStrip(days: days, calendar: calendar, selectedDayKey: "0", loads: [:], onSelect: { _ in }),
                width: 350, size: size)
            XCTAssertEqual(height(GroomerDayStripSkeleton(), width: 350, size: size), actual, accuracy: 0.5, "\(size)")
        }
    }

    private func height<V: View>(_ view: V, width: CGFloat, size: DynamicTypeSize) -> CGFloat {
        let host = UIHostingController(rootView: view.frame(width: width).environment(\.dynamicTypeSize, size).environment(\.scenePhase, .inactive))
        return host.sizeThatFits(in: CGSize(width: width, height: 10_000)).height
    }
}

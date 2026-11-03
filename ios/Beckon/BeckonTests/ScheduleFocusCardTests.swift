import SwiftUI
import XCTest
@testable import Beckon

@MainActor final class ScheduleFocusCardTests: XCTestCase {
    func testAllFocusStatesKeepTheSameWidthAndHeightWithLongText() throws {
        let calendar = GroomerSandboxFixtures.calendar
        let now = Date()
        let booking = makeBooking(1, start: now.addingTimeInterval(900), longText: true)
        let slot = try XCTUnwrap(GroomerScheduleSlot(booking))
        for size: DynamicTypeSize in [.large, .xxxLarge, .accessibility3] {
            for width: CGFloat in [320, 390] {
                let skeleton = measure(GroomerNowCardSkeleton(), width: width, size: size)
                let empty = measure(GroomerScheduleEmptyCard(note: String(repeating: "Long opening hours and day description. ", count: 12),
                    onSeeRequests: {}), width: width, size: size)
                let closed = measure(GroomerScheduleEmptyCard(note: "Closed", isClosed: true), width: width, size: size)
                for value in [empty, closed] {
                    XCTAssertEqual(value.width, skeleton.width, accuracy: 0.5)
                    XCTAssertEqual(value.height, skeleton.height, accuracy: 0.5)
                }
                for phase: GroomerSlotPhase in [.upcoming, .due, .live] {
                    let card = GroomerNowCard(item: .init(slot: slot, phase: phase), calendar: calendar, now: now,
                        onOpen: {}, onMessage: {}, onStart: phase == .due ? {} : nil,
                        onComplete: phase == .live ? {} : nil)
                    let actual = measure(card, width: width, size: size)
                    XCTAssertEqual(actual.width, skeleton.width, accuracy: 0.5)
                    XCTAssertEqual(actual.height, skeleton.height, accuracy: 0.5, "\(phase)/\(size)/\(width)")
                }
            }
        }
    }

    /// One batch of user-requested page comparisons; no live accounts or services.
    func testExportSchedulePageStateComparisons() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        defer { window.rootViewController = nil; window.isHidden = true; previous?.makeKeyAndVisible() }
        let now = Date()
        let next = makeBooking(1, start: now.addingTimeInterval(60))
        let later = makeBooking(2, start: now.addingTimeInterval(50 * 60))
        let live = makeBooking(3, start: now.addingTimeInterval(-20 * 60), live: true)
        let earlier = makeBooking(4, start: now.addingTimeInterval(-2 * 3600))
        let states: [(String, GroomerSandboxSession)] = [
            ("01-empty", .init(state: .empty)),
            ("02-upcoming", .init(state: .loaded, bookings: [next, later])),
            ("03-in-service", .init(state: .loaded, bookings: [earlier, live, later])),
            ("04-loading", .init(state: .loading))
        ]
        var directory = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { directory.deleteLastPathComponent() }
        directory.appendPathComponent("artifacts/evidence/T-453")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (name, session) in states {
            if session.state != .loading {
                await session.bookings.load()
                let calendar = try XCTUnwrap(session.bookings.scheduleCalendar)
                let start = calendar.startOfDay(for: now)
                let end = try XCTUnwrap(calendar.date(byAdding: .day, value: 7, to: start))
                await session.bookings.loadSchedule(interval: DateInterval(start: start, end: end))
            }
            let host = UIHostingController(rootView: GroomerTabView(sandbox: session, initialTab: .bookings)
                .environment(\.dynamicTypeSize, .large)
                .environment(\.scenePhase, .active)
                .transaction { $0.disablesAnimations = true; $0.animation = nil }
                .preferredColorScheme(.light))
            window.rootViewController = host
            window.makeKeyAndVisible()
            window.setNeedsLayout()
            window.layoutIfNeeded()
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            await Task.yield()
            try await Task.sleep(for: .milliseconds(1600))
            host.view.layoutIfNeeded()
            let format = UIGraphicsImageRendererFormat()
            format.scale = 2
            let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
                XCTAssertTrue(window.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
            }
            try XCTUnwrap(image.pngData()).write(to: directory.appendingPathComponent("\(name).png"))
            let attachment = XCTAttachment(image: image)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
            session.boundary.release()
            window.rootViewController = nil
            await Task.yield()
        }
    }

    private func makeBooking(_ number: Int, start: Date, live: Bool = false, longText: Bool = false) -> Booking {
        GroomerSandboxFixtures.booking(number, pet: GroomerSandboxFixtures.pet(number,
            name: longText ? String(repeating: "Very long pet name ", count: 10) : (live ? "Rosie" : "Milo \(number)"),
            breed: longText ? String(repeating: "Long breed description ", count: 10) : "Corgi",
            size: "M", weight: 26, temperament: "Calm"), service: .fullGroom,
            start: start, end: start.addingTimeInterval(30 * 60), price: 85,
            street: longText ? String(repeating: "Very long street address ", count: 10) : "88 Maple Court", zip: "98109",
            phase: live ? .inService : .scheduled, startedAt: live ? start : nil)
    }

    private func measure<V: View>(_ view: V, width: CGFloat, size: DynamicTypeSize) -> CGSize {
        let host = UIHostingController(rootView: view.environment(\.dynamicTypeSize, size))
        return host.sizeThatFits(in: CGSize(width: width, height: 5000))
    }
}

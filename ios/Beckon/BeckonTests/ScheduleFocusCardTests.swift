import SwiftUI
import XCTest
@testable import Beckon

@MainActor final class ScheduleFocusCardTests: XCTestCase {
    func testTodayAndSkeletonKeepTheOrdinaryDaysTrackThickness() throws {
        let day = GroomerSandboxFixtures.calendar.startOfDay(for: Date())
        let ordinary = GroomerDayShape(items: [], dayStart: day, open: nil, now: nil)
        let today = GroomerDayShape(items: [], dayStart: day, open: nil, now: day.addingTimeInterval(12 * 3600))
        func thickness(_ shape: GroomerDayShape?, x: Int = 80, threshold: UInt8 = 250) throws -> Int {
            let renderer = ImageRenderer(content: GroomerDayShapeBar(shape: shape)
                .frame(width: 320).background(Color.white))
            renderer.scale = 1
            let image = try XCTUnwrap(renderer.cgImage)
            var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
            try pixels.withUnsafeMutableBytes { buffer in
                let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                    bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            }
            // This column is clear of both end labels and the noon marker. Count the whole
            // column so bitmap row orientation does not affect the measured bar thickness.
            return (0..<image.height).filter { y in
                let offset = (y * image.width + x) * 4
                return pixels[offset] < threshold || pixels[offset + 1] < threshold || pixels[offset + 2] < threshold
            }.count
        }
        let baseline = try thickness(ordinary)
        XCTAssertEqual(baseline, Int(DesignTokens.Metrics.dayShapeHeight))
        XCTAssertEqual(try thickness(today), baseline, "The now marker must not enlarge the horizontal track")
        XCTAssertEqual(try thickness(nil), baseline, "The skeleton uses the same thin track")
        // Measure the dark marker ink, excluding the pale track and antialiased fringe.
        XCTAssertEqual(Double(try thickness(today, x: 128, threshold: 180)), Double(baseline), accuracy: 1,
            "The noon marker must fit inside the 12pt track")
    }

    func testAllFocusStatesKeepTheSameWidthAndHeightWithLongText() throws {
        let calendar = GroomerSandboxFixtures.calendar
        let now = Date()
        let booking = makeBooking(1, start: now.addingTimeInterval(900), longText: true)
        let slot = try XCTUnwrap(GroomerScheduleSlot(booking))
        for size: DynamicTypeSize in [.large, .xxxLarge, .accessibility3] {
            for width: CGFloat in [320, 390] {
                let skeleton = measure(GroomerNowCardSkeleton(), width: width, size: size)
                let empty = measure(GroomerScheduleEmptyCard(note: String(repeating: "Long opening hours and day description. ", count: 12),
                    hours: "9:00 AM – 5:00 PM", onSeeRequests: {}), width: width, size: size)
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

    func testHourStripUsesOneGeometryForEmptyBookedAndLoadingDays() throws {
        let calendar = GroomerSandboxFixtures.calendar
        let day = calendar.startOfDay(for: Date())
        let booking = makeBooking(1, start: day.addingTimeInterval(23 * 3600))
        let slot = try XCTUnwrap(GroomerScheduleSlot(booking))
        let empty = GroomerDayShape(items: [], dayStart: day, open: 540...1020, now: day.addingTimeInterval(12 * 3600))
        let late = GroomerDayShape(items: [.init(slot: slot, phase: .upcoming)], dayStart: day, open: 540...1020,
            now: day.addingTimeInterval(12 * 3600))
        XCTAssertEqual(empty.visible, 480...1080)
        XCTAssertEqual(late.visible, 480...1440, "Keep the real data-driven range, including late bookings")
        for size: DynamicTypeSize in [.large, .xxxLarge, .accessibility3] {
            for width: CGFloat in [320, 390] {
                let loading = measure(GroomerDayShapeBarSkeleton(), width: width, size: size)
                for shape in [empty, late] {
                    let actual = measure(GroomerDayShapeBar(shape: shape), width: width, size: size)
                    XCTAssertEqual(actual.width, loading.width, accuracy: 0.5)
                    XCTAssertEqual(actual.height, loading.height, accuracy: 0.5)
                }
                XCTAssertEqual(measure(GroomerScheduleDayHeader(date: day, calendar: calendar, isToday: true,
                    summary: "0 appointments"), width: width, size: size).height,
                    measure(GroomerScheduleDayHeader(date: day, calendar: calendar, isToday: true,
                        summary: "2 appointments · 1h · $170"), width: width, size: size).height, accuracy: 0.5)
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

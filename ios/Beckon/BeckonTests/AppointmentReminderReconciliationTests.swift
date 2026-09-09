import Foundation
import Testing
import UserNotifications
import SwiftUI
import UIKit
import XCTest
@testable import Beckon

@MainActor
final class AppointmentReminderRenderingTests: XCTestCase {
    func testTapShowsCurrentCancelledBookingAndMissingTargetRetry() async throws {
        let owner = UUID()
        let booking = BookingsStoreTests.booking(customerID: owner, status: .cancelledByGroomer)
        for missing in [false, true] {
            let repository = BookingRepositoryFake(bookingsResult: .success(missing ? [] : [booking]))
            let target = AppointmentReminderTap(accountID: owner, bookingID: booking.id, role: .customer)
            let host = UIHostingController(rootView: AppointmentReminderDestinationView(target: target, repository: repository))
            let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let previous = scene.windows.first(where: \.isKeyWindow)
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
            window.rootViewController = host
            window.makeKeyAndVisible()
            host.view.frame = window.bounds
            try await Task.sleep(for: .milliseconds(350))
            host.view.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = missing ? "T382 missing reminder target retry" : "T382 cancelled current reminder target"
            attachment.lifetime = .keepAlways
            add(attachment)
            XCTAssertEqual(image.size, window.bounds.size)
            window.isHidden = true
            window.rootViewController = nil
            previous?.makeKey()
        }
    }
}

@MainActor
struct AppointmentReminderReconciliationTests {
    let account = UUID()
    let now = Date(timeIntervalSince1970: 1_789_000_000)

    @Test func lateFetchAndLateSystemWriteCannotResurrectExitedAccount() async {
        let center = ReminderCenterFake()
        let repository = BookingRepositoryFake()
        repository.reminderResult = .success(snapshot([record()]))
        let scheduler = AppointmentReminderScheduler(notificationCenter: center, now: { now })
        scheduler.configure(repository: repository)
        scheduler.setAccount(account)
        repository.onReminderSnapshot = { scheduler.setAccount(nil) }
        await scheduler.activate(participantID: account, role: .customer)
        #expect(center.pendingRequests.isEmpty)
        repository.onReminderSnapshot = nil
        scheduler.setAccount(account)
        center.onAdd = { scheduler.setAccount(nil) }
        await scheduler.activate(participantID: account, role: .customer)
        #expect(center.pendingRequests.isEmpty)
    }

    @Test func partialPageSignalsRefreshAndRetainsCompleteSnapshotBookings() async {
        let center = ReminderCenterFake()
        let repository = BookingRepositoryFake()
        repository.reminderResult = .success(snapshot([record()]))
        let scheduler = AppointmentReminderScheduler(notificationCenter: center, now: { now })
        scheduler.configure(repository: repository)
        scheduler.setAccount(account)
        await scheduler.activate(participantID: account, role: .customer)
        #expect(await scheduler.syncReminders(for: [], role: .customer) == .scheduled(count: 1))
        #expect(center.pendingRequests.count == 1)
        repository.reminderResult = .failure(.networkUnavailable)
        #expect(await scheduler.refresh() == .unavailable)
        #expect(center.pendingRequests.count == 1)
        repository.reminderResult = .success(snapshot([]))
        #expect(await scheduler.refresh() == .scheduled(count: 0))
        #expect(center.pendingRequests.isEmpty)
    }

    @Test func capacityUTCAndColdTapKeepStableOwnedIdentity() async throws {
        let center = ReminderCenterFake()
        let repository = BookingRepositoryFake()
        let rows = (0..<65).map { record(offset: Double($0 + 3) * 3600) }
        repository.reminderResult = .success(snapshot(rows))
        let scheduler = AppointmentReminderScheduler(notificationCenter: center, now: { now })
        scheduler.configure(repository: repository)
        scheduler.acceptTap(userInfo: ["accountID": account.uuidString, "role": "customer", "bookingID": rows[0].id.uuidString])
        scheduler.setAccount(account)
        await scheduler.activate(participantID: account, role: .customer)
        #expect(scheduler.tap?.bookingID == rows[0].id)
        #expect(center.pendingRequests.count == 60)
        let ids = Set(center.pendingRequests.map(\.identifier))
        _ = await scheduler.refresh()
        #expect(Set(center.pendingRequests.map(\.identifier)) == ids)
        let trigger = try #require(center.pendingRequests.first?.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.dateComponents.timeZone?.secondsFromGMT() == 0)
        #expect(trigger.dateComponents.hour == Calendar(identifier: .gregorian).dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: now.addingTimeInterval(2 * 3600)).hour)
        scheduler.tap = nil
        scheduler.acceptTap(userInfo: ["accountID": UUID().uuidString, "role": "customer", "bookingID": rows[0].id.uuidString])
        #expect(scheduler.tap == nil)
        scheduler.setAccount(UUID())
        await scheduler.clearObsoleteSessions()
        #expect(center.pendingRequests.isEmpty)
    }

    @Test func completeSnapshotRemovesCancellationAndUpdatesTimeButPartialPageDoesNot() async throws {
        let center = ReminderCenterFake()
        let repository = BookingRepositoryFake()
        let row = record()
        repository.reminderResult = .success(snapshot([row]))
        let scheduler = AppointmentReminderScheduler(notificationCenter: center, now: { now })
        scheduler.configure(repository: repository)
        scheduler.setAccount(account)
        await scheduler.activate(participantID: account, role: .customer)
        #expect(center.pendingRequests.count == 1)
        let initial = try #require(center.pendingRequests.first)
        let moved = record(id: row.id, offset: 5 * 3600)
        repository.reminderResult = .success(snapshot([moved]))
        _ = await scheduler.refresh()
        #expect(center.pendingRequests.count == 1)
        #expect(center.pendingRequests.first?.content.userInfo["scheduledStart"] as? String != initial.content.userInfo["scheduledStart"] as? String)
        repository.reminderResult = .success(snapshot([], complete: false))
        #expect(await scheduler.refresh() == .unavailable)
        #expect(center.pendingRequests.count == 1)
        repository.reminderResult = .success(snapshot([]))
        _ = await scheduler.refresh()
        #expect(center.pendingRequests.isEmpty)
    }

    @Test func logoutClearsPendingAndDeliveredWithoutRemovingUnrelatedNotifications() async {
        let center = ReminderCenterFake()
        let repository = BookingRepositoryFake()
        repository.reminderResult = .success(snapshot([record()]))
        let scheduler = AppointmentReminderScheduler(notificationCenter: center, now: { now })
        scheduler.configure(repository: repository)
        scheduler.setAccount(account)
        await scheduler.activate(participantID: account, role: .customer)
        center.deliveredRequests = center.pendingRequests
        center.pendingRequests.append(UNNotificationRequest(identifier: "unrelated", content: UNMutableNotificationContent(), trigger: nil))
        scheduler.setAccount(nil)
        await scheduler.clearObsoleteSessions()
        #expect(center.pendingRequests.map(\.identifier) == ["unrelated"])
        #expect(center.deliveredRequests.isEmpty)
    }

    @Test func disabledPermissionAndForeignSnapshotNeverSchedule() async {
        let center = ReminderCenterFake()
        let repository = BookingRepositoryFake()
        repository.reminderResult = .success(snapshot([record()]))
        let scheduler = AppointmentReminderScheduler(notificationCenter: center, now: { now })
        scheduler.configure(repository: repository)
        scheduler.setAccount(account)
        await scheduler.activate(participantID: account, role: .customer)
        #expect(center.pendingRequests.count == 1)
        center.deliveredRequests = center.pendingRequests
        center.authorization = .denied
        #expect(await scheduler.refresh() == .refused)
        #expect(center.pendingRequests.isEmpty)
        #expect(center.deliveredRequests.isEmpty)
        center.authorization = .authorized
        repository.reminderResult = .success(AppointmentReminderSnapshot(participantID: UUID(), role: .customer,
            asOf: stamp(now), horizonEnd: stamp(now.addingTimeInterval(30 * 86400)), complete: true, bookings: []))
        #expect(await scheduler.refresh() == .unavailable)
    }

    @Test func lateOlderSystemWriteCannotReplaceNewerReschedule() async {
        let center = ReminderCenterFake()
        let repository = BookingRepositoryFake()
        let old = record()
        let moved = record(id: old.id, offset: 6 * 3600)
        repository.reminderResult = .success(snapshot([old]))
        let scheduler = AppointmentReminderScheduler(notificationCenter: center, now: { now })
        scheduler.configure(repository: repository)
        scheduler.setAccount(account)
        center.onAdd = {
            center.onAdd = nil
            repository.reminderResult = .success(snapshot([moved]))
            _ = await scheduler.refresh()
        }
        await scheduler.activate(participantID: account, role: .customer)
        #expect(center.pendingRequests.count == 1)
        #expect(center.pendingRequests.first?.content.userInfo["scheduledStart"] as? String == moved.scheduledStart)
    }

    func record(id: UUID = UUID(), offset: TimeInterval = 3 * 3600) -> AppointmentReminderBooking {
        AppointmentReminderBooking(id: id, customerID: account, groomerID: UUID(),
            scheduledStart: stamp(now.addingTimeInterval(offset)), updatedAt: stamp(now))
    }
    func snapshot(_ rows: [AppointmentReminderBooking], complete: Bool = true) -> AppointmentReminderSnapshot {
        AppointmentReminderSnapshot(participantID: account, role: .customer, asOf: stamp(now),
            horizonEnd: stamp(now.addingTimeInterval(30 * 86400)), complete: complete, bookings: rows)
    }
    func stamp(_ date: Date) -> String { GroomingRequestDateFormatting.serverString(from: date) }
}

@MainActor
final class ReminderCenterFake: AppointmentNotificationCenter {
    var pendingRequests: [UNNotificationRequest] = []
    var deliveredRequests: [UNNotificationRequest] = []
    var authorization: UNAuthorizationStatus = .authorized
    var onAdd: (() async -> Void)?
    func pending() async -> [UNNotificationRequest] { pendingRequests }
    func delivered() async -> [UNNotificationRequest] { deliveredRequests }
    func status() async -> UNAuthorizationStatus { authorization }
    func requestAuthorization() async throws -> Bool { authorization == .authorized }
    func add(_ request: UNNotificationRequest) async throws {
        await onAdd?()
        pendingRequests.removeAll { $0.identifier == request.identifier }
        pendingRequests.append(request)
    }
    func remove(_ ids: [String]) {
        pendingRequests.removeAll { ids.contains($0.identifier) }
        deliveredRequests.removeAll { ids.contains($0.identifier) }
    }
}

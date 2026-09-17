import Foundation
import Network
import Observation
import UserNotifications

protocol AppointmentReminderScheduling: Sendable {
    @MainActor func setAccount(_ accountID: UUID?)
    func syncReminders(for bookings: [Booking], role: UserRole) async -> AppointmentReminderSyncResult
    func cancelReminder(for bookingID: UUID, role: UserRole) async
}

extension AppointmentReminderScheduling {
    @MainActor func setAccount(_ accountID: UUID?) {}
}

enum AppointmentReminderSyncResult: Equatable, Sendable {
    case scheduled(count: Int)
    case refused
    case unavailable
}

struct AppointmentReminder: Equatable, Sendable {
    let bookingID: UUID
    let identifier: String
    let title: String
    let body: String
    let fireDate: Date
}

enum AppointmentReminderPlan {
    static let prefix = "beckon.appointment-reminder."
    static func reminders(for bookings: [Booking], role: UserRole, now: Date) -> [AppointmentReminder] {
        var seen: Set<UUID> = []
        return bookings.compactMap { booking in
            guard booking.status == .confirmed,
                  let start = GroomingRequestDateFormatting.parsedDate(from: booking.scheduledStart),
                  start.addingTimeInterval(-3600) > now, seen.insert(booking.id).inserted else { return nil }
            let owner = role == .customer ? booking.customerID : booking.groomerID
            return AppointmentReminder(bookingID: booking.id,
                identifier: identifier(for: booking.id, role: role, accountID: owner),
                title: "Upcoming Grooming Appointment",
                body: "Your grooming appointment starts in about one hour.",
                fireDate: start.addingTimeInterval(-3600))
        }
    }

    static func identifier(for bookingID: UUID, role: UserRole, accountID: UUID) -> String {
        let owner = accountID.uuidString.lowercased() + "."
        return "\(prefix)\(owner)\(role.rawValue).\(bookingID.uuidString.lowercased())"
    }
}

@MainActor
protocol AppointmentNotificationCenter: AnyObject {
    func pending() async -> [UNNotificationRequest]
    func delivered() async -> [UNNotificationRequest]
    func status() async -> UNAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func remove(_ ids: [String])
}

@MainActor
final class SystemAppointmentNotificationCenter: AppointmentNotificationCenter {
    private let center = UNUserNotificationCenter.current()
    func pending() async -> [UNNotificationRequest] { await center.pendingNotificationRequests() }
    func delivered() async -> [UNNotificationRequest] { await center.deliveredNotifications().map(\.request) }
    func status() async -> UNAuthorizationStatus { await center.notificationSettings().authorizationStatus }
    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }
    func add(_ request: UNNotificationRequest) async throws { try await center.add(request) }
    func remove(_ ids: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }
}

@MainActor
@Observable
final class AppointmentReminderScheduler: AppointmentReminderScheduling {
    static let shared = AppointmentReminderScheduler()
    private let center: any AppointmentNotificationCenter
    private let now: @Sendable () -> Date
    private var repository: (any BookingRepository)?
    private var accountID: UUID?
    private var role: UserRole?
    private var generation = UUID()
    private var refreshID = UUID()
    private var desiredIDs: Set<String> = []
    private var monitor: NWPathMonitor?
    private var initializedAccount = false
    private var pendingTap: AppointmentReminderTap?
    private(set) var lastResult: AppointmentReminderSyncResult = .unavailable
    var tap: AppointmentReminderTap?

    init(notificationCenter: (any AppointmentNotificationCenter)? = nil,
         now: @escaping @Sendable () -> Date = Date.init) {
        center = notificationCenter ?? SystemAppointmentNotificationCenter()
        self.now = now
    }

    func configure(repository: (any BookingRepository)?) { self.repository = repository }

    func startConnectivityMonitoring() {
        guard monitor == nil else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor in _ = await self?.refresh() }
        }
        monitor.start(queue: DispatchQueue(label: "beckon.reminders.connectivity"))
        self.monitor = monitor
    }

    func setAccount(_ accountID: UUID?) {
        guard !initializedAccount || self.accountID != accountID else { return }
        if self.accountID != nil { pendingTap = nil }
        initializedAccount = true
        self.accountID = accountID
        role = nil
        generation = UUID()
        refreshID = UUID()
        desiredIDs = []
        tap = nil
        Task { await clearObsoleteSessions() }
    }

    func clearObsoleteSessions() async {
        let epoch = generation
        let pending = await center.pending()
        let delivered = await center.delivered()
        guard generation == epoch else { return }
        center.remove((pending + delivered).filter {
            $0.identifier.hasPrefix(AppointmentReminderPlan.prefix)
                && ($0.content.userInfo["session"] as? String != epoch.uuidString || accountID == nil)
        }.map(\.identifier))
    }

    func activate(participantID: UUID, role: UserRole) async {
        guard accountID == participantID else { return }
        self.role = role
        if let pendingTap, pendingTap.accountID == participantID, pendingTap.role == role { tap = pendingTap }
        pendingTap = nil
        await clearObsoleteSessions()
        _ = await refresh()
    }

    func syncReminders(for bookings: [Booking], role: UserRole) async -> AppointmentReminderSyncResult {
        guard let accountID, self.role == role,
              bookings.allSatisfy({ (role == .customer ? $0.customerID : $0.groomerID) == accountID }) else {
            return .unavailable
        }
        // UI pages are refresh signals, never authoritative absence evidence.
        return await refresh()
    }

    @discardableResult
    func refresh() async -> AppointmentReminderSyncResult {
        guard let accountID, let role, let repository else { return .unavailable }
        let epoch = generation, operation = UUID()
        refreshID = operation
        do {
            let snapshot = try await repository.reminderSnapshot(participantID: accountID, role: role)
            guard isCurrent(epoch, operation) else { return .unavailable }
            let interval = try snapshot.validatedInterval(participantID: accountID, role: role, now: now())
            let result = try await reconcile(snapshot, interval: interval, epoch: epoch, operation: operation)
            guard isCurrent(epoch, operation) else { return .unavailable }
            lastResult = result
            return result
        } catch {
            if isCurrent(epoch, operation) { lastResult = .unavailable }
            return .unavailable
        }
    }

    func cancelReminder(for bookingID: UUID, role: UserRole) async {
        guard self.role == role else { return }
        let epoch = generation
        refreshID = UUID()
        let pending = await center.pending(), delivered = await center.delivered()
        guard epoch == generation else { return }
        let ids = (pending + delivered).filter {
            $0.identifier.hasPrefix(AppointmentReminderPlan.prefix)
                && $0.content.userInfo["session"] as? String == epoch.uuidString
                && $0.content.userInfo["bookingID"] as? String == bookingID.uuidString
        }.map(\.identifier)
        desiredIDs.subtract(ids)
        center.remove(ids)
    }

    func acceptTap(userInfo: [AnyHashable: Any]) {
        guard let owner = (userInfo["accountID"] as? String).flatMap(UUID.init(uuidString:)),
              let role = (userInfo["role"] as? String).flatMap(UserRole.init(rawValue:)),
              let bookingID = (userInfo["bookingID"] as? String).flatMap(UUID.init(uuidString:)) else { return }
        let target = AppointmentReminderTap(accountID: owner, bookingID: bookingID, role: role)
        if owner == accountID, role == self.role { tap = target }
        else if accountID == nil { pendingTap = target }
    }

    private func isCurrent(_ epoch: UUID, _ operation: UUID) -> Bool {
        !Task.isCancelled && epoch == generation && operation == refreshID
    }

    private func reconcile(_ snapshot: AppointmentReminderSnapshot, interval: DateInterval,
                           epoch: UUID, operation: UUID) async throws -> AppointmentReminderSyncResult {
        let pending = await center.pending(), delivered = await center.delivered()
        guard isCurrent(epoch, operation) else { return .unavailable }
        let rows = snapshot.bookings.filter { ($0.startDate?.addingTimeInterval(-3600) ?? .distantPast) > now() }
            .sorted { ($0.startDate!, $0.id.uuidString) < ($1.startDate!, $1.id.uuidString) }.prefix(60)
        let requests = rows.map { request(for: $0, snapshot: snapshot, epoch: epoch) }
        desiredIDs = Set(requests.map(\.identifier))
        let owned = (pending + delivered).filter {
            $0.identifier.hasPrefix(AppointmentReminderPlan.prefix)
                && $0.content.userInfo["session"] as? String == epoch.uuidString
        }
        center.remove(owned.filter { request in
            guard let start = request.content.userInfo["scheduledStart"] as? String,
                  let date = GroomingRequestDateFormatting.parsedDate(from: start) else { return true }
            return date < interval.end && (!desiredIDs.contains(request.identifier)
                || !requests.contains { $0.identifier == request.identifier && $0.content.userInfo["scheduledStart"] as? String == start })
        }.map(\.identifier))
        var status = await center.status()
        guard isCurrent(epoch, operation) else { return .unavailable }
        if status == .notDetermined && !requests.isEmpty {
            status = try await center.requestAuthorization() ? .authorized : .denied
        }
        guard isCurrent(epoch, operation) else { return .unavailable }
        guard [.authorized, .provisional, .ephemeral].contains(status) else {
            center.remove(owned.map(\.identifier))
            desiredIDs = []
            return requests.isEmpty ? .scheduled(count: 0) : .refused
        }
        for request in requests {
            guard isCurrent(epoch, operation) else { return .unavailable }
            try await center.add(request)
            if !isCurrent(epoch, operation) {
                // Reject a late system write after exit without touching a new session's alert.
                if epoch != generation || !desiredIDs.contains(request.identifier) { center.remove([request.identifier]) }
                return .unavailable
            }
        }
        return .scheduled(count: requests.count)
    }

    private func request(for booking: AppointmentReminderBooking, snapshot: AppointmentReminderSnapshot,
                         epoch: UUID) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Upcoming Grooming Appointment"
        content.body = "Your grooming appointment starts in about one hour."
        content.sound = .default
        content.userInfo = ["accountID": snapshot.participantID.uuidString, "role": snapshot.role.rawValue,
            "bookingID": booking.id.uuidString, "scheduledStart": booking.scheduledStart,
            "version": booking.updatedAt, "session": epoch.uuidString]
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second],
            from: booking.startDate!.addingTimeInterval(-3600))
        components.timeZone = calendar.timeZone
        let identifier = AppointmentReminderPlan.identifier(for: booking.id, role: snapshot.role,
            accountID: snapshot.participantID) + "." + epoch.uuidString + "." + booking.scheduledStart + "." + booking.updatedAt
        return UNNotificationRequest(identifier: identifier, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
    }
}

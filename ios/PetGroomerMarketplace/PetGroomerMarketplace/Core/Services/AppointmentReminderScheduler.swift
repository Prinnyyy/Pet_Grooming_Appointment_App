import Foundation
import UserNotifications

protocol AppointmentReminderScheduling: Sendable {
    func syncReminders(
        for bookings: [Booking],
        role: UserRole
    ) async -> AppointmentReminderSyncResult

    func cancelReminder(for bookingID: UUID, role: UserRole) async
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
    static func reminders(
        for bookings: [Booking],
        role: UserRole,
        now: Date
    ) -> [AppointmentReminder] {
        bookings.compactMap { booking in
            guard booking.status == .confirmed,
                  let scheduledStart = booking.scheduledStartDate,
                  scheduledStart > now
            else { return nil }

            let fireDate = scheduledStart.addingTimeInterval(-60 * 60)
            guard fireDate > now else { return nil }

            return AppointmentReminder(
                bookingID: booking.id,
                identifier: identifier(for: booking.id, role: role),
                title: "Upcoming Grooming Appointment",
                body: body(for: booking, role: role),
                fireDate: fireDate
            )
        }
    }

    static func identifier(for bookingID: UUID, role: UserRole) -> String {
        "groomly.appointment-reminder.\(role.appDebugName).\(bookingID.uuidString.lowercased())"
    }

    private static func body(for booking: Booking, role: UserRole) -> String {
        switch role {
        case .customer:
            "Your grooming appointment with \(booking.partnerDisplayTitle(for: role)) starts in about one hour."
        case .groomer:
            "Your grooming appointment with \(booking.partnerDisplayTitle(for: role)) starts in about one hour."
        }
    }
}

struct AppointmentReminderScheduler: AppointmentReminderScheduling {
    static let shared = AppointmentReminderScheduler()

    private let center: UNUserNotificationCenter
    private let calendar: Calendar
    private let now: @Sendable () -> Date

    init(
        center: UNUserNotificationCenter = .current(),
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.center = center
        self.calendar = calendar
        self.now = now
    }

    func syncReminders(
        for bookings: [Booking],
        role: UserRole
    ) async -> AppointmentReminderSyncResult {
        let reminders = AppointmentReminderPlan.reminders(
            for: bookings,
            role: role,
            now: now()
        )

        guard !reminders.isEmpty else {
            return .scheduled(count: 0)
        }

        let authorizationStatus = await notificationAuthorizationStatus()
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            break
        case .notDetermined:
            do {
                guard try await requestAuthorization() else {
                    return .refused
                }
            } catch {
                return .unavailable
            }
        case .denied:
            return .refused
        @unknown default:
            return .unavailable
        }

        var scheduledCount = 0
        for reminder in reminders {
            let request = notificationRequest(for: reminder)
            do {
                try await add(request)
                scheduledCount += 1
            } catch {
                return .unavailable
            }
        }

        return .scheduled(count: scheduledCount)
    }

    func cancelReminder(for bookingID: UUID, role: UserRole) async {
        center.removePendingNotificationRequests(
            withIdentifiers: [
                AppointmentReminderPlan.identifier(for: bookingID, role: role)
            ]
        )
    }

    private func notificationRequest(
        for reminder: AppointmentReminder
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default

        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminder.fireDate
        )
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )
        return UNNotificationRequest(
            identifier: reminder.identifier,
            content: content,
            trigger: trigger
        )
    }

    private func notificationAuthorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    private func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    private func add(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, any Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

private extension Booking {
    var scheduledStartDate: Date? {
        GroomingRequestDateFormatting.parsedDate(from: scheduledStart)
    }
}

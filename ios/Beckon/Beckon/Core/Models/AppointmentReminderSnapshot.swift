import Foundation

struct AppointmentReminderSnapshot: Codable, Sendable {
    let participantID: UUID
    let role: UserRole
    let asOf: String
    let horizonEnd: String
    let complete: Bool
    let bookings: [AppointmentReminderBooking]

    enum CodingKeys: String, CodingKey {
        case participantID = "participant_id", role, asOf = "as_of"
        case horizonEnd = "horizon_end", complete, bookings
    }

    func validatedInterval(participantID: UUID, role: UserRole, now: Date) throws -> DateInterval {
        guard complete, self.participantID == participantID, self.role == role,
              let start = GroomingRequestDateFormatting.parsedDate(from: asOf),
              let end = GroomingRequestDateFormatting.parsedDate(from: horizonEnd),
              end > start, end.timeIntervalSince(start) <= 30 * 86400 + 1,
              abs(start.timeIntervalSince(now)) < 300, bookings.count <= 4096,
              Set(bookings.map(\.id)).count == bookings.count,
              bookings.allSatisfy({ row in
                  guard (role == .customer ? row.customerID : row.groomerID) == participantID,
                        let date = row.startDate else { return false }
                  return date >= start && date < end
              }) else { throw BookingRepositoryError.unavailable }
        return DateInterval(start: start, end: end)
    }
}

struct AppointmentReminderBooking: Codable, Sendable {
    let id: UUID
    let customerID: UUID
    let groomerID: UUID
    let scheduledStart: String
    let updatedAt: String
    var startDate: Date? { GroomingRequestDateFormatting.parsedDate(from: scheduledStart) }

    enum CodingKeys: String, CodingKey {
        case id, customerID = "customer_id", groomerID = "groomer_id"
        case scheduledStart = "scheduled_start", updatedAt = "updated_at"
    }
}

struct AppointmentReminderTap: Identifiable {
    let id = UUID()
    let accountID: UUID
    let bookingID: UUID
    let role: UserRole
}

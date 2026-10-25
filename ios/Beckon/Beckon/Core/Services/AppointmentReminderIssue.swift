import Foundation

enum AppointmentReminderIssue: Equatable {
    case permissionDenied
    case updateFailed

    var message: String {
        switch self {
        case .permissionDenied:
            "Appointment reminders are off. Enable notifications in Settings to receive local reminders."
        case .updateFailed:
            "The appointment changed, but its local reminder could not be updated."
        }
    }
}

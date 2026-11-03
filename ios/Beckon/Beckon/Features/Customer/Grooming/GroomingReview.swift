// The review a customer writes once a grooming is finished: the form, the fit outcome per pet, the focus target and the keyboard
// presentation (S-089: lived in the snapshot of Features/Bookings/BookingsView.swift).
import SwiftUI
import UIKit


nonisolated enum GroomingReviewFocusTarget: String, Hashable {
    case content = "bookings.review.content.container"
}

nonisolated enum GroomingReviewKeyboardPresentation {
    static let contentFocusTarget = GroomingReviewFocusTarget.content.rawValue
}

/// Both appointment details and chat open the same Store-backed composer.
struct GroomingReviewForm: View {
    let booking: Booking
    let store: BookingsStore
    let accent: BeckonPrimaryButtonStyle.Accent
    @FocusState.Binding var focusedTarget: GroomingReviewFocusTarget?
    var body: some View { BookingReviewEntry(booking: booking, store: store) }
}

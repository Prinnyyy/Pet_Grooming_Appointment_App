import Foundation
import SwiftUI

enum CustomerRequestMatchingCopy {
    static let customerReviewInfo =
        "Your preferred time helps us find groomers with availability on that day. Groomers will send offers with a real appointment time for you to review."

    static let groomerOfferGuidance =
        "Start from the customer's preferred window, then choose a time that is actually available on your schedule."
}

nonisolated enum CustomerRequestWizardPresentationOwnership {
    static func shouldPresent(storeRequested: Bool, isActiveTab: Bool) -> Bool {
        storeRequested && isActiveTab
    }
}

extension Array where Element == CustomerGroomingRequest {
    func recentClosedRequests(limit: Int = 5) -> [CustomerGroomingRequest] {
        guard limit > 0 else { return [] }

        return filter { $0.status == .cancelled || $0.status == .expired }
            .sorted { lhs, rhs in
                if lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt > rhs.updatedAt
                }

                return lhs.id.uuidString < rhs.id.uuidString
            }
            .prefix(limit)
            .map { $0 }
    }
}

struct CustomerRequestDetailPresentation: Equatable {
    let showsRepublish: Bool
    let showsTimingRecovery: Bool

    init(status: GroomingRequestStatus, preferenceTimeZoneIdentifier: String? = nil) {
        showsRepublish = status == .cancelled || status == .expired
        showsTimingRecovery = status.isOpenForOffers && preferenceTimeZoneIdentifier.flatMap {
            try? GroomingServiceTiming.locationCalendar($0)
        } == nil
    }
}


struct CustomerRequestRepublishButton: View {
    let actionTitle: String
    let accessibilityIdentifier: String
    let action: () -> Void

    init(
        actionTitle: String,
        accessibilityIdentifier: String = "customer.requests.republish",
        action: @escaping () -> Void
    ) {
        self.actionTitle = actionTitle
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(actionTitle)
                .frame(maxWidth: .infinity)
            }
        .buttonStyle(BeckonSecondaryButtonStyle(accent: .customer))
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

struct CustomerRequestPhotoRowPresentation: Equatable {
    let title: String
    let detail: String?
    let isUnavailable: Bool

    init(photo: GroomingRequestPhoto, data: Data?) {
        title = photo.caption ?? photo.fileName
        isUnavailable = data == nil

        if isUnavailable {
            detail = "Photo unavailable"
        } else if photo.caption != nil {
            detail = photo.fileName
        } else {
            detail = nil
        }
    }
}

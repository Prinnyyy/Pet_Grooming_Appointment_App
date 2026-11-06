import SwiftUI

/// The stage owns the completed stops. The callout says who can act, who is waiting, or how the request ended.
struct GroomerVisitRequestJourney: View {
    let subject: GroomerRequestSubject
    let stage: GroomerRequestStage
    let now: Date
    var isPlaceholder = false

    var body: some View {
        let bubble = Callout.request(subject, stage: stage, now: now)
        let path = confirmedPath
        let track = journey(path, bubble: bubble)
        Group {
            if isPlaceholder {
                track.environment(\.scenePhase, .inactive)
                    .redacted(reason: .placeholder)
                    .overlay { DesignTokens.Colors.skeleton.blendMode(.sourceAtop) }
                    .compositingGroup()
            } else { track }
        }
        .transaction { transaction in
            if isPlaceholder || stage.kind == .closed {
                transaction.disablesAnimations = true
                transaction.animation = nil
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress: " + spokenProgress(bubble))
    }

    private func journey(_ path: GroomingDetailHero.Path, bubble: Callout) -> some View {
        let index = min(path.current, path.stops.count - 1)
        return bubble.track(stops: path.stops, current: path.current, fills: path.fills, column: index)
    }

    private var sent: Bool { subject.offer != nil || subject.match?.status == .offered }

    private var confirmedPath: GroomingDetailHero.Path {
        let current: Int
        switch stage.kind {
        case .new: current = 0
        case .offered: current = 1
        case .booked: return stage.path ?? closedPath
        case .closed:
            let status = stage.closed?.status
            if status == GroomerOfferStatus.unknown.presentation || status == .unavailable || status == nil {
                current = sent ? 1 : 0
            } else {
                return closedPath
            }
        }
        return .init(stops: BeckonJourneyStop.groomerRequestPath, current: current,
                     fills: current == 0 ? [0, 0] : [1, 0], status: current == 0 ? "Matched" : "Offer sent")
    }

    private var closedPath: GroomingDetailHero.Path {
        let status = stage.closed?.status ?? .unavailable
        let last: BeckonJourneyStop
        switch status {
        case GroomerOfferStatus.declinedByCustomer.presentation: last = .init(title: status.title, systemImage: "xmark")
        case GroomingRequestStatus.booked.presentation: last = .init(title: "Closed", systemImage: "archivebox")
        default: last = .init(title: status.title, systemImage: status.systemImage)
        }
        let stops = (sent ? [BeckonJourneyStop.matched, .offerSent] : [.matched]) + [last]
        return .init(stops: stops, current: stops.count - 1, fills: Array(repeating: 1, count: stops.count - 1), status: status.title)
    }

    private func spokenProgress(_ bubble: Callout) -> String {
        let phase: String
        switch stage.kind {
        case .new: phase = "Matched"
        case .offered: phase = "Offer sent"
        case .booked: phase = "Booked"
        case .closed: phase = sent ? "Offer sent" : "Matched"
        }
        var text = phase + ". " + bubble.text + "."
        if stage.kind == .closed, subject.request?.status == .booked,
           let status = subject.offer?.status, [.declinedByCustomer, .withdrawnByGroomer, .expired].contains(status) {
            text += " The request was booked with another groomer."
        }
        return text
    }

    private typealias Callout = GroomerVisitJourneyCallout
}

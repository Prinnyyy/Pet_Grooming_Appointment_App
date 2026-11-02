// One row of the groomer's Requests list (design; laid out again in design so that nothing in it can wrap into a mess). A request the
// groomer was matched to and an offer they made for it are one story (the request page is one page for both, design), so the Matches
// list and the Offers list share one row, and the row is the Schedule's appointment row in the way it is built: the time on the
// left, the pet's face, then three lines of text, each with one thing to say:
//   the name (with at its end the Invited mark, or an offer's price; the name is cut before anything beside it gives way)
//   who the pet is (breed and weight)
//   what is asked and where (service and city)
// Every line is one line, cut at its end when it is too long; at accessibility sizes the row stacks and nothing is cut. A request
// nobody has opened is a dot on the pet's face. What is out of the ordinary is never a tag that can wrap: it is one narrow note along
// the foot of the card (closes within the day, still being checked, an offer to replace, how an offer ended), and a request that
// names the groomer is a pink card (`.highlight`) with the Invited mark.
// The row is built from the stage the request page shows (`GroomerRequestStage`), so a row and its page cannot disagree.
import SwiftUI


/// What a row says, as plain data: built from a match (`.match`) or from an offer (`.offer`), shown by `GroomerRequestRow`.
struct GroomerRequestRowContent {
    /// What the row says about the request itself: a dot on the face when nobody has opened it, the Invited mark after the name.
    enum Mark: Equatable {
        case new
        /// The customer asked for this groomer. `source` is the real words ("Invited", "Invited + Request Pool").
        case invited(source: String)

        var words: String {
            switch self {
            case .new: "New"
            case .invited(let source): source
            }
        }
    }

    /// The one line along the foot of the card, for a state that is out of the ordinary.
    struct Note: Equatable {
        let text: String
        let systemImage: String
        let tone: BeckonFootNote.Tone
    }

    let species: String
    let photo: Data?
    let name: String
    let when: BeckonWhen?
    /// "Corgi" and "22 lb": the line says who the pet is, and when it is too long the breed is cut, never the weight.
    let breed: String
    let weight: String?
    /// "Full groom" and "Seattle": the line says what is asked and where, and the city is cut before the service.
    let service: String
    let place: String?
    /// An offer's price, at the end of the name line.
    let price: String?
    let marks: [Mark]
    let note: Note?

    var isInvited: Bool {
        marks.contains { if case .invited = $0 { true } else { false } }
    }

    var isNew: Bool { marks.contains(.new) }

    /// What VoiceOver reads for the whole row.
    var summary: String {
        var parts = [name]
        if let when { parts.append(when.full) }
        parts += [breed, weight, service, place].compactMap { $0 }.filter { !$0.isEmpty }
        if let price { parts.append(price) }
        parts += marks.map(\.words)
        if let note { parts.append(note.text) }
        return parts.joined(separator: ", ")
    }

    // MARK: Builders

    /// A request the groomer was matched to and has not answered.
    @MainActor
    static func match(_ matched: GroomerMatchedRequest, photo: Data?, now: Date) -> GroomerRequestRowContent {
        let request = matched.request
        let pet = request.petSnapshot
        let subject = GroomerRequestSubject(matched: matched, item: nil, history: matched.offer.map { [$0] } ?? [])
        let stage = GroomerRequestStage(subject, now: now)
        var marks: [Mark] = []
        if matched.match.status == .visible { marks.append(.new) }
        if let source = request.distributionSourceTitle, source.hasPrefix("Invited") { marks.append(.invited(source: source)) }
        // One note: what holds the answer back says more than that the request closes soon.
        let note: Note?
        if let hold = stage.hold {
            note = Note(text: hold.title, systemImage: hold == .checking ? "clock.fill" : "exclamationmark.circle.fill",
                tone: hold == .checking ? .calm : .warm)
        } else if stage.closesSoon, let closes = stage.closes {
            note = Note(text: closes, systemImage: "hourglass", tone: .warm)
        } else {
            note = nil
        }
        return GroomerRequestRowContent(species: pet.species, photo: photo, name: pet.name,
            when: BeckonWhen(start: request.preferredStart, end: request.preferredEnd,
                zoneIdentifier: request.preferenceTimeZoneIdentifier, now: now),
            breed: pet.breed ?? pet.species, weight: weight(pet), service: request.serviceType.title, place: request.city,
            price: nil, marks: marks, note: note)
    }

    /// An offer the groomer made, at the stage the request page shows it at. Its section says where it stands, so the note is only
    /// for what the section does not: the offer to replace, and how an earlier one ended.
    @MainActor
    static func offer(_ entry: GroomerOfferGroups.Entry, now: Date) -> GroomerRequestRowContent {
        let item = entry.item
        let offer = item.offer
        let pet = item.request?.petSnapshot ?? item.booking?.requestPetSnapshot
        let service = item.request?.serviceType ?? item.booking?.serviceType
        let note: Note?
        if let problem = entry.stage.problem {
            note = Note(text: problem.title, systemImage: problem.needsAttention ? "exclamationmark.triangle.fill" : "clock.fill",
                tone: problem.needsAttention ? .warm : .calm)
        } else if entry.stage.kind == .closed, let closed = entry.stage.closed {
            note = Note(text: closed.status.title, systemImage: closed.status.systemImage, tone: .calm)
        } else {
            note = nil
        }
        return GroomerRequestRowContent(species: pet?.species ?? "Dog", photo: nil, name: pet?.name ?? item.title,
            when: BeckonWhen(start: offer.proposedStart, end: offer.proposedEnd,
                zoneIdentifier: offer.agreementSnapshot?.serviceTimeZoneIdentifier ?? offer.serviceTimeZoneIdentifier
                    ?? item.request?.preferenceTimeZoneIdentifier, now: now),
            breed: pet.map { $0.breed ?? $0.species } ?? item.subtitle, weight: pet.flatMap(weight),
            service: service?.title ?? "", place: item.request?.city, price: offer.priceSummary, marks: [], note: note)
    }

    private static func weight(_ pet: GroomingRequestPetSnapshot) -> String? {
        pet.weightLbs.map { "\(Int($0.rounded())) lb" }
    }
}


struct GroomerRequestRow: View {
    let content: GroomerRequestRowContent
    let onOpen: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .subheadline) private var railWidth = DesignTokens.Metrics.timeColumnWidth

    private var stacks: Bool { typeSize.isAccessibilitySize }

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: DesignTokens.Spacing.sm) {
                    summary
                    Image(systemName: "chevron.right")
                        .font(DesignTokens.Typography.Expressive.label)
                        .foregroundStyle(DesignTokens.Colors.customerDeep)
                        .accessibilityHidden(true)
                }
                .padding(DesignTokens.Spacing.md)
                if let note = content.note { BeckonFootNote(text: note.text, systemImage: note.systemImage, tone: note.tone) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // The note runs edge to edge: the card's corners cut it.
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous))
        }
        .buttonStyle(BeckonLedgeButtonStyle(content.isInvited ? .highlight : .card))
        .accessibilityLabel(content.summary)
    }

    // MARK: Parts

    private var summary: some View {
        (stacks
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.md))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DesignTokens.Spacing.md))) {
            if let when = content.when { timeColumn(when) }
            GroomerPetAvatar(species: content.species, data: content.photo, size: DesignTokens.Metrics.petAvatarSmall)
                .overlay(alignment: .topTrailing) { if content.isNew { newDot } }
            lines
        }
    }

    /// "SUN", "6:27", "PM": when the customer asked for it, in the place and the colours of the Schedule's time column.
    @ViewBuilder
    private func timeColumn(_ when: BeckonWhen) -> some View {
        if stacks {
            Text(when.full)
                .font(DesignTokens.Typography.Expressive.emphasis)
                .foregroundStyle(DesignTokens.Colors.customerDeep)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            let clock = when.start.split(separator: " ")
            VStack(alignment: .leading, spacing: 0) {
                Text(when.day)
                    .textCase(.uppercase)
                    .font(DesignTokens.Typography.Expressive.chip)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                Text(clock.first.map(String.init) ?? "")
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.customerDeep)
                Text(clock.last.map(String.init) ?? "")
                    .font(DesignTokens.Typography.Expressive.chip)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
            }
            .lineLimit(1)
            .frame(width: railWidth, alignment: .leading)
            .accessibilityHidden(true)
        }
    }

    private var lines: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs / 2) {
            nameLine
            line(content.breed, tail: content.weight, tailWins: true, color: DesignTokens.Colors.textSecondary)
            line(content.service, tail: content.place, tailWins: false, color: DesignTokens.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Two facts on one line. When the line is too long the one that matters less is cut at its end (the breed before the weight,
    /// the city before the service); at accessibility sizes the line wraps and nothing is cut.
    @ViewBuilder
    private func line(_ head: String, tail: String?, tailWins: Bool, color: Color) -> some View {
        let parts = [head, tail].compactMap { $0 }.filter { !$0.isEmpty }
        if stacks {
            Text(parts.joined(separator: " · "))
                .font(DesignTokens.Typography.Expressive.supporting)
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
        } else if parts.count == 2, let tail {
            HStack(spacing: 0) {
                Text(head).lineLimit(1).layoutPriority(tailWins ? 0 : 1)
                Text(" · \(tail)").lineLimit(1).fixedSize(horizontal: tailWins, vertical: false).layoutPriority(tailWins ? 1 : 0)
            }
            .font(DesignTokens.Typography.Expressive.supporting)
            .foregroundStyle(color)
        } else if let only = parts.first {
            Text(only)
                .font(DesignTokens.Typography.Expressive.supporting)
                .foregroundStyle(color)
                .lineLimit(1)
        }
    }

    /// The name, then the price or the Invited mark. The name is written whole when it can be: the mark gives up its word first
    /// (a coral disc with the envelope), and only then is the name cut at its end.
    @ViewBuilder
    private var nameLine: some View {
        if stacks {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                nameText
                tail(compact: false)
            }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                    nameText.fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    tail(compact: false)
                }
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                    nameText.fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 0)
                    tail(compact: true)
                }
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                    nameText
                    Spacer(minLength: 0)
                    tail(compact: true)
                }
            }
        }
    }

    private var nameText: some View {
        Text(content.name)
            .font(DesignTokens.Typography.Expressive.title)
            .foregroundStyle(DesignTokens.Colors.textPrimary)
            .lineLimit(stacks ? nil : 1)
    }

    /// The price of an offer, or the mark of a request that names the groomer; never both, never wrapped.
    @ViewBuilder
    private func tail(compact: Bool) -> some View {
        if let price = content.price {
            Text(price)
                .font(DesignTokens.Typography.Expressive.section)
                .foregroundStyle(DesignTokens.Colors.customerDeep)
                .fixedSize()
        } else if content.isInvited {
            invitedMark(compact: compact)
        }
    }

    private func invitedMark(compact: Bool) -> some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: "envelope.fill").font(DesignTokens.Typography.Expressive.micro)
            if !compact { Text("Invited").font(DesignTokens.Typography.Expressive.chip) }
        }
        .foregroundStyle(DesignTokens.Colors.customerInk)
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(DesignTokens.Colors.customerFill, in: Capsule())
        .fixedSize()
        .accessibilityIdentifier("groomer.requests.source")
    }

    /// Nobody has opened this request yet: a dot on the pet's face, ringed in the colour of the card so it reads as a badge.
    private var newDot: some View {
        Circle()
            .fill(DesignTokens.Colors.customerDeep)
            .frame(width: DesignTokens.Metrics.liveDot, height: DesignTokens.Metrics.liveDot)
            .overlay {
                Circle().strokeBorder(content.isInvited ? DesignTokens.Colors.customerTint : DesignTokens.Colors.surface,
                    lineWidth: DesignTokens.Ledge.edgeWidth)
                    .padding(-DesignTokens.Ledge.edgeWidth)
            }
            .offset(x: DesignTokens.Spacing.xs / 2, y: -DesignTokens.Spacing.xs / 2)
    }
}


/// A row as bars, laid out as the real one, so the rows take their places.
struct GroomerRequestRowSkeleton: View {
    var label = "Loading requests"
    @ScaledMetric(relativeTo: .subheadline) private var railWidth = DesignTokens.Metrics.timeColumnWidth

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: 0) {
                DesignSkeletonLine(width: 0.7, font: DesignTokens.Typography.Expressive.chip)
                DesignSkeletonLine(width: 0.9, font: DesignTokens.Typography.Expressive.emphasis)
                DesignSkeletonLine(width: 0.5, font: DesignTokens.Typography.Expressive.chip)
            }
            .frame(width: railWidth)
            DesignSkeletonDisc()
                .frame(width: DesignTokens.Metrics.petAvatarSmall, height: DesignTokens.Metrics.petAvatarSmall)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                DesignSkeletonLine(width: 0.5, font: DesignTokens.Typography.Expressive.title)
                DesignSkeletonLine(width: 0.7)
                DesignSkeletonLine(width: 0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .designSkeleton(label: label)
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .beckonLedge(.card)
    }
}

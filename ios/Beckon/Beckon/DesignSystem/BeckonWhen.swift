// When something is, in the few words a card has for it (S-063). "Wed, Oct 28 · 10:02 AM–12:02 PM" did not fit a card, so: the
// weekday when the day is within a week of today, the date when it is further off, then the time. One rule for every card, tile and
// hero, in the time zone of the service (the one the countdown and the Finished rule read the day in).
//
//   Wed · 10:02 AM–12:02 PM      today to six days away (and the six days before: a grooming that has just finished)
//   Nov 4 · 10:02 AM–12:02 PM    any other day; Jan 3, 2027 when it is not this year
//
// A tile or a card that is still too narrow for the whole range shows the start only ("Wed · 10:02 AM"): `BeckonWhenLabel`
// tries both, so nothing is ever cut with "…". The end of the range is on the detail page.
import SwiftUI


struct BeckonWhen: Equatable {
    /// The day and the whole range: "Wed · 10:02 AM–12:02 PM".
    let full: String
    /// The day and the start: "Wed · 10:02 AM".
    let short: String

    init?(start: String, end: String?, zoneIdentifier: String?, now: Date = Date()) {
        guard let startDate = GroomingRequestDateFormatting.parsedDate(from: start) else { return nil }
        let endDate = end.flatMap { GroomingRequestDateFormatting.parsedDate(from: $0) }
        var calendar = Calendar(identifier: .gregorian)
        guard let zoneIdentifier, let zone = TimeZone(identifier: zoneIdentifier) else { return nil }
        calendar.timeZone = zone

        func format(_ pattern: String, _ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US")
            formatter.timeZone = zone
            formatter.dateFormat = pattern
            return formatter.string(from: date)
        }

        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: startDate)).day ?? 0
        let day: String
        if (-6...6).contains(days) {
            day = format("EEE", startDate)
        } else if calendar.component(.year, from: startDate) == calendar.component(.year, from: now) {
            day = format("MMM d", startDate)
        } else {
            day = format("MMM d, yyyy", startDate)
        }
        let begin = format("h:mm a", startDate)
        short = "\(day) · \(begin)"
        full = endDate.map { "\(day) · \(begin)–\(format("h:mm a", $0))" } ?? short
    }
}


/// The time of a card: the whole range when it fits one line, the start when it does not. At accessibility sizes it wraps instead.
struct BeckonWhenLabel: View {
    let when: BeckonWhen
    var font: Font = DesignTokens.Typography.Expressive.supporting
    var color: Color = DesignTokens.Colors.textSecondary
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                Text(when.full)
            } else {
                ViewThatFits(in: .horizontal) {
                    Text(when.full).lineLimit(1).fixedSize(horizontal: true, vertical: false)
                    Text(when.short).lineLimit(1).fixedSize(horizontal: true, vertical: false)
                    Text(when.short).lineLimit(1)
                }
            }
        }
        .font(font)
        .foregroundStyle(color)
        .accessibilityLabel(when.full)
    }
}

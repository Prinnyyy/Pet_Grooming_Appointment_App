import Foundation

struct GroomerWork: Identifiable, Equatable {
    let photo: GroomerPortfolioPhoto
    let tags: [PetFitSignal]
    /// The stand-in's pet and colour, 0 mint, 1 coral, 2 warm.
    let symbol: String
    let look: Int
    var image: Data?

    var id: UUID { photo.id }
    var caption: String { photo.caption ?? "" }
}


struct GroomerProfileContent: Equatable {
    var services: [GroomerService]
    var works: [GroomerWork]
    var specialties: [PetFitSignal]
    var modes: [GroomingLocationMode]
    var radiusMiles: Int?
    var windows: [GroomerAvailabilityWindow]
    var noticeDays: Int?
    var timeOff: GroomerTimeOffWindow?

    // MARK: What the page says about it

    /// Where the grooming happens, as the third figure of the hero: "Mobile / at your home", "Salon / at their studio", "Both / home or studio".
    var workplace: (value: String, caption: String) {
        switch (modes.contains(.groomerComesToCustomer), modes.contains(.customerComesToGroomer)) {
        case (true, true): ("Both", "home or studio")
        case (true, false): ("Mobile", "at your home")
        case (false, true): ("Salon", "at their studio")
        default: ("—", "location not listed")
        }
    }

    /// "9:00 AM – 5:00 PM" when every open day has the same hours, otherwise the earliest start to the latest end.
    var hoursText: String? {
        let open = windows.filter(\.isEnabled)
        guard let start = open.map(\.startMinutes).min(), let end = open.map(\.endMinutes).max() else { return nil }
        guard Set(open.map { "\($0.startMinutes)-\($0.endMinutes)" }).count == 1 else { return "Varies by day" }
        return "\(GroomerAvailabilityWindow.displayTime(fromMinutes: start)) – \(GroomerAvailabilityWindow.displayTime(fromMinutes: end))"
    }

    func isOpen(_ weekday: GroomerAvailabilityWeekday) -> Bool {
        windows.contains { $0.weekday == weekday && $0.isEnabled }
    }

    /// "S to XL" for the sizes of a service, "All sizes" when it takes every one.
    static func sizeText(_ sizes: [GroomerServicePetSize]) -> String {
        let ordered = GroomerServicePetSize.allCases.filter(sizes.contains)
        guard let first = ordered.first, let last = ordered.last else { return "Size on request" }
        if ordered.count == GroomerServicePetSize.allCases.count { return "All sizes" }
        return first == last ? first.title : "\(first.title) to \(last.title)"
    }

    /// "1 hr 30 min", "45 min".
    static func durationText(_ minutes: Int) -> String {
        let hours = minutes / 60, rest = minutes % 60
        switch (hours, rest) {
        case (0, _): return "\(rest) min"
        case (_, 0): return "\(hours) hr"
        default: return "\(hours) hr \(rest) min"
        }
    }
}

struct CustomerGroomerProfile: Equatable {
    let profile: MarketplaceGroomerSummary
    var content: GroomerProfileContent
}

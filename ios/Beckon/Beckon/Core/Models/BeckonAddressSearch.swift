import Combine
import CoreLocation
import Foundation
import MapKit

nonisolated struct BeckonAddressInput: Equatable, Sendable {
    var line1: String
    var line2: String
    var city: String
    var stateCode: USStateCode?
    var postalCode: String
    var countryCode: String
}

nonisolated struct BeckonAddressCoordinate: Equatable, Sendable {
    let latitude: Double
    let longitude: Double
}

nonisolated struct BeckonAddressCandidate: Equatable, Hashable, Identifiable, Sendable {
    let id: String
    let primaryText: String
    let secondaryText: String

    var title: String { primaryText }
    var subtitle: String { secondaryText }

    init(id: String, primaryText: String, secondaryText: String) {
        self.id = id
        self.primaryText = primaryText
        self.secondaryText = secondaryText
    }

    init(id: String, title: String, subtitle: String) {
        self.init(id: id, primaryText: title, secondaryText: subtitle)
    }
}

typealias BeckonAddressSuggestion = BeckonAddressCandidate

nonisolated struct BeckonResolvedAddress: Equatable, Sendable {
    let provider: String
    let placeID: String?
    let coordinate: BeckonAddressCoordinate
    let suggested: BeckonAddressInput
    let resolutionSource: String

    var streetAddress: String {
        guard !suggested.line2.isEmpty else { return suggested.line1 }
        return "\(suggested.line1) \(suggested.line2)"
    }
    var city: String { suggested.city }
    var stateCode: USStateCode { suggested.stateCode! }
    var zipCode: String { suggested.postalCode }
}

nonisolated struct BeckonConfirmedAddress: Equatable, Sendable {
    let entered: BeckonAddressInput
    let accepted: BeckonAddressInput
    let provider: String
    let placeID: String?
    let coordinate: BeckonAddressCoordinate
    let resolutionSource: String
    let confirmedAt: Date

    func isBuildingResolutionValid(for input: BeckonAddressInput) -> Bool {
        Self.materialFields(of: accepted) == Self.materialFields(of: input)
    }

    private static func materialFields(of input: BeckonAddressInput) -> [String] {
        [
            input.line1,
            input.city,
            input.stateCode?.rawValue ?? "",
            input.postalCode,
            input.countryCode,
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
    }
}

nonisolated struct BeckonSecondaryAddressConflict: Equatable, Sendable {
    let line1Secondary: String
    let existingLine2: String
}

nonisolated struct BeckonSecondaryAddressParseResult: Equatable, Sendable {
    let line1: String
    let line2: String
    let extractedSecondary: String?
    let movedSecondary: String?
    let conflict: BeckonSecondaryAddressConflict?
}

nonisolated enum BeckonSecondaryAddressParser {
    private static let pattern = #"(?i)^(.*?)\s*,?\s+((?:(?:apt\.?|apartment|unit|suite|ste\.?|floor|fl\.?|building|bldg\.?|room|rm\.?)\s+|#\s*)[a-z0-9][a-z0-9 .#/-]*)\s*$"#

    static func parse(line1: String, line2: String) -> BeckonSecondaryAddressParseResult {
        let trimmedLine1 = line1.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLine2 = line2.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parts = suffixParts(in: trimmedLine1) else {
            return BeckonSecondaryAddressParseResult(
                line1: trimmedLine1,
                line2: trimmedLine2,
                extractedSecondary: nil,
                movedSecondary: nil,
                conflict: nil
            )
        }

        guard trimmedLine2.isEmpty else {
            if normalized(parts.secondary) == normalized(trimmedLine2) {
                return BeckonSecondaryAddressParseResult(
                    line1: parts.base,
                    line2: trimmedLine2,
                    extractedSecondary: parts.secondary,
                    movedSecondary: nil,
                    conflict: nil
                )
            }
            return BeckonSecondaryAddressParseResult(
                line1: trimmedLine1,
                line2: trimmedLine2,
                extractedSecondary: parts.secondary,
                movedSecondary: nil,
                conflict: BeckonSecondaryAddressConflict(
                    line1Secondary: parts.secondary,
                    existingLine2: trimmedLine2
                )
            )
        }

        return BeckonSecondaryAddressParseResult(
            line1: parts.base,
            line2: parts.secondary,
            extractedSecondary: parts.secondary,
            movedSecondary: parts.secondary,
            conflict: nil
        )
    }

    private static func suffixParts(in value: String) -> (base: String, secondary: String)? {
        guard
            let expression = try? NSRegularExpression(pattern: pattern),
            let match = expression.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
            let baseRange = Range(match.range(at: 1), in: value),
            let secondaryRange = Range(match.range(at: 2), in: value)
        else { return nil }

        let base = String(value[baseRange]).trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ","))
        )
        let secondary = String(value[secondaryRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty, !secondary.isEmpty else { return nil }
        return (base, secondary)
    }

    private static func normalized(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}

nonisolated enum BeckonAddressSuggestionRetention {
    static func shouldRetain(previousQuery: String, nextQuery: String) -> Bool {
        let previous = normalized(previousQuery)
        let next = normalized(nextQuery)
        guard !previous.isEmpty, !next.isEmpty else { return false }
        return previous.hasPrefix(next) || next.hasPrefix(previous)
    }

    private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ")
    }
}

nonisolated enum BeckonAddressProviderError: Error, Equatable, Sendable {
    case unknownCandidate
    case noCompleteAddress
}

@MainActor
protocol BeckonAddressProviding: AnyObject {
    func updateSuggestions(for line1Query: String) async -> [BeckonAddressCandidate]
    func resolve(candidateID: String, preservingLine2: String) async throws -> BeckonResolvedAddress
    func geocode(_ input: BeckonAddressInput) async throws -> [BeckonResolvedAddress]
    func clear()
}

struct BeckonAddressCompletion<Completion> {
    let title: String
    let subtitle: String
    let completion: Completion
}

nonisolated struct BeckonAddressQuery: Equatable, Sendable {
    let searchStreet: String
    let secondaryUnit: String?

    init(street: String) {
        let parsed = BeckonSecondaryAddressParser.parse(line1: street, line2: "")
        searchStreet = parsed.line1.trimmingCharacters(in: .whitespacesAndNewlines)
        secondaryUnit = parsed.movedSecondary
    }

    func appendingSecondary(to resolvedStreet: String) -> String {
        guard let secondaryUnit else { return resolvedStreet }
        return "\(resolvedStreet) \(secondaryUnit)"
    }
}

private nonisolated enum BeckonAddressAutocompletePolicy {
    static let displayLimit = 5
}

enum BeckonAddressSuggestionBuilder {
    static func build<Completion>(
        from completions: [BeckonAddressCompletion<Completion>],
        limit: Int = 5
    ) -> (
        suggestions: [BeckonAddressSuggestion],
        completionsByID: [String: Completion]
    ) {
        var seenKeys: Set<String> = []
        var suggestions: [BeckonAddressSuggestion] = []
        var completionsByID: [String: Completion] = [:]

        for completion in completions where suggestions.count < limit {
            let title = completion.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let subtitle = completion.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }

            let key = "\(title)|\(subtitle)"
            guard seenKeys.insert(key).inserted else { continue }

            let suggestion = BeckonAddressSuggestion(
                id: key,
                primaryText: title,
                secondaryText: subtitle
            )
            suggestions.append(suggestion)
            completionsByID[suggestion.id] = completion.completion
        }

        return (suggestions, completionsByID)
    }

}

private struct BeckonAddressComponents: Sendable {
    let streetAddress: String
    let city: String
    let state: String
    let zipCode: String
}

final class MapKitAddressProvider:
    NSObject,
    ObservableObject,
    MKLocalSearchCompleterDelegate,
    BeckonAddressProviding
{
    @Published private(set) var suggestions: [BeckonAddressSuggestion] = []

    private let completer = MKLocalSearchCompleter()
    private var completionsByID: [String: MKLocalSearchCompletion] = [:]
    private var lastQueryFragment = ""
    private var currentQuery = BeckonAddressQuery(street: "")
    private var suggestionContinuation: CheckedContinuation<[BeckonAddressCandidate], Never>?

    override init() {
        super.init()
        configureCompleter()
    }

    private func configureCompleter() {
        completer.delegate = self
        completer.resultTypes = .address
    }

    func update(
        street: String,
        city: String,
        stateCode: USStateCode?
    ) {
        let addressQuery = BeckonAddressQuery(street: street)
        guard addressQuery.searchStreet.count >= 3 else {
            resetSuggestions()
            updateQueryFragmentIfNeeded("")
            return
        }

        currentQuery = addressQuery
        let query = [
            addressQuery.searchStreet,
            city.trimmingCharacters(in: .whitespacesAndNewlines),
            stateCode?.rawValue ?? "",
        ]
        .filter { !$0.isEmpty }
        .joined(separator: ", ")

        updateQueryFragmentIfNeeded(query)
    }

    func updateSuggestions(for line1Query: String) async -> [BeckonAddressCandidate] {
        let query = BeckonAddressQuery(street: line1Query).searchStreet
        guard query.count >= 3 else {
            clear()
            return []
        }
        if query == lastQueryFragment {
            return suggestions
        }

        suggestionContinuation?.resume(returning: suggestions)
        suggestionContinuation = nil
        return await withCheckedContinuation { continuation in
            suggestionContinuation = continuation
            update(street: line1Query, city: "", stateCode: nil)
        }
    }

    private func updateQueryFragmentIfNeeded(_ query: String) {
        guard query != lastQueryFragment else { return }
        if !BeckonAddressSuggestionRetention.shouldRetain(
            previousQuery: lastQueryFragment,
            nextQuery: query
        ) {
            suggestions = []
            completionsByID = [:]
        }
        lastQueryFragment = query
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let result = BeckonAddressSuggestionBuilder.build(
            from: completer.results.map { completion in
                BeckonAddressCompletion(
                    title: completion.title,
                    subtitle: completion.subtitle,
                    completion: completion
                )
            }
        )

        suggestions = result.suggestions
        completionsByID = result.completionsByID
        suggestionContinuation?.resume(returning: suggestions)
        suggestionContinuation = nil
    }

    func completer(
        _ completer: MKLocalSearchCompleter,
        didFailWithError error: any Error
    ) {
        if (error as? URLError)?.code != .cancelled {
            suggestions = []
            completionsByID = [:]
        }
        suggestionContinuation?.resume(returning: suggestions)
        suggestionContinuation = nil
    }

    func resolve(
        _ suggestion: BeckonAddressSuggestion
    ) async -> BeckonResolvedAddress? {
        try? await resolve(
            candidateID: suggestion.id,
            preservingLine2: currentQuery.secondaryUnit ?? ""
        )
    }

    func resolve(
        candidateID: String,
        preservingLine2: String
    ) async throws -> BeckonResolvedAddress {
        guard let completion = completionsByID[candidateID] else {
            throw BeckonAddressProviderError.unknownCandidate
        }

        let request = MKLocalSearch.Request(completion: completion)
        guard let mapItem = try await MKLocalSearch(request: request).start().mapItems.first else {
            throw BeckonAddressProviderError.noCompleteAddress
        }
        return try resolvedAddress(
            from: mapItem,
            preservingLine2: preservingLine2,
            source: "autocomplete_selection"
        )
    }

    func geocode(_ input: BeckonAddressInput) async throws -> [BeckonResolvedAddress] {
        let query = [
            input.line1,
            input.city,
            input.stateCode?.rawValue ?? "",
            input.postalCode,
            input.countryCode,
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: ", ")

        let mapItems: [MKMapItem]
        if #available(iOS 26.0, *) {
            guard let request = MKGeocodingRequest(addressString: query) else {
                throw BeckonAddressProviderError.noCompleteAddress
            }
            mapItems = try await request.mapItems
        } else {
            let placemarks = try await CLGeocoder().geocodeAddressString(query)
            mapItems = placemarks.map { MKMapItem(placemark: MKPlacemark(placemark: $0)) }
        }

        return mapItems.compactMap { mapItem in
            try? resolvedAddress(
                from: mapItem,
                preservingLine2: input.line2,
                source: "manual_geocode"
            )
        }
    }

    func clear() {
        completer.queryFragment = ""
        lastQueryFragment = ""
        currentQuery = BeckonAddressQuery(street: "")
        suggestionContinuation?.resume(returning: [])
        suggestionContinuation = nil
        resetSuggestions()
    }

    private func resetSuggestions() {
        suggestions = []
        completionsByID = [:]
    }

    private func resolvedAddress(
        from mapItem: MKMapItem,
        preservingLine2: String,
        source: String
    ) throws -> BeckonResolvedAddress {
        let components = addressComponents(from: mapItem)
        let coordinate = mapItem.placemark.coordinate
        guard
            let components,
            let stateCode = USStateCode(rawValue: components.state.uppercased()),
            mapItem.placemark.isoCountryCode?.uppercased() == "US",
            CLLocationCoordinate2DIsValid(coordinate),
            coordinate.latitude.isFinite,
            coordinate.longitude.isFinite
        else {
            throw BeckonAddressProviderError.noCompleteAddress
        }

        return BeckonResolvedAddress(
            provider: "apple_maps",
            placeID: mapItem.identifier?.rawValue,
            coordinate: BeckonAddressCoordinate(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            ),
            suggested: BeckonAddressInput(
                line1: components.streetAddress,
                line2: preservingLine2.trimmingCharacters(in: .whitespacesAndNewlines),
                city: components.city,
                stateCode: stateCode,
                postalCode: components.zipCode,
                countryCode: "US"
            ),
            resolutionSource: source
        )
    }

    private func addressComponents(from mapItem: MKMapItem) -> BeckonAddressComponents? {
        let streetAddress = [
            mapItem.placemark.subThoroughfare,
            mapItem.placemark.thoroughfare,
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " ")
        let city = mapItem.placemark.locality?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let state = mapItem.placemark.administrativeArea?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let zipCode = mapItem.placemark.postalCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !streetAddress.isEmpty, !city.isEmpty, !state.isEmpty, !zipCode.isEmpty else {
            return nil
        }
        return BeckonAddressComponents(
            streetAddress: streetAddress,
            city: city,
            state: state,
            zipCode: zipCode
        )
    }

}

typealias BeckonAddressSearch = MapKitAddressProvider

struct CustomerProfileAddressAutofill: Equatable, Sendable {
    let streetAddress: String
    let city: String
    let stateCode: USStateCode
    let zipCode: String

    static func make(from profile: CustomerProfileDetails) -> CustomerProfileAddressAutofill? {
        guard
            let streetAddress = normalized(profile.streetAddress),
            let city = normalized(profile.city),
            let stateCode = profile.stateCode,
            let zipCode = normalized(profile.zipCode)
        else {
            return nil
        }

        return CustomerProfileAddressAutofill(
            streetAddress: streetAddress,
            city: city,
            stateCode: stateCode,
            zipCode: zipCode
        )
    }

    private static func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

typealias CustomerRequestAddressSuggestion = BeckonAddressSuggestion
typealias CustomerRequestAddressCompletion<Completion> = BeckonAddressCompletion<Completion>
typealias CustomerRequestAddressSuggestionBuilder = BeckonAddressSuggestionBuilder
typealias CustomerRequestResolvedAddress = BeckonResolvedAddress
typealias CustomerRequestAddressSearch = BeckonAddressSearch

typealias CustomerProfileAddressSuggestion = BeckonAddressSuggestion
typealias CustomerProfileAddressCompletion<Completion> = BeckonAddressCompletion<Completion>
typealias CustomerProfileAddressSuggestionBuilder = BeckonAddressSuggestionBuilder
typealias CustomerProfileResolvedAddress = BeckonResolvedAddress
typealias CustomerProfileAddressSearch = BeckonAddressSearch

typealias GroomerProfileAddressSuggestion = BeckonAddressSuggestion
typealias GroomerProfileAddressCompletion<Completion> = BeckonAddressCompletion<Completion>
typealias GroomerProfileAddressSuggestionBuilder = BeckonAddressSuggestionBuilder
typealias GroomerProfileResolvedAddress = BeckonResolvedAddress
typealias GroomerProfileAddressSearch = BeckonAddressSearch

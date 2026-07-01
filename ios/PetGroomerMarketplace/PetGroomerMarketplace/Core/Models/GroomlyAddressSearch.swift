import Combine
import Foundation
import MapKit

struct GroomlyAddressSuggestion: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
}

struct GroomlyAddressCompletion<Completion> {
    let title: String
    let subtitle: String
    let completion: Completion
}

enum GroomlyAddressSuggestionBuilder {
    static func build<Completion>(
        from completions: [GroomlyAddressCompletion<Completion>],
        limit: Int = 5
    ) -> (
        suggestions: [GroomlyAddressSuggestion],
        completionsByID: [String: Completion]
    ) {
        var seenKeys: Set<String> = []
        var suggestions: [GroomlyAddressSuggestion] = []
        var completionsByID: [String: Completion] = [:]

        for completion in completions where suggestions.count < limit {
            let title = completion.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let subtitle = completion.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }

            let key = "\(title)|\(subtitle)"
            guard seenKeys.insert(key).inserted else { continue }

            let suggestion = GroomlyAddressSuggestion(
                id: key,
                title: title,
                subtitle: subtitle
            )
            suggestions.append(suggestion)
            completionsByID[suggestion.id] = completion.completion
        }

        return (suggestions, completionsByID)
    }
}

struct GroomlyResolvedAddress {
    let streetAddress: String
    let city: String
    let stateCode: USStateCode
    let zipCode: String
}

final class GroomlyAddressSearch:
    NSObject,
    ObservableObject,
    MKLocalSearchCompleterDelegate
{
    @Published private(set) var suggestions: [GroomlyAddressSuggestion] = []

    private let completer = MKLocalSearchCompleter()
    private var completionsByID: [String: MKLocalSearchCompletion] = [:]
    private var lastQueryFragment = ""

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func update(
        street: String,
        city: String,
        stateCode: USStateCode?
    ) {
        let trimmedStreet = street.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedStreet.count >= 3 else {
            suggestions = []
            completionsByID = [:]
            updateQueryFragmentIfNeeded("")
            return
        }

        let query = [
            trimmedStreet,
            city.trimmingCharacters(in: .whitespacesAndNewlines),
            stateCode?.rawValue ?? "",
        ]
        .filter { !$0.isEmpty }
        .joined(separator: ", ")

        updateQueryFragmentIfNeeded(query)
    }

    private func updateQueryFragmentIfNeeded(_ query: String) {
        guard query != lastQueryFragment else { return }
        lastQueryFragment = query
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let result = GroomlyAddressSuggestionBuilder.build(
            from: completer.results.map { completion in
                GroomlyAddressCompletion(
                    title: completion.title,
                    subtitle: completion.subtitle,
                    completion: completion
                )
            }
        )

        DispatchQueue.main.async {
            self.suggestions = result.suggestions
            self.completionsByID = result.completionsByID
        }
    }

    func completer(
        _ completer: MKLocalSearchCompleter,
        didFailWithError error: any Error
    ) {
        DispatchQueue.main.async {
            self.suggestions = []
            self.completionsByID = [:]
        }
    }

    func resolve(
        _ suggestion: GroomlyAddressSuggestion
    ) async -> GroomlyResolvedAddress? {
        guard let completion = completionsByID[suggestion.id] else { return nil }

        let request = MKLocalSearch.Request(completion: completion)
        guard
            let mapItem = try? await MKLocalSearch(request: request).start().mapItems.first,
            let state = mapItem.placemark.administrativeArea,
            let stateCode = USStateCode(rawValue: state.uppercased()),
            let zipCode = mapItem.placemark.postalCode?.trimmingCharacters(in: .whitespacesAndNewlines),
            !zipCode.isEmpty
        else {
            return nil
        }

        let streetAddress = [
            mapItem.placemark.subThoroughfare,
            mapItem.placemark.thoroughfare,
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " ")

        guard !streetAddress.isEmpty else { return nil }

        return GroomlyResolvedAddress(
            streetAddress: streetAddress,
            city: mapItem.placemark.locality ?? "",
            stateCode: stateCode,
            zipCode: zipCode
        )
    }
}

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

typealias CustomerRequestAddressSuggestion = GroomlyAddressSuggestion
typealias CustomerRequestAddressCompletion<Completion> = GroomlyAddressCompletion<Completion>
typealias CustomerRequestAddressSuggestionBuilder = GroomlyAddressSuggestionBuilder
typealias CustomerRequestResolvedAddress = GroomlyResolvedAddress
typealias CustomerRequestAddressSearch = GroomlyAddressSearch

typealias CustomerProfileAddressSuggestion = GroomlyAddressSuggestion
typealias CustomerProfileAddressCompletion<Completion> = GroomlyAddressCompletion<Completion>
typealias CustomerProfileAddressSuggestionBuilder = GroomlyAddressSuggestionBuilder
typealias CustomerProfileResolvedAddress = GroomlyResolvedAddress
typealias CustomerProfileAddressSearch = GroomlyAddressSearch

typealias GroomerProfileAddressSuggestion = GroomlyAddressSuggestion
typealias GroomerProfileAddressCompletion<Completion> = GroomlyAddressCompletion<Completion>
typealias GroomerProfileAddressSuggestionBuilder = GroomlyAddressSuggestionBuilder
typealias GroomerProfileResolvedAddress = GroomlyResolvedAddress
typealias GroomerProfileAddressSearch = GroomlyAddressSearch

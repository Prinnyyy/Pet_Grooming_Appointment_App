import Combine
import CoreLocation
import Foundation
import MapKit

struct BeckonAddressSuggestion: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
}

struct BeckonAddressCompletion<Completion> {
    let title: String
    let subtitle: String
    let completion: Completion
}

nonisolated struct BeckonAddressSuggestionFallback: Equatable, Sendable {
    let title: String
    let subtitle: String
}

nonisolated struct BeckonAddressQuery: Equatable, Sendable {
    let searchStreet: String
    let secondaryUnit: String?

    init(street: String) {
        let trimmed = street.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"(?i)^(.*?)\s*,?\s+((?:unit|apt\.?|apartment|suite|ste\.?|#)\s*[-a-z0-9]+(?:\s+[-a-z0-9]+)*)\s*$"#
        guard
            let expression = try? NSRegularExpression(pattern: pattern),
            let match = expression.firstMatch(
                in: trimmed,
                range: NSRange(trimmed.startIndex..., in: trimmed)
            ),
            let streetRange = Range(match.range(at: 1), in: trimmed),
            let unitRange = Range(match.range(at: 2), in: trimmed)
        else {
            searchStreet = trimmed
            secondaryUnit = nil
            return
        }

        searchStreet = String(trimmed[streetRange])
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",")))
        secondaryUnit = String(trimmed[unitRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func appendingSecondary(to resolvedStreet: String) -> String {
        guard let secondaryUnit else { return resolvedStreet }
        return "\(resolvedStreet) \(secondaryUnit)"
    }
}

enum BeckonAddressSuggestionBuilder {
    static func build<Completion>(
        from completions: [BeckonAddressCompletion<Completion>],
        limit: Int = 5,
        englishFallback: BeckonAddressSuggestionFallback? = nil
    ) -> (
        suggestions: [BeckonAddressSuggestion],
        completionsByID: [String: Completion]
    ) {
        var seenKeys: Set<String> = []
        var suggestions: [BeckonAddressSuggestion] = []
        var completionsByID: [String: Completion] = [:]

        for completion in completions where suggestions.count < limit {
            let localizedTitle = completion.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let localizedSubtitle = completion.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let shouldUseFallback = Self.containsHanScript(localizedTitle)
                || Self.containsHanScript(localizedSubtitle)
            let title = shouldUseFallback ? englishFallback?.title ?? "" : localizedTitle
            let subtitle = shouldUseFallback ? englishFallback?.subtitle ?? "" : localizedSubtitle
            guard !title.isEmpty else { continue }

            let key = "\(title)|\(subtitle)"
            guard seenKeys.insert(key).inserted else { continue }

            let suggestion = BeckonAddressSuggestion(
                id: key,
                title: title,
                subtitle: subtitle
            )
            suggestions.append(suggestion)
            completionsByID[suggestion.id] = completion.completion
        }

        return (suggestions, completionsByID)
    }

    private static func containsHanScript(_ value: String) -> Bool {
        value.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF:
                true
            default:
                false
            }
        }
    }
}

struct BeckonResolvedAddress {
    let streetAddress: String
    let city: String
    let stateCode: USStateCode
    let zipCode: String
}

private struct BeckonAddressComponents: Sendable {
    let streetAddress: String
    let city: String
    let state: String
    let zipCode: String
}

final class BeckonAddressSearch:
    NSObject,
    ObservableObject,
    MKLocalSearchCompleterDelegate
{
    @Published private(set) var suggestions: [BeckonAddressSuggestion] = []

    private let completer = MKLocalSearchCompleter()
    private var completionsByID: [String: MKLocalSearchCompletion] = [:]
    private var lastQueryFragment = ""
    private var currentQuery = BeckonAddressQuery(street: "")
    private var currentFallback: BeckonAddressSuggestionFallback?

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
        let addressQuery = BeckonAddressQuery(street: street)
        guard addressQuery.searchStreet.count >= 3 else {
            suggestions = []
            completionsByID = [:]
            updateQueryFragmentIfNeeded("")
            return
        }

        currentQuery = addressQuery
        currentFallback = BeckonAddressSuggestionFallback(
            title: addressQuery.searchStreet,
            subtitle: [
                city.trimmingCharacters(in: .whitespacesAndNewlines),
                stateCode?.rawValue ?? "",
            ]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        )
        if currentFallback?.subtitle.isEmpty == true {
            currentFallback = BeckonAddressSuggestionFallback(
                title: addressQuery.searchStreet,
                subtitle: "United States"
            )
        }

        let query = [
            addressQuery.searchStreet,
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
        let result = BeckonAddressSuggestionBuilder.build(
            from: completer.results.map { completion in
                BeckonAddressCompletion(
                    title: completion.title,
                    subtitle: completion.subtitle,
                    completion: completion
                )
            },
            englishFallback: currentFallback
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
        _ suggestion: BeckonAddressSuggestion
    ) async -> BeckonResolvedAddress? {
        guard let completion = completionsByID[suggestion.id] else { return nil }
        let addressQuery = currentQuery

        let request = MKLocalSearch.Request(completion: completion)
        guard let localizedMapItem = try? await MKLocalSearch(request: request).start().mapItems.first else {
            return nil
        }
        let components = await englishAddressComponents(for: localizedMapItem)
            ?? addressComponents(from: localizedMapItem)
        guard
            let components,
            let stateCode = USStateCode(rawValue: components.state.uppercased())
        else {
            return nil
        }

        return BeckonResolvedAddress(
            streetAddress: addressQuery.appendingSecondary(to: components.streetAddress),
            city: components.city,
            stateCode: stateCode,
            zipCode: components.zipCode
        )
    }

    private func englishAddressComponents(for mapItem: MKMapItem) async -> BeckonAddressComponents? {
        if #available(iOS 26.0, *),
           let request = MKReverseGeocodingRequest(location: mapItem.location) {
            request.preferredLocale = Locale(identifier: "en_US")
            return await withCheckedContinuation { continuation in
                request.getMapItems { items, _ in
                    continuation.resume(returning: items?.first.flatMap(self.addressComponents))
                }
            }
        }

        guard let location = mapItem.placemark.location else { return nil }
        let geocoder = CLGeocoder()
        return await withCheckedContinuation { continuation in
            geocoder.reverseGeocodeLocation(
                location,
                preferredLocale: Locale(identifier: "en_US")
            ) { placemarks, _ in
                guard let placemark = placemarks?.first else {
                    continuation.resume(returning: nil)
                    return
                }
                let streetAddress = [placemark.subThoroughfare, placemark.thoroughfare]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                let city = placemark.locality?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let state = placemark.administrativeArea?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let zipCode = placemark.postalCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !streetAddress.isEmpty, !city.isEmpty, !state.isEmpty, !zipCode.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: BeckonAddressComponents(
                    streetAddress: streetAddress,
                    city: city,
                    state: state,
                    zipCode: zipCode
                ))
            }
        }
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

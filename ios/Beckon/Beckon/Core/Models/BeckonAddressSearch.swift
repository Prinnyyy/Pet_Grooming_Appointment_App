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

nonisolated struct BeckonAddressCandidate: Equatable, Sendable {
    let streetAddress: String
    let city: String
    let state: String
    let zipCode: String

    var id: String {
        "\(streetAddress)|\(city)|\(state)|\(zipCode)"
    }
}

nonisolated enum BeckonAddressCandidateBatch {
    static func resolve<Input: Sendable>(
        _ inputs: [Input],
        limit: Int,
        using resolver: @escaping @Sendable (Input) async -> BeckonAddressCandidate?
    ) async -> [BeckonAddressCandidate] {
        await withTaskGroup(
            of: (Int, BeckonAddressCandidate?).self,
            returning: [BeckonAddressCandidate].self
        ) { group in
            for (index, input) in inputs.prefix(limit).enumerated() {
                group.addTask {
                    (index, await resolver(input))
                }
            }

            var indexedCandidates: [(Int, BeckonAddressCandidate)] = []
            for await (index, candidate) in group {
                if let candidate {
                    indexedCandidates.append((index, candidate))
                }
            }

            return indexedCandidates
                .sorted { $0.0 < $1.0 }
                .map(\.1)
        }
    }
}

private nonisolated enum BeckonAddressAutocompletePolicy {
    static let displayLimit = 5
    static let resolutionLimit = 8
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
            let localizedTitle = completion.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let localizedSubtitle = completion.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !Self.containsHanScript(localizedTitle),
                  !Self.containsHanScript(localizedSubtitle) else { continue }
            let title = localizedTitle
            let subtitle = localizedSubtitle
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

    static func build(
        from candidates: [BeckonAddressCandidate],
        limit: Int = 5
    ) -> [BeckonAddressSuggestion] {
        var seenIDs: Set<String> = []
        return candidates.compactMap { candidate in
            guard !Self.containsHanScript(candidate.streetAddress),
                  !Self.containsHanScript(candidate.city),
                  !Self.containsHanScript(candidate.state),
                  !Self.containsHanScript(candidate.zipCode) else { return nil }
            guard seenIDs.insert(candidate.id).inserted else { return nil }
            return BeckonAddressSuggestion(
                id: candidate.id,
                title: candidate.streetAddress,
                subtitle: "\(candidate.city), \(candidate.state) \(candidate.zipCode)"
            )
        }
        .prefix(limit)
        .map { $0 }
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

private enum BeckonAddressResolution {
    case completion(MKLocalSearchCompletion)
    case candidate(BeckonAddressCandidate)
}

private nonisolated struct BeckonSendableMapCompletion: @unchecked Sendable {
    let completion: MKLocalSearchCompletion
}

final class BeckonAddressSearch:
    NSObject,
    ObservableObject,
    MKLocalSearchCompleterDelegate
{
    @Published private(set) var suggestions: [BeckonAddressSuggestion] = []

    private let completer = MKLocalSearchCompleter()
    private var resolutionsByID: [String: BeckonAddressResolution] = [:]
    private var rawSuggestions: [BeckonAddressSuggestion] = []
    private var rawResolutionsByID: [String: BeckonAddressResolution] = [:]
    private var englishSuggestions: [BeckonAddressSuggestion] = []
    private var englishResolutionsByID: [String: BeckonAddressResolution] = [:]
    private var lastQueryFragment = ""
    private var currentQuery = BeckonAddressQuery(street: "")
    private var lookupGeneration = 0
    private var completionResolutionTask: Task<Void, Never>?

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

    private func updateQueryFragmentIfNeeded(_ query: String) {
        guard query != lastQueryFragment else { return }
        prepareForNewQuery()
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

        rawSuggestions = result.suggestions
        rawResolutionsByID = result.completionsByID.mapValues(BeckonAddressResolution.completion)
        publishMergedSuggestions()
        beginCompletionResolution(for: completer.results)
    }

    private func beginCompletionResolution(
        for completions: [MKLocalSearchCompletion]
    ) {
        let generation = lookupGeneration
        completionResolutionTask?.cancel()
        englishSuggestions = []
        englishResolutionsByID = [:]
        publishMergedSuggestions()

        let sendableCompletions = completions.map(BeckonSendableMapCompletion.init)
        completionResolutionTask = Task { [weak self] in
            guard let self else { return }
            let candidates = await BeckonAddressCandidateBatch.resolve(
                sendableCompletions,
                limit: BeckonAddressAutocompletePolicy.resolutionLimit
            ) { [weak self] wrappedCompletion in
                guard let self else { return nil }
                return await self.englishCandidate(for: wrappedCompletion.completion)
            }
            guard !Task.isCancelled, generation == self.lookupGeneration else { return }
            let uniqueCandidates = self.uniqueCandidates(candidates)
            self.englishSuggestions = BeckonAddressSuggestionBuilder.build(
                from: uniqueCandidates,
                limit: BeckonAddressAutocompletePolicy.displayLimit
            )
            self.englishResolutionsByID = uniqueCandidates.reduce(into: [:]) { result, candidate in
                result[candidate.id] = .candidate(candidate)
            }
            self.publishMergedSuggestions()
        }
    }

    func completer(
        _ completer: MKLocalSearchCompleter,
        didFailWithError error: any Error
    ) {
        rawSuggestions = []
        rawResolutionsByID = [:]
        publishMergedSuggestions()
    }

    func resolve(
        _ suggestion: BeckonAddressSuggestion
    ) async -> BeckonResolvedAddress? {
        guard let resolution = resolutionsByID[suggestion.id] else { return nil }
        let addressQuery = currentQuery

        if case let .candidate(candidate) = resolution {
            guard let stateCode = USStateCode(rawValue: candidate.state.uppercased()) else {
                return nil
            }
            return BeckonResolvedAddress(
                streetAddress: addressQuery.appendingSecondary(to: candidate.streetAddress),
                city: candidate.city,
                stateCode: stateCode,
                zipCode: candidate.zipCode
            )
        }

        guard case let .completion(completion) = resolution else { return nil }

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

    private func publishMergedSuggestions() {
        var seenLocations: Set<String> = []
        suggestions = (englishSuggestions + rawSuggestions)
            .filter { suggestion in
                let city = suggestion.subtitle.split(separator: ",").first
                    .map(String.init) ?? suggestion.subtitle
                let locationKey = "\(suggestion.title)|\(city)".lowercased()
                return seenLocations.insert(locationKey).inserted
            }
            .prefix(BeckonAddressAutocompletePolicy.displayLimit)
            .map { $0 }
        resolutionsByID = rawResolutionsByID.merging(englishResolutionsByID) { _, english in english }
    }

    private func prepareForNewQuery() {
        lookupGeneration += 1
        completionResolutionTask?.cancel()
        rawSuggestions = []
        rawResolutionsByID = [:]
        englishSuggestions = []
        englishResolutionsByID = [:]
        suggestions = []
        resolutionsByID = [:]
    }

    private func resetSuggestions() {
        prepareForNewQuery()
    }

    private func englishCandidate(
        for completion: MKLocalSearchCompletion
    ) async -> BeckonAddressCandidate? {
        let request = MKLocalSearch.Request(completion: completion)
        guard let response = try? await MKLocalSearch(request: request).start() else {
            return nil
        }

        for mapItem in response.mapItems {
            let components = await englishAddressComponents(for: mapItem)
                ?? addressComponents(from: mapItem)
            if let components {
                return BeckonAddressCandidate(
                    streetAddress: components.streetAddress,
                    city: components.city,
                    state: components.state,
                    zipCode: components.zipCode
                )
            }
        }
        return nil
    }

    private func uniqueCandidates(
        _ candidates: [BeckonAddressCandidate]
    ) -> [BeckonAddressCandidate] {
        var seenIDs: Set<String> = []
        return candidates.filter { seenIDs.insert($0.id.lowercased()).inserted }
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

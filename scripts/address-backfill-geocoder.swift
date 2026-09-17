import Foundation
import MapKit

private struct Query: Codable {
    let id: String
    let line1: String
    let city: String
    let state: String
    let zipCode: String
}

private struct Input: Codable {
    let queries: [Query]
}

private struct Candidate: Codable {
    let provider: String
    let placeID: String?
    let line1: String
    let city: String
    let state: String
    let zipCode: String
    let countryCode: String
    let latitude: Double
    let longitude: Double
}

private struct QueryResult: Codable {
    let id: String
    let candidates: [Candidate]
    let errorCode: String?
}

private struct Output: Codable {
    let results: [QueryResult]
}

@main
private struct AddressBackfillGeocoder {
    static func main() async throws {
        let inputData = FileHandle.standardInput.readDataToEndOfFile()
        let input = try JSONDecoder().decode(Input.self, from: inputData)
        var results: [QueryResult] = []
        for (index, query) in input.queries.enumerated() {
            if index > 0 {
                try await Task.sleep(for: .milliseconds(650))
            }
            results.append(await resolve(query))
        }
        let data = try JSONEncoder().encode(Output(results: results))
        FileHandle.standardOutput.write(data)
    }

    private static func resolve(_ query: Query) async -> QueryResult {
        let address = [query.line1, query.city, query.state, query.zipCode, "US"]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        var lastErrorCode: String?
        for attempt in 0..<3 {
            do {
            let mapItems: [MKMapItem]
            if #available(macOS 26.0, *) {
                guard let request = MKGeocodingRequest(addressString: address) else {
                    return QueryResult(id: query.id, candidates: [], errorCode: "invalid_query")
                }
                request.preferredLocale = Locale(identifier: "en_US")
                mapItems = try await request.mapItems
            } else {
                let placemarks = try await CLGeocoder().geocodeAddressString(
                    address,
                    in: nil,
                    preferredLocale: Locale(identifier: "en_US")
                )
                mapItems = placemarks.map { MKMapItem(placemark: MKPlacemark(placemark: $0)) }
            }
            let candidates = mapItems.compactMap(candidate(from:))
            return QueryResult(id: query.id, candidates: candidates, errorCode: nil)
            } catch {
                lastErrorCode = (error as NSError).domain + ":" + String((error as NSError).code)
                if attempt < 2 {
                    try? await Task.sleep(for: .milliseconds(1_500 * (attempt + 1)))
                }
            }
        }
        return QueryResult(id: query.id, candidates: [], errorCode: lastErrorCode)
    }

    private static func candidate(from mapItem: MKMapItem) -> Candidate? {
        let placemark = mapItem.placemark
        let line1 = [placemark.subThoroughfare, placemark.thoroughfare]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let city = placemark.locality?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let state = placemark.administrativeArea?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let zipCode = placemark.postalCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let countryCode = placemark.isoCountryCode?.uppercased() ?? ""
        let coordinate = placemark.coordinate
        guard !line1.isEmpty,
              !city.isEmpty,
              !state.isEmpty,
              !zipCode.isEmpty,
              CLLocationCoordinate2DIsValid(coordinate),
              coordinate.latitude.isFinite,
              coordinate.longitude.isFinite else { return nil }
        return Candidate(
            provider: "apple_maps",
            placeID: mapItem.identifier?.rawValue,
            line1: line1,
            city: city,
            state: state,
            zipCode: zipCode,
            countryCode: countryCode,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }
}

import Foundation
import UniformTypeIdentifiers

nonisolated enum GroomingServiceType:
    String,
    Codable,
    CaseIterable,
    Hashable,
    Identifiable,
    Sendable
{
    case fullGroom = "full_groom"
    case bathAndBrush = "bath_and_brush"
    case haircutOnly = "haircut_only"
    case nailTrim = "nail_trim"
    case deShedding = "de_shedding"
    case customRequest = "custom_request"

    var id: Self { self }

    var title: String {
        switch self {
        case .fullGroom:
            "Full Groom"
        case .bathAndBrush:
            "Bath & Brush"
        case .haircutOnly:
            "Haircut Only"
        case .nailTrim:
            "Nail Trim"
        case .deShedding:
            "De-shedding"
        case .customRequest:
            "Custom Request"
        }
    }

    var subtitle: String {
        switch self {
        case .fullGroom:
            "Bath, haircut, nail trim, ear cleaning"
        case .bathAndBrush:
            "Bath, blow dry, brushing"
        case .haircutOnly:
            "Trim and style shaping"
        case .nailTrim:
            "Quick clip and file"
        case .deShedding:
            "Deshed treatment and blow out"
        case .customRequest:
            "Describe exactly what you need"
        }
    }
}

nonisolated enum GroomingLocationMode:
    String,
    Codable,
    CaseIterable,
    Hashable,
    Identifiable,
    Sendable
{
    case groomerComesToCustomer = "groomer_comes_to_customer"
    case customerComesToGroomer = "customer_comes_to_groomer"

    var id: Self { self }

    var customerTitle: String {
        switch self {
        case .groomerComesToCustomer:
            "Mobile Groomer Comes To Me"
        case .customerComesToGroomer:
            "I Can Visit The Groomer"
        }
    }

    var groomerTitle: String {
        switch self {
        case .groomerComesToCustomer:
            "I Travel To Customers"
        case .customerComesToGroomer:
            "Customers Visit My Place"
        }
    }

    var icon: String {
        switch self {
        case .groomerComesToCustomer:
            "🚐"
        case .customerComesToGroomer:
            "🏠"
        }
    }
}

nonisolated enum USStateCode:
    String,
    Codable,
    CaseIterable,
    Hashable,
    Identifiable,
    Sendable
{
    case alabama = "AL"
    case alaska = "AK"
    case arizona = "AZ"
    case arkansas = "AR"
    case california = "CA"
    case colorado = "CO"
    case connecticut = "CT"
    case delaware = "DE"
    case districtOfColumbia = "DC"
    case florida = "FL"
    case georgia = "GA"
    case hawaii = "HI"
    case idaho = "ID"
    case illinois = "IL"
    case indiana = "IN"
    case iowa = "IA"
    case kansas = "KS"
    case kentucky = "KY"
    case louisiana = "LA"
    case maine = "ME"
    case maryland = "MD"
    case massachusetts = "MA"
    case michigan = "MI"
    case minnesota = "MN"
    case mississippi = "MS"
    case missouri = "MO"
    case montana = "MT"
    case nebraska = "NE"
    case nevada = "NV"
    case newHampshire = "NH"
    case newJersey = "NJ"
    case newMexico = "NM"
    case newYork = "NY"
    case northCarolina = "NC"
    case northDakota = "ND"
    case ohio = "OH"
    case oklahoma = "OK"
    case oregon = "OR"
    case pennsylvania = "PA"
    case rhodeIsland = "RI"
    case southCarolina = "SC"
    case southDakota = "SD"
    case tennessee = "TN"
    case texas = "TX"
    case utah = "UT"
    case vermont = "VT"
    case virginia = "VA"
    case washington = "WA"
    case westVirginia = "WV"
    case wisconsin = "WI"
    case wyoming = "WY"

    var id: Self { self }
}

struct GroomingRequestPhoto: Equatable, Identifiable, Sendable {
    let id: UUID
    let requestID: UUID
    let customerID: UUID
    let storageBucket: String
    let storagePath: String
    let caption: String?
    let sortOrder: Int
    let createdAt: String?

    var fileName: String {
        storagePath.split(separator: "/").last.map(String.init) ?? storagePath
    }
}

nonisolated enum GroomingRequestPhotoContentType:
    String,
    CaseIterable,
    Identifiable,
    Sendable
{
    case jpeg
    case png
    case heic
    case heif

    var id: Self { self }

    var fileExtension: String {
        switch self {
        case .jpeg:
            "jpg"
        case .png:
            "png"
        case .heic:
            "heic"
        case .heif:
            "heif"
        }
    }

    var mimeType: String {
        switch self {
        case .jpeg:
            "image/jpeg"
        case .png:
            "image/png"
        case .heic:
            "image/heic"
        case .heif:
            "image/heif"
        }
    }

    init?(uniformType: UTType) {
        if uniformType.conforms(to: .jpeg) {
            self = .jpeg
        } else if uniformType.conforms(to: .png) {
            self = .png
        } else if uniformType.identifier == "public.heic" {
            self = .heic
        } else if uniformType.identifier == "public.heif" {
            self = .heif
        } else {
            return nil
        }
    }
}

nonisolated enum GroomingRequestPhotoPath {
    static func make(
        customerID: UUID,
        requestID: UUID,
        fileID: UUID = UUID(),
        contentType: GroomingRequestPhotoContentType
    ) -> String {
        [
            customerID.uuidString.lowercased(),
            requestID.uuidString.lowercased(),
            "\(fileID.uuidString.lowercased()).\(contentType.fileExtension)",
        ]
        .joined(separator: "/")
    }
}

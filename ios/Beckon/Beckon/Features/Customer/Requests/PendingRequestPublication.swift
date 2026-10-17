import Foundation

struct PendingRequestPublication: Codable, Equatable, Sendable {
    enum ProtocolVersion: String, Codable { case legacyV4, discoveryV1 }
    enum Acknowledgement: Codable, Equatable, Sendable {
        case legacy(GroomingRequestPublishResult)
        case discovery(RequestDistributionReceipt)

        var requestID: UUID {
            switch self {
            case let .legacy(value): value.requestID
            case let .discovery(value): value.requestID
            }
        }
    }

    let schemaVersion: Int
    let protocolVersion: ProtocolVersion
    let customerID: UUID
    let draft: GroomingRequestDraft
    var photos: [PendingGroomingRequestPhoto]
    let session: DiscoverySession?
    let poolEnabled: Bool
    let groomerIDs: [UUID]
    var acknowledgement: Acknowledgement?

    init(customerID: UUID, draft: GroomingRequestDraft, photos: [PendingGroomingRequestPhoto],
         session: DiscoverySession? = nil, poolEnabled: Bool = false, groomerIDs: [UUID] = []) {
        schemaVersion = 1
        protocolVersion = session == nil ? .legacyV4 : .discoveryV1
        self.customerID = customerID
        self.draft = draft
        self.photos = photos
        self.session = session
        self.poolEnabled = poolEnabled
        self.groomerIDs = groomerIDs.sorted { $0.uuidString < $1.uuidString }
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, protocolVersion, customerID, draft, photos, session, poolEnabled, groomerIDs, acknowledgement
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let version = try values.decodeIfPresent(Int.self, forKey: .schemaVersion)
        guard version == nil || version == 1 else { throw RequestDiscoveryError.clientUpdateRequired }
        schemaVersion = 1
        customerID = try values.decode(UUID.self, forKey: .customerID)
        draft = try values.decode(GroomingRequestDraft.self, forKey: .draft)
        photos = try values.decode([PendingGroomingRequestPhoto].self, forKey: .photos)
        if version == nil {
            protocolVersion = .legacyV4
            session = nil; poolEnabled = false; groomerIDs = []; acknowledgement = nil
        } else {
            protocolVersion = try values.decode(ProtocolVersion.self, forKey: .protocolVersion)
            session = try values.decodeIfPresent(DiscoverySession.self, forKey: .session)
            poolEnabled = try values.decode(Bool.self, forKey: .poolEnabled)
            groomerIDs = try values.decode([UUID].self, forKey: .groomerIDs)
            acknowledgement = try values.decodeIfPresent(Acknowledgement.self, forKey: .acknowledgement)
            guard (protocolVersion == .discoveryV1) == (session != nil),
                  Set(groomerIDs).count == groomerIDs.count, groomerIDs.count <= 5 else {
                throw RequestDiscoveryError.invalidInput
            }
            if let acknowledgement {
                switch (protocolVersion, acknowledgement) {
                case (.legacyV4, .legacy), (.discoveryV1, .discovery): break
                default: throw RequestDiscoveryError.invalidInput
                }
            }
        }
    }
}

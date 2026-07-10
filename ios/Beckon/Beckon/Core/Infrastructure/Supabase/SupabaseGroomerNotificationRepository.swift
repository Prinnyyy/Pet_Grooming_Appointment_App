import Foundation
import Supabase

@MainActor
final class SupabaseGroomerNotificationRepository: GroomerNotificationRepository {
    private static let notificationColumns = """
        id,groomer_id,kind,title,body,is_read,created_at,read_at,\
        related_request_id,related_booking_id,related_offer_id
        """

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func notifications(groomerID: UUID) async throws -> [GroomerNotification] {
        try await notifications(groomerID: groomerID, page: .first).items
    }

    func notifications(
        groomerID: UUID,
        page: ListPageRequest
    ) async throws -> ListPage<GroomerNotification> {
        do {
            let rows: [GroomerNotificationRow] = try await client
                .from("groomer_notifications")
                .select(Self.notificationColumns)
                .eq("groomer_id", value: groomerID.uuidString.lowercased())
                .order("created_at", ascending: false)
                .range(from: page.offset, to: page.inclusiveRangeEnd)
                .execute()
                .value

            return ListPage(items: rows.map(\.notification), request: page)
        } catch {
            throw Self.map(error)
        }
    }

    func markRead(
        notificationID: UUID
    ) async throws -> GroomerNotification {
        do {
            let rows: [GroomerNotificationRow] = try await client
                .rpc(
                    "mark_groomer_notification_read",
                    params: MarkGroomerNotificationReadParameters(
                        notificationID: notificationID
                    )
                )
                .execute()
                .value

            guard rows.count == 1, let notification = rows.first?.notification else {
                throw GroomerNotificationRepositoryError.unavailable
            }

            return notification
        } catch let error as GroomerNotificationRepositoryError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    func markAllRead(
        groomerID: UUID
    ) async throws -> [GroomerNotification] {
        do {
            let rows: [GroomerNotificationRow] = try await client
                .rpc("mark_all_groomer_notifications_read")
                .execute()
                .value

            return rows.map(\.notification)
        } catch {
            throw Self.map(error)
        }
    }

    private static func map(
        _ error: any Error
    ) -> GroomerNotificationRepositoryError {
        if AppDebugErrorClassifier.isCancellation(error) {
            return .cancelled
        }

        if let repositoryError = error as? GroomerNotificationRepositoryError {
            return repositoryError
        }

        if let postgrestError = error as? PostgrestError {
            switch postgrestError.code {
            case "42501", "28000":
                return .notAllowed
            case "22023":
                return .invalidInput
            case "P0001":
                switch postgrestError.message {
                case "notification_not_found":
                    return .notificationNotFound
                case "groomer_profile_required":
                    return .notAllowed
                default:
                    return .unavailable
                }
            default:
                return .unavailable
            }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .timedOut,
                 .cannotConnectToHost,
                 .cannotFindHost,
                 .dnsLookupFailed:
                return .networkUnavailable
            default:
                return .unavailable
            }
        }

        return .unavailable
    }
}

private struct GroomerNotificationRow: Decodable {
    let id: UUID
    let groomerID: UUID
    let kind: GroomerNotificationKind
    let title: String
    let body: String
    let isRead: Bool
    let createdAt: String
    let readAt: String?
    let relatedRequestID: UUID?
    let relatedBookingID: UUID?
    let relatedOfferID: UUID?

    var notification: GroomerNotification {
        GroomerNotification(
            id: id,
            groomerID: groomerID,
            kind: kind,
            title: title,
            body: body,
            isRead: isRead,
            createdAt: createdAt,
            readAt: readAt,
            relatedRequestID: relatedRequestID,
            relatedBookingID: relatedBookingID,
            relatedOfferID: relatedOfferID
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case groomerID = "groomer_id"
        case kind
        case title
        case body
        case isRead = "is_read"
        case createdAt = "created_at"
        case readAt = "read_at"
        case relatedRequestID = "related_request_id"
        case relatedBookingID = "related_booking_id"
        case relatedOfferID = "related_offer_id"
    }
}

private struct MarkGroomerNotificationReadParameters: Encodable {
    let notificationID: UUID

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(
            notificationID.uuidString.lowercased(),
            forKey: .notificationID
        )
    }

    private enum CodingKeys: String, CodingKey {
        case notificationID = "p_notification_id"
    }
}

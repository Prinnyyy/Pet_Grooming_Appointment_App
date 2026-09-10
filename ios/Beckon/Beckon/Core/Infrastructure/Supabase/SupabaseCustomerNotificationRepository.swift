import Foundation
import Supabase

@MainActor
final class SupabaseCustomerNotificationRepository: CustomerNotificationRepository {
    private static let notificationColumns = """
        id,customer_id,kind,title,body,is_read,created_at,read_at,\
        related_request_id,related_booking_id,related_offer_id,related_conversation_id
        """

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func notifications(customerID: UUID) async throws -> [CustomerNotification] {
        try await notifications(customerID: customerID, page: .first).items
    }

    func notifications(
        customerID: UUID,
        page: ListPageRequest
    ) async throws -> ListPage<CustomerNotification> {
        do {
            let rows: [CustomerNotificationRow] = try await client
                .from("customer_notifications")
                .select(Self.notificationColumns)
                .eq("customer_id", value: customerID.uuidString.lowercased())
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
    ) async throws -> CustomerNotification {
        do {
            let rows: [CustomerNotificationRow] = try await client
                .rpc(
                    "mark_customer_notification_read",
                    params: MarkCustomerNotificationReadParameters(
                        notificationID: notificationID
                    )
                )
                .execute()
                .value

            guard rows.count == 1, let notification = rows.first?.notification else {
                throw CustomerNotificationRepositoryError.unavailable
            }

            return notification
        } catch let error as CustomerNotificationRepositoryError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    func markAllRead(
        customerID: UUID
    ) async throws -> [CustomerNotification] {
        do {
            let rows: [CustomerNotificationRow] = try await client
                .rpc("mark_all_customer_notifications_read")
                .execute()
                .value

            return rows.map(\.notification)
        } catch {
            throw Self.map(error)
        }
    }

    private static func map(
        _ error: any Error
    ) -> CustomerNotificationRepositoryError {
        if AppDebugErrorClassifier.isCancellation(error) {
            return .cancelled
        }

        if let repositoryError = error as? CustomerNotificationRepositoryError {
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
                case "customer_profile_required":
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

struct CustomerNotificationRow: Decodable {
    let id: UUID
    let customerID: UUID
    let kind: CustomerNotificationKind
    let title: String
    let body: String
    let isRead: Bool
    let createdAt: String
    let readAt: String?
    let relatedRequestID: UUID?
    let relatedBookingID: UUID?
    let relatedOfferID: UUID?
    let relatedConversationID: UUID?

    var notification: CustomerNotification {
        CustomerNotification(
            id: id,
            customerID: customerID,
            kind: kind,
            title: title,
            body: body,
            isRead: isRead,
            createdAt: createdAt,
            readAt: readAt,
            relatedRequestID: relatedRequestID,
            relatedBookingID: relatedBookingID,
            relatedOfferID: relatedOfferID,
            relatedConversationID: relatedConversationID
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case customerID = "customer_id"
        case kind
        case title
        case body
        case isRead = "is_read"
        case createdAt = "created_at"
        case readAt = "read_at"
        case relatedRequestID = "related_request_id"
        case relatedBookingID = "related_booking_id"
        case relatedOfferID = "related_offer_id"
        case relatedConversationID = "related_conversation_id"
    }
}

private struct MarkCustomerNotificationReadParameters: Encodable {
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

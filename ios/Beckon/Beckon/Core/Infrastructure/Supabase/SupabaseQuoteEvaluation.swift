import Foundation

struct SupabaseQuoteEvaluationParameters: Encodable {
    let offerIDs: [UUID]
    private enum CodingKeys: String, CodingKey {
        case offerIDs = "p_offer_ids"
    }
}

struct SupabaseQuoteEvaluationRow: Decodable {
    let offerID: UUID
    let evaluation: QuoteEvaluation
    private enum CodingKeys: String, CodingKey {
        case offerID = "offer_id"
        case evaluation
    }
}

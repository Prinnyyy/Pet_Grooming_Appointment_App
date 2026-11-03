import Foundation

/// Account/Store-scoped editing state. Closing a sheet does not submit or erase it.
nonisolated struct BookingReviewComposeDraft: Equatable, Sendable {
    var rating = 5
    var content = ""

    mutating func toggleStarter(_ sentence: String) {
        if let range = content.range(of: sentence) {
            content.removeSubrange(range)
            content = content.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            let combined = [content.trimmingCharacters(in: .whitespacesAndNewlines), sentence]
                .filter { !$0.isEmpty }.joined(separator: " ")
            if combined.count <= 2000 { content = combined }
        }
    }
}

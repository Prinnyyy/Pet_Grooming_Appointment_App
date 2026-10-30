// What Messages looks like while its conversations are on their way (design). The title is the page's own and stays; each conversation
// is a card of the real size with its picture and words as bars, so the rows take their places without the page moving.
import SwiftUI


/// One conversation as bars: the avatar square, the name and two lines of the last message, the time at the right. The same card,
/// padding and avatar size as `ChatConversationRow`.
struct ChatConversationRowSkeleton: View {
    /// One row carries the VoiceOver label for the whole list; the others are silent.
    var label: String?
    private let avatarSize = ChatConversationListPresentation.customer.avatarSize

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.lg) {
            DesignSkeletonBlock()
                .frame(width: avatarSize, height: avatarSize)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                DesignSkeletonLine(width: 0.5, font: DesignTokens.Typography.Expressive.emphasis)
                VStack(alignment: .leading, spacing: 0) {
                    DesignSkeletonLine(width: 0.95)
                    DesignSkeletonLine(width: 0.62)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            DesignSkeletonLine(width: 1, font: DesignTokens.Typography.Expressive.chip)
                .frame(width: 36)
        }
        .designSkeleton(label: label)
        .padding(DesignTokens.Spacing.md)
        .beckonLedge(.card)
    }
}


/// The list while the first answer is awaited: three rows, the third already cut by the fold of a small phone.
struct ChatConversationsSkeleton: View {
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ChatConversationRowSkeleton(label: "Loading conversations")
            ChatConversationRowSkeleton()
            ChatConversationRowSkeleton()
        }
    }
}

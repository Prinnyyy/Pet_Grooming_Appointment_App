import PhotosUI
import SwiftUI

enum GroomerAvatarImageEncoder {
    static func displayablePayload(
        from data: Data,
        preferredContentType: GroomerAvatarPhotoContentType
    ) -> (data: Data, contentType: GroomerAvatarPhotoContentType)? {
        guard let image = UIImage(data: data) else { return nil }

        if preferredContentType == .png,
           let pngData = image.pngData(),
           UIImage(data: pngData) != nil {
            return (pngData, .png)
        }

        guard let jpegData = image.jpegData(compressionQuality: 0.88),
              UIImage(data: jpegData) != nil else {
            return nil
        }

        return (jpegData, .jpeg)
    }
}

struct ProfileBadges: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let profile: GroomerProfile

    var body: some View {
        if profile.ratingCount > 0 || profile.isVerified {
            badgeLayout {
                if let average = profile.exactRatingAverage {
                    BeckonStatusChip(.rating(average: average, count: profile.ratingCount))
                }

                if profile.isVerified {
                    BeckonStatusChip(.verified)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var badgeLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.sm))
            : AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.sm))
    }
}

import SwiftUI

enum BeckonModuleImageLayout {
    nonisolated static func filledFrame(
        imageSize: CGSize,
        in containerSize: CGSize
    ) -> CGRect {
        guard
            imageSize.width > 0,
            imageSize.height > 0,
            containerSize.width > 0,
            containerSize.height > 0
        else {
            return .zero
        }

        let scale = max(
            containerSize.width / imageSize.width,
            containerSize.height / imageSize.height
        )
        let filledSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )

        return CGRect(
            x: (containerSize.width - filledSize.width) / 2,
            y: (containerSize.height - filledSize.height) / 2,
            width: filledSize.width,
            height: filledSize.height
        )
    }
}

struct BeckonModuleImage<Placeholder: View>: View {
    private let data: Data?
    private let placeholder: Placeholder

    init(
        data: Data?,
        @ViewBuilder placeholder: () -> Placeholder
    ) {
        self.data = data
        self.placeholder = placeholder()
    }

    var body: some View {
        if let image {
            GeometryReader { proxy in
                let frame = BeckonModuleImageLayout.filledFrame(
                    imageSize: image.size,
                    in: proxy.size
                )

                Image(uiImage: image)
                    .resizable()
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
            }
            .clipped()
        } else {
            ZStack {
                placeholder
            }
        }
    }

    private var image: UIImage? {
        guard let data else { return nil }
        return UIImage(data: data)
    }
}

struct BeckonProfileAvatar: View {
    let data: Data?
    let tone: BeckonDefaultProfileAvatarTone
    let size: CGFloat
    let cornerRadius: CGFloat
    var placeholderSize: CGFloat = 24

    var body: some View {
        BeckonModuleImage(data: data) {
            BeckonDefaultProfileAvatar(
                tone: tone,
                symbolSize: placeholderSize
            )
        }
        .frame(width: size, height: size)
        .clipShape(
            RoundedRectangle(
                cornerRadius: cornerRadius,
                style: .continuous
            )
        )
        .accessibilityHidden(true)
    }
}

struct BeckonPetAvatar: View {
    let data: Data?
    let fallbackText: String
    let background: AnyShapeStyle
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        BeckonModuleImage(data: data) {
            Text(fallbackText)
                .font(.system(size: min(width, height) * 0.5))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(background)
        }
        .frame(width: width, height: height)
        .background(background)
        .clipShape(
            RoundedRectangle(
                cornerRadius: cornerRadius,
                style: .continuous
            )
        )
        .accessibilityHidden(true)
    }
}

struct BeckonAnnotatedModule<Content: View>: View {
    let title: String
    let subtitle: String
    private let content: Content

    init(
        _ title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                Text(subtitle)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct BeckonPhotoEditorCard<Preview: View, Action: View>: View {
    let title: String
    let statusText: String
    let showsSavedIndicator: Bool
    let savedAccessibilityLabel: String
    private let preview: Preview
    private let action: Action

    init(
        title: String,
        statusText: String,
        showsSavedIndicator: Bool,
        savedAccessibilityLabel: String,
        @ViewBuilder preview: () -> Preview,
        @ViewBuilder action: () -> Action
    ) {
        self.title = title
        self.statusText = statusText
        self.showsSavedIndicator = showsSavedIndicator
        self.savedAccessibilityLabel = savedAccessibilityLabel
        self.preview = preview()
        self.action = action()
    }

    var body: some View {
        BeckonCard {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.lg) {
                ZStack(alignment: .bottomTrailing) {
                    preview

                    if showsSavedIndicator {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(DesignTokens.Colors.success)
                            .background(Circle().fill(DesignTokens.Colors.surface))
                            .accessibilityLabel(savedAccessibilityLabel)
                    }
                }

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(title)
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        Text(statusText)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    action
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

enum BeckonDefaultProfileAvatarTone {
    case customer
    case groomer
    case neutral
}

struct BeckonDefaultProfileAvatar: View {
    let tone: BeckonDefaultProfileAvatarTone
    var symbolSize: CGFloat = 30

    var body: some View {
        ZStack {
            background

            Circle()
                .fill(Color.white.opacity(0.35))
                .frame(width: symbolSize * 1.55, height: symbolSize * 1.55)

            Image(systemName: symbolName)
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(foregroundColor)
        }
    }

    private var symbolName: String {
        switch tone {
        case .customer:
            "person.fill"
        case .groomer:
            "scissors"
        case .neutral:
            "person.crop.circle.fill"
        }
    }

    private var foregroundColor: Color {
        switch tone {
        case .customer:
            DesignTokens.Colors.customerPrimaryDark
        case .groomer:
            DesignTokens.Colors.groomerAccentDark
        case .neutral:
            DesignTokens.Colors.textSecondary
        }
    }

    private var background: LinearGradient {
        switch tone {
        case .customer:
            LinearGradient(
                colors: [
                    DesignTokens.Colors.customerPrimary.opacity(0.42),
                    DesignTokens.Colors.groomerAccent.opacity(0.28),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .groomer:
            LinearGradient(
                colors: [
                    DesignTokens.Colors.groomerAccent.opacity(0.4),
                    DesignTokens.Colors.customerPrimary.opacity(0.28),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .neutral:
            LinearGradient(
                colors: [
                    DesignTokens.Colors.surfaceRaised,
                    DesignTokens.Colors.borderSoft,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

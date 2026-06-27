import SwiftUI

enum GroomlyModuleImageLayout {
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

struct GroomlyModuleImage<Placeholder: View>: View {
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
                let frame = GroomlyModuleImageLayout.filledFrame(
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

import SwiftUI

struct GroomlyStorageImageThumbnail: View {
    let bucket: String
    let path: String
    let fileName: String
    let urlProvider: (any StorageImageURLProvider)?
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let tint: Color

    @State private var signedURL: URL?
    @State private var isLoadingURL = false
    @State private var didFail = false

    init(
        bucket: String,
        path: String,
        fileName: String,
        urlProvider: (any StorageImageURLProvider)?,
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat = DesignTokens.CornerRadius.input,
        tint: Color = DesignTokens.Colors.customerPrimary
    ) {
        self.bucket = bucket
        self.path = path
        self.fileName = fileName
        self.urlProvider = urlProvider
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.tint = tint
    }

    var body: some View {
        ZStack {
            if let signedURL {
                AsyncImage(url: signedURL) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()

                    case .empty:
                        loadingPlaceholder

                    case .failure:
                        failedPlaceholder

                    @unknown default:
                        failedPlaceholder
                    }
                }
            } else if isLoadingURL {
                loadingPlaceholder
            } else if didFail {
                failedPlaceholder
            } else {
                emptyPlaceholder
            }
        }
        .frame(width: width, height: height)
        .background(DesignTokens.Colors.surface.opacity(0.6))
        .clipShape(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
        .accessibilityLabel(fileName)
        .task(id: cacheKey) {
            signedURL = nil
            didFail = false
            await loadSignedURL()
        }
    }

    private var cacheKey: String {
        "\(bucket)/\(path)"
    }

    private var emptyPlaceholder: some View {
        placeholder(systemImage: "photo")
    }

    private var failedPlaceholder: some View {
        placeholder(systemImage: "photo.badge.exclamationmark")
    }

    private var loadingPlaceholder: some View {
        ZStack {
            emptyPlaceholder

            ProgressView()
                .tint(tint)
        }
    }

    private func placeholder(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.title3.weight(.semibold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(tint.opacity(0.12))
    }

    private func loadSignedURL() async {
        guard !bucket.isEmpty, !path.isEmpty else {
            didFail = true
            return
        }

        guard let urlProvider else {
            didFail = true
            return
        }

        isLoadingURL = true
        defer { isLoadingURL = false }

        do {
            signedURL = try await urlProvider.signedURL(
                bucket: bucket,
                path: path,
                expiresIn: 10 * 60
            )
        } catch {
            didFail = true
        }
    }
}

import SwiftUI

/// A shared real-data host for the picker and saved list. Layout and actions are the adopted design's.
struct CustomerGroomerProfilePage<Bar: View>: View {
    let marketplace: CustomerMarketplaceSession
    var context: GroomerProfileContext?
    var isFavorite: Bool?
    var onFavorite: () -> Void
    var onClose: (() -> Void)?
    @State private var store: CustomerGroomerProfileStore
    private let bar: Bar

    init(groomerID: UUID, marketplace: CustomerMarketplaceSession, context: GroomerProfileContext? = nil,
         isFavorite: Bool? = nil, onFavorite: @escaping () -> Void = {}, onClose: (() -> Void)? = nil,
         @ViewBuilder bar: () -> Bar) {
        self.marketplace = marketplace; self.context = context; self.isFavorite = isFavorite
        self.onFavorite = onFavorite; self.onClose = onClose; self.bar = bar()
        _store = State(initialValue: marketplace.profileStore(groomerID: groomerID))
    }

    var body: some View {
        Group {
            if let result = store.profile {
                GroomerProfileView(profile: result.profile, avatarData: marketplace.avatarData[result.profile.id],
                    content: result.content, context: context, isFavorite: isFavorite,
                    onFavorite: onFavorite, onClose: onClose) {
                    VStack(spacing: DesignTokens.Spacing.sm) {
                        if !store.unavailablePhotoIDs.isEmpty {
                            Button("Retry unavailable photos") { Task { await store.load() } }
                                .buttonStyle(BeckonGuardedPlainButtonStyle())
                        }
                        bar
                    }
                }
                .task(id: result.profile.avatarPath) { await marketplace.loadAvatar(result.profile) }
            } else {
                DesignPage(cascades: false) {
                    if let error = store.error {
                        BeckonErrorBanner(title: "Profile unavailable", message: error.message)
                        Button("Retry") { Task { await store.load() } }
                            .buttonStyle(BeckonGuardedPlainButtonStyle())
                    } else {
                        BeckonLoadingView(title: "Loading profile…", message: "Fetching this groomer's details.", accent: .customer)
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    if let onClose { DesignSheetBar(title: "Groomer profile", closeIdentifier: "customer.groomer-profile.close", onClose: onClose) }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await store.load() }
    }
}

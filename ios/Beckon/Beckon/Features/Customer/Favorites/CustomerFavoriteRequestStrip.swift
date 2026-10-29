// The request picker of Saved groomers (S-048, redone in S-049 and S-050). The page's body is the groomers you saved; this is the
// control above them that says which of your open requests they would be invited to. So it is small and flat, a different thing
// from the white ledge cards of the groomers below: a soft mint tile per request (pet, service, when) that turns solid mint with a
// tick when chosen. Tap it again to clear it. Nothing is chosen on open. A chosen tile changes colour and nothing else, so nothing
// on the page moves when it is tapped (only the groomer cards below gain their Send button).
//
// Shape: no request, one dashed card that says why and offers New request. One request, its tile at page width. Two or more, a row
// of wide tiles that swipes, the next peeking in (`BeckonPeekCarousel`). New requests are started from Requests; only
// with no request at all does this module offer it, as the dashed card.
import SwiftUI


struct CustomerFavoriteRequestStrip: View {
    let requests: [CustomerGroomingRequest]
    let selectedID: UUID?
    /// Taps a request: the page chooses it, or clears it when it was already the chosen one.
    let onSelect: (CustomerGroomingRequest) -> Void
    let onNewRequest: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        // The heading is 12 pt from what it heads in every state (the page puts 24 between sections).
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            header

            if requests.isEmpty {
                CustomerFavoriteNewRequestCard(action: onNewRequest)
            } else if requests.count == 1 || typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    ForEach(requests) { requestTile($0, width: nil) }
                }
            } else {
                BeckonPeekCarousel(wholeCards: 1, minimumWidth: Self.minimumTileWidth, verticalInset: 0) { width in
                    ForEach(requests) { requestTile($0, width: width) }
                }
                .accessibilityIdentifier("favorites.choose-request")
            }
        }
    }

    /// A tile needs room for its date line: below this a small phone would wrap it.
    private static let minimumTileWidth: CGFloat = 240

    /// A plain label that is also the instruction. It never changes with the state, so nothing under it moves. New requests are
    /// started from Requests; with no request at all the dashed card below offers it.
    private var header: some View {
        Text(requests.isEmpty ? "Request to send" : "Choose a request to send")
            .font(DesignTokens.Typography.Expressive.headline)
            .foregroundStyle(DesignTokens.Colors.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private func requestTile(_ request: CustomerGroomingRequest, width: CGFloat?) -> some View {
        CustomerFavoriteRequestTile(request: request, isSelected: request.id == selectedID, width: width) {
            onSelect(request)
        }
    }
}


/// One open request to pick: the pet, the service and when. A soft mint tile with an empty ring while it waits, solid mint with a
/// tick while it is the one the cards below send. Flat (no border, no lip) so it reads as a control and not as one of the groomer
/// cards; both states are the same size, so choosing changes colour only.
private struct CustomerFavoriteRequestTile: View {
    let request: CustomerGroomingRequest
    let isSelected: Bool
    /// nil: the width of the page.
    let width: CGFloat?
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    private var isVisit: Bool { request.locationMode == .customerComesToGroomer }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                BeckonPetAvatar(
                    data: nil,
                    systemImage: BeckonPetPresentation.symbol(for: request.petSnapshot.species),
                    width: 36, height: 36, cornerRadius: 18
                )
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(request.petSnapshot.name) · \(request.serviceType.title)")
                        .font(DesignTokens.Typography.Expressive.emphasis)
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                    if let when = BeckonWhen(start: request.preferredStart, end: request.preferredEnd,
                        zoneIdentifier: request.preferenceTimeZoneIdentifier) {
                        // The tile's colour is the tile's (ink on mint), so the label does not choose its own.
                        BeckonWhenLabel(when: when, color: DesignTokens.Colors.customerInk)
                    } else {
                        Text(request.preferredTimePresentation.text)
                            .font(DesignTokens.Typography.Expressive.supporting)
                            .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                BeckonTickCircle(isOn: isSelected, off: DesignTokens.Colors.customerHeroDecoration)
            }
            .foregroundStyle(DesignTokens.Colors.customerInk)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .modifier(FavoriteRequestTileWidth(width: width))
            .background(isSelected ? DesignTokens.Colors.customerFill : DesignTokens.Colors.customerTint,
                in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(BeckonGuardedPlainButtonStyle())
        .animation(DesignTokens.Motion.morph, value: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(request.petSnapshot.name), \(request.serviceType.title)")
        .accessibilityValue("\(request.preferredTimePresentation.accessibilityLabel), \(isVisit ? "visit" : "mobile"), \(request.city)")
        .accessibilityHint(isSelected ? "Chosen. Double tap to clear it."
            : "Chooses this request to send to the saved groomers below.")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("favorites.request.\(request.id.uuidString)")
    }
}


/// The width of a request tile: the carousel's, or the page's when nil.
private struct FavoriteRequestTileWidth: ViewModifier {
    let width: CGFloat?

    func body(content: Content) -> some View {
        if let width {
            content.frame(width: width, alignment: .leading)
        } else {
            content.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}


/// With no open request: the dashed card says why the page cannot send anything yet and offers the way out. Page wide, its
/// symbol and words side by side in the middle.
private struct CustomerFavoriteNewRequestCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                DesignIconDisc(systemImage: "plus", size: .tile, font: DesignTokens.Typography.Expressive.glyph)
                VStack(alignment: .leading, spacing: 0) {
                    Text("New request")
                        .font(DesignTokens.Typography.Expressive.emphasis)
                        .foregroundStyle(DesignTokens.Colors.customerDeep)
                    Text("Post one to invite these groomers.")
                        .font(DesignTokens.Typography.Expressive.supporting)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .buttonStyle(BeckonLedgeButtonStyle(.dashed))
        .accessibilityLabel("New request")
        .accessibilityHint("Starts a new grooming request.")
        .accessibilityIdentifier("favorites.new-request")
    }
}

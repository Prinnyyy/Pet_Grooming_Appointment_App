// A sideways row of cards that shows the start of the next card (S-048). Home's pet cards and Saved groomers' request cards use it.
import SwiftUI


/// A row of cards that scrolls sideways and always shows the first `carouselPeek` points of the next card. A row that ends exactly
/// on a card reads as a pair of buttons; a cut-off card says "swipe". The cards' width is worked out from the screen, so the peek
/// is the same on every phone: `wholeCards` whole cards, then the peek.
///
/// The row cancels the page inset so cards bleed to the screen edge; the first card still starts one inset in. `content` gets the
/// width of a card.
struct BeckonPeekCarousel<Content: View>: View {
    let wholeCards: Int
    var minimumWidth = DesignTokens.Metrics.carouselCardMinimumWidth
    /// Room above and below the cards for a ledge's lip and the tilt; flat tiles need none.
    var verticalInset = DesignTokens.Spacing.sm
    /// Cards in the row. More than one draws page dots under it that follow the swipe; 0 (the default) draws none.
    var pageCount = 0
    var pageLabel: (Int) -> String = { "Page \($0 + 1)" }
    /// The card at the leading edge, for a page that scrolls to a card or reads which one is showing.
    var scrollPosition: Binding<UUID?>?
    let content: (CGFloat) -> Content
    @State private var rowWidth: CGFloat = 0
    @State private var progress: CGFloat = 0
    @State private var ownPosition: UUID?

    init(wholeCards: Int, minimumWidth: CGFloat = DesignTokens.Metrics.carouselCardMinimumWidth,
         verticalInset: CGFloat = DesignTokens.Spacing.sm, pageCount: Int = 0,
         pageLabel: @escaping (Int) -> String = { "Page \($0 + 1)" }, scrollPosition: Binding<UUID?>? = nil,
         @ViewBuilder content: @escaping (CGFloat) -> Content) {
        self.wholeCards = wholeCards
        self.minimumWidth = minimumWidth
        self.verticalInset = verticalInset
        self.pageCount = pageCount
        self.pageLabel = pageLabel
        self.scrollPosition = scrollPosition
        self.content = content
    }

    private var gap: CGFloat { DesignTokens.Spacing.md }

    /// The screen is the first inset, `wholeCards` cards each followed by a gap, and the peek.
    private var width: CGFloat {
        guard rowWidth > 0 else { return minimumWidth }
        let room = rowWidth - DesignTokens.Spacing.screenHorizontal - CGFloat(wholeCards) * gap
            - DesignTokens.Metrics.carouselPeek
        return max(minimumWidth, (room / CGFloat(wholeCards)).rounded(.down))
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            scroller
            if pageCount > 1 {
                let page = min(max(Int(progress.rounded()), 0), pageCount - 1)
                DesignPageDots(count: pageCount, current: page, label: pageLabel(page), progress: progress)
            }
        }
    }

    private var scroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: gap) {
                content(width)
            }
            .padding(.vertical, verticalInset)
            .scrollTargetLayout()
        }
        // Measured before the inset is cancelled, so this is the whole screen's width.
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rowWidth = $0 }
        .contentMargins(.horizontal, DesignTokens.Spacing.screenHorizontal, for: .scrollContent)
        .padding(.horizontal, -DesignTokens.Spacing.screenHorizontal)
        .scrollClipDisabled()
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: scrollPosition ?? $ownPosition)
        // How far the swipe is, in pages: the first card at rest is 0, the last at its stop is `pageCount - 1`, and in between it
        // follows the finger. Measured against the scroll's own range, so the last stop is exactly the last page.
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            let start = -geometry.contentInsets.leading
            let end = geometry.contentSize.width + geometry.contentInsets.trailing - geometry.containerSize.width
            guard end > start else { return 0 }
            return min(1, max(0, (geometry.contentOffset.x - start) / (end - start)))
        } action: { _, fraction in
            progress = fraction * CGFloat(max(pageCount - 1, 0))
        }
        .beckonTracksScroll()
        // Until the row is measured the cards would be drawn at the floor width and then jump: show nothing for that one pass, and
        // let the width arrive without an animation of its own.
        .opacity(rowWidth > 0 ? 1 : 0)
        .animation(nil, value: rowWidth)
    }
}

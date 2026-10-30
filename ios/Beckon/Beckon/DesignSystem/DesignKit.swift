import SwiftUI

// Shared customer UI building blocks adopted from the approved design.

/// Page shell for the variants: mint wash, scrolling content, standard insets.
struct DesignPage<Content: View>: View {
    /// How the page arrives: a detail page by default; list pages say `.list`.
    var rhythm = BeckonEntranceRhythm.detail
    /// True: every block of the page arrives in order, numbered for you (a detail page). False: the page numbers its own
    /// blocks with `.beckonEntrance(_:)`, for rows that come and go (a list).
    var cascades = true
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            BeckonExpressiveBackdrop()
            ScrollView {
                Group {
                    if cascades {
                        BeckonCascade(spacing: DesignTokens.Layout.sectionSpacing) { content }
                    } else {
                        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionSpacing) { content }
                            .beckonEntranceClock()
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.top, DesignTokens.Spacing.lg)
                .padding(.bottom, DesignTokens.Layout.pageBottomInset)
            }
            .scrollContentBackground(.hidden)
            .beckonTracksScroll()
        }
        .beckonEntranceRhythm(rhythm)
    }
}

/// The round tinted disc behind an icon: the leading mark of a heading, a fact row, a link card or a note. Three sizes only,
/// so a new view never invents one: `tile` (a row or heading), `touch` (a row that is a control, or a hero initial), `large`
/// (a dashed add slot). Hidden from VoiceOver unless `isDecorative` is false (the icon is then the control's only label).
struct DesignIconDisc: View {
    /// Mint for the customer's own things; caution (pink, red ink) for what warns or cannot be taken back.
    enum Tone {
        /// `solid` is the mint fill with ink on it, for a disc that is the picture of a page (a sheet's moment) and has to stand out
        /// on the mint wash, where the tint would melt into it.
        case customer, solid, caution

        var ink: Color {
            switch self {
            case .customer: DesignTokens.Colors.customerDeep
            case .solid: DesignTokens.Colors.customerInk
            case .caution: DesignTokens.Colors.statusErrorText
            }
        }

        var fill: Color {
            switch self {
            case .customer: DesignTokens.Colors.customerTint
            case .solid: DesignTokens.Colors.customerFill
            case .caution: DesignTokens.Colors.statusErrorFill
            }
        }
    }

    enum Size {
        case tile, touch, large

        var points: CGFloat {
            switch self {
            case .tile: DesignTokens.Metrics.ledgeIconTile
            case .touch: DesignTokens.Metrics.minimumTouchTarget
            case .large: DesignTokens.Metrics.iconDiscLarge
            }
        }
    }

    let systemImage: String
    var size = Size.tile
    var font = DesignTokens.Typography.Expressive.emphasis
    var tone = Tone.customer
    var isDecorative = true

    var body: some View {
        Image(systemName: systemImage)
            .font(font)
            .contentTransition(.symbolEffect(.replace))
            .designIconDisc(size, tone: tone)
            .accessibilityHidden(isDecorative)
    }
}

extension View {
    /// The disc itself, for content that is not a plain symbol (a letter, a count): deep ink on the tint, round, one of the
    /// three sizes of `DesignIconDisc`.
    func designIconDisc(_ size: DesignIconDisc.Size = .tile, tone: DesignIconDisc.Tone = .customer) -> some View {
        foregroundStyle(tone.ink)
            .frame(width: size.points, height: size.points)
            .background(tone.fill, in: Circle())
    }

    /// A line of helper text under a heading or inside a card: supporting size, secondary ink, wraps instead of truncating.
    func designSupportingText() -> some View {
        font(DesignTokens.Typography.Expressive.supporting)
            .foregroundStyle(DesignTokens.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The standard card body: large padding, full width, left aligned, on the white ledge card. Put it on a stack of content.
    func designCardBody() -> some View {
        padding(DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .beckonLedge(.card)
    }
}

/// Icon tile + caption + value. The unit of every fact in the variants.
struct DesignFactRow: View {
    let systemImage: String
    let title: String
    let value: String
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        (typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.sm))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DesignTokens.Spacing.md))) {
            DesignIconDisc(systemImage: systemImage)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignTokens.Typography.Expressive.chip)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                Text(value)
                    .font(DesignTokens.Typography.Expressive.supporting)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Card body for static groups of facts: ledge card, rows stacked with `spacing`.
struct DesignFactCard<Content: View>: View {
    var spacing: CGFloat = DesignTokens.Spacing.md
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) { content }
            .designCardBody()
    }
}

/// A titled group: ledge heading (optional count) above one fact card. The standard way to group fields or facts on a page.
struct DesignSection<Content: View>: View {
    let title: String
    let systemImage: String
    var count: Int?
    var spacing: CGFloat = DesignTokens.Spacing.md
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            BeckonLedgeHeading(title: title, systemImage: systemImage, count: count)
            DesignFactCard(spacing: spacing) { content }
        }
    }
}

/// A fact as one line: a small icon and caption on the left, the value on the right (stacked at accessibility sizes). For the
/// dense lists inside a card where `DesignFactRow` (icon disc, value under caption) would be too tall.
struct DesignValueRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.xs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md))
        layout {
            Label {
                Text(title)
                    .font(DesignTokens.Typography.Expressive.label)
            } icon: {
                Image(systemName: systemImage)
                    .font(DesignTokens.Typography.Expressive.label)
            }
            .foregroundStyle(DesignTokens.Colors.textSecondary)

            if !typeSize.isAccessibilitySize { Spacer(minLength: DesignTokens.Spacing.md) }

            Text(value)
                .font(DesignTokens.Typography.Expressive.body)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .multilineTextAlignment(typeSize.isAccessibilitySize ? .leading : .trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}

/// Icon and one sentence, for closed or informational states inside a card.
struct DesignInfoLine: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.Expressive.glyph)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .accessibilityHidden(true)
            Text(text)
                .designSupportingText()
        }
    }
}

extension View {
    /// The mint summary banner: gradient fill with a thick bottom edge. Put the content inside, then apply this.
    /// Text inside uses `customerInk`, never white.
    func designBanner() -> some View {
        padding(DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [DesignTokens.Colors.customerFill, DesignTokens.Colors.customerHeroEnd],
                    startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous)
                    .fill(DesignTokens.Colors.customerFillPressed).offset(y: DesignTokens.Ledge.card))
            .padding(.bottom, DesignTokens.Ledge.card)
    }
}

/// Generic stage path (Tier M): done nodes check, the current node rings, upcoming nodes wait. Static; no idle loops.
struct DesignStepPath: View {
    let labels: [String]
    let systemImages: [String]
    /// 1-based index of the current step; `labels.count + 1` means every step is done.
    let current: Int
    var nodeSize: CGFloat = DesignTokens.Metrics.journeyNode
    var showsLabels = true
    /// The current node swells with a bounce when a step becomes current (a flow the person moves through, not a status).
    var pulsesCurrent = false

    private var columnWidth: CGFloat { showsLabels ? 64 : nodeSize }

    var body: some View {
        ZStack(alignment: .top) {
            HStack(spacing: 0) {
                ForEach(0..<(labels.count - 1), id: \.self) { index in
                    Capsule()
                        .fill(index + 1 < current ? DesignTokens.Colors.customerFill : DesignTokens.Colors.borderSoft)
                        .frame(height: nodeSize > 34 ? 9 : 7)
                }
            }
            .padding(.horizontal, columnWidth / 2)
            .padding(.top, nodeSize / 2 - 4)

            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                    let step = index + 1
                    VStack(spacing: DesignTokens.Spacing.sm) {
                        stepNode(step: step, systemImage: systemImages[index])
                        if showsLabels {
                            Text(label)
                                .font(step <= current
                                    ? DesignTokens.Typography.Expressive.label : DesignTokens.Typography.Expressive.labelMuted)
                                .foregroundStyle(step <= current
                                    ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textTertiary)
                                .lineLimit(1)
                                .fixedSize()
                        }
                    }
                    .frame(width: columnWidth)
                    if index < labels.count - 1 { Spacer(minLength: 0) }
                }
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func stepNode(step: Int, systemImage: String) -> some View {
        let isDone = step < current
        let isCurrent = step == current
        Image(systemName: isDone ? "checkmark" : systemImage)
            .font(.system(size: nodeSize * 0.4, weight: .black, design: .rounded)) // decorative glyph, fixed by design
            .foregroundStyle(isDone ? DesignTokens.Colors.customerInk
                : isCurrent ? DesignTokens.Colors.customerDeep : DesignTokens.Colors.textTertiary)
            .frame(width: nodeSize, height: nodeSize)
            .background(isDone ? DesignTokens.Colors.customerFill
                : isCurrent ? DesignTokens.Colors.surface : DesignTokens.Colors.placeholderFill, in: Circle())
            .overlay { if isCurrent { Circle().strokeBorder(DesignTokens.Colors.customerDeep, lineWidth: 3) } }
            .background(Circle().fill(isDone || isCurrent ? DesignTokens.Colors.customerDeep : DesignTokens.Colors.border)
                .offset(y: DesignTokens.Ledge.control))
            .padding(.bottom, DesignTokens.Ledge.control)
            .scaleEffect(pulsesCurrent && isCurrent ? DesignTokens.Motion.currentNodeScale : 1)
            .beckonAnimation(DesignTokens.Motion.bounce, value: isCurrent)
    }
}

/// The pup resting its paws on the top edge of whatever card is placed below it.
struct DesignPupPeek<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let paused = BeckonMotionGate(reduceMotion: reduceMotion, scenePhase: scenePhase).isPaused
        ZStack(alignment: .topTrailing) {
            content.padding(.top, 46)
            TimelineView(.animation(minimumInterval: DesignTokens.Motion.idleFrame, paused: paused)) { context in
                BeckonPup(time: paused ? 0 : context.date.timeIntervalSinceReferenceDate, excited: false)
            }
            .frame(width: 120, height: 92)
            .scaleEffect(0.92, anchor: .bottom)
            .padding(.trailing, 22)
            .offset(y: -16)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

/// Large mint call-to-action for a Tier M page (the Home primary button is reserved for the hero).
struct DesignActionLabel: View {
    let title: String
    let systemImage: String
    /// The act is under way (signing in, sending): a spinner takes the place of the symbol, and the pill keeps its size.
    var isBusy = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // At accessibility sizes the words need the whole pill: a long title must never break inside a word.
            if isBusy {
                ProgressView().tint(DesignTokens.Colors.customerInk)
            } else if !typeSize.isAccessibilitySize {
                Image(systemName: systemImage).font(DesignTokens.Typography.Expressive.glyph)
                    .contentTransition(.symbolEffect(.replace))
            }
            Text(title)
                .font(DesignTokens.Typography.Expressive.headline)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(DesignTokens.Colors.customerInk)
        .padding(.vertical, typeSize.isAccessibilitySize ? DesignTokens.Spacing.md : 0)
        .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.ledgePrimaryButtonHeight)
        .padding(.horizontal, DesignTokens.Spacing.lg)
    }
}

/// Quiet text-and-icon button for secondary actions (Tier C calm: no ledge).
struct DesignQuietAction: View {
    let title: String
    let systemImage: String
    var isDestructive = false

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(DesignTokens.Typography.Expressive.emphasis)
            .foregroundStyle(isDestructive ? DesignTokens.Colors.statusErrorText : DesignTokens.Colors.customerDeep)
            .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.minimumTouchTarget)
            .contentShape(Rectangle())
    }
}

/// Icon tile + heading line that opens a block inside a card ("New time proposed", "In service").
struct DesignBlockHeader: View {
    let systemImage: String
    let title: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            DesignIconDisc(systemImage: systemImage)
            Text(title)
                .font(DesignTokens.Typography.Expressive.headline)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

/// The top of a sheet that is a page of its own, in the app's own pieces instead of the system's: our grabber, the title, and a
/// round ledge close button where the navigation bar's "Done" or "Close" would be (a groomer's page, password recovery). Under it
/// the page scrolls; over it the mint wash of the wizard's header. Put `.designSheetStyle()` on the sheet's content.
struct DesignSheetBar: View {
    let title: String
    /// Off in a full-screen view, which has nothing to drag down.
    var showsGrabber = true
    var closeIdentifier = "sheet.close"
    /// A sheet that is busy (saving, sending) cannot be closed from its button.
    var isCloseDisabled = false
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            if showsGrabber {
                Capsule()
                    .fill(DesignTokens.Colors.border)
                    .frame(width: 40, height: 5)
                    .accessibilityHidden(true)
            }
            HStack(spacing: DesignTokens.Spacing.md) {
                Text(title)
                    .font(DesignTokens.Typography.Expressive.headline)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(DesignTokens.Typography.Expressive.emphasis)
                        .foregroundStyle(isCloseDisabled ? DesignTokens.Colors.textTertiary : DesignTokens.Colors.customerDeep)
                        .frame(width: DesignTokens.Metrics.minimumTouchTarget, height: DesignTokens.Metrics.minimumTouchTarget)
                }
                .buttonStyle(BeckonLedgeButtonStyle(.round))
                .disabled(isCloseDisabled)
                .accessibilityLabel("Close")
                .accessibilityIdentifier(closeIdentifier)
            }
        }
        .padding(.horizontal, DesignTokens.Layout.pageHorizontalInset)
        .padding(.top, DesignTokens.Spacing.sm)
        .padding(.bottom, DesignTokens.Spacing.sm)
        .background(LinearGradient(colors: [DesignTokens.Colors.customerTint, DesignTokens.Colors.appBackground],
            startPoint: .top, endPoint: .bottom))
    }
}

extension View {
    /// A sheet dressed like the app: the warm page behind it, no system grabber (`DesignSheetBar` draws ours).
    func designSheetStyle() -> some View {
        presentationDragIndicator(.hidden)
            .presentationBackground(DesignTokens.Colors.appBackground)
    }
}


/// Dots under a carousel: the page you are on is a longer, darker capsule. With `progress` (the swipe's position in pages, 0 to
/// count - 1) the capsule stretches and fades from one dot to the next as the finger moves, instead of jumping when the page
/// lands; without it the dots follow `current`. Says "Offer 2 of 5" to VoiceOver.
struct DesignPageDots: View {
    let count: Int
    /// Zero-based.
    let current: Int
    let label: String
    var progress: CGFloat?

    private static let dot = DesignTokens.Spacing.sm
    private static let stretch = DesignTokens.Spacing.lg

    var body: some View {
        HStack(spacing: Self.dot) {
            ForEach(0..<count, id: \.self) { index in
                let weight = weight(of: index)
                Capsule()
                    .fill(DesignTokens.Colors.customerHeroDecoration.mix(with: DesignTokens.Colors.customerDeep, by: weight))
                    .frame(width: Self.dot + Self.stretch * weight, height: Self.dot)
            }
        }
        .frame(maxWidth: .infinity)
        // Following a finger needs no animation of its own; a jump from `current` does.
        .beckonAnimation(DesignTokens.Motion.swap, value: progress == nil ? current : -1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    /// 1 on the page you are on, falling to 0 a page away.
    private func weight(of index: Int) -> CGFloat {
        if let progress { return max(0, 1 - abs(progress - CGFloat(index))) }
        return index == current ? 1 : 0
    }
}

/// Hairline between rows of a card or between zones of a ticket.
struct DesignRowDivider: View {
    var body: some View {
        DesignTokens.Colors.borderSoft.frame(height: DesignTokens.Ledge.edgeWidth / 2)
            .accessibilityHidden(true)
    }
}

/// One quiet row of a "Manage" section (change, revise, cancel, report): icon, title, chevron. Rare actions live here, not
/// next to the action that moves things forward. Style it like any button (the guarded plain style is applied).
struct DesignManageRow: View {
    let title: String
    let systemImage: String
    var isDestructive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: systemImage)
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .frame(width: DesignTokens.Metrics.ledgeIconTile)
                    .accessibilityHidden(true)
                Text(title)
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                Image(systemName: "chevron.right")
                    .font(DesignTokens.Typography.Expressive.chip)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(isDestructive ? DesignTokens.Colors.statusErrorText : DesignTokens.Colors.textPrimary)
            .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(BeckonGuardedPlainButtonStyle())
    }
}

/// Label of a white ledge card that opens a page: mint icon tile, a title, one line saying what is inside, a chevron. It is the
/// link that has to read as a button (the way from a few previews to the full list). Wrap it in a `NavigationLink`/`Button`
/// styled `BeckonLedgeButtonStyle(.card)`.
struct DesignLinkCardLabel: View {
    let title: String
    var summary: String?
    let systemImage: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.Expressive.glyph)
                .foregroundStyle(DesignTokens.Colors.customerInk)
                .frame(width: DesignTokens.Metrics.minimumTouchTarget, height: DesignTokens.Metrics.minimumTouchTarget)
                .background(DesignTokens.Colors.customerFill, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.Expressive.headline)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                if let summary {
                    Text(summary)
                        .font(DesignTokens.Typography.Expressive.chip)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right")
                .font(DesignTokens.Typography.Expressive.label)
                .foregroundStyle(DesignTokens.Colors.customerDeep)
                .accessibilityHidden(true)
        }
        .padding(DesignTokens.Spacing.md)
        .accessibilityElement(children: .combine)
    }
}

/// Shortcut to a page, as a tile: icon on top, title, one line of what is inside. Two sit side by side
/// (`DesignShortcutRow`), so the account page opens with what the person uses most instead of a list of rows.
struct DesignShortcutTile<Destination: View>: View {
    let title: String
    let summary: String
    let systemImage: String
    private let destination: Destination

    init(title: String, summary: String, systemImage: String, @ViewBuilder destination: () -> Destination) {
        self.title = title
        self.summary = summary
        self.systemImage = systemImage
        self.destination = destination()
    }

    var body: some View {
        NavigationLink {
            destination
        } label: {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                DesignIconDisc(systemImage: systemImage, size: .touch, font: DesignTokens.Typography.Expressive.headline)
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(title)
                        .font(DesignTokens.Typography.Expressive.emphasis)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                    Text(summary)
                        .font(DesignTokens.Typography.Expressive.chip)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .accessibilityElement(children: .combine)
        }
        .buttonStyle(BeckonLedgeButtonStyle(.card))
    }
}

/// A shortcut tile as bars: the icon disc, the title, two lines of summary; the real tile's card and padding.
struct DesignShortcutTileSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            DesignSkeletonDisc()
                .frame(width: DesignTokens.Metrics.minimumTouchTarget, height: DesignTokens.Metrics.minimumTouchTarget)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                DesignSkeletonLine(width: 0.7, font: DesignTokens.Typography.Expressive.emphasis)
                VStack(alignment: .leading, spacing: 0) {
                    DesignSkeletonLine(width: 0.95, font: DesignTokens.Typography.Expressive.chip)
                    DesignSkeletonLine(width: 0.6, font: DesignTokens.Typography.Expressive.chip)
                }
            }
            Spacer(minLength: 0)
        }
        .designSkeleton(label: nil)
        .padding(DesignTokens.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .beckonLedge(.card)
    }
}


/// Lays shortcut tiles side by side at the same height; stacks them at accessibility sizes.
struct DesignShortcutRow<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.md))
            : AnyLayout(HStackLayout(alignment: .top, spacing: DesignTokens.Spacing.md))
        layout { content }
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Selectable capsule for sort and filter rows: mint ledge when on, white card ledge when off.
struct DesignChoiceChip: View {
    let title: String
    var systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage).font(DesignTokens.Typography.Expressive.label)
                        .accessibilityHidden(true)
                }
                Text(title).font(DesignTokens.Typography.Expressive.emphasis)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(isSelected ? DesignTokens.Colors.customerInk : DesignTokens.Colors.textSecondary)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
        }
        .buttonStyle(BeckonLedgeButtonStyle(isSelected ? .pill : .card))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

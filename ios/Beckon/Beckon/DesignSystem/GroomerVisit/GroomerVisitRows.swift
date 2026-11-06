import SwiftUI

/// Use the actual line boxes (including wrapped lines) for the same rounded bars as DesignSkeletonLine.
private struct GroomerVisitFactTextBars: TextRenderer {
    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            let rect = line.typographicBounds.rect
            let bar = rect.insetBy(dx: 0, dy: rect.height * 0.2)
            context.fill(Path(roundedRect: bar, cornerRadius: bar.height / 2), with: .color(DesignTokens.Colors.skeleton))
        }
    }
}

extension View {
    @ViewBuilder func groomerVisitFactSkeletonText(_ loading: Bool) -> some View {
        if loading { textRenderer(GroomerVisitFactTextBars()) } else { self }
    }

}

/// The groomerVisit's two row contracts. Cards own their padding; rows own their columns.
enum GroomerVisitDetailRowLayout {
    static let iconSize = DesignIconDisc.Size.tile.points
    static let iconGap = DesignTokens.Spacing.md
    static let labelSpacing = DesignTokens.Spacing.xs
    static let rowSpacing = DesignTokens.Spacing.lg
    static let separatorInset = DesignTokens.Spacing.sm
    static let accessoryWidth: CGFloat = 24
    static let accessoryGap = DesignTokens.Spacing.md
    static let minimumHeight: CGFloat = 56
    static let inlineEditorSpacing = DesignTokens.Spacing.sm
    static let inlineHeaderInset = DesignTokens.Spacing.sm
    static let inlineEditorBottomInset = DesignTokens.Spacing.xs

    static var contentLeadingInset: CGFloat { iconSize + iconGap }
    static var accessoryInset: CGFloat { accessoryGap + accessoryWidth }

    static func cardRowInsets(isFirst: Bool = false, isLast: Bool = false) -> EdgeInsets {
        EdgeInsets(top: isFirst ? DesignTokens.Spacing.lg : separatorInset,
                   leading: DesignTokens.Spacing.lg,
                   bottom: isLast ? DesignTokens.Spacing.lg : separatorInset,
                   trailing: DesignTokens.Spacing.lg)
    }
}

/// Facts and disclosure rows share one gap and divider, without separators around missing rows.
/// Full-card rows receive their inset values at construction, before subview resolution.
struct GroomerVisitDetailRowGroup<Content: View>: View {
    var fillsCard = false
    @ViewBuilder let content: Content

    var body: some View {
        Group(subviews: content) { rows in
            VStack(alignment: .leading, spacing: 0) {
                ForEach(rows) { row in
                    if row.id != rows.first?.id {
                        DesignRowDivider()
                            .padding(.vertical, fillsCard ? 0 : GroomerVisitDetailRowLayout.separatorInset)
                            .padding(.horizontal, fillsCard ? DesignTokens.Spacing.lg : 0)
                    }
                    row
                }
            }
        }
    }
}

/// A read-only row uses the whole content width, without a reserved accessory column.
/// The text sets the row height. The leading disc stays on that row's horizontal midline.
struct GroomerVisitRequestFactRow: View {
    let systemImage: String
    let title: String
    let value: String
    var detail: String? = nil
    var detailIsError = false
    var isPlaceholder = false
    var valueFont: Font = DesignTokens.Typography.Expressive.supporting
    var detailFont: Font = DesignTokens.Typography.Expressive.chip
    var detailColor: Color? = nil
    @ScaledMetric(relativeTo: .subheadline) private var minimumHeight = GroomerVisitDetailRowLayout.minimumHeight

    var body: some View {
        let diameter = GroomerVisitDetailRowLayout.iconSize
        VStack(alignment: .leading, spacing: GroomerVisitDetailRowLayout.labelSpacing) {
            Text(title).font(DesignTokens.Typography.Expressive.chip)
                .foregroundStyle(DesignTokens.Colors.textTertiary)
            Text(value).font(valueFont)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let detail {
                Text(detail).font(detailFont)
                    .foregroundStyle(detailIsError ? DesignTokens.Colors.statusErrorText : (detailColor ?? DesignTokens.Colors.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .groomerVisitFactSkeletonText(isPlaceholder)
        .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .leading)
        .padding(.leading, GroomerVisitDetailRowLayout.contentLeadingInset)
        .overlay(alignment: .leading) {
            Group {
                if isPlaceholder {
                    DesignSkeletonDisc()
                } else {
                    DesignIconDisc(systemImage: systemImage)
                }
            }
            .frame(width: diameter, height: diameter)
            .symbolRenderingMode(.monochrome)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Shared booked interval: start date, then both clock times. End date stays in VoiceOver.
struct GroomerVisitBookedTimeRow: View {
    let start: String
    let end: String
    let timeZoneIdentifier: String?
    var isPlaceholder = false
    var title = "Booked time"
    var systemImage = "clock"
    var dateFont: Font = DesignTokens.Typography.Expressive.supporting
    var timeFont: Font = DesignTokens.Typography.Expressive.supporting

    var body: some View {
        let summary = BeckonDateTimeFormatter.interval(from: start, to: end,
            serviceTimeZoneIdentifier: timeZoneIdentifier).summary
        Group {
            if let from = GroomingRequestDateFormatting.parsedDate(from: start),
               let until = GroomingRequestDateFormatting.parsedDate(from: end) {
                let labels = labels(from: from, until: until)
                GroomerVisitRequestFactRow(systemImage: systemImage, title: title,
                    value: labels.startDate, detail: labels.startTime + " – " + labels.endTime,
                    isPlaceholder: isPlaceholder, valueFont: dateFont, detailFont: timeFont,
                    detailColor: DesignTokens.Colors.textPrimary)
            } else {
                GroomerVisitRequestFactRow(systemImage: systemImage, title: title, value: summary, isPlaceholder: isPlaceholder)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title + ". " + summary)
    }

    private func labels(from: Date, until: Date) -> GroomerVisitRequestTimeLabels {
        var calendar = Calendar.current
        if let timeZoneIdentifier, let zone = TimeZone(identifier: timeZoneIdentifier) {
            calendar.timeZone = zone
        }
        return GroomerVisitRequestTimeLabels(start: from, end: until, calendar: calendar)
    }
}

/// Two adopted editor arrangements, with the same icon, content and accessory columns.
/// Expansion state and field bindings stay with the owning flow.
struct GroomerVisitDisclosureRow<Editor: View>: View {
    enum Presentation {
        /// The summary remains above a card-width picker.
        case belowSummary
        /// The editor replaces the summary in the body column; the marks keep their initial anchor.
        case inlineText
    }

    let systemImage: String
    let title: String
    let value: String
    var detail: String? = nil
    var detailIsError = false
    let isExpanded: Bool
    var presentation: Presentation = .belowSummary
    var valueIsPlaceholder = false
    var rowInsets = EdgeInsets()
    let headerIdentifier: String
    let onToggle: () -> Void
    @ViewBuilder let editor: () -> Editor

    @ScaledMetric(relativeTo: .subheadline) private var headerMinHeight = GroomerVisitDetailRowLayout.minimumHeight
    @ScaledMetric(relativeTo: .subheadline) private var inlineHeaderInset = GroomerVisitDetailRowLayout.inlineHeaderInset
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var headerPressed = false
    @State private var headerTapCount = 0

    var body: some View {
        rowContent
        .accessibilityElement(children: .contain)
    }

    private var rowContent: some View {
        Group {
            switch presentation {
            case .belowSummary:
                VStack(alignment: .leading, spacing: GroomerVisitDetailRowLayout.rowSpacing) {
                    header
                    if isExpanded {
                        editor()
                            .padding(.leading, rowInsets.leading)
                            .padding(.trailing, rowInsets.trailing)
                            .padding(.bottom, rowInsets.bottom)
                            .transition(GroomerVisitDetailMotion.editorTransition(reduceMotion: reduceMotion))
                    }
                }
            case .inlineText:
                VStack(alignment: .leading, spacing: isExpanded ? GroomerVisitDetailRowLayout.inlineEditorSpacing : 0) {
                    // Render and measure the summary once; its full-slot button lives behind it.
                    inlineSummary.accessibilityHidden(true).allowsHitTesting(false)
                    if isExpanded {
                        editor()
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .clipped()
                            .padding(.trailing, GroomerVisitDetailRowLayout.accessoryInset)
                            .padding(.bottom, GroomerVisitDetailRowLayout.inlineEditorBottomInset)
                            .transition(GroomerVisitDetailMotion.editorTransition(reduceMotion: reduceMotion))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.leading, GroomerVisitDetailRowLayout.contentLeadingInset)
                .overlay(alignment: isExpanded ? .topLeading : .leading) {
                    DesignIconDisc(systemImage: systemImage)
                        .frame(width: GroomerVisitDetailRowLayout.iconSize, height: headerMinHeight)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .overlay(alignment: isExpanded ? .topTrailing : .trailing) {
                    disclosure.frame(height: headerMinHeight)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .padding(rowInsets)
                // The clear header receives taps without repainting or relaying out the content.
                .background(alignment: .topLeading) { header }
            }
        }
    }

    private var header: some View {
        Button {
            headerTapCount += 1
            onToggle()
        } label: {
            headerLabel
                // Include the slot padding in the hit area without moving its visible content.
                .padding(EdgeInsets(top: rowInsets.top, leading: rowInsets.leading,
                    bottom: isExpanded ? 0 : rowInsets.bottom, trailing: rowInsets.trailing))
                .contentShape(Rectangle())
        }
        .buttonStyle(GroomerVisitDisclosureButtonStyle(isPressed: $headerPressed))
        .accessibilityLabel([title, value, detail].compactMap { $0 }.joined(separator: ", "))
        .accessibilityHint(isExpanded ? "Collapse this field" : "Edit in this card")
        .accessibilityIdentifier(headerIdentifier)
        .groomerVisitKeyboardInputRegion()
    }

    @ViewBuilder private var headerLabel: some View {
            switch presentation {
            case .belowSummary:
                HStack(alignment: .center, spacing: GroomerVisitDetailRowLayout.accessoryGap) {
                    GroomerVisitRequestFactRow(systemImage: systemImage, title: title, value: value, detail: detail, detailIsError: detailIsError)
                    disclosure
                }
                .frame(minHeight: headerMinHeight)
                .contentShape(Rectangle())
            case .inlineText:
                // This is only the hit/press surface. The foreground owns all visible geometry.
                // Collapsed: fill its measured summary slot. Expanded: retain the 56pt header.
                Color.clear
                    .frame(height: isExpanded ? headerMinHeight : nil)
                    .contentShape(Rectangle())
            }
    }

    private var inlineSummary: some View {
        // One layout owns the title and summary. Expanded input stays 8pt below this title,
        // independently of the button's 56pt minimum hit area and the card's edge padding.
        VStack(alignment: .leading, spacing: GroomerVisitDetailRowLayout.labelSpacing) {
            Text(title)
                .font(DesignTokens.Typography.Expressive.chip)
                .foregroundStyle(DesignTokens.Colors.textTertiary)
                .contentTransition(.interpolate)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !isExpanded {
                Text(value)
                    .font(valueIsPlaceholder ? .system(.subheadline, weight: .semibold).italic()
                          : DesignTokens.Typography.Expressive.supporting)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }
        }
        .padding(.top, inlineHeaderInset)
        .padding(.bottom, isExpanded ? 0 : inlineHeaderInset)
        .padding(.trailing, GroomerVisitDetailRowLayout.accessoryInset)
        .frame(maxWidth: .infinity, minHeight: isExpanded ? 0 : headerMinHeight, alignment: .topLeading)
    }

    private var disclosure: some View {
        BeckonPressEngine(isPressed: headerPressed) { amount in
            Image(systemName: "chevron.down")
                .foregroundStyle(DesignTokens.Colors.groomerDeep)
                .overlay {
                    Image(systemName: "chevron.down")
                        .foregroundStyle(DesignTokens.Colors.groomerFill)
                        .opacity(amount * 0.5)
                        .allowsHitTesting(false)
                }
        }
        .environment(\.beckonTapCount, headerTapCount)
        .font(DesignTokens.Typography.Expressive.chip)
        .rotationEffect(.degrees(isExpanded ? 180 : 0))
        .frame(width: GroomerVisitDetailRowLayout.accessoryWidth)
        .accessibilityHidden(true)
    }
}

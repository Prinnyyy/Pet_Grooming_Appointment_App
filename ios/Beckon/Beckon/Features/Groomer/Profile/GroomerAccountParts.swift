// The pieces the groomer's Account pages share (design): a text field with its caption, a switch row, the pinned save bar, the
// size-range slider, the room a pinned bar needs, and the store's notices and running actions as toasts. Colour comes from the role,
// so nothing here names coral.
import SwiftUI


// MARK: Fields

/// A caption over a text field that scrolls clear of the keyboard (`beckonKeyboardFocusTarget`).
struct GroomerTextField: View {
    let title: String
    @Binding var text: String
    let prompt: String
    var axis: Axis = .horizontal
    let focusTarget: String
    @FocusState.Binding var focusedTarget: String?

    init(title: String, text: Binding<String>, prompt: String, axis: Axis = .horizontal, focusTarget: String,
         focusedTarget: FocusState<String?>.Binding) {
        self.title = title
        _text = text
        self.prompt = prompt
        self.axis = axis
        self.focusTarget = focusTarget
        _focusedTarget = focusedTarget
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .font(DesignTokens.Typography.Expressive.label)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
            TextField(prompt, text: $text, axis: axis)
                .focused($focusedTarget, equals: focusTarget)
                .beckonFormField()
                .tint(DesignTokens.Colors.customerDeep)
        }
        .beckonKeyboardFocusTarget(focusTarget)
    }
}


/// A caption over anything that is not a text field (a menu, a slider).
struct GroomerCaptioned<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .font(DesignTokens.Typography.Expressive.label)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
            content
        }
    }
}


/// A menu that looks like a field: its value and the up-down chevrons.
struct GroomerMenuLabel: View {
    let text: String
    var isPlaceholder = false

    var body: some View {
        HStack {
            Text(text)
                .font(DesignTokens.Typography.Expressive.body)
                .foregroundStyle(isPlaceholder ? DesignTokens.Colors.textSecondary : DesignTokens.Colors.textPrimary)
            Spacer(minLength: DesignTokens.Spacing.xs)
            Image(systemName: "chevron.up.chevron.down")
                .font(DesignTokens.Typography.Expressive.chip)
                .foregroundStyle(DesignTokens.Colors.customerDeep)
        }
        .beckonFormField()
    }
}


/// A line that says what it is and what it changes, with a switch.
struct GroomerToggleRow: View {
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool
    var identifier: String?

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle { Text(subtitle).designSupportingText() }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .tint(DesignTokens.Colors.customerDeep)
                .accessibilityIdentifier(identifier ?? "")
        }
        .accessibilityElement(children: .combine)
    }
}


// MARK: Pinned bar

/// The one button of an editing page, pinned to the foot: it says what it saves, and shows a spinner while it does. `summary` is
/// one line over it (what the page has in it); `leading` is a second control beside it (delete).
struct GroomerSaveBar<Leading: View>: View {
    let title: String
    var busyTitle = "Saving…"
    var systemImage = "checkmark"
    let isSaving: Bool
    let isDisabled: Bool
    let identifier: String
    var summary: String?
    @ViewBuilder var leading: Leading
    let action: () -> Void

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            if let summary {
                Text(summary)
                    .font(DesignTokens.Typography.Expressive.supporting)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            HStack(spacing: DesignTokens.Spacing.md) {
                leading
                Button(action: action) {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        if isSaving { ProgressView().tint(DesignTokens.Colors.customerInk) }
                        Text(isSaving ? busyTitle : title)
                            .font(DesignTokens.Typography.Expressive.headline)
                        if !isSaving { Image(systemName: systemImage).font(DesignTokens.Typography.Expressive.glyph) }
                    }
                    .foregroundStyle(DesignTokens.Colors.customerInk)
                    .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.ledgePrimaryButtonHeight)
                }
                .buttonStyle(BeckonLedgeButtonStyle(.pill))
                .disabled(isDisabled)
                .accessibilityIdentifier(identifier)
            }
        }
        .padding(.horizontal, DesignTokens.Layout.pageHorizontalInset)
        .padding(.vertical, DesignTokens.Layout.actionAreaInset)
        .background(DesignTokens.Colors.appBackground.ignoresSafeArea())
        .overlay(alignment: .top) { DesignTokens.Colors.borderSoft.frame(height: DesignTokens.Ledge.edgeWidth / 2) }
    }
}

extension GroomerSaveBar where Leading == EmptyView {
    init(title: String, busyTitle: String = "Saving…", systemImage: String = "checkmark", isSaving: Bool, isDisabled: Bool,
         identifier: String, summary: String? = nil, action: @escaping () -> Void) {
        self.init(title: title, busyTitle: busyTitle, systemImage: systemImage, isSaving: isSaving, isDisabled: isDisabled,
            identifier: identifier, summary: summary, leading: { EmptyView() }, action: action)
    }
}


/// The room a pinned bar takes at the foot of a page, as the last block of its content.
struct GroomerBarClearance: View {
    var body: some View {
        Color.clear
            .frame(height: DesignTokens.Layout.stationaryActionContentClearance - DesignTokens.Layout.pageBottomInset)
            .accessibilityHidden(true)
    }
}


// MARK: Messages

/// Sends what the store says (a notice, an error, a running save or upload) to the global feedback layer, as the real page does.

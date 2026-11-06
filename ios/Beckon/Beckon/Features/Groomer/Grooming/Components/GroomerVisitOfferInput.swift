import SwiftUI
import UIKit

/// Local editor constraints; the production offer contract is unchanged.
enum GroomerVisitOfferInput {
    static let maximumPrice: Decimal = Decimal(999_999) / 100
    static let messageLength = 200

    static func priceDraft(_ proposed: String, previous: String) -> String {
        let text = proposed.replacingOccurrences(of: Locale.current.decimalSeparator ?? ".", with: ".")
        guard text.range(of: #"^[0-9]{0,4}(\.[0-9]{0,2})?$"#, options: .regularExpression) == text.startIndex..<text.endIndex else { return previous }
        return text
    }

    static func normalizedPrice(_ text: String, preservingDecimals: Bool = true) -> String? {
        guard text.contains(where: { $0.isNumber }),
              text.range(of: #"^[0-9]{0,4}(\.[0-9]{0,2})?$"#, options: .regularExpression) == text.startIndex..<text.endIndex,
              let value = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")),
              (0...maximumPrice).contains(value) else { return nil }
        let places = preservingDecimals ? text.split(separator: ".", omittingEmptySubsequences: false).dropFirst().first?.count ?? 0 : 0
        return displayPrice(value, minimumFractionDigits: places)
    }

    static func displayPrice(_ value: Decimal, minimumFractionDigits: Int = 0) -> String {
        value.formatted(.number.locale(Locale(identifier: "en_US_POSIX"))
            .grouping(.never).precision(.fractionLength(minimumFractionDigits...2)))
    }

    /// Find the committed replacement, so reaching the limit never removes an unchanged suffix.
    static func messageChange(from current: String, to proposed: String) -> (BeckonTextInputLimit.Change, Int) {
        let before = Array(current), after = Array(proposed)
        var prefix = 0, suffix = 0
        while prefix < min(before.count, after.count), before[prefix] == after[prefix] { prefix += 1 }
        while suffix < min(before.count, after.count) - prefix,
              before[before.count - suffix - 1] == after[after.count - suffix - 1] { suffix += 1 }
        let start = current.index(current.startIndex, offsetBy: prefix)
        let end = current.index(current.endIndex, offsetBy: -suffix)
        let range = NSRange(start..<end, in: current)
        let replacement = String(after[prefix..<(after.count - suffix)])
        let change = BeckonTextInputLimit.applyingChange(currentText: current, range: range,
            replacement: replacement, maximumLength: messageLength)
        return (change, range.location + change.acceptedReplacement.utf16.count)
    }
}

/// The native field shows its caret, while keeping price edits at the end of the amount.
struct GroomerVisitOfferPriceInput: View {
    @Binding var text: String
    var focusedTarget: Binding<GroomerOfferFocusTarget?>
    var pointSize: CGFloat? = nil
    var usesRowStyle = false
    @State private var isEditing = false
    @State private var draft = ""
    @State private var previousPrice = ""
    @State private var hasEdited = false
    @State private var changedThisEdit = false

    private var display: String {
        if isEditing { return draft.isEmpty ? "0" : draft }
        return GroomerVisitOfferInput.normalizedPrice(text, preservingDecimals: hasEdited) ?? "—"
    }

    var body: some View {
        Text(display)
            .lineLimit(1).minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Keep the existing SwiftUI line box and baseline; UIKit supplies text and the native caret.
            .hidden()
            .overlay {
                GroomerVisitPriceKeyboard(isFocused: focusedTarget.wrappedValue == .price,
                    display: isEditing ? draft : display, pointSize: pointSize, usesRowStyle: usesRowStyle,
                    onEditing: editingChanged, onInsert: insert, onDelete: delete)
            }
    }

    private func editingChanged(_ editing: Bool) -> String {
        guard isEditing != editing else { return draft }
        if editing {
            previousPrice = text
            draft = hasEdited ? GroomerVisitOfferInput.normalizedPrice(text) ?? "" : ""
            changedThisEdit = false
            isEditing = true
            focusedTarget.wrappedValue = .price
        } else {
            // Input already published its amount; resignation must not overwrite a newer action.
            if changedThisEdit, GroomerVisitOfferInput.normalizedPrice(draft) != nil { hasEdited = true }
            isEditing = false
            if focusedTarget.wrappedValue == .price { focusedTarget.wrappedValue = nil }
        }
        return draft
    }

    private func insert(_ addition: String) -> String {
        let accepted = GroomerVisitOfferInput.priceDraft(draft + addition, previous: draft)
        guard accepted != draft else { return draft }
        draft = accepted
        changedThisEdit = true
        publishDraft()
        return draft
    }

    private func delete() -> String {
        guard !draft.isEmpty else { return draft }
        draft.removeLast()
        changedThisEdit = true
        publishDraft()
        return draft
    }

    private func publishDraft() {
        // Keep Send offer current even if it is tapped before keyboard resignation completes.
        text = GroomerVisitOfferInput.normalizedPrice(draft) ?? previousPrice
    }
}

private struct GroomerVisitPriceKeyboard: UIViewRepresentable {
    let isFocused: Bool
    let display: String
    let pointSize: CGFloat?
    let usesRowStyle: Bool
    let onEditing: (Bool) -> String
    let onInsert: (String) -> String
    let onDelete: () -> String
    @Environment(\.isEnabled) private var isEnabled

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> GroomerVisitPriceTextField {
        let view = GroomerVisitPriceTextField()
        view.delegate = context.coordinator
        view.keyboardType = .decimalPad
        view.borderStyle = .none
        view.adjustsFontSizeToFitWidth = true
        view.adjustsFontForContentSizeCategory = true
        view.accessibilityLabel = "Price estimate in dollars"
        view.accessibilityHint = "Enter or delete digits at the end of the amount"
        view.inputAccessoryView = GroomerVisitKeyboardAccessory { [weak view, weak coordinator = context.coordinator] in
            view?.wantsFocus = false
            _ = coordinator?.parent.onEditing(false)
            view?.resignFirstResponder()
        }
        return view
    }

    func updateUIView(_ view: GroomerVisitPriceTextField, context: Context) {
        context.coordinator.parent = self
        let base = pointSize.map { UIFont.systemFont(ofSize: $0, weight: usesRowStyle ? .bold : .black) }
            ?? UIFont.preferredFont(forTextStyle: .body, compatibleWith: view.traitCollection)
        let descriptor = pointSize != nil ? base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor : base.fontDescriptor
        view.font = UIFont(descriptor: descriptor, size: base.pointSize)
        view.minimumFontSize = base.pointSize * 0.75
        view.textColor = UIColor(usesRowStyle ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.groomerInk)
        view.tintColor = UIColor(DesignTokens.Colors.groomerDeep)
        view.attributedPlaceholder = NSAttributedString(string: "0", attributes: [.foregroundColor: UIColor(DesignTokens.Colors.textTertiary)])
        if view.text != display { view.text = display; view.moveCaretToEnd() }
        view.isEnabled = isEnabled
        view.wantsFocus = isFocused && isEnabled
        if view.wantsFocus != view.isFirstResponder {
            DispatchQueue.main.async { [weak view] in
                guard let view else { return }
                if view.wantsFocus, view.window != nil { view.becomeFirstResponder() }
                else if !view.wantsFocus { view.resignFirstResponder() }
            }
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: GroomerVisitPriceKeyboard
        init(parent: GroomerVisitPriceKeyboard) { self.parent = parent }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            (textField as? GroomerVisitPriceTextField)?.wantsFocus = true
            textField.text = parent.onEditing(true)
            (textField as? GroomerVisitPriceTextField)?.moveCaretToEnd()
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            (textField as? GroomerVisitPriceTextField)?.wantsFocus = false
            _ = parent.onEditing(false)
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            textField.text = string.isEmpty ? parent.onDelete() : parent.onInsert(string)
            (textField as? GroomerVisitPriceTextField)?.moveCaretToEnd()
            return false
        }
    }
}

/// Native blinking caret remains visible; selection and insertion stay at the trailing edge.
private final class GroomerVisitPriceTextField: UITextField {
    var wantsFocus = false
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        // Restrict editing menus, not keyboard dismissal through the responder chain.
        action == #selector(UIResponder.resignFirstResponder)
    }

    override var selectedTextRange: UITextRange? {
        get { super.selectedTextRange }
        set {
            guard newValue != nil else { super.selectedTextRange = nil; return }
            super.selectedTextRange = textRange(from: endOfDocument, to: endOfDocument)
        }
    }

    func moveCaretToEnd() { selectedTextRange = textRange(from: endOfDocument, to: endOfDocument) }
}

/// Native multiline input supports composition and replacement limits without a counter or alert.
/// The enclosing SwiftUI field still owns its padding, border, focus reveal and body-column width.
struct GroomerVisitOfferMessageInput: UIViewRepresentable {
    @Binding var text: String
    var focusedTarget: Binding<GroomerOfferFocusTarget?>
    var expressive = true
    @Environment(\.isEnabled) private var isEnabled

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.adjustsFontForContentSizeCategory = true
        view.keyboardDismissMode = .interactive
        view.autocapitalizationType = .sentences
        view.accessibilityLabel = "Message"
        view.inputAccessoryView = GroomerVisitKeyboardAccessory { [weak view, weak coordinator = context.coordinator] in
            coordinator?.parent.focusedTarget.wrappedValue = nil
            view?.resignFirstResponder()
        }
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        var descriptor = UIFont.preferredFont(forTextStyle: expressive ? .subheadline : .body,
            compatibleWith: view.traitCollection).fontDescriptor
        if expressive {
            descriptor = (descriptor.withDesign(.rounded) ?? descriptor)
                .addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: UIFont.Weight.semibold]])
        }
        view.font = UIFont(descriptor: descriptor, size: 0)
        view.textColor = UIColor(DesignTokens.Colors.textPrimary)
        view.tintColor = UIColor(DesignTokens.Colors.customerDeep)
        view.isEditable = isEnabled
        if view.markedTextRange == nil, view.text != text { view.text = text }
        if (focusedTarget.wrappedValue == .message && isEnabled) != view.isFirstResponder {
            context.coordinator.scheduleFocusUpdate(for: view)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        let line = uiView.font?.lineHeight ?? 18
        let height = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        return CGSize(width: width, height: ceil(min(line * 6, max(line * 3, height))))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: GroomerVisitOfferMessageInput
        private var focusUpdateScheduled = false
        init(parent: GroomerVisitOfferMessageInput) { self.parent = parent }

        func scheduleFocusUpdate(for view: UITextView) {
            guard !focusUpdateScheduled else { return }
            focusUpdateScheduled = true
            // Resigning asks the hosting view for its next responder. Doing that inside
            // updateUIView re-enters SwiftUI's active graph update and can lock the main thread.
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self else { return }
                self.focusUpdateScheduled = false
                guard let view else { return }
                let wantsFocus = self.parent.focusedTarget.wrappedValue == .message && self.parent.isEnabled
                if wantsFocus {
                    guard view.window != nil, !view.isFirstResponder else { return }
                    view.becomeFirstResponder()
                } else if view.isFirstResponder {
                    view.resignFirstResponder()
                }
            }
        }

        func textViewDidBeginEditing(_ textView: UITextView) { parent.focusedTarget.wrappedValue = .message }

        func textViewDidEndEditing(_ textView: UITextView) {
            textView.unmarkText()
            textViewDidChange(textView)
            if parent.focusedTarget.wrappedValue == .message { parent.focusedTarget.wrappedValue = nil }
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // Leave uncommitted Chinese/Japanese input alone; constrain the committed result below.
            guard textView.markedTextRange == nil else { return true }
            let change = BeckonTextInputLimit.applyingChange(currentText: textView.text ?? "", range: range,
                replacement: text, maximumLength: GroomerVisitOfferInput.messageLength)
            guard change.didReachLimit else { return true }
            apply(change.text, caret: range.location + change.acceptedReplacement.utf16.count, to: textView)
            return false
        }

        func textViewDidChange(_ textView: UITextView) {
            guard textView.markedTextRange == nil else { return }
            let proposed = textView.text ?? ""
            let (change, caret) = GroomerVisitOfferInput.messageChange(from: parent.text, to: proposed)
            if change.text != proposed { apply(change.text, caret: caret, to: textView) }
            else { parent.text = proposed }
        }

        private func apply(_ text: String, caret: Int, to view: UITextView) {
            view.text = text
            view.selectedRange = NSRange(location: min(caret, text.utf16.count), length: 0)
            parent.text = text
        }
    }
}

/// UIKit owns the attachment to the keyboard, including app/scene transitions.
/// Reuse the app's circular Done control; the remaining accessory area also dismisses.
private final class GroomerVisitKeyboardAccessory: UIInputView {
    private let host: UIHostingController<AnyView>

    init(onDone: @escaping () -> Void) {
        host = UIHostingController(rootView: AnyView(
            BeckonKeyboardDoneAccessoryControl(onDone: onDone)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .background(DesignTokens.Colors.appBackground)
                .contentShape(Rectangle())
                .onTapGesture(perform: onDone)
        ))
        super.init(frame: CGRect(x: 0, y: 0, width: 0,
            height: BeckonKeyboardDoneAccessoryPolicy.controlDiameter + BeckonKeyboardDoneAccessoryPolicy.keyboardGap),
            inputViewStyle: .keyboard)
        autoresizingMask = [.flexibleWidth]
        host.safeAreaRegions = []
        host.view.backgroundColor = .clear
        host.view.frame = bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(host.view)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

import SwiftUI
import UIKit

nonisolated struct BeckonKeyboardFormLayout: Equatable {
    static let focusedGroupAnchorY: CGFloat = 0.55

    let keyboardOverlap: CGFloat

    init(containerMaxY: CGFloat, keyboardMinY: CGFloat) {
        keyboardOverlap = max(0, containerMaxY - keyboardMinY)
    }

    func scrollBottomClearance(base: CGFloat) -> CGFloat {
        base + keyboardOverlap
    }
}

nonisolated enum BeckonTextInputLimit {
    struct Change: Equatable, Sendable {
        let text: String
        let acceptedReplacement: String
        let didReachLimit: Bool
    }

    static func applyingChange(
        currentText: String,
        range: NSRange,
        replacement: String,
        maximumLength: Int
    ) -> Change {
        guard maximumLength >= 0,
              let stringRange = Range(range, in: currentText) else {
            return Change(
                text: String(currentText.prefix(max(0, maximumLength))),
                acceptedReplacement: "",
                didReachLimit: true
            )
        }

        let removedCount = currentText[stringRange].count
        let retainedCount = currentText.count - removedCount
        let availableCount = max(0, maximumLength - retainedCount)
        let acceptedReplacement = String(replacement.prefix(availableCount))
        let updatedText = currentText.replacingCharacters(
            in: stringRange,
            with: acceptedReplacement
        )

        return Change(
            text: updatedText,
            acceptedReplacement: acceptedReplacement,
            didReachLimit: acceptedReplacement.count < replacement.count
        )
    }
}

nonisolated enum BeckonAddressInputRule: Sendable {
    case street
    case city
    case zipCode

    func sanitize(_ value: String) -> String {
        String(value.unicodeScalars.filter(isAllowed))
    }

    private func isAllowed(_ scalar: Unicode.Scalar) -> Bool {
        switch self {
        case .street:
            CharacterSet.alphanumerics.contains(scalar)
                || CharacterSet.whitespaces.contains(scalar)
                || "#.,-/'&".unicodeScalars.contains(scalar)
        case .city:
            CharacterSet.alphanumerics.contains(scalar)
                || CharacterSet.whitespaces.contains(scalar)
                || ".-'".unicodeScalars.contains(scalar)
        case .zipCode:
            CharacterSet.decimalDigits.contains(scalar)
        }
    }
}

struct BeckonLimitedTextField: View {
    let placeholder: String
    @Binding var text: String
    let maximumLength: Int
    var isInvalid = false
    var textContentType: UITextContentType?
    var keyboardType: UIKeyboardType = .default
    var autocapitalizationType: UITextAutocapitalizationType = .sentences
    var addressInputRule: BeckonAddressInputRule?
    var onEditingBegan: () -> Void = {}
    var onTextChange: (String) -> Void = { _ in }

    @State private var isLimitFlashing = false
    @State private var limitFeedbackToken = 0

    var body: some View {
        BeckonLimitedUITextField(
            placeholder: placeholder,
            text: $text,
            maximumLength: maximumLength,
            textContentType: textContentType,
            keyboardType: keyboardType,
            autocapitalizationType: autocapitalizationType,
            addressInputRule: addressInputRule,
            isInvalid: isInvalid || isLimitFlashing,
            onEditingBegan: onEditingBegan,
            onTextChange: onTextChange,
            onLimitReached: showLimitFeedback
        )
        .beckonFormField(isInvalid: isInvalid || isLimitFlashing)
    }

    private func showLimitFeedback() {
        limitFeedbackToken += 1
        let token = limitFeedbackToken
        withAnimation(.easeOut(duration: 0.1)) {
            isLimitFlashing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            guard token == limitFeedbackToken else { return }
            withAnimation(.easeIn(duration: 0.16)) {
                isLimitFlashing = false
            }
        }
    }
}

private struct BeckonLimitedUITextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    let maximumLength: Int
    let textContentType: UITextContentType?
    let keyboardType: UIKeyboardType
    let autocapitalizationType: UITextAutocapitalizationType
    let addressInputRule: BeckonAddressInputRule?
    let isInvalid: Bool
    let onEditingBegan: () -> Void
    let onTextChange: (String) -> Void
    let onLimitReached: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.borderStyle = .none
        textField.adjustsFontForContentSizeCategory = true
        textField.font = UIFont.preferredFont(forTextStyle: .body)
        textField.textColor = UIColor(DesignTokens.Colors.textPrimary)
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged(_:)),
            for: .editingChanged
        )
        configure(textField)
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        context.coordinator.parent = self
        configure(textField)
        let constrainedText = String(text.prefix(maximumLength))
        if textField.text != constrainedText {
            textField.text = constrainedText
        }
    }

    private func configure(_ textField: UITextField) {
        textField.placeholder = placeholder
        textField.textContentType = textContentType
        textField.keyboardType = keyboardType
        textField.autocapitalizationType = autocapitalizationType
        textField.autocorrectionType = .default
        textField.tintColor = UIColor(
            isInvalid ? DesignTokens.Colors.error : DesignTokens.Colors.customerPrimaryDark
        )
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: BeckonLimitedUITextField

        init(parent: BeckonLimitedUITextField) {
            self.parent = parent
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.onEditingBegan()
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            let currentText = textField.text ?? ""
            let sanitizedReplacement = parent.addressInputRule?.sanitize(string) ?? string
            let change = BeckonTextInputLimit.applyingChange(
                currentText: currentText,
                range: range,
                replacement: sanitizedReplacement,
                maximumLength: parent.maximumLength
            )

            let rejectedCharacters = sanitizedReplacement != string
            guard change.didReachLimit || rejectedCharacters else { return true }

            textField.text = change.text
            parent.text = change.text
            parent.onTextChange(change.text)
            moveCursor(
                in: textField,
                utf16Offset: range.location + change.acceptedReplacement.utf16.count
            )
            parent.onLimitReached()
            return false
        }

        @objc func editingChanged(_ textField: UITextField) {
            let constrainedText = String((textField.text ?? "").prefix(parent.maximumLength))
            if textField.text != constrainedText {
                textField.text = constrainedText
                parent.onLimitReached()
            }
            parent.text = constrainedText
            parent.onTextChange(constrainedText)
        }

        private func moveCursor(in textField: UITextField, utf16Offset: Int) {
            guard let position = textField.position(
                from: textField.beginningOfDocument,
                offset: utf16Offset
            ) else { return }
            textField.selectedTextRange = textField.textRange(from: position, to: position)
        }
    }
}

extension View {
    func beckonFormField(isInvalid: Bool = false) -> some View {
        modifier(BeckonFormFieldModifier(isInvalid: isInvalid))
    }
}

struct BeckonFieldGroup<Content: View>: View {
    let label: String
    let supportingText: String?
    let errorText: String?
    let content: Content

    init(
        _ label: String,
        supportingText: String? = nil,
        errorText: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label
        self.supportingText = supportingText
        self.errorText = errorText
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(label)
                .font(DesignTokens.Typography.fieldLabel)
                .foregroundStyle(DesignTokens.Colors.textPrimary)

            content

            if let errorText {
                Text(errorText)
                    .font(DesignTokens.Typography.status)
                    .foregroundStyle(DesignTokens.Colors.errorText)
            } else if let supportingText {
                Text(supportingText)
                    .font(DesignTokens.Typography.supporting)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
        }
    }
}

private struct BeckonFormFieldModifier: ViewModifier {
    @Environment(\.isEnabled) private var isEnabled

    let isInvalid: Bool

    func body(content: Content) -> some View {
        content
            .font(DesignTokens.Typography.body)
            .foregroundStyle(DesignTokens.Colors.textPrimary)
            .tint(isInvalid ? DesignTokens.Colors.error : DesignTokens.Colors.customerPrimaryDark)
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.md)
            .frame(minHeight: 52)
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
                    .fill(backgroundColor)
            }
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
                    .stroke(borderColor, lineWidth: isInvalid ? 1.6 : 1)
            }
            .shadow(
                color: isInvalid ? DesignTokens.Colors.error.opacity(0.28) : .clear,
                radius: isInvalid ? 9 : 0,
                x: 0,
                y: 0
            )
            .opacity(isEnabled ? 1 : 0.64)
    }

    private var backgroundColor: Color {
        isEnabled ? DesignTokens.Colors.surface : DesignTokens.Colors.borderSoft.opacity(0.35)
    }

    private var borderColor: Color {
        if isInvalid {
            return DesignTokens.Colors.error
        }

        return isEnabled ? DesignTokens.Colors.borderSoft : DesignTokens.Colors.borderSoft.opacity(0.7)
    }
}

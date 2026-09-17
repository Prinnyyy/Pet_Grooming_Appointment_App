import SwiftUI
import UIKit

nonisolated enum BeckonKeyboardActionPlacement: Sendable {
    case pageAction
    case inputAccessory
}

nonisolated enum BeckonKeyboardDismissalPolicy {
    static let supportsInteractiveScroll = true
    static let supportsExplicitDoneAction = true
}

nonisolated enum BeckonKeyboardDoneAccessoryPresentation: Sendable {
    case floatingCircularGlass
}

nonisolated enum BeckonKeyboardDoneAccessoryPolicy {
    static let presentation: BeckonKeyboardDoneAccessoryPresentation = .floatingCircularGlass
    static let controlDiameter: CGFloat = 52
    static let trailingInset: CGFloat = 20
    static let keyboardGap: CGFloat = 12
    static let symbolName = "checkmark"
    static let usesInteractiveSystemGlass = true
    static let symbolColorHex = DesignTokens.DisplayP3Hex.customerAccentStrong
}

nonisolated enum BeckonKeyboardRevealPolicy {
    static let animatesProgrammaticReveal = false

    static func shouldCancelAutomaticReveal(for phase: ScrollPhase) -> Bool {
        switch phase {
        case .tracking, .interacting, .decelerating:
            true
        case .idle, .animating:
            false
        }
    }

    static func shouldRequestReveal(
        wasKeyboardVisible: Bool,
        isKeyboardVisible: Bool
    ) -> Bool {
        !wasKeyboardVisible && isKeyboardVisible
    }
}

nonisolated enum BeckonKeyboardPresentationPolicy {
    static func keyboardIsOnScreen(keyboardFrame: CGRect, screenBounds: CGRect) -> Bool {
        guard keyboardFrame.width > 0, keyboardFrame.height > 0 else { return false }
        let intersection = screenBounds.intersection(keyboardFrame)
        return !intersection.isNull && intersection.width > 0 && intersection.height > 0
    }

    static func preventSheetDismissal(
        keyboardFrame: CGRect,
        screenBounds: CGRect,
        additionallyPrevented: Bool = false
    ) -> Bool {
        if additionallyPrevented { return true }
        return keyboardIsOnScreen(keyboardFrame: keyboardFrame, screenBounds: screenBounds)
    }

    static func shouldRetainKeyboardGestureLock(
        isKeyboardVisible: Bool,
        scrollPhase: ScrollPhase,
        wasLocked: Bool
    ) -> Bool {
        if isKeyboardVisible { return true }
        return wasLocked
            && BeckonKeyboardRevealPolicy.shouldCancelAutomaticReveal(for: scrollPhase)
    }
}

@MainActor
private var beckonActiveScreenBounds: CGRect {
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first(where: { $0.activationState == .foregroundActive })?
        .screen.bounds ?? .zero
}

nonisolated struct BeckonKeyboardFormLayout: Equatable {
    enum RevealAction: Equatable, Sendable {
        case none
        case top
        case bottom
    }

    let containerFrame: CGRect
    let keyboardFrame: CGRect
    let keyboardOverlap: CGFloat

    init(containerFrame: CGRect, keyboardFrame: CGRect) {
        self.containerFrame = containerFrame
        self.keyboardFrame = keyboardFrame

        let intersection = containerFrame.intersection(keyboardFrame)
        keyboardOverlap = intersection.isNull ? 0 : intersection.height
    }

    func stationaryPageActionOffset(actionHeight: CGFloat) -> CGFloat {
        let keyboardIsDocked = keyboardFrame.maxY >= containerFrame.maxY - 1
        guard keyboardIsDocked, keyboardOverlap > 0 else { return 0 }
        return keyboardOverlap + max(0, actionHeight)
    }

    func revealAction(for targetFrame: CGRect, clearance: CGFloat) -> RevealAction {
        let horizontalIntersection = containerFrame.minX < keyboardFrame.maxX
            && containerFrame.maxX > keyboardFrame.minX
        let keyboardReachesContainer = keyboardFrame.minY <= containerFrame.maxY
            && keyboardFrame.maxY > containerFrame.minY
        guard keyboardFrame.height > 0,
              horizontalIntersection,
              keyboardReachesContainer else {
            return .none
        }

        let usableMinY = containerFrame.minY + clearance
        let usableMaxY = min(containerFrame.maxY, keyboardFrame.minY) - clearance
        guard usableMaxY > usableMinY else { return .none }

        let topCorrection = max(0, usableMinY - targetFrame.minY)
        let bottomCorrection = max(0, targetFrame.maxY - usableMaxY)
        guard topCorrection > 0 || bottomCorrection > 0 else { return .none }

        if topCorrection > 0, bottomCorrection > 0 {
            return topCorrection <= bottomCorrection ? .top : .bottom
        }
        return topCorrection > 0 ? .top : .bottom
    }

    func scrollAnchor(for action: RevealAction, clearance: CGFloat) -> UnitPoint? {
        guard containerFrame.height > 0 else { return nil }

        switch action {
        case .none:
            return nil
        case .top:
            let rawY = clearance / containerFrame.height
            let y = Swift.min(Swift.max(rawY, 0), 1)
            return UnitPoint(x: 0.5, y: y)
        case .bottom:
            let usableMaxY = min(containerFrame.maxY, keyboardFrame.minY) - clearance
            let rawY = (usableMaxY - containerFrame.minY) / containerFrame.height
            let y = Swift.min(Swift.max(rawY, 0), 1)
            return UnitPoint(x: 0.5, y: y)
        }
    }
}

nonisolated struct BeckonKeyboardFocusTargetID: Equatable, Hashable, Sendable {
    let semanticID: String

    init(_ semanticID: String) {
        self.semanticID = semanticID
    }

    var top: String { "\(semanticID).keyboard-target.top" }
    var bottom: String { "\(semanticID).keyboard-target.bottom" }
}

nonisolated struct BeckonKeyboardFocusMeasurement: Equatable, Sendable {
    let target: String
    let frame: CGRect
}

nonisolated enum BeckonKeyboardFocusMeasurementPolicy {
    static func measurement(
        target: String,
        focusedTarget: String?,
        frame: CGRect
    ) -> BeckonKeyboardFocusMeasurement? {
        guard target == focusedTarget,
              !frame.isNull,
              !frame.isInfinite,
              frame.width > 0,
              frame.height > 0 else {
            return nil
        }
        return BeckonKeyboardFocusMeasurement(target: target, frame: frame)
    }
}

private struct BeckonKeyboardFocusReportingContext {
    let focusedTarget: String?
    let report: (BeckonKeyboardFocusMeasurement) -> Void

    static let inactive = BeckonKeyboardFocusReportingContext(
        focusedTarget: nil,
        report: { _ in }
    )
}

private struct BeckonKeyboardFocusReportingContextKey: EnvironmentKey {
    static let defaultValue = BeckonKeyboardFocusReportingContext.inactive
}

private extension EnvironmentValues {
    var beckonKeyboardFocusReportingContext: BeckonKeyboardFocusReportingContext {
        get { self[BeckonKeyboardFocusReportingContextKey.self] }
        set { self[BeckonKeyboardFocusReportingContextKey.self] = newValue }
    }
}

private struct BeckonKeyboardFocusTargetModifier: ViewModifier {
    let id: String
    @Environment(\.beckonKeyboardFocusReportingContext) private var reportingContext
    @State private var measuredFrame: CGRect = .null

    func body(content: Content) -> some View {
        let marker = BeckonKeyboardFocusTargetID(id)

        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .frame(height: 0)
                .accessibilityHidden(true)
                .id(marker.top)

            content
                .onGeometryChange(for: CGRect.self) { geometry in
                    geometry.frame(in: .global)
                } action: { frame in
                    measuredFrame = frame
                    reportIfFocused(frame)
                }

            Color.clear
                .frame(height: 0)
                .accessibilityHidden(true)
                .id(marker.bottom)
        }
        .onChange(of: reportingContext.focusedTarget) { _, _ in
            reportIfFocused(measuredFrame)
        }
    }

    private func reportIfFocused(_ frame: CGRect) {
        guard let measurement = BeckonKeyboardFocusMeasurementPolicy.measurement(
            target: id,
            focusedTarget: reportingContext.focusedTarget,
            frame: frame
        ) else {
            return
        }
        reportingContext.report(measurement)
    }
}

private struct BeckonKeyboardRevealRequest: Equatable {
    let target: String
    let action: BeckonKeyboardFormLayout.RevealAction
    let targetFrame: CGRect
    let keyboardFrame: CGRect
    let viewportFrame: CGRect
}

private struct BeckonKeyboardAvoidanceModifier: ViewModifier {
    let focusedTarget: String?
    let proxy: ScrollViewProxy
    let additionallyPreventsPresentationDismissal: Bool

    @State private var keyboardFrame: CGRect = .null
    @State private var viewportFrame: CGRect = .zero
    @State private var focusMeasurement: BeckonKeyboardFocusMeasurement?
    @State private var lastRequest: BeckonKeyboardRevealRequest?
    @State private var pendingTask: Task<Void, Never>?
    @State private var automaticRevealRequested = false
    @State private var preventsSheetDismissal = false
    @State private var scrollPhase: ScrollPhase = .idle

    func body(content: Content) -> some View {
        content
            .environment(
                \.beckonKeyboardFocusReportingContext,
                BeckonKeyboardFocusReportingContext(
                    focusedTarget: focusedTarget,
                    report: receiveFocusMeasurement
                )
            )
            .scrollDismissesKeyboard(.interactively)
            .presentationContentInteraction(.scrolls)
            .interactiveDismissDisabled(
                preventsSheetDismissal || additionallyPreventsPresentationDismissal
            )
            .beckonKeyboardDoneAccessory()
            .onGeometryChange(for: CGRect.self) { geometry in
                geometry.frame(in: .global)
            } action: { frame in
                guard frame != viewportFrame else { return }
                viewportFrame = frame
                scheduleRequestedReveal()
            }
            .onChange(of: focusedTarget) { _, target in
                lastRequest = nil
                pendingTask?.cancel()
                if focusMeasurement?.target != target {
                    focusMeasurement = nil
                }
                guard target != nil else {
                    automaticRevealRequested = false
                    return
                }
                requestAutomaticReveal()
            }
            .onScrollPhaseChange { _, phase in
                scrollPhase = phase
                if BeckonKeyboardRevealPolicy.shouldCancelAutomaticReveal(for: phase) {
                    pendingTask?.cancel()
                    automaticRevealRequested = false
                }
                updateKeyboardGestureLock()
            }
            .onReceive(NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillChangeFrameNotification
            )) { notification in
                guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey]
                    as? CGRect else { return }
                let screenBounds = beckonActiveScreenBounds
                let wasKeyboardVisible = BeckonKeyboardPresentationPolicy.keyboardIsOnScreen(
                    keyboardFrame: keyboardFrame,
                    screenBounds: screenBounds
                )
                keyboardFrame = frame
                let isKeyboardVisible = BeckonKeyboardPresentationPolicy.keyboardIsOnScreen(
                    keyboardFrame: frame,
                    screenBounds: screenBounds
                )
                updateKeyboardGestureLock(isKeyboardVisible: isKeyboardVisible)
                if BeckonKeyboardRevealPolicy.shouldRequestReveal(
                    wasKeyboardVisible: wasKeyboardVisible,
                    isKeyboardVisible: isKeyboardVisible
                ) {
                    requestAutomaticReveal()
                }
            }
            .onReceive(NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillHideNotification
            )) { _ in
                pendingTask?.cancel()
                lastRequest = nil
                automaticRevealRequested = false
                keyboardFrame = .null
                updateKeyboardGestureLock(isKeyboardVisible: false)
            }
    }

    private func updateKeyboardGestureLock(isKeyboardVisible: Bool? = nil) {
        let keyboardIsVisible = isKeyboardVisible
            ?? BeckonKeyboardPresentationPolicy.keyboardIsOnScreen(
                keyboardFrame: keyboardFrame,
                screenBounds: beckonActiveScreenBounds
            )
        preventsSheetDismissal =
            BeckonKeyboardPresentationPolicy.shouldRetainKeyboardGestureLock(
                isKeyboardVisible: keyboardIsVisible,
                scrollPhase: scrollPhase,
                wasLocked: preventsSheetDismissal
            )
    }

    private func requestAutomaticReveal() {
        automaticRevealRequested = true
        scheduleRequestedReveal()
    }

    private func receiveFocusMeasurement(_ measurement: BeckonKeyboardFocusMeasurement) {
        guard measurement.target == focusedTarget,
              measurement != focusMeasurement else {
            return
        }
        focusMeasurement = measurement
        scheduleRequestedReveal()
    }

    private func scheduleRequestedReveal() {
        pendingTask?.cancel()
        guard automaticRevealRequested,
              let target = focusedTarget,
              let measurement = focusMeasurement,
              measurement.target == target,
              viewportFrame != .zero else {
            return
        }
        let targetFrame = measurement.frame

        let layout = BeckonKeyboardFormLayout(
            containerFrame: viewportFrame,
            keyboardFrame: keyboardFrame
        )
        let clearance = DesignTokens.Layout.fieldSpacing
        let action = layout.revealAction(for: targetFrame, clearance: clearance)
        guard action != .none,
              let anchor = layout.scrollAnchor(for: action, clearance: clearance) else {
            automaticRevealRequested = false
            lastRequest = nil
            return
        }

        let request = BeckonKeyboardRevealRequest(
            target: target,
            action: action,
            targetFrame: targetFrame,
            keyboardFrame: keyboardFrame,
            viewportFrame: viewportFrame
        )
        guard request != lastRequest else { return }
        lastRequest = request

        pendingTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled, focusedTarget == target else { return }
            automaticRevealRequested = false
            let marker = BeckonKeyboardFocusTargetID(target)
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = !BeckonKeyboardRevealPolicy.animatesProgrammaticReveal
            withTransaction(transaction) {
                proxy.scrollTo(
                    action == .top ? marker.top : marker.bottom,
                    anchor: anchor
                )
            }
        }
    }
}

private struct BeckonKeyboardDoneAccessoryModifier: ViewModifier {
    @State private var isKeyboardVisible = false

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isKeyboardVisible {
                    BeckonKeyboardDoneAccessoryControl()
                }
            }
            .onReceive(NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillChangeFrameNotification
            )) { notification in
                guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey]
                    as? CGRect else { return }
                isKeyboardVisible = BeckonKeyboardPresentationPolicy.keyboardIsOnScreen(
                    keyboardFrame: frame,
                    screenBounds: beckonActiveScreenBounds
                )
            }
            .onReceive(NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillHideNotification
            )) { _ in
                isKeyboardVisible = false
            }
    }
}

private struct BeckonKeyboardDoneAccessoryControl: View {
    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            doneButton
        }
        .padding(.trailing, BeckonKeyboardDoneAccessoryPolicy.trailingInset)
        .padding(.bottom, BeckonKeyboardDoneAccessoryPolicy.keyboardGap)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var doneButton: some View {
        if #available(iOS 26.0, *) {
            button
                .glassEffect(.regular.interactive(), in: Circle())
        } else {
            button
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle()
                        .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
                        .accessibilityHidden(true)
                }
        }
    }

    private var button: some View {
        Button(action: dismissKeyboard) {
            Image(systemName: BeckonKeyboardDoneAccessoryPolicy.symbolName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(DesignTokens.Colors.customerAccentStrong)
                .frame(
                    width: BeckonKeyboardDoneAccessoryPolicy.controlDiameter,
                    height: BeckonKeyboardDoneAccessoryPolicy.controlDiameter
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Done")
        .accessibilityIdentifier("beckon.keyboard.done")
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

private struct BeckonStationaryPageActionModifier<Actions: View>: ViewModifier {
    let actions: Actions

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var keyboardFrame: CGRect = .null
    @State private var actionHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                actions
                    .onGeometryChange(for: CGFloat.self) { geometry in
                        geometry.size.height
                    } action: { height in
                        actionHeight = height
                    }
                    .offset(
                        y: BeckonKeyboardFormLayout(
                            containerFrame: beckonActiveScreenBounds,
                            keyboardFrame: keyboardFrame
                        ).stationaryPageActionOffset(actionHeight: actionHeight)
                    )
            }
            .onReceive(NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillChangeFrameNotification
            )) { notification in
                guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey]
                    as? CGRect else { return }
                updateKeyboardFrame(frame, from: notification)
            }
            .onReceive(NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillHideNotification
            )) { notification in
                updateKeyboardFrame(.null, from: notification)
            }
    }

    private func updateKeyboardFrame(_ frame: CGRect, from notification: Notification) {
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey]
            as? Double ?? 0.25
        if reduceMotion {
            keyboardFrame = frame
        } else {
            withAnimation(.easeOut(duration: duration)) {
                keyboardFrame = frame
            }
        }
    }
}

extension View {
    func beckonKeyboardFocusTarget(_ id: String) -> some View {
        modifier(BeckonKeyboardFocusTargetModifier(id: id))
    }

    func beckonKeyboardAvoidance(
        focusedTarget: String?,
        using proxy: ScrollViewProxy,
        additionallyPreventsPresentationDismissal: Bool = false
    ) -> some View {
        modifier(
            BeckonKeyboardAvoidanceModifier(
                focusedTarget: focusedTarget,
                proxy: proxy,
                additionallyPreventsPresentationDismissal:
                    additionallyPreventsPresentationDismissal
            )
        )
    }

    func beckonKeyboardDoneAccessory() -> some View {
        modifier(BeckonKeyboardDoneAccessoryModifier())
    }

    func beckonStationaryPageAction<Actions: View>(
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        modifier(BeckonStationaryPageActionModifier(actions: actions()))
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
            isInvalid ? DesignTokens.Colors.error : DesignTokens.Colors.customerAccentStrong
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
            .tint(isInvalid ? DesignTokens.Colors.error : DesignTokens.Colors.customerAccentStrong)
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

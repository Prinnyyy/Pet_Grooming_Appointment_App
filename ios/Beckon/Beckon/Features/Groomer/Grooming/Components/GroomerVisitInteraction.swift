import SwiftUI

@MainActor @Observable final class GroomerVisitNavigationPress {
    private(set) var amount: CGFloat = 0
    @ObservationIgnored private var reachedBottom = false
    @ObservationIgnored private var activation: (() -> Void)?
    @ObservationIgnored private var generation = 0

    func touch(_ down: Bool) {
        if down {
            depress()
        } else {
            // Native Button resolves a lift as a tap or scroll cancellation.
            let current = generation
            Task { @MainActor in
                await Task.yield()
                if generation == current && activation == nil { release() }
            }
        }
    }

    func activate(_ action: @escaping () -> Void) {
        guard activation == nil else { return }
        activation = action
        if reachedBottom { finish(); return }
        depress()
    }

    private func depress() {
        guard amount == 0 else { return }
        generation += 1
        let current = generation
        withAnimation(.easeOut(duration: 0.09), completionCriteria: .removed) {
            amount = 1
        } completion: {
            guard self.generation == current else { return }
            self.reachedBottom = true
            if self.activation != nil { self.finish() }
        }
    }

    private func finish() {
        let action = activation
        release()
        action?()
    }

    func release() {
        generation += 1
        activation = nil
        reachedBottom = false
        withAnimation(.easeOut(duration: 0.12)) { amount = 0 }
    }
}

extension EnvironmentValues {
    @Entry var groomerVisitNavigationPress: GroomerVisitNavigationPress? = nil
}

/// Start feedback on touch-down and overlap its release with the push.
/// Native Button still decides whether a finger lift is a tap or a cancelled scroll.
struct GroomerVisitNavigationButton<Content: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.isEnabled) private var isEnabled
    @State private var press = GroomerVisitNavigationPress()
    var body: some View {
        Button {
            guard isEnabled else { return }
            if reduceMotion || voiceOver { action(); return }
            press.activate(action)
        } label: { label() }
        .environment(\.groomerVisitNavigationPress, press)
        .onDisappear { press.release() }
        .onChange(of: isEnabled) { _, enabled in if !enabled { press.release() } }
    }
}

import UIKit

/// The existing Groomer motion tokens, applied only to the editable groomerVisit detail flow.
enum GroomerVisitDetailMotion {
    static func expansion(reduceMotion: Bool) -> Animation {
        reduceMotion ? DesignTokens.Motion.reduced : DesignTokens.Motion.swap
    }

    static func editorTransition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .offset(y: -DesignTokens.Spacing.sm))
    }
}

/// Keep the whole header tappable, but let only its arrow draw the existing press feedback.
struct GroomerVisitDisclosureButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? 1 : 0.4)
            .onChange(of: configuration.isPressed && isEnabled) { _, pressed in isPressed = pressed }
            .onDisappear { isPressed = false }
    }
}

/// A focus action must remain usable while the keyboard moves its containing card.
/// Only the keyboard symbol changes; no halo, tint or press scale.
struct GroomerVisitPriceKeyboardButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        BeckonPressCountingBody(configuration: configuration, style: GroomerVisitPriceKeyboardPressLook())
    }
}

private struct GroomerVisitPriceKeyboardPressLook: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(isEnabled ? 1 : 0.4)
    }
}

private struct GroomerVisitKeyboardInputRegions: PreferenceKey {
    static var defaultValue: [CGRect] { [] }
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) {
        value.append(contentsOf: nextValue())
    }
}

private struct GroomerVisitOutsideKeyboardDismissal: ViewModifier {
    let isEditing: Bool
    let dismiss: () -> Void
    @State private var inputRegions: [CGRect] = []

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onPreferenceChange(GroomerVisitKeyboardInputRegions.self) { inputRegions = $0 }
            .gesture(GroomerVisitOutsideInputTap(isEditing: isEditing, inputRegions: inputRegions, dismiss: dismiss))
    }
}

/// Classify a touch before the native field focuses and the keyboard scrolls the page.
/// Rechecking moving input frames at touch-up can dismiss the very tap that opened the field.
private struct GroomerVisitOutsideInputTap: UIGestureRecognizerRepresentable {
    let isEditing: Bool
    let inputRegions: [CGRect]
    let dismiss: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator(parent: self, converter: converter)
    }

    func makeUIGestureRecognizer(context: Context) -> UITapGestureRecognizer {
        let tap = UITapGestureRecognizer()
        tap.delegate = context.coordinator
        tap.cancelsTouchesInView = false
        tap.delaysTouchesBegan = false
        tap.delaysTouchesEnded = false
        return tap
    }

    func updateUIGestureRecognizer(_ recognizer: UITapGestureRecognizer, context: Context) {
        context.coordinator.parent = self
    }

    func handleUIGestureRecognizerAction(_ recognizer: UITapGestureRecognizer, context: Context) {
        if recognizer.state == .ended, isEditing { dismiss() }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: GroomerVisitOutsideInputTap
        let converter: CoordinateSpaceConverter

        init(parent: GroomerVisitOutsideInputTap, converter: CoordinateSpaceConverter) {
            self.parent = parent
            self.converter = converter
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard parent.isEditing, !parent.inputRegions.isEmpty else { return false }
            var view = touch.view
            while let candidate = view {
                if candidate is UITextField || candidate is UITextView { return false }
                view = candidate.superview
            }
            let location = converter.convert(globalPoint: touch.location(in: nil), to: .global)
            return !parent.inputRegions.contains(where: { $0.contains(location) })
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
    }
}

extension View {
    /// Input controls and focus-changing buttons keep their own tap handling.
    func groomerVisitKeyboardInputRegion() -> some View {
        background {
            GeometryReader { geometry in
                Color.clear.preference(key: GroomerVisitKeyboardInputRegions.self,
                    value: [geometry.frame(in: .global)])
            }
        }
    }

    func groomerVisitDismissKeyboardOnOutsideTap(isEditing: Bool, dismiss: @escaping () -> Void) -> some View {
        modifier(GroomerVisitOutsideKeyboardDismissal(isEditing: isEditing, dismiss: dismiss))
    }

    /// Comparison hosts suppress entrances for static inspection. This interactive flow opts back in.
    func groomerVisitDetailPresentation() -> some View {
        environment(\.groomerVisitAppearance, true)
            .environment(\.beckonRole, .groomer)
            .environment(\.beckonRevealsInPlace, false)
            .beckonEntranceRhythm(.detail)
            .beckonAllowsInteractiveBack()
    }
}

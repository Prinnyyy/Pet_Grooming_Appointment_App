// The form that answers a request with an offer (design, moved out of the request page in design): the service confirmations some
// requests ask for, a start in the service's own time zone, a duration, a price and a message. Its state (`GroomerOfferFormState`),
// its rules and every id are the real ones; the page owns the state and the one button that sends it, pinned to its foot.
import SwiftUI
import UIKit


nonisolated enum GroomerOfferFocusTarget: String, CaseIterable, Hashable {
    case duration = "groomer.offers.duration.container"
    case price = "groomer.offers.price.container"
    case message = "groomer.offers.message.container"
}

nonisolated enum GroomerOfferInputFocusPolicy {
    static func target(
        afterTapping tappedTarget: GroomerOfferFocusTarget,
        current: GroomerOfferFocusTarget?
    ) -> GroomerOfferFocusTarget {
        current == tappedTarget ? current ?? tappedTarget : tappedTarget
    }
}


struct GroomerOfferForm: View {
    let matched: GroomerMatchedRequest
    @Bindable var form: GroomerOfferFormState
    var focusedTarget: FocusState<GroomerOfferFocusTarget?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            Text(CustomerRequestMatchingCopy.groomerOfferGuidance).designSupportingText()

            ForEach((matched.match.eligibilityEvaluation?.confirmationKeys ?? []).sorted(), id: \.self) { key in
                Toggle(isOn: Binding(
                    get: { form.confirmedAssessmentKeys.contains(key) },
                    set: { confirmed in
                        if confirmed { form.confirmedAssessmentKeys.insert(key) } else { form.confirmedAssessmentKeys.remove(key) }
                    }
                )) {
                    Text(assessmentConfirmationTitle(key)).designSupportingText()
                }
                .tint(DesignTokens.Colors.customerDeep)
                .accessibilityIdentifier("groomer.offers.confirmation.\(key)")
            }

            startField

            field("Duration") {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Picker("Hours", selection: Binding(get: { form.durationHours }, set: { form.durationHours = $0 })) {
                        ForEach(0...12, id: \.self) { Text("\($0) hr").tag($0) }
                    }
                    .accessibilityIdentifier("groomer.offers.duration.hours")
                    Picker("Minutes", selection: Binding(get: { form.durationMinutePart }, set: { form.durationMinutePart = $0 })) {
                        ForEach(form.availableDurationMinutes, id: \.self) { Text("\($0) min").tag($0) }
                    }
                    .accessibilityIdentifier("groomer.offers.duration.minutes")
                }
                .pickerStyle(.wheel)
                .frame(height: 150)
                .accessibilityIdentifier("groomer.offers.duration")
            }

            if let proposedEnd = form.proposedEnd, let zone = form.serviceTimeZone {
                DesignValueRow(title: "Proposed end", value: GroomingRequestDateFormatting.displayString(
                    from: GroomingRequestDateFormatting.serverString(from: proposedEnd), serviceTimeZoneIdentifier: zone.identifier),
                    systemImage: "clock")
                    .accessibilityIdentifier("groomer.offers.proposed-end")
            }

            textField("Price estimate", text: $form.priceEstimateText, target: .price, keyboard: .decimalPad)
            textField("Message", text: $form.message, target: .message, multiline: true)
        }
        .designCardBody()
    }

    /// The start is a wall-clock time in the service's own time zone; until the zone is known the field says so and waits.
    @ViewBuilder
    private var startField: some View {
        if let zone = form.serviceTimeZone {
            field("Proposed start") {
                DatePicker("Proposed start", selection: Binding(get: { form.proposedStart }, set: {
                    form.proposedStart = $0
                    form.selectedOccurrence = nil
                }), displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .tint(DesignTokens.Colors.customerDeep)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.timeZone, TimeZone(secondsFromGMT: 0)!)
                    .environment(\.calendar, Calendar(identifier: .gregorian))
                    .accessibilityIdentifier("groomer.offers.start-input")
            }
            DesignValueRow(title: "Service time zone", value: zone.identifier, systemImage: "globe")
                .accessibilityIdentifier("groomer.offers.service-time-zone")
            if case let .ambiguous(first, last) = form.proposedStartResolution {
                Picker("Start occurrence", selection: $form.selectedOccurrence) {
                    Text("Choose occurrence").tag(Optional<Date>.none)
                    ForEach([first, last], id: \.self) { date in
                        Text(date.formatted(Date.FormatStyle(timeZone: zone).hour().minute().timeZone(.iso8601(.short))))
                            .tag(Optional(date))
                    }
                }
                .tint(DesignTokens.Colors.customerDeep)
                .accessibilityIdentifier("groomer.offers.start-occurrence")
            }
            if form.proposedStartResolution == .nonexistent {
                DesignInfoLine(systemImage: "exclamationmark.triangle.fill",
                    text: "This local time does not exist. Choose another start time.")
                    .accessibilityIdentifier("groomer.offers.nonexistent-start")
            }
        } else if form.isLoadingTimeZone || !form.didInitializeOfferForm {
            field("Proposed start") {
                DesignSkeletonLine(width: 0.6).designSkeleton(label: "Loading service time zone")
            }
            .accessibilityIdentifier("groomer.offers.time-zone-loading")
        } else if matched.request.locationMode == .groomerComesToCustomer {
            DesignInfoLine(systemImage: "exclamationmark.triangle.fill",
                text: "This request has no confirmed service time zone. The customer needs to publish a new request with a confirmed address.")
                .accessibilityIdentifier("groomer.offers.request-time-zone-missing")
        } else {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                DesignInfoLine(systemImage: "exclamationmark.triangle.fill",
                    text: form.timeZoneError ?? "Confirm the service address time zone before making an offer.")
                Button { Task { await form.loadServiceTimeZone(for: matched) } } label: {
                    DesignQuietAction(title: "Retry", systemImage: "arrow.clockwise")
                }
                .buttonStyle(BeckonGuardedPlainButtonStyle())
                .disabled(form.isInitializingOfferForm)
                .accessibilityIdentifier("groomer.offers.time-zone-retry")
            }
        }
    }

    private func assessmentConfirmationTitle(_ key: String) -> String {
        switch key {
        case "pet_size": "I have assessed this pet's size and can provide the quoted service."
        case "pet_coat": "I have assessed the coat and included its care in this quote."
        case "pet_matting": "I have assessed possible matting and included its care in this quote."
        case "custom_service": "I have reviewed the custom request and included its scope in this quote."
        default: "Unsupported service confirmation"
        }
    }

    // MARK: Fields

    /// A caption over what the groomer types or picks.
    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .font(DesignTokens.Typography.Expressive.label)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
            content()
        }
    }

    private func textField(_ title: String, text: Binding<String>, target: GroomerOfferFocusTarget,
                           keyboard: UIKeyboardType = .default, multiline: Bool = false) -> some View {
        field(title) {
            TextField(title, text: text, axis: multiline ? .vertical : .horizontal)
                .focused(focusedTarget, equals: target)
                .keyboardType(keyboard)
                .lineLimit(multiline ? 3...6 : 1...1)
                .beckonFormField()
                .tint(DesignTokens.Colors.customerDeep)
                .accessibilityIdentifier(identifier(for: target))
        }
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded {
            focusedTarget.wrappedValue = GroomerOfferInputFocusPolicy.target(afterTapping: target, current: focusedTarget.wrappedValue)
        })
        .beckonKeyboardFocusTarget(target.rawValue)
    }

    private func identifier(for target: GroomerOfferFocusTarget) -> String {
        switch target {
        case .duration: "groomer.offers.duration"
        case .price: "groomer.offers.price"
        case .message: "groomer.offers.message"
        }
    }
}

import SwiftUI

struct GroomerVisitRequestOfferForm: View {
    let matched: GroomerMatchedRequest
    @Bindable var form: GroomerOfferFormState
    // Both editors are UIKit controls. Their delegates own focus; SwiftUI only stores the target.
    var focusedTarget: Binding<GroomerOfferFocusTarget?>

    let startError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            startField
            if let startError {
                GroomerVisitRequestInfoLine(systemImage: "clock.badge.exclamationmark", text: startError)
                    .accessibilityIdentifier("groomerVisit.request.offer.start-error")
            }

            durationField
            endField
            priceField
            messageField
        }
        .designCardBody()
    }

    var durationField: some View { durationField(wheelHeight: 150) }

    func durationField(wheelHeight: CGFloat, holdingFinish: Bool = false) -> some View {
        field("Duration") {
            durationWheels(height: wheelHeight, holdingFinish: holdingFinish)
        }
    }

    func durationWheels(height: CGFloat, holdingFinish: Bool = false) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Picker("Hours", selection: Binding(get: { form.durationHours }, set: { hours in
                form.changeVisitDuration(holdingFinish: holdingFinish) { form.durationHours = hours }
            })) {
                ForEach(0...12, id: \.self) { Text("\($0) hr").tag($0) }
            }
            .accessibilityIdentifier("groomer.offers.duration.hours")
            Picker("Minutes", selection: Binding(get: { form.durationMinutePart }, set: { minutes in
                form.changeVisitDuration(holdingFinish: holdingFinish) { form.durationMinutePart = minutes }
            })) {
                ForEach(form.availableDurationMinutes, id: \.self) { Text("\($0) min").tag($0) }
            }
            .accessibilityIdentifier("groomer.offers.duration.minutes")
        }
        .pickerStyle(.wheel)
        .frame(height: height)
        .clipped().contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("groomer.offers.duration")
    }

    @ViewBuilder var endField: some View {
        if let proposedEnd = form.proposedEnd, let zone = form.serviceTimeZone {
            DesignValueRow(title: "Proposed end", value: GroomingRequestDateFormatting.displayString(
                from: GroomingRequestDateFormatting.serverString(from: proposedEnd), serviceTimeZoneIdentifier: zone.identifier),
                systemImage: "clock")
                .accessibilityIdentifier("groomer.offers.proposed-end")
        }
    }

    var priceField: some View {
        field("Price estimate") {
            GroomerVisitOfferPriceInput(text: $form.priceEstimateText, focusedTarget: focusedTarget)
                .beckonFormField()
                .accessibilityIdentifier(identifier(for: .price))
                .groomerVisitKeyboardInputRegion()
        }
        .beckonKeyboardFocusTarget(GroomerOfferFocusTarget.price.rawValue)
    }

    var messageField: some View {
        field("Message (optional)") { messageEditor(expressive: false) }
            .beckonKeyboardFocusTarget(GroomerOfferFocusTarget.message.rawValue)
    }

    var messageInput: some View {
        messageEditor(expressive: true)
            .beckonKeyboardFocusTarget(GroomerOfferFocusTarget.message.rawValue)
    }

    private func messageEditor(expressive: Bool) -> some View {
        GroomerVisitOfferMessageInput(text: $form.message, focusedTarget: focusedTarget, expressive: expressive)
            .beckonFormField()
            .accessibilityIdentifier(identifier(for: .message))
            .groomerVisitKeyboardInputRegion()
    }

    /// The start is a wall-clock time in the service's own time zone; until the zone is known the field says so and waits.
    @ViewBuilder
    var startField: some View {
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
                GroomerVisitRequestInfoLine(systemImage: "exclamationmark.triangle.fill",
                    text: "This local time does not exist. Choose another start time.")
                    .accessibilityIdentifier("groomer.offers.nonexistent-start")
            }
        } else if form.isLoadingTimeZone || !form.didInitializeOfferForm {
            field("Proposed start") {
                DesignSkeletonLine(width: 0.6).designSkeleton(label: "Loading service time zone")
            }
            .accessibilityIdentifier("groomer.offers.time-zone-loading")
        } else if matched.request.locationMode == .groomerComesToCustomer {
            GroomerVisitRequestInfoLine(systemImage: "exclamationmark.triangle.fill",
                text: "This request has no confirmed service time zone. The customer needs to publish a new request with a confirmed address.")
                .accessibilityIdentifier("groomer.offers.request-time-zone-missing")
        } else {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                GroomerVisitRequestInfoLine(systemImage: "exclamationmark.triangle.fill",
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

    private func identifier(for target: GroomerOfferFocusTarget) -> String {
        switch target {
        case .duration: "groomer.offers.duration"
        case .price: "groomer.offers.price"
        case .message: "groomer.offers.message"
        }
    }
}

extension GroomerOfferFormState {
    /// Start the local draft at the customer's original time, including when that time has passed.
    func initializeRequestDraft(for match: GroomerMatchedRequest) async {
        guard !didInitializeOfferForm else { return }
        await initializeOfferFormIfNeeded(for: match)
        guard !Task.isCancelled, didInitializeOfferForm,
              let earliest = GroomingRequestDateFormatting.parsedDate(from: match.request.preferredStart) else { return }
        setVisitStart(earliest)
    }

    /// All inline time controls propose an instant in the service calendar, including the two occurrences of a repeated hour.
    func setVisitStart(_ instant: Date) {
        guard let zone = serviceTimeZone,
              let wall = try? GroomingServiceTiming.wallInput(for: instant, timeZoneIdentifier: zone.identifier) else { return }
        proposedStart = wall
        if case let .ambiguous(first, last) = proposedStartResolution {
            selectedOccurrence = abs(first.timeIntervalSince(instant)) < 60 ? first : last
        } else { selectedOccurrence = nil }
    }

    func changeVisitDuration(holdingFinish: Bool, _ edit: () -> Void) {
        let finish = holdingFinish ? proposedEnd : nil
        edit()
        if let finish, let minutes = Int(durationMinutesText) {
            setVisitStart(finish.addingTimeInterval(-Double(minutes) * 60))
        }
    }
}

struct GroomerVisitOfferStartError: LocalizedError {
    var errorDescription: String? { "Choose a start at least 5 minutes from now." }
}

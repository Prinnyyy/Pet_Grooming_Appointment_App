// Step 3 of the request wizard, "Time & place" (page map section 12): a When card above a Where card (S-043).
// The time comes first because it is the quick decision that changes from request to request; the address is the long form
// most people reuse. The request's time zone is read from the confirmed address, so until the address is confirmed the day
// and the time are chosen in the device's zone, and the wizard re-reads the choice in the address's zone when it confirms.
import SwiftUI


// MARK: When

/// Which day, which part of the day, and what the groomers will be told. Same state and actions as the old time block
/// (`flow.selectedDate`, `selectedTimeWindow`, `isFlexibleWithTime`, `store.preferredStart/End`).
struct CustomerRequestWhenSection: View {
    @Bindable var store: CustomerRequestsStore
    let flow: CustomerRequestWizardState
    @Environment(\.dynamicTypeSize) private var typeSize

    /// The address's calendar once it is confirmed, the device's until then.
    private var calendar: Calendar { store.requestCalendar ?? .current }
    private var isConfirmedZone: Bool { store.requestCalendar != nil }
    private var isExact: Bool { flow.selectedTimeWindow == .detailed && !flow.isFlexibleWithTime }

    var body: some View {
        DesignSection(title: "When", systemImage: "calendar", spacing: DesignTokens.Spacing.lg) {
            CustomerRequestDayStrip(selectedDate: flow.selectedDate, calendar: calendar, onSelect: selectDate)
            timeOfDay
            otherWays
            if isExact {
                CustomerRequestExactTimeFields(
                    preferredStart: $store.preferredStart,
                    preferredEnd: $store.preferredEnd,
                    isInvalid: flow.invalidFields.contains(.timeWindow)
                )
                .onChange(of: store.preferredStart) { _, _ in flow.clearInvalidField(.timeWindow) }
                .onChange(of: store.preferredEnd) { _, _ in flow.clearInvalidField(.timeWindow) }
                .transition(.opacity.combined(with: .move(edge: .top)))
                occurrencePicker(isStart: true)
                occurrencePicker(isStart: false)
            }
            CustomerRequestWhenSummary(
                range: summaryRange,
                calendar: calendar,
                isFlexible: flow.isFlexibleWithTime,
                isInvalid: flow.invalidFields.contains(.timeWindow)
            )
        }
        .environment(\.calendar, calendar)
        .environment(\.timeZone, calendar.timeZone)
        .beckonAnimation(DesignTokens.Motion.swap, value: isExact)
    }

    // MARK: Choices

    private var timeOfDay: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            let layout = CustomerRequestWizardProgressLayout(dynamicTypeSize: typeSize).usesSingleColumnChoices
                ? AnyLayout(VStackLayout(spacing: DesignTokens.Spacing.sm))
                : AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.sm))
            layout {
                ForEach([CustomerRequestTimeWindowOption.morning, .afternoon, .evening]) { option in
                    CustomerRequestTimeOfDayTile(
                        option: option,
                        hours: Self.hours(of: option, calendar: calendar),
                        isSelected: flow.selectedTimeWindow == option && !flow.isFlexibleWithTime
                    ) { selectWindow(option) }
                }
            }
        }
    }

    /// The two choices that are not a part of the day: exact times, or any time. One choice with the three tiles above, as before
    /// (choosing a window turns flexible off; flexible greys the windows).
    private var otherWays: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: DesignTokens.Spacing.sm))
            : AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.sm))
        return layout {
            CustomerRequestTimeModeTile(
                title: CustomerRequestTimeWindowOption.detailed.title, systemImage: "clock", isSelected: isExact
            ) { selectWindow(.detailed) }
            CustomerRequestTimeModeTile(
                title: "I'm flexible with time", systemImage: "clock.arrow.2.circlepath", isSelected: flow.isFlexibleWithTime
            ) { toggleFlexible() }
        }
    }

    @ViewBuilder
    private func occurrencePicker(isStart: Bool) -> some View {
        let choices = isStart ? store.preferredStartOccurrences : store.preferredEndOccurrences
        if choices.count == 2 {
            Picker(isStart ? "Start Occurrence" : "End Occurrence", selection: Binding<Date?>(
                get: { store.confirmedPreferredOccurrence(isStart: isStart) },
                set: { if let date = $0 { store.confirmPreferredOccurrence(date, isStart: isStart) } }
            )) {
                Text("Choose occurrence").tag(Optional<Date>.none)
                ForEach(choices, id: \.self) { date in
                    Text(CustomerRequestDayFormat.string(date, "h:mm a XXX", calendar: calendar)).tag(Optional(date))
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier(isStart ? "customer.requests.start-occurrence" : "customer.requests.end-occurrence")
        }
    }

    // MARK: Actions

    private func selectDate(_ date: Date) {
        flow.selectedDate = date
        flow.clearInvalidField(.timeWindow)
        flow.applySelectedTimeWindow()
    }

    private func selectWindow(_ option: CustomerRequestTimeWindowOption) {
        flow.selectedTimeWindow = option
        flow.isFlexibleWithTime = false
        flow.clearInvalidField(.timeWindow)
        flow.applySelectedTimeWindow()
    }

    private func toggleFlexible() {
        flow.isFlexibleWithTime.toggle()
        flow.clearInvalidField(.timeWindow)
        flow.applySelectedTimeWindow()
    }

    // MARK: What it says

    /// What the groomers will be told. With the address's zone it is what will be published; before that it is read from the
    /// choice in the device's zone.
    private var summaryRange: (start: Date, end: Date)? {
        if isConfirmedZone { return store.remainingPreferredRange(now: Date()) }
        if flow.isFlexibleWithTime {
            return CustomerRequestTimeWindowOption.flexibleRange(on: flow.selectedDate, calendar: calendar)
        }
        return flow.selectedTimeWindow.range(on: flow.selectedDate, calendar: calendar) ?? (store.preferredStart, store.preferredEnd)
    }

    /// "6 AM–12 PM", "12–5 PM", "5–9 PM": read from the same ranges the request is built from.
    private static func hours(of option: CustomerRequestTimeWindowOption, calendar: Calendar) -> String {
        guard let range = option.range(on: Date(), calendar: calendar) else { return "" }
        let endsAtMinuteBefore = calendar.component(.minute, from: range.end) == 59
        let startHour = calendar.component(.hour, from: range.start)
        let endHour = calendar.component(.hour, from: endsAtMinuteBefore ? range.end.addingTimeInterval(60) : range.end)
        func clock(_ hour: Int) -> Int { hour % 12 == 0 ? 12 : hour % 12 }
        func period(_ hour: Int) -> String { hour % 24 < 12 ? "AM" : "PM" }
        return period(startHour) == period(endHour)
            ? "\(clock(startHour))–\(clock(endHour)) \(period(endHour))"
            : "\(clock(startHour)) \(period(startHour))–\(clock(endHour)) \(period(endHour))"
    }
}


/// Seven days in a row, and a calendar behind "More dates". A date outside the seven shows on the chip.
private struct CustomerRequestDayStrip: View {
    let selectedDate: Date
    let calendar: Calendar
    let onSelect: (Date) -> Void
    @State private var showsCalendar = false
    @Environment(\.dynamicTypeSize) private var typeSize

    private var selection: CustomerRequestDateSelection { CustomerRequestDateSelection(calendar: calendar) }
    private var isOutsideStrip: Bool { !selection.isQuickDate(selectedDate) }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.sm))
                : AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.sm))
            layout {
                Text(monthTitle)
                    .font(DesignTokens.Typography.Expressive.label)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !typeSize.isAccessibilitySize { Spacer(minLength: DesignTokens.Spacing.sm) }
                DesignChoiceChip(
                    title: isOutsideStrip ? CustomerRequestDayFormat.string(selectedDate, "MMM d", calendar: calendar) : "More dates",
                    systemImage: "calendar",
                    isSelected: isOutsideStrip || showsCalendar
                ) { showsCalendar.toggle() }
                .accessibilityIdentifier("customer.requests.wizard.more-dates")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    ForEach(Array(selection.quickDates.enumerated()), id: \.offset) { index, date in
                        CustomerRequestDayTile(
                            date: date, calendar: calendar, isToday: index == 0,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate)
                        ) { onSelect(date) }
                    }
                }
            }
            .beckonTracksScroll()

            if showsCalendar {
                DatePicker(
                    "Choose Another Date",
                    selection: Binding(
                        get: { selectedDate },
                        set: {
                            onSelect(selection.normalized($0))
                            showsCalendar = false
                        }
                    ),
                    in: selection.minimumDate...,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(DesignTokens.Colors.customerDeep)
                .accessibilityIdentifier("customer.requests.wizard.date-picker")
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .beckonAnimation(DesignTokens.Motion.swap, value: showsCalendar)
    }

    /// "October", or "Oct – Nov" when the seven days cross a month.
    private var monthTitle: String {
        guard let first = selection.quickDates.first, let last = selection.quickDates.last else { return "Day" }
        let firstMonth = CustomerRequestDayFormat.string(first, "MMMM", calendar: calendar)
        let lastMonth = CustomerRequestDayFormat.string(last, "MMMM", calendar: calendar)
        if firstMonth == lastMonth { return firstMonth }
        return "\(CustomerRequestDayFormat.string(first, "MMM", calendar: calendar)) – \(CustomerRequestDayFormat.string(last, "MMM", calendar: calendar))"
    }
}


private struct CustomerRequestDayTile: View {
    let date: Date
    let calendar: Calendar
    let isToday: Bool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignTokens.Spacing.xs) {
                Text(isToday ? "Today" : CustomerRequestDayFormat.string(date, "EEE", calendar: calendar))
                    .font(DesignTokens.Typography.Expressive.chip)
                Text(CustomerRequestDayFormat.string(date, "d", calendar: calendar))
                    .font(DesignTokens.Typography.Expressive.title)
            }
            .foregroundStyle(isSelected ? DesignTokens.Colors.customerInk : DesignTokens.Colors.textPrimary)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .frame(minWidth: 58, minHeight: 68)
        }
        .buttonStyle(BeckonLedgeButtonStyle(isSelected ? .pill : .card))
        .accessibilityLabel(CustomerRequestDayFormat.string(date, "EEEE, MMMM d", calendar: calendar))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}


private struct CustomerRequestTimeOfDayTile: View {
    let option: CustomerRequestTimeWindowOption
    let hours: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: symbol)
                    .font(DesignTokens.Typography.Expressive.glyph)
                    .accessibilityHidden(true)
                Text(option.title)
                    .font(DesignTokens.Typography.Expressive.emphasis)
                Text(hours)
                    .font(DesignTokens.Typography.Expressive.chip)
                    .foregroundStyle(isSelected ? DesignTokens.Colors.customerInk : DesignTokens.Colors.textSecondary)
            }
            .foregroundStyle(isSelected ? DesignTokens.Colors.customerInk : DesignTokens.Colors.textPrimary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, DesignTokens.Spacing.xs)
            .padding(.vertical, DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 88)
        }
        .buttonStyle(BeckonLedgeButtonStyle(isSelected ? .pill : .card))
        .accessibilityLabel("\(option.title), \(hours)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var symbol: String {
        switch option {
        case .morning: "sunrise.fill"
        case .afternoon: "sun.max.fill"
        case .evening: "moon.stars.fill"
        case .detailed: "clock"
        }
    }
}


/// "Detailed Time" and "I'm flexible with time": the two ways to say a time that is not a part of the day.
private struct CustomerRequestTimeModeTile: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: systemImage)
                    .font(DesignTokens.Typography.Expressive.label)
                    .accessibilityHidden(true)
                Text(title)
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(isSelected ? DesignTokens.Colors.customerInk : DesignTokens.Colors.textSecondary)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.minimumTouchTarget + DesignTokens.Spacing.sm)
        }
        .buttonStyle(BeckonLedgeButtonStyle(isSelected ? .pill : .card))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}


/// From and to, side by side (stacked at accessibility sizes). The pickers keep their labels for VoiceOver and their ids.
private struct CustomerRequestExactTimeFields: View {
    @Binding var preferredStart: Date
    @Binding var preferredEnd: Date
    let isInvalid: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.md))
            : AnyLayout(HStackLayout(alignment: .top, spacing: DesignTokens.Spacing.md))
        layout {
            field("From", label: "Start Time", selection: $preferredStart, identifier: "customer.requests.start-time")
            field("To", label: "End Time", selection: $preferredEnd, identifier: "customer.requests.end-time")
        }
    }

    private func field(_ caption: String, label: String, selection: Binding<Date>, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(caption)
                .font(DesignTokens.Typography.Expressive.label)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .accessibilityHidden(true)
            DatePicker(label, selection: selection, displayedComponents: [.hourAndMinute])
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                .beckonFormField(isInvalid: isInvalid)
                .accessibilityLabel(label)
                .accessibilityIdentifier(identifier)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}


/// The sentence the groomers will read. It carries a second line only when the time cannot be used; the zone note that used to sit
/// under it is gone (the zone comes from the address, and the time is shown in it).
private struct CustomerRequestWhenSummary: View {
    let range: (start: Date, end: Date)?
    let calendar: Calendar
    let isFlexible: Bool
    let isInvalid: Bool

    @Environment(\.dynamicTypeSize) private var typeSize

    private var isProblem: Bool { isInvalid || range == nil }

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            // The words get the whole width at accessibility sizes.
            if !typeSize.isAccessibilitySize {
                DesignIconDisc(systemImage: isProblem ? "exclamationmark.triangle.fill" : "calendar.badge.checkmark",
                    tone: isProblem ? .caution : .customer)
            }
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(headline)
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                if isInvalid {
                    Text("Choose a time that hasn't passed.")
                        .font(DesignTokens.Typography.Expressive.chip)
                        .foregroundStyle(DesignTokens.Colors.statusErrorText)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isProblem ? DesignTokens.Colors.statusErrorFill : DesignTokens.Colors.customerTint,
            in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("customer.requests.wizard.when-summary")
    }

    private var headline: String {
        guard let range else { return "No time chosen" }
        if isFlexible {
            return "\(CustomerRequestDayFormat.string(range.start, "EEE, MMM d", calendar: calendar)) · Any time"
        }
        // The windows end one minute before the hour (4:59 PM); people read them as 5:00 PM.
        let end = calendar.component(.minute, from: range.end) == 59 ? range.end.addingTimeInterval(60) : range.end
        return BeckonDateTimeFormatter.interval(from: range.start, to: end,
            serviceTimeZoneIdentifier: calendar.timeZone.identifier).text
    }

}


// MARK: Where

/// How the service happens and the address it needs. The address is one line once it is confirmed, the full form until then.
struct CustomerRequestWhereSection: View {
    @Bindable var store: CustomerRequestsStore
    let flow: CustomerRequestWizardState
    let useProfileAddress: () -> Void
    let onFieldFocused: (String) -> Void
    @State private var isChangingAddress = false

    private var state: BeckonAddressEditorState { store.addressEditorState }
    private var showsSummary: Bool { store.requestCalendar != nil && state.status == .confirmed && !isChangingAddress }
    private var travels: Bool { store.locationMode == .customerComesToGroomer }

    var body: some View {
        DesignSection(title: "Where", systemImage: "mappin.and.ellipse", spacing: DesignTokens.Spacing.lg) {
            BeckonGroomingLocationModeSelector(
                selection: [store.locationMode],
                selectionPolicy: .single,
                perspective: .customer,
                accent: .customer,
                showsSentence: false
            ) { selection in
                if let mode = selection.first { store.locationMode = mode }
            }

            BeckonGroupedDivider(leadingInset: 0)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                addressHeading
                if showsSummary {
                    CustomerRequestAddressSummary(input: state.input) { isChangingAddress = true }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    profileButton
                    BeckonAddressEditor(
                        state: state,
                        isStateInvalid: flow.invalidFields.contains(.state),
                        showsVerificationAction: false,
                        onFieldFocused: onFieldFocused
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            if travels {
                BeckonGroupedDivider(leadingInset: 0)
                CustomerRequestTravelRangeControl(miles: $store.travelRadiusMiles)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .beckonAnimation(DesignTokens.Motion.swap, value: showsSummary)
        .beckonAnimation(DesignTokens.Motion.swap, value: travels)
        .onChange(of: state.status) { _, status in
            guard status == .confirmed else { return }
            isChangingAddress = false
            for field: CustomerRequestWizardValidationField in [.streetAddress, .city, .state, .zipCode, .addressConfirmation] {
                flow.clearInvalidField(field)
            }
        }
    }

    private var addressHeading: some View {
        Text(travels ? "Your location" : "Service address")
            .font(DesignTokens.Typography.Expressive.emphasis)
            .foregroundStyle(DesignTokens.Colors.textPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    private var profileButton: some View {
        Button(action: useProfileAddress) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                if flow.isApplyingProfileAddress {
                    ProgressView().tint(DesignTokens.Colors.customerDeep)
                } else {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                }
                Text(flow.isApplyingProfileAddress ? "Loading Profile Address..." : "Use Profile Address")
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .font(DesignTokens.Typography.Expressive.emphasis)
            .foregroundStyle(DesignTokens.Colors.customerDeep)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.minimumTouchTarget + DesignTokens.Spacing.sm,
                alignment: .leading)
        }
        .buttonStyle(BeckonLedgeButtonStyle(.card))
        .disabled(flow.isApplyingProfileAddress)
        .accessibilityIdentifier("customer.requests.use-profile-address")
    }
}


/// A confirmed address as two lines, with a way back into the form. The seal says it was confirmed; the "Confirmed with Apple Maps"
/// line and the zone name are gone (S-066).
private struct CustomerRequestAddressSummary: View {
    let input: BeckonAddressInput
    let change: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.sm))
            : AnyLayout(HStackLayout(alignment: .top, spacing: DesignTokens.Spacing.md))
        layout {
            DesignIconDisc(systemImage: "checkmark.seal.fill")
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(streetLine)
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                Text(cityLine)
                    .designSupportingText()
            }
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
            .accessibilityValue("Confirmed")
            .accessibilityIdentifier(BeckonAddressEditorSelectors.status)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
            Button(action: change) {
                Text("Change")
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.customerDeep)
                    .frame(minWidth: DesignTokens.Metrics.minimumTouchTarget, minHeight: DesignTokens.Metrics.minimumTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(BeckonGuardedPlainButtonStyle())
            .accessibilityLabel("Change address")
            .accessibilityIdentifier("customer.requests.change-address")
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
                .strokeBorder(DesignTokens.Colors.border, lineWidth: DesignTokens.Ledge.edgeWidth)
        }
    }

    private var streetLine: String {
        [input.line1, input.line2]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private var cityLine: String {
        let stateAndZip = [input.stateCode?.rawValue ?? "", input.postalCode]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return [input.city, stateAndZip]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}


/// How far the customer can go to a groomer's place: the number, a stepper for one mile, a slider for the rest.
private struct CustomerRequestTravelRangeControl: View {
    @Binding var miles: Int
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.sm))
                : AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.md))
            layout {
                Text("Travel range")
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
                Text("\(miles) mi")
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.customerInk)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(DesignTokens.Colors.customerTint, in: Capsule())
                    .accessibilityHidden(true)
                Stepper("Travel range", value: $miles,
                    in: CustomerRequestTravelRange.minimumMiles...CustomerRequestTravelRange.maximumMiles)
                    .labelsHidden()
                    .fixedSize()
                    .accessibilityLabel("Travel range")
                    .accessibilityValue("\(miles) miles")
                    .accessibilityIdentifier("customer.requests.travel-range")
            }

            Slider(
                value: Binding(
                    get: { Double(miles) },
                    set: { miles = CustomerRequestTravelRange.clampedMiles($0) }
                ),
                in: Double(CustomerRequestTravelRange.minimumMiles)...Double(CustomerRequestTravelRange.maximumMiles),
                step: 1
            )
            .tint(DesignTokens.Colors.customerDeep)
            .accessibilityLabel("Travel range")
        }
    }
}


// MARK: Formatting

private enum CustomerRequestDayFormat {
    static func string(_ date: Date, _ format: String, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}

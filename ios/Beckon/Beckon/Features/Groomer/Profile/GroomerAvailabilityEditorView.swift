// The groomer's availability, in the customer prototype's language (design). Same job as GroomerAvailabilityEditorView in
// Features/Groomer/Profile/GroomerAvailabilityEditorView.swift: the weekly hours (a day on or off, from when to when), the booking
// preferences (how many a day, how much notice, auto-ready) and time off (a list, and a sheet to add one). There are no timing
// buffers (design): the groomer picks each time in an offer and judges whether it fits, so this page asks for no estimate of
// preparation, cleanup or travel. The page keeps its edits until Save: leaving with edits asks first.
// The store, its edit tracking and every id are the real ones. What is new is the surface: one ledge card for the week, coral time
// chips that open a menu, and one pinned Save.
import SwiftUI


struct GroomerAvailabilityEditorView: View {
    @Bindable var store: GroomerProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingLeave = false

    var body: some View {
        let presentation = GroomerAvailabilityWorkspacePresentation(
            enabledDayCount: store.availabilityDayStates.filter(\.isEnabled).count,
            maxAppointmentsPerDay: store.maxAppointmentsPerDay,
            minimumAdvanceNoticeDays: store.minimumAdvanceNoticeDays,
            isSaving: store.isSaving,
            isBusy: store.isBusy
        )

        DesignPage {
            weeklyHours(presentation)
            preferences(presentation)
            timeOff
            // A failed save is the toast's (the status view below sends it, design): the card said the same thing a second time.
            GroomerBarClearance()
        }
        .disabled(store.isBusy)
        .navigationTitle("Availability")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .beckonAllowsInteractiveBack {
            guard !store.isBusy else { return false }
            if store.hasAvailabilityEdits { isConfirmingLeave = true; return false }
            return true
        }
        .beckonHidesTabBar()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if store.hasAvailabilityEdits { isConfirmingLeave = true } else { dismiss() }
                } label: {
                    Image(systemName: "chevron.left").foregroundStyle(DesignTokens.Colors.customerDeep)
                }
                .accessibilityLabel("Back")
                .accessibilityIdentifier("BackButton")
                .disabled(store.isSaving)
            }
        }
        .designAlertDialog(isPresented: $isConfirmingLeave) {
            .destructive(title: "Discard availability changes?", message: "What you changed here is not saved.",
                systemImage: "xmark.circle.fill", keepTitle: "Keep editing", confirmTitle: "Discard changes",
                confirmSystemImage: "xmark") {
                store.discardAvailabilityEdits()
                dismiss()
            }
        }
        .onAppear { store.isEditingAvailability = true }
        .onDisappear {
            store.isEditingAvailability = false
            store.discardAvailabilityEdits()
        }
        .background { GroomerProfileStatusView(store: store) }
        .beckonStationaryPageAction {
            GroomerSaveBar(title: "Save availability", isSaving: store.isSaving, isDisabled: presentation.isSaveDisabled,
                identifier: "groomer.availability.save") {
                Task { await store.saveAvailability() }
            }
        }
        .beckonSheet(isPresented: $store.isShowingTimeOffForm) {
            GroomerTimeOffFormView(store: store)
                .presentationDetents([.large])
                .designSheetStyle()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("groomer.availability.edit")
    }

    // MARK: Weekly hours

    private func weeklyHours(_ presentation: GroomerAvailabilityWorkspacePresentation) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            BeckonLedgeHeading(title: "Weekly hours", systemImage: "calendar")
            Text("\(presentation.openDaysSummary). Set the recurring hours when you can accept appointments.")
                .designSupportingText()
            VStack(spacing: 0) {
                ForEach($store.availabilityDayStates) { $dayState in
                    GroomerDayRow(dayState: $dayState)
                    if dayState.weekday != store.availabilityDayStates.last?.weekday { DesignRowDivider() }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity)
            .beckonLedge(.card)
        }
    }

    // MARK: Preferences

    private func preferences(_ presentation: GroomerAvailabilityWorkspacePresentation) -> some View {
        DesignSection(title: "Booking preferences", systemImage: "slider.horizontal.3", spacing: DesignTokens.Spacing.lg) {
            preferenceRow(title: "Daily capacity", subtitle: presentation.capacitySummary, value: "\(store.maxAppointmentsPerDay) / day",
                label: "Daily capacity") {
                ForEach(1...12, id: \.self) { capacity in
                    Button("\(capacity) per day") { store.maxAppointmentsPerDay = capacity }
                }
            }
            preferenceRow(title: "Advance notice", subtitle: presentation.advanceNoticeSummary,
                value: Self.noticeTitle(store.minimumAdvanceNoticeDays), label: "Advance notice") {
                ForEach(0...2, id: \.self) { days in
                    Button(Self.noticeTitle(days)) { store.minimumAdvanceNoticeDays = days }
                }
            }

        }
    }

    private func preferenceRow<Options: View>(title: String, subtitle: String, value: String, label: String,
                                              @ViewBuilder options: () -> Options) -> some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                Text(subtitle).designSupportingText()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Menu { options() } label: { GroomerChoiceChip(text: value) }
                .accessibilityLabel(label)
                .accessibilityValue(subtitle)
        }
    }

    private static func noticeTitle(_ days: Int) -> String {
        switch min(max(days, 0), 2) {
        case 0: "Same day"
        case 1: "1 day"
        default: "2 days"
        }
    }

    // MARK: Time off

    private var timeOff: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                BeckonLedgeHeading(title: "Time off", systemImage: "calendar.badge.minus", count: store.timeOffWindows.count)
                Button { store.startCreateTimeOff() } label: {
                    Image(systemName: "plus")
                        .font(DesignTokens.Typography.Expressive.glyph)
                        .foregroundStyle(DesignTokens.Colors.customerDeep)
                        .frame(width: DesignTokens.Metrics.minimumTouchTarget, height: DesignTokens.Metrics.minimumTouchTarget)
                        .beckonLedge(.round)
                }
                .buttonStyle(BeckonGuardedPlainButtonStyle())
                .accessibilityLabel("Add time off")
                .accessibilityIdentifier("groomer.availability.time-off.add")
                .disabled(store.isBusy)
            }
            Text("Block dates when you are unavailable for appointments.").designSupportingText()
            if store.timeOffWindows.isEmpty {
                BeckonLedgeNote(systemImage: "calendar.badge.minus", text: "No time off planned")
            } else {
                VStack(spacing: DesignTokens.Spacing.md) {
                    ForEach(store.timeOffWindows) { window in
                        GroomerTimeOffRow(window: window) { Task { await store.deleteTimeOff(window) } }
                    }
                }
            }
        }
    }
}


// MARK: Parts

/// A value in a pill that opens a menu (capacity, notice).
private struct GroomerChoiceChip: View {
    let text: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Text(text)
                .font(DesignTokens.Typography.Expressive.emphasis)
                .foregroundStyle(DesignTokens.Colors.customerDeep)
                .fixedSize(horizontal: false, vertical: true)
            Image(systemName: "chevron.up.chevron.down")
                .font(DesignTokens.Typography.Expressive.micro)
                .foregroundStyle(DesignTokens.Colors.customerDeep)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
        .background(DesignTokens.Colors.customerTint, in: Capsule())
    }
}


/// One day of the week: its name, from when to when (two chips that open menus) or "Unavailable", and the switch.
private struct GroomerDayRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var dayState: GroomerAvailabilityDayState

    var body: some View {
        (typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.sm))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DesignTokens.Spacing.md))) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Text(dayState.weekday.shortTitle)
                    .font(DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(dayState.isEnabled ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textSecondary)
                    .frame(minWidth: DesignTokens.Metrics.dayNameWidth, alignment: .leading)
                    .fixedSize()
                    .accessibilityHidden(true)
                if typeSize.isAccessibilitySize {
                    Spacer(minLength: 0)
                    toggle
                }
            }
            Group {
                if dayState.isEnabled {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        GroomerTimeChip(minutes: $dayState.startMinutes, title: "Start", day: dayState.weekday.title)
                        Text("to")
                            .font(DesignTokens.Typography.Expressive.chip)
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                        GroomerTimeChip(minutes: $dayState.endMinutes, title: "End", day: dayState.weekday.title)
                    }
                } else {
                    Text("Unavailable").designSupportingText()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !typeSize.isAccessibilitySize { toggle }
        }
        .frame(minHeight: DesignTokens.Metrics.dayRowHeight)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .animation(reduceMotion ? nil : DesignTokens.Motion.reveal, value: dayState.isEnabled)
    }

    private var toggle: some View {
        Toggle(dayState.weekday.title, isOn: $dayState.isEnabled)
            .labelsHidden()
            .tint(DesignTokens.Colors.customerDeep)
            .accessibilityIdentifier("groomer.availability.day.\(dayState.weekday.rawValue)")
    }
}


/// A time of day on a coral chip; it opens a menu of half hours from 6 AM to 10 PM.
struct GroomerTimeChip: View {
    @Binding var minutes: Int
    let title: String
    let day: String

    private static let options = Array(stride(from: 6 * 60, through: 22 * 60, by: 30))

    var body: some View {
        Menu {
            ForEach(Self.options, id: \.self) { option in
                Button(GroomerAvailabilityWindow.displayTime(fromMinutes: option)) { minutes = option }
            }
        } label: {
            Text(GroomerAvailabilityWindow.displayTime(fromMinutes: minutes))
                .font(DesignTokens.Typography.Expressive.label)
                .foregroundStyle(DesignTokens.Colors.customerDeep)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
                .background(DesignTokens.Colors.customerTint, in: Capsule())
        }
        .accessibilityLabel("\(day), \(title.lowercased()) time")
        .accessibilityValue(GroomerAvailabilityWindow.displayTime(fromMinutes: minutes))
        .accessibilityIdentifier("groomer.availability.\(day.lowercased()).\(title.lowercased())")
    }
}


/// One planned time off: its name and dates, and a way to remove it.
private struct GroomerTimeOffRow: View {
    let window: GroomerTimeOffWindow
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            DesignIconDisc(systemImage: "calendar", size: .touch, font: DesignTokens.Typography.Expressive.glyph)
            VStack(alignment: .leading, spacing: 2) {
                Text(window.title)
                    .font(DesignTokens.Typography.Expressive.headline)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .lineLimit(2)
                Text(window.dateSummary).designSupportingText()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(DesignTokens.Typography.Expressive.glyph)
                    .foregroundStyle(DesignTokens.Colors.statusErrorText)
                    .frame(width: DesignTokens.Metrics.minimumTouchTarget, height: DesignTokens.Metrics.minimumTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(BeckonGuardedPlainButtonStyle())
            .accessibilityLabel("Remove \(window.title)")
            .accessibilityIdentifier("groomer.availability.time-off.remove")
        }
        .padding(DesignTokens.Spacing.md)
        .beckonLedge(.card)
    }
}


// MARK: Time off form

/// Adding a time off, in a sheet: a name, the first day and the last, and the one pinned button.
private struct GroomerTimeOffFormView: View {
    @Bindable var store: GroomerProfileStore
    @FocusState private var focusedTarget: String?

    var body: some View {
        VStack(spacing: 0) {
            DesignSheetBar(title: "Add time off", closeIdentifier: "groomer.availability.time-off.cancel",
                isCloseDisabled: store.isSaving) { store.cancelTimeOffForm() }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionSpacing) {
                        DesignSection(title: "Time off", systemImage: "calendar.badge.minus", spacing: DesignTokens.Spacing.lg) {
                            Text("Add the dates you will not accept appointments.").designSupportingText()
                            GroomerTextField(title: "Title", text: $store.timeOffTitle, prompt: "Time off title",
                                focusTarget: GroomerTimeOffFocusTarget.title.rawValue, focusedTarget: $focusedTarget)
                            dateRow("Start date", selection: $store.timeOffStartDate)
                            dateRow("End date", selection: $store.timeOffEndDate)
                        }
                        if let message = store.actionErrorMessage {
                            BeckonErrorBanner(title: "Time off could not be saved", message: message)
                                .accessibilityIdentifier("groomer.availability.time-off.error")
                        }
                    }
                    .padding(.horizontal, DesignTokens.Layout.pageHorizontalInset)
                    .padding(.top, DesignTokens.Spacing.lg)
                    .padding(.bottom, DesignTokens.Layout.stationaryActionContentClearance)
                }
                .scrollContentBackground(.hidden)
                .beckonKeyboardAvoidance(focusedTarget: focusedTarget, using: proxy,
                    additionallyPreventsPresentationDismissal: store.isSaving)
            }
        }
        .background(BeckonExpressiveBackdrop())
        .beckonStationaryPageAction {
            GroomerSaveBar(title: "Add time off", busyTitle: "Saving…", isSaving: store.isSaving, isDisabled: store.isBusy,
                identifier: "groomer.availability.time-off.save") {
                Task { await store.createTimeOff() }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("groomer.availability.time-off.form")
    }

    private func dateRow(_ title: String, selection: Binding<Date>) -> some View {
        DatePicker(title, selection: selection, displayedComponents: .date)
            .font(DesignTokens.Typography.Expressive.emphasis)
            .tint(DesignTokens.Colors.customerDeep)
    }
}

nonisolated enum GroomerTimeOffFocusTarget: String, CaseIterable, Hashable {
    case title = "groomer.availability.time-off.title.container"
}

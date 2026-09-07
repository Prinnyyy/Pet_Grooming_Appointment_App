import SwiftUI

nonisolated enum GroomerTimeOffFocusTarget: String, CaseIterable, Hashable {
    case title = "groomer.availability.time-off.title.container"
}

struct GroomerAvailabilityEditorView: View {
    @Bindable var store: GroomerProfileStore
    @State private var isConfirmingReload = false
    @State private var isConfirmingLeave = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let presentation = GroomerAvailabilityWorkspacePresentation(
            enabledDayCount: store.availabilityDayStates.filter(\.isEnabled).count,
            maxAppointmentsPerDay: store.maxAppointmentsPerDay,
            minimumAdvanceNoticeDays: store.minimumAdvanceNoticeDays,
            isSaving: store.isSaving,
            isBusy: store.isBusy
        )

        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                GroomerAvailabilityWeeklyHoursSection(
                    dayStates: $store.availabilityDayStates,
                    openDaysSummary: presentation.openDaysSummary
                )

                GroomerBookingPreferencesSection(
                    maxAppointmentsPerDay: $store.maxAppointmentsPerDay,
                    minimumAdvanceNoticeDays: $store.minimumAdvanceNoticeDays,
                    autoAcceptBookings: $store.autoAcceptBookings
                )

                GroomerTimeOffSection(store: store)

                if let errorMessage = store.errorMessage {
                    BeckonErrorBanner(
                        title: "Availability Needs Attention",
                        message: errorMessage
                    )
                    .accessibilityIdentifier("groomer.availability.error")
                }
            }
            .disabled(store.isBusy)
            .beckonPageInsets()
        }
        .accessibilityIdentifier("groomer.availability.edit")
        .background(DesignTokens.Colors.background.ignoresSafeArea())
        .navigationTitle("Availability")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if store.hasAvailabilityEdits { isConfirmingLeave = true }
                    else { dismiss() }
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Back")
                .accessibilityIdentifier("BackButton")
                .disabled(store.isSaving)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isConfirmingReload = true
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Reload saved availability")
                .help("Reload saved availability")
                .disabled(store.isBusy)
            }
        }
        .confirmationDialog("Discard edits and reload saved availability?", isPresented: $isConfirmingReload) {
            Button("Reload", role: .destructive) {
                Task { await store.reloadAvailability() }
            }
        }
        .confirmationDialog("Discard availability changes?", isPresented: $isConfirmingLeave) {
            Button("Discard Changes", role: .destructive) {
                store.discardAvailabilityEdits()
                dismiss()
            }
        }
        .onAppear { store.isEditingAvailability = true }
        .onDisappear {
            store.isEditingAvailability = false
            store.discardAvailabilityEdits()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            GroomerAvailabilitySaveActionBar(
                presentation: presentation,
                save: saveAvailability
            )
        }
        .sheet(isPresented: $store.isShowingTimeOffForm) {
            GroomerTimeOffFormView(store: store)
                .presentationDetents([.medium])
        }
    }

    private func saveAvailability() {
        Task {
            await store.saveAvailability()
        }
    }
}

private struct GroomerAvailabilityMatchingSection: View {
    @Binding var isActive: Bool

    var body: some View {
        BeckonSection(
            "Request Matching",
            subtitle: "Use your saved hours when Beckon finds compatible requests."
        ) {
            BeckonGroupedSurface {
                HStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "checkmark.circle")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(
                            isActive
                                ? DesignTokens.Colors.success
                                : DesignTokens.Colors.textSecondary
                        )
                        .frame(width: 28)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Available for requests")
                            .font(DesignTokens.Typography.body.weight(.semibold))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        Text("Use your enabled hours for request matching.")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Toggle("Available for requests", isOn: $isActive)
                        .labelsHidden()
                        .tint(DesignTokens.Colors.groomerAccent)
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, DesignTokens.Spacing.md)
            }
        }
    }
}

private struct GroomerAvailabilityWeeklyHoursSection: View {
    @Binding var dayStates: [GroomerAvailabilityDayState]
    let openDaysSummary: String

    var body: some View {
        BeckonSection(
            "Weekly Hours",
            subtitle: "Set the recurring hours when you can accept appointments."
        ) {
            BeckonGroupedSurface {
                VStack(spacing: 0) {
                    ForEach($dayStates) { $dayState in
                        GroomerAvailabilityDayRow(dayState: $dayState)

                        if dayState.weekday != dayStates.last?.weekday {
                            BeckonGroupedDivider(leadingInset: 58)
                        }
                    }
                }
            }
        } trailing: {
                Text(openDaysSummary)
                    .font(DesignTokens.Typography.status)
                    .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
        }
    }
}

private struct GroomerAvailabilityDayRow: View {
    @Binding var dayState: GroomerAvailabilityDayState

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Text(dayState.weekday.shortTitle)
                .font(DesignTokens.Typography.body.weight(.semibold))
                .foregroundStyle(
                    dayState.isEnabled
                        ? DesignTokens.Colors.textPrimary
                        : DesignTokens.Colors.textSecondary
                )
                .frame(width: 38, alignment: .leading)

            if dayState.isEnabled {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    GroomerAvailabilityTimeMenu(minutes: $dayState.startMinutes)

                    Text("-")
                        .font(DesignTokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)

                    GroomerAvailabilityTimeMenu(minutes: $dayState.endMinutes)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Unavailable")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Toggle(dayState.weekday.title, isOn: $dayState.isEnabled)
                .labelsHidden()
                .tint(DesignTokens.Colors.groomerAccent)
        }
        .frame(minHeight: 64)
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .animation(.easeInOut(duration: 0.18), value: dayState.isEnabled)
    }
}

private struct GroomerAvailabilityTimeMenu: View {
    @Binding var minutes: Int

    var body: some View {
        Menu {
            ForEach(Self.timeOptions, id: \.self) { option in
                Button(GroomerAvailabilityWindow.displayTime(fromMinutes: option)) {
                    minutes = option
                }
            }
        } label: {
            Text(GroomerAvailabilityWindow.displayTime(fromMinutes: minutes))
                .font(DesignTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .frame(width: 70)
                .frame(minHeight: 36)
                .background(DesignTokens.Colors.borderSoft.opacity(0.48))
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: DesignTokens.CornerRadius.input,
                        style: .continuous
                    )
                )
        }
    }

    private static let timeOptions: [Int] = stride(
        from: 6 * 60,
        through: 22 * 60,
        by: 30
    )
    .map { $0 }
}

private struct GroomerBookingPreferencesSection: View {
    @Binding var maxAppointmentsPerDay: Int
    @Binding var minimumAdvanceNoticeDays: Int
    @Binding var autoAcceptBookings: Bool

    private var presentation: GroomerAvailabilityWorkspacePresentation {
        GroomerAvailabilityWorkspacePresentation(
            enabledDayCount: 0,
            maxAppointmentsPerDay: maxAppointmentsPerDay,
            minimumAdvanceNoticeDays: minimumAdvanceNoticeDays,
            isSaving: false,
            isBusy: false
        )
    }

    var body: some View {
        BeckonSection(
            "Booking Preferences",
            subtitle: "Set capacity and notice rules for your schedule."
        ) {
            BeckonGroupedSurface {
                VStack(spacing: 0) {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        preferenceText(
                            title: "Daily capacity",
                            subtitle: presentation.capacitySummary
                        )

                        Menu {
                            ForEach(1...12, id: \.self) { capacity in
                                Button("\(capacity) per day") {
                                    maxAppointmentsPerDay = capacity
                                }
                            }
                        } label: {
                            preferenceMenuLabel("\(maxAppointmentsPerDay) / day")
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.vertical, DesignTokens.Spacing.md)

                    BeckonGroupedDivider(leadingInset: DesignTokens.Spacing.lg)

                    HStack(spacing: DesignTokens.Spacing.md) {
                        preferenceText(
                            title: "Advance notice",
                            subtitle: presentation.advanceNoticeSummary
                        )

                        Menu {
                            ForEach(0...2, id: \.self) { days in
                                Button(Self.advanceNoticeMenuTitle(for: days)) {
                                    minimumAdvanceNoticeDays = days
                                }
                            }
                        } label: {
                            preferenceMenuLabel(Self.advanceNoticeMenuTitle(for: minimumAdvanceNoticeDays))
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.vertical, DesignTokens.Spacing.md)

                    BeckonGroupedDivider(leadingInset: DesignTokens.Spacing.lg)

                    HStack(spacing: DesignTokens.Spacing.md) {
                        preferenceText(
                            title: "Auto-ready during open hours",
                            subtitle: "Use enabled hours when checking availability."
                        )

                        Toggle("Auto-ready during open hours", isOn: $autoAcceptBookings)
                            .labelsHidden()
                            .tint(DesignTokens.Colors.groomerAccent)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.vertical, DesignTokens.Spacing.md)
                }
            }
        }
    }

    private func preferenceText(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(title)
                .font(DesignTokens.Typography.body.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)

            Text(subtitle)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func preferenceMenuLabel(_ title: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Text(title)
                .font(DesignTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                .lineLimit(1)

            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(DesignTokens.Colors.borderSoft.opacity(0.48))
        .clipShape(
            RoundedRectangle(
                cornerRadius: DesignTokens.CornerRadius.input,
                style: .continuous
            )
        )
    }

    private static func advanceNoticeMenuTitle(for days: Int) -> String {
        switch min(max(days, 0), 2) {
        case 0:
            "Same day"
        case 1:
            "1 day"
        default:
            "2 days"
        }
    }
}

private struct GroomerTimeOffSection: View {
    @Bindable var store: GroomerProfileStore

    var body: some View {
        BeckonSection(
            "Time Off",
            subtitle: "Block dates when you are unavailable for appointments."
        ) {
            BeckonGroupedSurface {
                if store.timeOffWindows.isEmpty {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        Image(systemName: "calendar.badge.minus")
                            .font(DesignTokens.Typography.action)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .frame(width: DesignTokens.Metrics.settingsIconSlot)
                            .accessibilityHidden(true)

                        Text("No time off planned")
                            .font(DesignTokens.Typography.supporting)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                    .padding(DesignTokens.Layout.surfaceInset)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(store.timeOffWindows.enumerated()), id: \.element.id) { index, window in
                            GroomerTimeOffRow(
                                window: window,
                                onDelete: {
                                    Task {
                                        await store.deleteTimeOff(window)
                                    }
                                }
                            )

                            if index < store.timeOffWindows.count - 1 {
                                BeckonGroupedDivider(leadingInset: 56)
                            }
                        }
                    }
                }
            }
        } trailing: {
                Button(action: startCreateTimeOff) {
                    Image(systemName: "plus")
                        .font(DesignTokens.Typography.action)
                        .frame(width: 44, height: 44)
                        .background(DesignTokens.Colors.surface)
                        .clipShape(DesignTokens.Shapes.circular)
                        .overlay {
                            Circle()
                                .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add time off")
                .accessibilityIdentifier("groomer.availability.time-off.add")
                .disabled(store.isBusy)
        }
    }

    private func startCreateTimeOff() {
        store.startCreateTimeOff()
    }
}

private struct GroomerTimeOffRow: View {
    let window: GroomerTimeOffWindow
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "calendar")
                .font(.body.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(window.title)
                    .font(DesignTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .lineLimit(1)

                Text(window.dateSummary)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.error)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Remove \(window.title)")
            .accessibilityIdentifier("groomer.availability.time-off.remove")
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
    }
}

private struct GroomerAvailabilitySaveActionBar: View {
    let presentation: GroomerAvailabilityWorkspacePresentation
    let save: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(DesignTokens.Colors.divider)

            Button(action: save) {
                if presentation.saveActionTitle == "Saving..." {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        ProgressView()
                            .tint(DesignTokens.Colors.surface)
                        Text(presentation.saveActionTitle)
                    }
                } else {
                    Label(presentation.saveActionTitle, systemImage: "checkmark.circle")
                }
            }
            .buttonStyle(BeckonPrimaryButtonStyle(accent: .groomer))
            .disabled(presentation.isSaveDisabled)
            .accessibilityIdentifier("groomer.availability.save")
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.vertical, DesignTokens.Spacing.md)
        }
        .background(DesignTokens.Colors.background)
    }
}

private struct GroomerTimeOffFormView: View {
    @Bindable var store: GroomerProfileStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedTarget: String?

    var body: some View {
        NavigationStack {
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                        BeckonSection(
                            "Time Off",
                            subtitle: "Add the dates you will not accept appointments."
                        ) {
                            BeckonGroupedSurface {
                                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                                    GroomerProfileTextField(
                                        title: "Title",
                                        text: $store.timeOffTitle,
                                        prompt: "Time off title",
                                        focusTarget: GroomerTimeOffFocusTarget.title.rawValue,
                                        focusedTarget: $focusedTarget
                                    )

                                    BeckonGroupedDivider()

                                    DatePicker(
                                        "Start date",
                                        selection: $store.timeOffStartDate,
                                        displayedComponents: .date
                                    )
                                    .font(DesignTokens.Typography.body.weight(.semibold))

                                    BeckonGroupedDivider()

                                    DatePicker(
                                        "End date",
                                        selection: $store.timeOffEndDate,
                                        displayedComponents: .date
                                    )
                                    .font(DesignTokens.Typography.body.weight(.semibold))
                                }
                                .padding(DesignTokens.Spacing.lg)
                            }
                        }

                        if let errorMessage = store.errorMessage {
                            BeckonErrorBanner(
                                title: "Time Off Could Not Be Saved",
                                message: errorMessage
                            )
                            .accessibilityIdentifier("groomer.availability.time-off.error")
                        }
                    }
                    .beckonPageInsets(
                        bottom: DesignTokens.Layout.stationaryActionContentClearance
                    )
                }
                .beckonKeyboardAvoidance(
                    focusedTarget: focusedTarget,
                    using: scrollProxy,
                    additionallyPreventsPresentationDismissal: store.isSaving
                )
            }
            .background(DesignTokens.Colors.background.ignoresSafeArea())
            .navigationTitle("Add time off")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                        .disabled(store.isSaving)
                }
            }
            .beckonStationaryPageAction {
                GroomerTimeOffSaveActionBar(
                    isSaving: store.isSaving,
                    isDisabled: store.isBusy,
                    save: addTimeOff
                )
            }
        }
        .accessibilityIdentifier("groomer.availability.time-off.form")
    }

    private func cancel() {
        store.cancelTimeOffForm()
        dismiss()
    }

    private func addTimeOff() {
        Task {
            await store.createTimeOff()
            if !store.isShowingTimeOffForm {
                dismiss()
            }
        }
    }
}

private struct GroomerTimeOffSaveActionBar: View {
    let isSaving: Bool
    let isDisabled: Bool
    let save: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(DesignTokens.Colors.divider)

            Button(action: save) {
                if isSaving {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        ProgressView()
                            .tint(DesignTokens.Colors.surface)
                        Text("Saving...")
                    }
                } else {
                    Label("Add Time Off", systemImage: "checkmark.circle")
                }
            }
            .buttonStyle(BeckonPrimaryButtonStyle(accent: .groomer))
            .disabled(isDisabled)
            .accessibilityIdentifier("groomer.availability.time-off.save")
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.vertical, DesignTokens.Spacing.md)
        }
        .background(DesignTokens.Colors.background)
    }
}

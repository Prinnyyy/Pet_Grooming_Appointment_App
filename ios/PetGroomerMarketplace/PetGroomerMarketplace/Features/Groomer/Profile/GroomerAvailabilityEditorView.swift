import SwiftUI

struct GroomerAvailabilityEditorView: View {
    @Bindable var store: GroomerProfileStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .bottom) {
            DesignTokens.Colors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(DesignTokens.Colors.textPrimary)
                                .frame(width: 54, height: 54)
                                .background(DesignTokens.Colors.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
                                }
                        }
                        .accessibilityLabel("Back")

                        Text("Availability")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                    }
                    .padding(.top, DesignTokens.Spacing.md)

                    GroomerAvailabilityActiveCard(isActive: $store.isActive)

                    GroomerAvailabilityWeeklyHoursSection(dayStates: $store.availabilityDayStates)

                    GroomerBookingPreferencesSection(autoAcceptBookings: $store.autoAcceptBookings)

                    GroomerTimeOffSection(store: store)

                    if let errorMessage = store.errorMessage {
                        GroomlyErrorBanner(
                            title: "Availability Could Not Be Saved",
                            message: errorMessage
                        )
                        .accessibilityIdentifier("groomer.availability.error")
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.bottom, 132)
            }

            Button {
                Task {
                    await store.saveAvailability()
                }
            } label: {
                if store.isSaving {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        ProgressView()
                            .tint(DesignTokens.Colors.surface)
                        Text("Saving...")
                    }
                } else {
                    Text("Save Availability")
                }
            }
            .buttonStyle(GroomlyPrimaryButtonStyle(accent: .groomer))
            .disabled(store.isBusy)
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.bottom, DesignTokens.Spacing.lg)
            .background(
                LinearGradient(
                    colors: [
                        DesignTokens.Colors.background.opacity(0),
                        DesignTokens.Colors.background,
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea(edges: .bottom)
            )
            .accessibilityIdentifier("groomer.availability.save")
        }
        .sheet(isPresented: $store.isShowingTimeOffForm) {
            GroomerTimeOffFormView(store: store)
                .presentationDetents([.medium])
        }
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
        .accessibilityIdentifier("groomer.availability.edit")
    }
}

private struct GroomerAvailabilityActiveCard: View {
    @Binding var isActive: Bool

    var body: some View {
        GroomlyCard {
            HStack(spacing: DesignTokens.Spacing.lg) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(isActive ? DesignTokens.Colors.success : DesignTokens.Colors.textSecondary)
                    .frame(width: 54, height: 54)
                    .background((isActive ? DesignTokens.Colors.success : DesignTokens.Colors.borderSoft).opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Available for requests")
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Matching requests can be sent to you during available windows.")
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Toggle("Available for requests", isOn: $isActive)
                    .labelsHidden()
                    .tint(DesignTokens.Colors.success)
            }
        }
    }
}

private struct GroomerAvailabilityWeeklyHoursSection: View {
    @Binding var dayStates: [GroomerAvailabilityDayState]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                Text("Weekly Hours")
                    .font(DesignTokens.Typography.caption.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .textCase(.uppercase)

                Spacer()

                Text("\(dayStates.filter(\.isEnabled).count) days open")
                    .font(DesignTokens.Typography.caption.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.groomerAccent)
            }

            GroomlyCard(padding: DesignTokens.Spacing.md) {
                VStack(spacing: 0) {
                    ForEach($dayStates) { $dayState in
                        GroomerAvailabilityDayRow(dayState: $dayState)

                        if dayState.weekday != dayStates.last?.weekday {
                            Divider()
                                .padding(.leading, 78)
                        }
                    }
                }
            }

            Text("Tap a time to adjust your hours for that day.")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary.opacity(0.76))
                .padding(.horizontal, DesignTokens.Spacing.sm)
        }
    }
}

private struct GroomerAvailabilityDayRow: View {
    @Binding var dayState: GroomerAvailabilityDayState

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Text(dayState.weekday.shortTitle)
                .font(DesignTokens.Typography.body.weight(.bold))
                .foregroundStyle(dayState.isEnabled ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textSecondary)
                .frame(width: 42, alignment: .leading)

            if dayState.isEnabled {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    GroomerAvailabilityTimeMenu(minutes: $dayState.startMinutes)

                    Text("-")
                        .font(DesignTokens.Typography.body.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .frame(width: 10)

                    GroomerAvailabilityTimeMenu(minutes: $dayState.endMinutes)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Unavailable")
                    .font(DesignTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Toggle(dayState.weekday.title, isOn: $dayState.isEnabled)
                .labelsHidden()
                .tint(DesignTokens.Colors.groomerAccent)
        }
        .frame(minHeight: 72)
        .padding(.vertical, DesignTokens.Spacing.xs)
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
                .font(DesignTokens.Typography.body.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .frame(width: 78, alignment: .center)
                .frame(minHeight: 54)
                .background(DesignTokens.Colors.borderSoft.opacity(0.42))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
    @Binding var autoAcceptBookings: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Request Preferences")
                .font(DesignTokens.Typography.caption.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .textCase(.uppercase)

            GroomlyCard {
                HStack(spacing: DesignTokens.Spacing.md) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Auto-ready during open hours")
                            .font(DesignTokens.Typography.body.weight(.bold))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        Text("Use your open hours when checking request and offer availability.")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Toggle("Auto-ready during open hours", isOn: $autoAcceptBookings)
                        .labelsHidden()
                        .tint(DesignTokens.Colors.groomerAccent)
                }
            }
        }
    }
}

private struct GroomerTimeOffSection: View {
    @Bindable var store: GroomerProfileStore

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Time Off")
                .font(DesignTokens.Typography.caption.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .textCase(.uppercase)

            VStack(spacing: DesignTokens.Spacing.md) {
                ForEach(store.timeOffWindows) { window in
                    GroomerTimeOffRow(window: window) {
                        Task {
                            await store.deleteTimeOff(window)
                        }
                    }
                }

                Button {
                    store.startCreateTimeOff()
                } label: {
                    Label("Add time off", systemImage: "plus")
                        .font(DesignTokens.Typography.body.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.Spacing.lg)
                        .background(DesignTokens.Colors.background)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous)
                                .stroke(
                                    DesignTokens.Colors.border.opacity(0.55),
                                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
                                )
                        }
                }
                .buttonStyle(.plain)
                .disabled(store.isBusy)
            }
        }
    }
}

private struct GroomerTimeOffRow: View {
    let window: GroomerTimeOffWindow
    let onDelete: () -> Void

    var body: some View {
        GroomlyCard {
            HStack(spacing: DesignTokens.Spacing.md) {
                Text(icon)
                    .font(.system(size: 24))
                    .frame(width: 54, height: 54)
                    .background(DesignTokens.Colors.borderSoft.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(window.title)
                        .font(DesignTokens.Typography.body.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)

                    Text(window.dateSummary)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("Remove \(window.title)")
            }
        }
    }

    private var icon: String {
        window.title.localizedCaseInsensitiveContains("workshop") ? "📚" : "🏖️"
    }
}

private struct GroomerTimeOffFormView: View {
    @Bindable var store: GroomerProfileStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Time Off") {
                    TextField("Title", text: $store.timeOffTitle)
                    DatePicker(
                        "Start Date",
                        selection: $store.timeOffStartDate,
                        displayedComponents: .date
                    )
                    DatePicker(
                        "End Date",
                        selection: $store.timeOffEndDate,
                        displayedComponents: .date
                    )
                }

                if let errorMessage = store.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(DesignTokens.Colors.error)
                    }
                }
            }
            .navigationTitle("Add time off")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        store.cancelTimeOffForm()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            await store.createTimeOff()
                            if !store.isShowingTimeOffForm {
                                dismiss()
                            }
                        }
                    }
                    .disabled(store.isBusy)
                }
            }
        }
    }
}

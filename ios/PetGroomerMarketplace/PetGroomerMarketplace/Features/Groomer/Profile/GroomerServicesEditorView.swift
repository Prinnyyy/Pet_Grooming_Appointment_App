import SwiftUI

struct GroomerServicesEditorView: View {
    @Bindable var store: GroomerProfileStore

    var body: some View {
        ScrollView {
            GroomerServicesSection(store: store)
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.top, DesignTokens.Spacing.lg)
                .padding(.bottom, 120)
        }
        .background(DesignTokens.Colors.background.ignoresSafeArea())
        .navigationTitle("Services")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("groomer.services.edit")
    }
}

private struct GroomerServicesSection: View {
    @Bindable var store: GroomerProfileStore

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GroomlySectionHeader(
                "Services",
                subtitle: "Services inherit Fit Signals size experience unless a custom service range is enabled."
            ) {
                Button {
                    store.startCreateService()
                } label: {
                    Label("Add Service", systemImage: "plus")
                }
                .buttonStyle(GroomlySecondaryButtonStyle(accent: .groomer, isFullWidth: false))
                .disabled(store.isBusy)
                .accessibilityIdentifier("groomer.services.add")
            }

            if store.services.isEmpty {
                GroomlyEmptyState(
                    title: "No Services Yet",
                    message: "Add services before responding to future requests.",
                    systemImage: "scissors",
                    accent: .groomer
                ) {
                    Button {
                        store.startCreateService()
                    } label: {
                        Label("Add Service", systemImage: "plus")
                    }
                    .buttonStyle(GroomlySecondaryButtonStyle(accent: .groomer))
                    .disabled(store.isBusy)
                }
                .accessibilityIdentifier("groomer.services.empty")
            } else {
                VStack(spacing: DesignTokens.Spacing.md) {
                    ForEach(store.services) { service in
                        GroomerServiceRow(
                            service: service,
                            store: store
                        )
                    }
                }
            }
        }
    }
}

private struct GroomerServiceRow: View {
    let service: GroomerService
    @Bindable var store: GroomerProfileStore

    var body: some View {
        GroomlyCard {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text(service.title)
                                .font(DesignTokens.Typography.headline)
                                .foregroundStyle(DesignTokens.Colors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("$\(service.basePrice, specifier: "%.2f") • \(service.durationMinutes) min")
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(DesignTokens.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        GroomlyStatusChip(
                            service.isActive ? "Visible" : "Hidden",
                            systemImage: service.isActive ? "eye.fill" : "eye.slash",
                            tone: service.isActive ? .success : .neutral
                        )
                    }

                    Label(store.serviceSizePolicySummary(for: service), systemImage: "ruler")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let description = service.description {
                        Text(description)
                            .font(DesignTokens.Typography.body)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Menu {
                    Button("Edit") {
                        store.startEditService(service)
                    }

                    Button("Delete", role: .destructive) {
                        Task {
                            await store.deleteService(service)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(DesignTokens.Typography.title)
                        .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                        .accessibilityLabel("Service actions")
                }
                .disabled(store.isBusy)
            }
        }
    }
}

private struct GroomerServiceTypePicker: View {
    @Binding var selection: GroomingServiceType

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Service Menu")
                .font(DesignTokens.Typography.caption.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .textCase(.uppercase)

            GroomlyCard(padding: DesignTokens.Spacing.sm) {
                VStack(spacing: 0) {
                    ForEach(GroomingServiceType.allCases) { type in
                        Button {
                            selection = type
                        } label: {
                            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                                    Text(type.title)
                                        .font(DesignTokens.Typography.body.weight(.bold))
                                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Text(serviceEditorSubtitle(for: type))
                                        .font(DesignTokens.Typography.caption)
                                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Image(systemName: selection == type ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(
                                        selection == type
                                            ? DesignTokens.Colors.groomerAccent
                                            : DesignTokens.Colors.textTertiary
                                    )
                                    .accessibilityHidden(true)
                            }
                            .padding(.horizontal, DesignTokens.Spacing.sm)
                            .padding(.vertical, DesignTokens.Spacing.md)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(type.title)
                        .accessibilityValue(selection == type ? "Selected" : "Not selected")

                        if type != GroomingServiceType.allCases.last {
                            Divider()
                                .overlay(DesignTokens.Colors.divider)
                        }
                    }
                }
            }
        }
    }

    private func serviceEditorSubtitle(for type: GroomingServiceType) -> String {
        switch type {
        case .fullGroom:
            "Bath, coat cut, nails, ears, and finish"
        case .bathAndBrush:
            "Wash, dry, brush-out, and tidy touchups"
        case .haircutOnly:
            "Coat shaping for pets that do not need a bath"
        case .nailTrim:
            "Clip, grind, and paw handling"
        case .deShedding:
            "Undercoat release, blow-out, and brush work"
        case .customRequest:
            "Special-care appointment scoped in your offer"
        }
    }
}

struct GroomerServiceFormView: View {
    @Bindable var store: GroomerProfileStore

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        GroomlySectionHeader(
                            store.serviceFormTitle,
                            subtitle: "Set one offer-ready service with clear price, duration, visibility, and pet-size policy."
                        )

                        GroomerServiceTypePicker(selection: $store.serviceType)

                        GroomlyCard {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                                GroomerProfileTextField(
                                    title: "Description",
                                    text: $store.serviceDescription,
                                    prompt: "What is included",
                                    axis: .vertical
                                )
                                .lineLimit(2...4)

                                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                                    GroomerProfileTextField(
                                        title: "Base Price",
                                        text: $store.serviceBasePrice,
                                        prompt: "Price"
                                    )
                                    .keyboardType(.decimalPad)

                                    GroomerProfileTextField(
                                        title: "Minutes",
                                        text: $store.serviceDurationMinutes,
                                        prompt: "Duration"
                                    )
                                    .keyboardType(.numberPad)
                                }

                                GroomlyToggleRow(
                                    title: "Visible to Customers",
                                    subtitle: "Hidden services stay saved but do not appear as active options.",
                                    systemImage: "eye",
                                    isOn: $store.serviceIsActive
                                )
                            }
                        }

                        GroomerServiceAcceptedPetSizeSection(store: store)

                        if let errorMessage = store.errorMessage {
                            GroomlyErrorBanner(
                                title: "Service Could Not Be Saved",
                                message: errorMessage
                            )
                            .accessibilityIdentifier("groomer.services.form-error")
                        }
                    }
                    .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                    .padding(.vertical, DesignTokens.Spacing.lg)
                }
            }
            .navigationTitle(store.serviceFormTitle)
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        store.cancelServiceForm()
                    }
                    .disabled(store.isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await store.saveService()
                        }
                    }
                    .disabled(store.isSaving)
                }
            }
        }
        .interactiveDismissDisabled(store.isSaving)
    }
}

private struct GroomerServiceAcceptedPetSizeSection: View {
    @Bindable var store: GroomerProfileStore

    private let serviceSizes = GroomerServicePetSize.allCases

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            GroomlySectionHeader(
                "Accepted Pet Size",
                subtitle: "Default follows your Fit Signals size experience."
            )

            GroomlyCard {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text("Custom Service Range")
                                .font(DesignTokens.Typography.body.weight(.bold))
                                .foregroundStyle(DesignTokens.Colors.textPrimary)

                            Text(sizePolicySubtitle)
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(DesignTokens.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Toggle(
                            "Custom Service Range",
                            isOn: Binding(
                                get: { store.serviceUsesCustomSizeRange },
                                set: { store.setServiceUsesCustomSizeRange($0) }
                            )
                        )
                        .labelsHidden()
                        .tint(DesignTokens.Colors.groomerAccent)
                    }

                    if store.serviceUsesCustomSizeRange {
                        Divider()
                            .overlay(DesignTokens.Colors.divider)

                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
                                Text("Service Range")
                                    .font(DesignTokens.Typography.body.weight(.bold))
                                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                                Spacer(minLength: DesignTokens.Spacing.md)

                                Text(store.serviceSizeRangeTitle)
                                    .font(DesignTokens.Typography.caption.weight(.bold))
                                    .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                                    .padding(.horizontal, DesignTokens.Spacing.sm)
                                    .padding(.vertical, DesignTokens.Spacing.xs)
                                    .background(DesignTokens.Colors.groomerAccent.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .accessibilityIdentifier("groomer.services.size-range-title")
                            }

                            GroomerSizeRangeSlider(
                                lowerIndex: Binding(
                                    get: { store.selectedServiceSizeRange.lowerBound },
                                    set: { newValue in
                                        store.setServiceAcceptedPetSizeRange(
                                            lowerIndex: newValue,
                                            upperIndex: store.selectedServiceSizeRange.upperBound
                                        )
                                    }
                                ),
                                upperIndex: Binding(
                                    get: { store.selectedServiceSizeRange.upperBound },
                                    set: { newValue in
                                        store.setServiceAcceptedPetSizeRange(
                                            lowerIndex: store.selectedServiceSizeRange.lowerBound,
                                            upperIndex: newValue
                                        )
                                    }
                                ),
                                optionCount: serviceSizes.count,
                                rangeTitle: store.serviceSizeRangeTitle,
                                accessibilityIdentifier: "groomer.services.size-range-slider"
                            )

                            HStack(spacing: 0) {
                                ForEach(serviceSizes) { size in
                                    Text(size.title)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.72)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: store.serviceUsesCustomSizeRange)
            }
        }
    }

    private var sizePolicySubtitle: String {
        if store.serviceUsesCustomSizeRange {
            return store.serviceSizeRangeTitle
        }
        return "Following \(store.sizeBandFitClaimRangeTitle)"
    }
}

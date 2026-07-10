import SwiftUI

struct GroomerServicesEditorView: View {
    @Bindable var store: GroomerProfileStore

    var body: some View {
        let presentation = GroomerServicesWorkspacePresentation(
            serviceCount: store.services.count
        )

        ScrollView {
            GroomerServicesSection(
                store: store,
                presentation: presentation
            )
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.top, DesignTokens.Spacing.lg)
            .padding(.bottom, DesignTokens.Spacing.xl)
        }
        .accessibilityIdentifier("groomer.services.edit")
        .background(DesignTokens.Colors.background.ignoresSafeArea())
        .navigationTitle("Services")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: startCreateService) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Service")
                .accessibilityIdentifier("groomer.services.add")
                .disabled(store.isBusy)
            }
        }
    }

    private func startCreateService() {
        store.startCreateService()
    }
}

private struct GroomerServicesSection: View {
    @Bindable var store: GroomerProfileStore
    let presentation: GroomerServicesWorkspacePresentation

    var body: some View {
        GroomerWorkspaceSection(title: "Offer menu") {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Text(presentation.summary)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)

                if store.services.isEmpty {
                    GroomerServicesEmptyState(action: startCreateService)
                        .accessibilityIdentifier("groomer.services.empty")
                } else {
                    GroomerGroupedSurface {
                        VStack(spacing: 0) {
                            ForEach(Array(store.services.enumerated()), id: \.element.id) { index, service in
                                GroomerServiceRow(
                                    service: service,
                                    store: store
                                )

                                if index < store.services.count - 1 {
                                    GroomerWorkspaceDivider(leadingInset: 64)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func startCreateService() {
        store.startCreateService()
    }
}

private struct GroomerServicesEmptyState: View {
    let action: () -> Void

    var body: some View {
        GroomerGroupedSurface {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Image(systemName: "scissors")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                    .frame(width: 44, height: 44)
                    .background(DesignTokens.Colors.groomerAccent.opacity(0.14))
                    .clipShape(DesignTokens.Shapes.circular)
                    .accessibilityHidden(true)

                Text("No services yet")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                Text("Add an offer-ready service before responding to requests.")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: action) {
                    Label("Add Service", systemImage: "plus")
                }
                .buttonStyle(BeckonSecondaryButtonStyle(accent: .groomer, isFullWidth: false))
            }
            .padding(DesignTokens.Spacing.lg)
        }
    }
}

private struct GroomerServiceRow: View {
    let service: GroomerService
    @Bindable var store: GroomerProfileStore

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            Image(systemName: "scissors")
                .font(.body.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                    Text(service.title)
                        .font(DesignTokens.Typography.body.weight(.semibold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(2)

                    if !service.isActive {
                        Text("Hidden")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                }

                Text("$\(service.basePrice, specifier: "%.2f") · \(service.durationMinutes) min")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)

                Text(store.serviceSizePolicySummary(for: service))
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                    .lineLimit(2)

                if let description = service.description,
                   !description.isEmpty {
                    Text(description)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Menu {
                Button("Edit", action: startEdit)
                Button("Delete", role: .destructive, action: deleteService)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Actions for \(service.title)")
            .disabled(store.isBusy)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.md)
    }

    private func startEdit() {
        store.startEditService(service)
    }

    private func deleteService() {
        Task {
            await store.deleteService(service)
        }
    }
}

private struct GroomerServiceTypePicker: View {
    @Binding var selection: GroomingServiceType

    var body: some View {
        GroomerGroupedSurface {
            VStack(spacing: 0) {
                ForEach(GroomingServiceType.allCases) { type in
                    Button {
                        selection = type
                    } label: {
                        HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                                Text(type.title)
                                    .font(DesignTokens.Typography.body.weight(.semibold))
                                    .foregroundStyle(DesignTokens.Colors.textPrimary)

                                Text(serviceEditorSubtitle(for: type))
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Image(systemName: selection == type ? "checkmark.circle.fill" : "circle")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(
                                    selection == type
                                        ? DesignTokens.Colors.groomerAccentDark
                                        : DesignTokens.Colors.textTertiary
                                )
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, DesignTokens.Spacing.lg)
                        .padding(.vertical, DesignTokens.Spacing.md)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(type.title)
                    .accessibilityValue(selection == type ? "Selected" : "Not selected")

                    if type != GroomingServiceType.allCases.last {
                        GroomerWorkspaceDivider(leadingInset: DesignTokens.Spacing.lg)
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
        let presentation = GroomerServiceFormPresentation(
            isSaving: store.isSaving,
            isBusy: store.isBusy
        )

        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    GroomerWorkspaceSection(title: "Service type") {
                        GroomerServiceTypePicker(selection: $store.serviceType)
                    }

                    GroomerWorkspaceSection(title: "Details") {
                        GroomerServiceDetailsSection(store: store)
                    }

                    GroomerWorkspaceSection(title: "Accepted pet size") {
                        GroomerServiceAcceptedPetSizeSection(store: store)
                    }

                    if let errorMessage = store.errorMessage {
                        BeckonErrorBanner(
                            title: "Service Could Not Be Saved",
                            message: errorMessage
                        )
                        .accessibilityIdentifier("groomer.services.form-error")
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.top, DesignTokens.Spacing.lg)
                .padding(.bottom, DesignTokens.Spacing.xl)
            }
            .background(DesignTokens.Colors.background.ignoresSafeArea())
            .navigationTitle(store.serviceFormTitle)
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                        .disabled(store.isSaving)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                GroomerServiceSaveActionBar(
                    presentation: presentation,
                    save: saveService
                )
            }
        }
        .interactiveDismissDisabled(store.isSaving)
        .accessibilityIdentifier("groomer.services.form")
    }

    private func cancel() {
        store.cancelServiceForm()
    }

    private func saveService() {
        Task {
            await store.saveService()
        }
    }
}

private struct GroomerServiceDetailsSection: View {
    @Bindable var store: GroomerProfileStore

    var body: some View {
        GroomerGroupedSurface {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                GroomerProfileTextField(
                    title: "Description",
                    text: $store.serviceDescription,
                    prompt: "What is included",
                    axis: .vertical
                )
                .lineLimit(2...4)

                GroomerWorkspaceDivider()

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

                GroomerWorkspaceDivider()

                HStack(spacing: DesignTokens.Spacing.md) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Visible to customers")
                            .font(DesignTokens.Typography.body.weight(.semibold))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        Text("Hidden services remain saved for later.")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Toggle("Visible to customers", isOn: $store.serviceIsActive)
                        .labelsHidden()
                        .tint(DesignTokens.Colors.groomerAccent)
                }
            }
            .padding(DesignTokens.Spacing.lg)
        }
    }
}

private struct GroomerServiceAcceptedPetSizeSection: View {
    @Bindable var store: GroomerProfileStore

    private let serviceSizes = GroomerServicePetSize.allCases

    var body: some View {
        GroomerGroupedSurface {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Custom service range")
                            .font(DesignTokens.Typography.body.weight(.semibold))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        Text(sizePolicySubtitle)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Toggle(
                        "Custom service range",
                        isOn: Binding(
                            get: { store.serviceUsesCustomSizeRange },
                            set: { store.setServiceUsesCustomSizeRange($0) }
                        )
                    )
                    .labelsHidden()
                    .tint(DesignTokens.Colors.groomerAccent)
                }

                if store.serviceUsesCustomSizeRange {
                    GroomerWorkspaceDivider()

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
                            Text("Service range")
                                .font(DesignTokens.Typography.body.weight(.semibold))
                                .foregroundStyle(DesignTokens.Colors.textPrimary)

                            Spacer(minLength: DesignTokens.Spacing.md)

                            Text(store.serviceSizeRangeTitle)
                                .font(DesignTokens.Typography.caption.weight(.semibold))
                                .foregroundStyle(DesignTokens.Colors.groomerAccentDark)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
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
            .padding(DesignTokens.Spacing.lg)
            .animation(.easeInOut(duration: 0.2), value: store.serviceUsesCustomSizeRange)
        }
    }

    private var sizePolicySubtitle: String {
        if store.serviceUsesCustomSizeRange {
            return store.serviceSizeRangeTitle
        }
        return "Following \(store.sizeBandFitClaimRangeTitle)"
    }
}

private struct GroomerServiceSaveActionBar: View {
    let presentation: GroomerServiceFormPresentation
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
            .accessibilityIdentifier("groomer.services.save")
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.vertical, DesignTokens.Spacing.md)
        }
        .background(DesignTokens.Colors.background)
    }
}

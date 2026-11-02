// The groomer's services, in the customer prototype's language (design). Same job as GroomerServicesEditorView and
// GroomerServiceFormView in Features/Groomer/Profile/GroomerServicesEditorView.swift: the service menu (what is offered, for how
// much and how long, which sizes and species, hidden or not), adding, editing and deleting a service, and the form in a sheet
// (type, description, price, minutes, visibility, species, the accepted size range). The store, its form state and the ids are the
// real ones. What is new is the surface: one ledge card per service, a dashed card to add one, a sheet with our own bar, and a
// question before a service is deleted.
import SwiftUI


struct GroomerServicesEditorView: View {
    @Bindable var store: GroomerProfileStore
    @State private var deleting: GroomerService?

    var body: some View {
        DesignPage {
            BeckonLedgeHeading(title: "Service menu", systemImage: "scissors", count: store.services.count)
            if store.services.isEmpty {
                empty.accessibilityIdentifier("groomer.services.empty")
            } else {
                VStack(spacing: DesignTokens.Spacing.md) {
                    ForEach(store.services) { service in
                        GroomerServiceCard(service: service, sizeSummary: store.serviceSizePolicySummary(for: service),
                            isBusy: store.isBusy, onEdit: { store.startEditService(service) }, onDelete: { deleting = service })
                    }
                }
            }
            addCard
        }
        .navigationTitle("Services")
        .navigationBarTitleDisplayMode(.inline)
        .beckonHidesTabBar()
        .background { GroomerProfileStatusView(store: store) }
        .beckonSheet(isPresented: $store.isShowingServiceForm) {
            GroomerServiceFormView(store: store)
                .designSheetStyle()
        }
        .designAlertDialog(item: $deleting) { service in
            .destructive(title: "Delete \(service.title)?", message: "It leaves your service menu. Customers will not see it any more.",
                systemImage: "trash.fill", keepTitle: "Keep it", confirmTitle: "Delete", confirmSystemImage: "trash",
                confirmIdentifier: "groomer.services.delete.confirm") {
                Task { await store.deleteService(service) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("groomer.services.edit")
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("No services yet")
                .font(DesignTokens.Typography.Expressive.title)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
            Text("Add an offer-ready service before responding to requests.").designSupportingText()
        }
        .designCardBody()
    }

    private var addCard: some View {
        Button { store.startCreateService() } label: {
            HStack(spacing: DesignTokens.Spacing.md) {
                DesignIconDisc(systemImage: "plus", size: .touch, font: DesignTokens.Typography.Expressive.glyph)
                Text("Add service")
                    .font(DesignTokens.Typography.Expressive.headline)
                    .foregroundStyle(DesignTokens.Colors.customerDeep)
                Spacer(minLength: 0)
            }
            .padding(DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.ledgePrimaryButtonHeight)
        }
        .buttonStyle(BeckonLedgeButtonStyle(.dashed))
        .disabled(store.isBusy)
        .accessibilityLabel("Add service")
        .accessibilityIdentifier("groomer.services.add")
    }
}


/// One service on the menu: its name, price and time, who it takes, and a menu for editing or deleting it. The text opens it.
private struct GroomerServiceCard: View {
    let service: GroomerService
    let sizeSummary: String
    let isBusy: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                        Text(service.title)
                            .font(DesignTokens.Typography.Expressive.title)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        if !service.isActive { BeckonStatusChip("Hidden", systemImage: "eye.slash") }
                    }
                    Text("\(service.basePrice.formatted(.currency(code: "USD"))) · \(service.durationMinutes) min")
                        .font(DesignTokens.Typography.Expressive.emphasis)
                        .foregroundStyle(DesignTokens.Colors.customerDeep)
                    BeckonFlowLayout(spacing: DesignTokens.Spacing.sm, rowSpacing: DesignTokens.Spacing.sm) {
                        BeckonMetaChip(text: sizeSummary, systemImage: "ruler")
                        BeckonMetaChip(text: service.acceptedSpeciesSummary, systemImage: "pawprint.fill")
                    }
                    if let description = service.description, !description.isEmpty {
                        Text(description).designSupportingText().lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(BeckonGuardedPlainButtonStyle())

            Menu {
                Button("Edit", systemImage: "pencil", action: onEdit)
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .font(DesignTokens.Typography.Expressive.glyph)
                    .foregroundStyle(DesignTokens.Colors.customerDeep)
                    .frame(width: DesignTokens.Metrics.minimumTouchTarget, height: DesignTokens.Metrics.minimumTouchTarget)
                    .contentShape(Rectangle())
            }
            .disabled(isBusy)
            .accessibilityLabel("Actions for \(service.title)")
        }
        .padding(DesignTokens.Spacing.lg)
        .beckonLedge(.card)
    }
}


// MARK: Form

/// The form of a service, in a sheet: its own bar with a close button, the sections, and the one pinned Save.
struct GroomerServiceFormView: View {
    @Bindable var store: GroomerProfileStore
    @FocusState private var focusedTarget: String?

    var body: some View {
        let presentation = GroomerServiceFormPresentation(isSaving: store.isSaving, isBusy: store.isBusy)

        VStack(spacing: 0) {
            DesignSheetBar(title: store.serviceFormTitle, closeIdentifier: "groomer.services.cancel",
                isCloseDisabled: store.isSaving) { store.cancelServiceForm() }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionSpacing) {
                        typeSection
                        detailsSection
                        speciesSection
                        sizeSection
                        if let message = store.actionErrorMessage {
                            BeckonErrorBanner(title: "Service could not be saved", message: message)
                                .accessibilityIdentifier("groomer.services.form-error")
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
            GroomerSaveBar(title: "Save service", isSaving: store.isSaving, isDisabled: presentation.isSaveDisabled,
                identifier: "groomer.services.save") {
                Task { await store.saveService() }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("groomer.services.form")
    }

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            BeckonLedgeHeading(title: "Service type", systemImage: "scissors")
            Text("Choose the category customers will see.").designSupportingText()
            VStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(GroomingServiceType.allCases) { type in
                    let isSelected = store.serviceType == type
                    Button { store.serviceType = type } label: {
                        HStack(spacing: DesignTokens.Spacing.md) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(type.title)
                                    .font(DesignTokens.Typography.Expressive.emphasis)
                                    .foregroundStyle(isSelected ? DesignTokens.Colors.customerInk : DesignTokens.Colors.textPrimary)
                                Text(Self.subtitle(for: type))
                                    .font(DesignTokens.Typography.Expressive.chip)
                                    .foregroundStyle(isSelected ? DesignTokens.Colors.customerInk : DesignTokens.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            BeckonTickCircle(isOn: isSelected)
                        }
                        .padding(DesignTokens.Spacing.md)
                        .frame(maxWidth: .infinity, minHeight: DesignTokens.Metrics.minimumTouchTarget)
                    }
                    .buttonStyle(BeckonLedgeButtonStyle(isSelected ? .pill : .card))
                    .accessibilityLabel(type.title)
                    .accessibilityValue(isSelected ? "Selected" : "Not selected")
                }
            }
        }
    }

    private static func subtitle(for type: GroomingServiceType) -> String {
        switch type {
        case .fullGroom: "Bath, coat cut, nails, ears, and finish"
        case .bathAndBrush: "Wash, dry, brush-out, and tidy touchups"
        case .haircutOnly: "Coat shaping for pets that do not need a bath"
        case .nailTrim: "Clip, grind, and paw handling"
        case .deShedding: "Undercoat release, blow-out, and brush work"
        case .customRequest: "Special-care appointment scoped in your offer"
        }
    }

    private var detailsSection: some View {
        DesignSection(title: "Details", systemImage: "list.bullet.rectangle.fill", spacing: DesignTokens.Spacing.lg) {
            GroomerTextField(title: "Description", text: $store.serviceDescription, prompt: "What is included", axis: .vertical,
                focusTarget: GroomerServiceFormFocusTarget.description.rawValue, focusedTarget: $focusedTarget)
                .lineLimit(2...4)
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                GroomerTextField(title: "Base price", text: $store.serviceBasePrice, prompt: "Price",
                    focusTarget: GroomerServiceFormFocusTarget.basePrice.rawValue, focusedTarget: $focusedTarget)
                    .keyboardType(.decimalPad)
                GroomerTextField(title: "Minutes", text: $store.serviceDurationMinutes, prompt: "Duration",
                    focusTarget: GroomerServiceFormFocusTarget.duration.rawValue, focusedTarget: $focusedTarget)
                    .keyboardType(.numberPad)
            }
            GroomerToggleRow(title: "Visible to customers", subtitle: "Hidden services remain saved for later.",
                isOn: $store.serviceIsActive, identifier: "groomer.services.visible")
        }
    }

    private var speciesSection: some View {
        DesignSection(title: "Accepted species", systemImage: "pawprint.fill", spacing: DesignTokens.Spacing.lg) {
            ForEach(GroomerServiceSpecies.allCases) { species in
                GroomerToggleRow(title: species.title, isOn: Binding(
                    get: { store.selectedServiceSpecies.contains(species) },
                    set: { store.setServiceSpecies(species, accepted: $0) }),
                    identifier: "groomer.services.species.\(species.rawValue)")
            }
            if !store.serviceSpeciesConfirmed {
                DesignInfoLine(systemImage: "exclamationmark.circle", text: "Species confirmation required")
            }
        }
    }

    private var sizeSection: some View {
        let sizes = GroomerServicePetSize.allCases
        return DesignSection(title: "Accepted pet size", systemImage: "ruler", spacing: DesignTokens.Spacing.lg) {
            GroomerToggleRow(title: "Accepted size range",
                subtitle: store.serviceUsesCustomSizeRange ? store.serviceSizeRangeTitle : "Size assessment required",
                isOn: Binding(get: { store.serviceUsesCustomSizeRange }, set: { store.setServiceUsesCustomSizeRange($0) }),
                identifier: "groomer.services.size-range-toggle")
            if store.serviceUsesCustomSizeRange {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    Text(store.serviceSizeRangeTitle)
                        .font(DesignTokens.Typography.Expressive.title)
                        .foregroundStyle(DesignTokens.Colors.customerDeep)
                        .accessibilityIdentifier("groomer.services.size-range-title")
                    GroomerSizeRangeSlider(
                        lowerIndex: Binding(get: { store.selectedServiceSizeRange.lowerBound }, set: {
                            store.setServiceAcceptedPetSizeRange(lowerIndex: $0, upperIndex: store.selectedServiceSizeRange.upperBound)
                        }),
                        upperIndex: Binding(get: { store.selectedServiceSizeRange.upperBound }, set: {
                            store.setServiceAcceptedPetSizeRange(lowerIndex: store.selectedServiceSizeRange.lowerBound, upperIndex: $0)
                        }),
                        optionCount: sizes.count, rangeTitle: store.serviceSizeRangeTitle,
                        accessibilityIdentifier: "groomer.services.size-range-slider")
                    GroomerSizeRangeLegend(titles: sizes.map(\.title))
                }
            }
        }
    }
}

nonisolated enum GroomerServiceFormFocusTarget: String, CaseIterable, Hashable {
    case description = "groomer.services.description.container"
    case basePrice = "groomer.services.base-price.container"
    case duration = "groomer.services.duration.container"
}

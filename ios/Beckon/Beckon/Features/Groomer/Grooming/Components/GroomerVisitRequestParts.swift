import SwiftUI

private extension View {
    @ViewBuilder func groomerVisitFactSweep(_ loading: Bool) -> some View {
        if loading { designSkeleton(label: nil) } else { self }
    }
}

extension GroomingLocationMode {
    var groomerVisitVisitPlace: String {
        switch self {
        case .customerComesToGroomer: "Your studio"
        case .groomerComesToCustomer: "Customer’s home"
        }
    }
}

struct GroomerVisitVisitIdentity: View {
    let pet: GroomingRequestPetSnapshot?
    let photo: Data?
    let service: GroomingServiceType?
    let fallbackTitle: String
    @Binding var selectedPet: GroomingRequestPetSnapshot?
    var isPlaceholder = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .trailing, spacing: DesignTokens.Spacing.xs))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DesignTokens.Spacing.md))) {
            HStack(spacing: DesignTokens.Spacing.md) {
                if let pet {
                    if isPlaceholder {
                        DesignSkeletonDisc().frame(width: 56, height: 56)
                    } else {
                        BeckonPetAvatar(data: photo,
                            systemImage: BeckonPetPresentation.symbol(for: pet.species), width: 56, height: 56, cornerRadius: 28)
                            .overlay(Circle().strokeBorder(DesignTokens.Colors.customerFill, lineWidth: DesignTokens.Ledge.edgeWidth + 1))
                            .accessibilityHidden(true)
                    }
                }
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(pet?.name ?? fallbackTitle).font(DesignTokens.Typography.Expressive.headline)
                    if let service {
                        Text(service.title).font(DesignTokens.Typography.Expressive.emphasis)
                            .foregroundStyle(DesignTokens.Colors.customerDeep)
                    }
                }.groomerVisitFactSkeletonText(isPlaceholder)
            }.frame(maxWidth: .infinity, alignment: .leading)
            if let pet {
                Group {
                    if isPlaceholder { GroomerVisitPetProfileButton.placeholder }
                    else { GroomerVisitPetProfileButton(pet: pet, selection: $selectedPet) }
                }.fixedSize(horizontal: !typeSize.isAccessibilitySize, vertical: true)
            }
        }
    }
}

struct GroomerVisitVisitOverviewCard<Header: View, Explanation: View>: View {
    let decision: String?
    var status: GroomerVisitCardStatus? = nil
    var isPlaceholder = false
    var explanationTitle: String? = nil
    var usesStructuredStatus = false
    @ViewBuilder let header: () -> Header
    @ViewBuilder let explanation: (String) -> Explanation

    var body: some View {
        let surface: BeckonLedgeSurface = decision == nil ? .card : .highlight
        let shape = RoundedRectangle(cornerRadius: surface.radius, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: GroomerVisitDetailRowLayout.rowSpacing) {
                header()
                if let decision {
                    GroomerVisitNeedsActionPanel(title: explanationTitle ?? decision, symbol: "exclamationmark.circle") {
                        explanation(decision)
                    }
                } else if let status, status.showsExplanation {
                    if usesStructuredStatus {
                        GroomerVisitStatusContentPanel(title: status.title, tone: status.resolvedTone) {
                            explanation(status.title)
                        }
                    } else {
                        GroomerVisitStatusInfoPanel(title: status.title, message: status.message, waitingFor: status.waitingFor, tone: status.resolvedTone)
                            .groomerVisitFactSkeletonText(isPlaceholder)
                    }
                }
            }
            .padding(DesignTokens.Spacing.lg)

        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BeckonLedgeSurface.card.face)
        .compositingGroup()
        .clipShape(shape)
        .overlay { shape.strokeBorder(surface.edge ?? .clear, lineWidth: DesignTokens.Ledge.edgeWidth) }
        .background { shape.fill(surface.lip).offset(y: surface.depth) }
        .padding(.bottom, surface.depth)
        .accessibilityElement(children: .contain)
    }
}

/// The original three-stop journey and the short brief for this visit.
struct GroomerVisitRequestOverview: View {
    let subject: GroomerRequestSubject
    let photo: Data?
    let stage: GroomerRequestStage
    let now: Date
    let decision: String?
    @Binding var selectedPet: GroomingRequestPetSnapshot?
    var hasLinkedBooking = false
    var isPlaceholder = false
    @Environment(\.dynamicTypeSize) private var typeSize

    private var pet: GroomingRequestPetSnapshot? { subject.request?.petSnapshot ?? subject.item?.groomerVisitPet }
    private var service: GroomingServiceType? {
        subject.request?.serviceType ?? subject.offer?.agreementSnapshot?.serviceType ?? subject.booking?.serviceType
    }

    var body: some View {
        GroomerVisitVisitOverviewCard(decision: decision, status: GroomerVisitCardStatus.offer(subject, stage: stage, linked: hasLinkedBooking), isPlaceholder: isPlaceholder) {
            VStack(alignment: .leading, spacing: GroomerVisitDetailRowLayout.rowSpacing) {
                GroomerVisitVisitIdentity(pet: pet, photo: photo, service: service, fallbackTitle: subject.item?.title ?? "Request",
                    selectedPet: $selectedPet, isPlaceholder: isPlaceholder)
                GroomerVisitRequestJourney(subject: subject, stage: stage, now: now, isPlaceholder: isPlaceholder)
            }
            .groomerVisitFactSweep(isPlaceholder)
        } explanation: { _ in
            if let replacement = GroomerVisitOfferReplacement(stage.problem) {
                Text(replacement.instructions).designSupportingText()
            } else if stage.problem == .timeUnavailable {
                Text("Your proposed time is unavailable. Check your schedule before the offer expires.").designSupportingText()
            } else if stage.hold == .species {
                Text("Confirm which pets you serve in your profile before sending an offer.").designSupportingText()
            } else {
                Text("The customer invited you to this request. Send an offer or dismiss the invitation.").designSupportingText()
            }
        }
        .accessibilityIdentifier("groomerVisit.request.overview")
        // The navigation push reveals this white surface; fading it would expose the coral backdrop.
        .containerValue(\.beckonCascadeOwnsArrival, true)
    }
}

extension GroomerVisitRequestFactRow {
    static func serviceLocation(_ mode: GroomingLocationMode, isPlaceholder: Bool = false) -> Self {
        Self(systemImage: mode == .customerComesToGroomer ? "storefront" : "house",
            title: "Service location", value: mode.groomerVisitVisitPlace, isPlaceholder: isPlaceholder)
    }

    @ViewBuilder static func customerNote(_ raw: String?, isPlaceholder: Bool = false) -> some View {
        if let note = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            Self(systemImage: "text.bubble", title: "From the customer", value: note, isPlaceholder: isPlaceholder)
        }
    }
}

/// The time is the customer's request throughout. Only this groomer's linked booking supplies a full address.
struct GroomerVisitRequestFacts: View {
    let request: GroomerMatchedGroomingRequest
    let booking: Booking?
    let groomerID: UUID
    var isPlaceholder = false

    var body: some View {
        DesignSection(title: "The request", systemImage: "doc.text.fill") {
            GroomerVisitDetailRowGroup {
                GroomerVisitRequestFactRow(systemImage: "number", title: "Request number",
                    value: "#" + request.id.uuidString.prefix(8).uppercased(), isPlaceholder: isPlaceholder)
                GroomerVisitPreferredWindow(request: request, isPlaceholder: isPlaceholder)
                GroomerVisitRequestFactRow(systemImage: "scissors", title: "Service",
                    value: request.serviceType.title, isPlaceholder: isPlaceholder)
                GroomerVisitRequestFactRow.serviceLocation(request.locationMode, isPlaceholder: isPlaceholder)
                GroomerVisitRequestFactRow(systemImage: "location.fill", title: "Address", value: address, isPlaceholder: isPlaceholder)
                GroomerVisitRequestFactRow.customerNote(request.serviceNotes, isPlaceholder: isPlaceholder)
                if !isPlaceholder {
                    GroomerVisitRequestContact(requestID: request.id, groomerID: groomerID,
                        authorizationRevision: "\(request.id)/\(request.updatedAt)/\(request.invitationState?.rawValue ?? "")/\(request.status.rawValue)")
                }
            }.groomerVisitFactSweep(isPlaceholder)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("groomerVisit.request.facts")
    }

    private var address: String {
        if let booking, booking.requestID == request.id, booking.groomerID == groomerID, booking.customerID == request.customerID {
            return GroomerVisitVisitAddress.confirmed(booking) ?? booking.appointmentAddressSummary
        }
        return GroomerVisitVisitAddress.lines(request.streetAddress,
            city: request.city, state: request.state, zip: request.zipCode)
    }
}

enum GroomerVisitVisitAddress {
    static func confirmed(_ booking: Booking) -> String? {
        guard let snapshot = booking.agreementSnapshot, snapshot.isSupported else { return nil }
        let address = snapshot.address
        let street = [address.streetAddress, address.addressLine2].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        guard !street.isEmpty || !address.city.isEmpty || !address.state.isEmpty || !address.zipCode.isEmpty else { return nil }
        return lines(street, city: address.city, state: address.state, zip: address.zipCode)
    }

    static func lines(_ street: String, city: String, state: String, zip: String) -> String {
        let region = [state, zip].filter { !$0.isEmpty }.joined(separator: " ")
        let locality = [city, region].filter { !$0.isEmpty }.joined(separator: ", ")
        let address = [street, locality].filter { !$0.isEmpty }.joined(separator: "\n")
        return address.isEmpty ? "Location unavailable" : address
    }
}
/// All footer actions share the Send offer face, height and press travel.
struct GroomerVisitRequestFooterActionStyle: PrimitiveButtonStyle {
    enum Tone { case primary, secondary, management }
    var tone: Tone = .primary
    var fullWidth = true
    var retainsDisabledColor = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let secondary = tone == .secondary
        let depth = secondary ? DesignTokens.Ledge.control : BeckonLedgeSurface.pill.depth
        let surface = BeckonLedgeSurface.pill
        typealias Ink = DesignTokens.Colors
        let colors: (text: Color, face: Color, lip: Color) = switch tone {
        case .secondary: (Ink.textSecondary, Ink.surface, Ink.border)
        case .primary, .management: (Ink.groomerInk, surface.face, GroomerVisitButtonLips.coral)
        }
        let haptic: SensoryFeedback? = tone == .primary && configuration.role != .destructive ? .impact(weight: .medium) : nil
        return BeckonGuardedButtonBody(configuration: configuration, style: BeckonPressActionLook { button in
            BeckonPressEngine(isPressed: button.isPressed && isEnabled, haptic: haptic) { amount in
                Group {
                    if secondary { button.label.labelStyle(.titleOnly) }
                    else { button.label }
                }
                    .font(DesignTokens.Typography.Expressive.headline)
                    .foregroundStyle(colors.text)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: DesignTokens.Metrics.ledgePrimaryButtonHeight)
                    .modifier(BeckonPressFace(
                        face: colors.face, pressedFace: colors.face, lip: colors.lip, edge: secondary ? Ink.border : nil,
                        depth: depth, radius: secondary ? DesignTokens.CornerRadius.round : surface.radius, amount: amount))
                    .padding(.bottom, DesignTokens.Ledge.room - depth)
                    .fixedSize(horizontal: !fullWidth, vertical: true)
                    .opacity(isEnabled || retainsDisabledColor ? 1 : 0.5)
            }
        })
    }
}

/// The available width excludes the gap. A single action receives the entire width.
struct GroomerVisitFooterColumns: Layout {
    let gap: CGFloat
    private func widths(_ width: CGFloat, count: Int) -> [CGFloat] {
        guard count > 0 else { return [] }
        let available = max(0, width - CGFloat(count - 1) * gap)
        if count == 2 { return [available * 0.36, available * 0.64] }
        return Array(repeating: available / CGFloat(count), count: count)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? subviews.reduce(0) { $0 + $1.sizeThatFits(.unspecified).width } + CGFloat(max(0, subviews.count - 1)) * gap
        let heights = zip(subviews, widths(width, count: subviews.count)).map { view, width in
            view.sizeThatFits(.init(width: width, height: nil)).height
        }
        return CGSize(width: width, height: heights.max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        for (view, width) in zip(subviews, widths(bounds.width, count: subviews.count)) {
            view.place(at: CGPoint(x: x, y: bounds.midY), anchor: .leading, proposal: .init(width: width, height: nil))
            x += width + gap
        }
    }
}

struct GroomerVisitFooterLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            configuration.title
            configuration.icon.accessibilityHidden(true)
        }
    }
}

struct GroomerVisitRequestFooter<Primary: View>: ViewModifier {
    let showsPrimary: Bool
    var onDismissMatch: (() -> Void)? = nil
    var onWithdrawOffer: (() -> Void)? = nil
    var isEditing = false
    var busy = false
    var error: String? = nil
    @ViewBuilder let primary: () -> Primary
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var height: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: isEditing ? 0 : height).allowsHitTesting(false).accessibilityHidden(true)
            }
            .beckonStationaryPageAction {
                VStack(spacing: 0) {
                    if showsPrimary || onDismissMatch != nil || onWithdrawOffer != nil { bar }
                }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
                .opacity(isEditing ? 0 : 1)
                .allowsHitTesting(!isEditing)
                .accessibilityHidden(isEditing)
            }

    }

    private var bar: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            if let error {
                Text(error).font(DesignTokens.Typography.Expressive.supporting)
                    .foregroundStyle(DesignTokens.Colors.statusErrorText)
            }
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.sm))
                : AnyLayout(GroomerVisitFooterColumns(gap: DesignTokens.Spacing.md))
            layout {
                if let onDismissMatch {
                    managementButton("Dismiss", icon: "xmark.circle", id: "groomer.requests.dismiss", tone: .management, action: onDismissMatch)
                        .accessibilityLabel("Dismiss match")
                } else if let onWithdrawOffer {
                    managementButton("Withdraw", icon: "arrow.uturn.backward.circle", id: "groomer.offers.withdraw", tone: .management, action: onWithdrawOffer)
                        .accessibilityLabel("Withdraw offer")
                }
                if showsPrimary { primary() }
            }
            .labelStyle(GroomerVisitFooterLabelStyle())
            .disabled(busy)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignTokens.Layout.pageHorizontalInset)
        .padding(.vertical, DesignTokens.Layout.actionAreaInset)
        .background(DesignTokens.Colors.appBackground.ignoresSafeArea())
        .overlay(alignment: .top) { DesignTokens.Colors.borderSoft.frame(height: DesignTokens.Ledge.edgeWidth / 2) }
    }

    private func managementButton(_ title: LocalizedStringKey, icon: String, id: String, tone: GroomerVisitRequestFooterActionStyle.Tone,
                                  action: @escaping () -> Void) -> some View {
        Button(title, systemImage: icon, role: .destructive, action: action)
            .buttonStyle(GroomerVisitRequestFooterActionStyle(tone: showsPrimary ? .secondary : tone))
            .accessibilityIdentifier(id)
    }
}

struct GroomerVisitDetailNavigationLabel: View {
    let title: LocalizedStringKey

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Text(title)
            Image(systemName: "arrow.forward").accessibilityHidden(true)
        }
    }
}

/// Shared by both detail routes. A delayed booking can be fetched from the same footer.
struct GroomerVisitViewBookingAction: View {
    let booking: Booking?
    let open: (Booking) -> Void
    let refresh: () async -> Void
    @State private var checking = false

    var body: some View {
        Group {
            if let booking {
                GroomerVisitNavigationButton { open(booking) } label: { GroomerVisitDetailNavigationLabel(title: "View booking") }
                    .buttonStyle(GroomerVisitRequestFooterActionStyle())
            } else {
                Button {
                    guard !checking else { return }
                    checking = true
                    Task {
                        defer { checking = false }
                        await refresh()
                    }
                } label: {
                    DesignQuietAction(title: checking ? "Checking booking…" : "Refresh booking", systemImage: "arrow.clockwise")
                        .frame(minHeight: DesignTokens.Metrics.ledgePrimaryButtonHeight + DesignTokens.Ledge.room)
                }
                .buttonStyle(BeckonGuardedPlainButtonStyle())
                .disabled(checking)
            }
        }
        .accessibilityHint(booking == nil ? "Check for the booking created from this offer." : "Open the appointment details.")
        .accessibilityIdentifier(booking == nil ? "groomer.requests.refresh-booking" : "groomer.requests.view-booking")
    }
}

/// Preferred and booked intervals share the same service-local two-line display.
private struct GroomerVisitPreferredWindow: View {
    let request: GroomerMatchedGroomingRequest
    let isPlaceholder: Bool

    var body: some View {
        Group {
            if let zone = request.preferenceTimeZoneIdentifier, let _ = try? GroomingServiceTiming.locationCalendar(zone),
               let start = GroomingRequestDateFormatting.parsedDate(from: request.preferredStart),
               let end = GroomingRequestDateFormatting.parsedDate(from: request.preferredEnd), end > start {
                GroomerVisitBookedTimeRow(start: request.preferredStart, end: request.preferredEnd,
                    timeZoneIdentifier: zone, isPlaceholder: isPlaceholder, title: "Preferred time")
            } else {
                GroomerVisitRequestFactRow(systemImage: "clock", title: "Preferred time",
                    value: request.preferredTimePresentation.text, isPlaceholder: isPlaceholder)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preferred time window. " + request.preferredTimePresentation.accessibilityLabel)
        .accessibilityIdentifier("groomerVisit.request.preferred-window")
    }
}

private struct GroomerVisitOfferConfirmationSummary: View {
    let draft: GroomerOfferDraft
    let request: GroomerMatchedGroomingRequest
    let serviceTimeZone: TimeZone?
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .footnote) private var labelColumnWidth: CGFloat = 80

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                detailRow("Service") {
                    VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xs) {
                        Text(request.serviceType.title)
                        Text(request.locationMode.groomerVisitVisitPlace)
                            .font(DesignTokens.Typography.Expressive.chip)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                }
                VStack(alignment: .leading, spacing: 0) {
                    detailRow("When") { proposedTime }
                    DesignRowDivider().frame(height: DesignTokens.Spacing.md)
                    priceRow
                }
            }
            .font(DesignTokens.Typography.Expressive.supporting)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(DesignTokens.Colors.textPrimary)
            .padding(DesignTokens.Spacing.lg)
            .background(DesignTokens.Colors.groomerTint, in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.inset))
            Text("Customer acceptance confirms the booking.")
                .designSupportingText()
                .multilineTextAlignment(.center)
        }
    }

    private func fieldLabel(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(DesignTokens.Typography.Expressive.chip)
            .foregroundStyle(DesignTokens.Colors.textPrimary)
    }

    private func detailRow<Value: View>(_ title: LocalizedStringKey, @ViewBuilder value: () -> Value) -> some View {
        let stacked = typeSize.isAccessibilitySize
        let layout = stacked
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.xs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md))

        return layout {
            fieldLabel(title)
                .frame(width: stacked ? nil : labelColumnWidth, alignment: .leading)
            value()
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private var priceRow: some View {
        let label = fieldLabel("Price estimate")
        let amount = Text(draft.priceEstimate, format: .currency(code: "USD").precision(.fractionLength(2)))
            .font(DesignTokens.Typography.Expressive.headline)
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                label.fixedSize()
                Spacer(minLength: 0)
                amount.fixedSize()
            }
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                label
                amount.frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var proposedTime: some View {
        if let serviceTimeZone, let calendar = try? GroomingServiceTiming.locationCalendar(serviceTimeZone.identifier) {
            let labels = GroomerVisitRequestTimeLabels(start: draft.proposedStart, end: draft.proposedEnd, calendar: calendar)
            VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xs) {
                Text(labels.startDate)
                Text("\(labels.startTime) – \(labels.endTime)")
                    .font(DesignTokens.Typography.Expressive.chip)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Starts \(labels.startDate) at \(labels.startTime). Ends \(labels.endDate ?? labels.startDate) at \(labels.endTime).")
        } else {
            Text("Time unavailable").designSupportingText()
        }
    }
}

extension DesignModal {
    static func groomerVisitSendOffer(draft: GroomerOfferDraft, request: GroomerMatchedGroomingRequest,
                                 serviceTimeZone: TimeZone?, keepEditing: @escaping @MainActor () -> Void, confirm: @escaping @MainActor () -> Void) -> Self {
        Self(systemImage: "paperplane.fill", title: "Send this offer?", actions: [
            .primary("Confirm", systemImage: "checkmark", identifier: "groomer.offers.submit.confirm", perform: confirm),
            .quiet("Keep editing", identifier: "dialog.cancel", perform: keepEditing)
        ]) {
            GroomerVisitOfferConfirmationSummary(draft: draft, request: request, serviceTimeZone: serviceTimeZone)
        }
    }
}

extension DesignAlertDialog {
    static func groomerVisitWithdrawOffer(price: String?, petName: String?, confirm: @escaping @MainActor () -> Void) -> Self {
        let offer = price.map { "your " + $0 + " offer" } ?? "this offer"
        let pet = petName.map { " for " + $0 } ?? ""
        return .confirmation(title: "Withdraw this offer?",
            message: "The customer will no longer be able to accept " + offer + pet + ". You can send a new offer if the request is still open.",
            systemImage: "arrow.uturn.backward.circle.fill", confirmTitle: "Withdraw offer",
            confirmSystemImage: "arrow.uturn.backward", confirmIdentifier: "groomer.offers.withdraw.confirm",
            cancelTitle: "Keep offer", confirm: confirm)
    }
}

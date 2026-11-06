import SwiftUI

/// Adopted C3-A. Historical experiments use the same fields, not this flow's state.
struct GroomerVisitCurrentOfferForm: View {
    static let startAnchor = "groomerVisit.request.offer.start"
    let fields: GroomerVisitRequestOfferForm
    private enum Editor { case time, duration, note }
    @State private var expanded: Editor?
    @State private var messageStartedEmpty = true
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private typealias Ink = DesignTokens.Colors
    private typealias TypeRole = DesignTokens.Typography.Expressive
    private var form: GroomerOfferFormState { fields.form }
    private var start: Date? { form.resolvedProposedStart }
    private var finish: Date? { form.proposedEnd }
    private var requestStart: Date? { GroomingRequestDateFormatting.parsedDate(from: fields.matched.request.preferredStart) }
    private var minutes: Int { Int(form.durationMinutesText) ?? 0 }
    private var editingPrice: Bool { fields.focusedTarget.wrappedValue == .price }
    private var visibleEditor: Editor? { editingPrice ? nil : expanded }
    private var messageText: String { form.message.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var editingMessage: Bool { expanded == .note }
    private var calendar: Calendar? {
        guard let zone = form.serviceTimeZone else { return nil }
        return try? GroomingServiceTiming.locationCalendar(zone.identifier)
    }
    private func time(_ instant: Date?, day: Bool = false) -> String {
        guard let instant, let calendar else { return "Choose time" }
        let style = Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone)
        if day { return instant.formatted(style.weekday(.abbreviated).month(.abbreviated).day()) }
        return instant.formatted(style.hour().minute())
    }

    private func stamp(_ date: Date?) -> String {
        guard let date, let zone = form.serviceTimeZone else { return "Choose time" }
        return BeckonDateTimeFormatter.instant(from: GroomingRequestDateFormatting.serverString(from: date),
                                              serviceTimeZoneIdentifier: zone.identifier).text
    }

    private var finishText: String {
        if let start, let finish, let calendar, calendar.isDate(start, inSameDayAs: finish),
           calendar.timeZone.secondsFromGMT(for: start) == calendar.timeZone.secondsFromGMT(for: finish) {
            return time(finish)
        }
        return stamp(finish)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            VStack(spacing: 0) {
                GroomerVisitOfferPriceHeader(editPrice: { fields.focusedTarget.wrappedValue = .price }) { pointSize in
                    priceEditor(pointSize: pointSize)
                } accessory: { priceKeyboardButton }
                GroomerVisitDetailRowGroup(fillsCard: true) {
                    if form.serviceTimeZone == nil {
                        fields.startField.padding(GroomerVisitDetailRowLayout.cardRowInsets()).id(Self.startAnchor)
                    } else {
                        timingRow.id(Self.startAnchor).zIndex(1)
                        durationRow.zIndex(1)
                    }
                    inlineMessage
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card, style: .continuous))
            .beckonLedge(.card)
        }
        .foregroundStyle(Ink.textPrimary)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("groomerVisit.offer.design.C3-A")
        .onChange(of: fields.focusedTarget.wrappedValue) { old, new in
            // A switch to another input needs no second layout animation. Keyboard dismissal
            // below owns the collapse when focus becomes nil.
            if old == .message, new == .price, editingMessage { expanded = nil }
        }
        .beckonOnKeyboardDismiss { duration in
            guard editingMessage else { return }
            // Collapse alongside the keyboard, rather than starting a separate spring on focus loss.
            withAnimation(reduceMotion ? nil : .easeOut(duration: duration)) { expanded = nil }
        }
    }
    private static let inlineWheelHeight: CGFloat = 122
    private var durationEditor: some View { fields.durationWheels(height: Self.inlineWheelHeight) }
    private func toggle(_ editor: Editor) {
        let wasOpen = visibleEditor == editor
        fields.focusedTarget.wrappedValue = nil
        withAnimation(GroomerVisitDetailMotion.expansion(reduceMotion: reduceMotion)) { expanded = wasOpen ? nil : editor }
    }
    private func setAnchor(_ instant: Date) {
        fields.focusedTarget.wrappedValue = nil
        form.setVisitStart(instant)
    }
    private func editFact(_ editor: Editor, icon: String, title: String, value: String, detail: String? = nil) -> some View {
        let error = editor == .time ? fields.startError : nil
        return GroomerVisitDisclosureRow(systemImage: icon, title: title, value: value, detail: error ?? detail, detailIsError: error != nil,
            isExpanded: visibleEditor == editor, rowInsets: GroomerVisitDetailRowLayout.cardRowInsets(),
            headerIdentifier: editor == .time ? "groomerVisit.quick.time" : "groomerVisit.quick.duration", onToggle: { toggle(editor) }) {
            switch editor {
            case .time: exactTime
            case .duration: durationEditor
            case .note: EmptyView()
            }
        }
    }
    private var timingRow: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading)) : AnyLayout(HStackLayout(spacing: 10))
        return layout { editFact(.time, icon: "calendar", title: "Start · \(time(start, day: true))", value: time(start)) }
    }
    private var durationRow: some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading)) : AnyLayout(HStackLayout(spacing: 10))
        return layout { editFact(.duration, icon: "timer", title: "Service duration", value: GroomerProfileContent.durationText(minutes), detail: "Ends \(finishText)") }
    }
    private func priceEditor(pointSize: CGFloat) -> some View {
        GroomerVisitOfferPriceInput(text: Binding(get: { form.priceEstimateText }, set: { form.priceEstimateText = $0 }),
            focusedTarget: fields.focusedTarget, pointSize: pointSize, usesRowStyle: true)
            .accessibilityIdentifier("groomerVisit.quick.price")
    }

    private var priceKeyboardButton: some View {
        let diameter = DesignIconDisc.Size.tile.points
        let touch = DesignTokens.Metrics.minimumTouchTarget
        return Button { fields.focusedTarget.wrappedValue = editingPrice ? nil : .price } label: {
            Image(systemName: editingPrice ? "keyboard.chevron.compact.down" : "keyboard")
                .font(TypeRole.emphasis).foregroundStyle(Ink.groomerDeep)
                .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace, options: .speed(1.5)))
                .frame(width: diameter, height: diameter).background(Ink.surface, in: Circle())
                .frame(width: touch, height: touch).contentShape(Rectangle())
        }
        .buttonStyle(GroomerVisitPriceKeyboardButtonStyle())
        .accessibilityLabel(editingPrice ? "Done editing price" : "Type exact price")
    }

    /// A wheel edits a real instant in the visit's time zone, in place. Its change preserves the chosen fold during DST.
    @ViewBuilder private var exactTime: some View {
        if let zone = form.serviceTimeZone, let calendar, let initial = start ?? requestStart {
            DatePicker("Exact start",
                selection: Binding(get: { start ?? initial }, set: { setAnchor($0) }),
                displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.wheel).labelsHidden().tint(Ink.groomerDeep)
                .environment(\.calendar, calendar).environment(\.timeZone, zone)
                .frame(height: Self.inlineWheelHeight).clipped().contentShape(Rectangle())
                .accessibilityIdentifier("groomerVisit.quick.time-wheel")
        }
    }

    private var inlineMessage: some View {
        let showsAdd = editingMessage ? messageStartedEmpty : messageText.isEmpty
        let title = showsAdd ? "Add message" : "Messages"
        return GroomerVisitDisclosureRow(systemImage: "text.bubble", title: title,
            value: messageText.isEmpty ? "Optional" : messageText,
            isExpanded: editingMessage, presentation: .inlineText, valueIsPlaceholder: messageText.isEmpty,
            rowInsets: GroomerVisitDetailRowLayout.cardRowInsets(isLast: true),
            headerIdentifier: "groomerVisit.quick.note", onToggle: toggleMessage) {
            fields.messageInput
        }
        .accessibilityIdentifier("groomerVisit.quick.note.section")
    }

    private func toggleMessage() {
        let shouldOpen = !editingMessage
        if shouldOpen { messageStartedEmpty = messageText.isEmpty }
        if shouldOpen {
            // The native keyboard transition owns viewport movement; avoid a competing spring.
            expanded = .note
        }
        // Closing waits for keyboardWillHide so the row and viewport move together.
        // The action owns focus. A view appearing during a transition must not reopen editing.
        fields.focusedTarget.wrappedValue = shouldOpen ? .message : nil
    }

}

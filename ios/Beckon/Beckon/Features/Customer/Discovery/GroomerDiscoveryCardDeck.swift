import SwiftUI

struct GroomerDiscoveryCardDeck<Content: View>: View {
    let groomerIDs: [UUID]
    @Binding var selection: GroomerDiscoveryDeckSelection?
    let revision: UUID
    let isRefreshing: Bool
    @ViewBuilder let content: (GroomerDiscoveryDeckSelection) -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var offset: CGFloat = 0
    @State private var cardWidth: CGFloat = 320
    @State private var direction: GroomerDiscoveryDeckDirection = .next
    @State private var horizontalIntent: Bool?
    @State private var transition = GroomerDiscoveryDeckTransition()
    @GestureState private var isDragging = false

    var body: some View {
        VStack(spacing: 16) {
            GeometryReader { geometry in
                if let selection {
                    let width = geometry.size.width
                    let next = destination(from: selection, direction: direction)
                    let progress = min(abs(offset) / max(width, 1), 1)
                    ZStack {
                        if next != selection {
                            surface.scaleEffect(0.92, anchor: .bottom).offset(y: 16)
                                .accessibilityHidden(true)
                            card(next)
                                .scaleEffect(0.96 + progress * 0.04, anchor: .bottom)
                                .offset(y: 8 * (1 - progress))
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                        card(selection)
                            .disabled(horizontalIntent == true || transition.isActive)
                            .rotationEffect(.degrees(reduceMotion ? 0 : max(-8, min(8, offset / max(width, 1) * 12))), anchor: .bottom)
                            .offset(x: reduceMotion ? offset * 0.04 : offset)
                            .opacity(reduceMotion ? 1 - progress : 1)
                            .allowsHitTesting(!transition.isActive)
                    }
                    .contentShape(Rectangle())
                    .simultaneousGesture(drag(width: width))
                    .accessibilityAction(named: "Previous groomer") { advance(.previous, width: width) }
                    .accessibilityAction(named: "Next groomer") { advance(.next, width: width) }
                }
            }
            .frame(height: 500)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                cardWidth = width
                cancel()
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.bottom, DesignTokens.Spacing.lg)

            HStack(spacing: 16) {
                browseButton(.previous, symbol: "chevron.left", label: "Previous groomer")
                Text(positionLabel)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("discovery.page-position")
                browseButton(.next, symbol: "chevron.right", label: "Next groomer")
            }
        }
        .onChange(of: revision) { _, _ in cancel() }
        .onChange(of: selection) { _, _ in cancel() }
        .onChange(of: isRefreshing) { _, loading in if loading { cancel() } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { cancel() } }
        .onChange(of: reduceMotion) { _, _ in cancel() }
        .onChange(of: isDragging) { _, active in
            if !active {
                Task { @MainActor in
                    await Task.yield()
                    if !isDragging && !transition.isActive { settle() }
                }
            }
        }
        .onDisappear { cancel() }
    }

    private var surface: some View {
        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card)
            .fill(DesignTokens.Colors.surface)
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card)
                    .stroke(DesignTokens.Colors.border, lineWidth: 1)
            }
    }

    private func card(_ position: GroomerDiscoveryDeckSelection) -> some View {
        content(position)
            .id(position)
            .padding(DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card))
            .background(surface.beckonShadow(DesignTokens.Shadows.smallCard))
    }

    private var positionLabel: String {
        if case .groomer(let id) = selection, let index = groomerIDs.firstIndex(of: id) {
            return "\(index + 1) of \(groomerIDs.count)"
        }
        return "More Groomers"
    }

    private func browseButton(_ direction: GroomerDiscoveryDeckDirection, symbol: String, label: String) -> some View {
        Button { advance(direction, width: cardWidth) } label: {
            Image(systemName: symbol).frame(width: 44, height: 44)
        }
        .buttonStyle(.borderless)
        .tint(DesignTokens.Colors.customerAccentStrong)
        .accessibilityLabel(label).help(label)
        .accessibilityIdentifier(direction == .next ? "discovery.next" : "discovery.previous")
        .disabled(transition.isActive || selection == nil || selection.map { destination(from: $0, direction: direction) == $0 } == true)
    }

    private func destination(from selection: GroomerDiscoveryDeckSelection,
                             direction: GroomerDiscoveryDeckDirection) -> GroomerDiscoveryDeckSelection {
        GroomerDiscoveryDeckPolicy.destination(from: selection, direction: direction, groomerIDs: groomerIDs)
    }

    private func drag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($isDragging) { _, state, _ in state = true }
            .onChanged { value in
                guard !transition.isActive, !isRefreshing, let selection else { return }
                if horizontalIntent == nil {
                    horizontalIntent = abs(value.translation.width) > abs(value.translation.height) * 1.25
                }
                guard horizontalIntent == true else { return }
                direction = value.translation.width < 0 ? .next : .previous
                let bounded = destination(from: selection, direction: direction) == selection
                offset = bounded ? max(-24, min(24, value.translation.width * 0.12)) : value.translation.width
            }
            .onEnded { value in
                guard !transition.isActive else { return }
                let horizontal = horizontalIntent == true
                horizontalIntent = nil
                if horizontal, let direction = GroomerDiscoveryDeckPolicy.committedDirection(
                    translation: CGSize(width: value.translation.width, height: 0),
                    predictedEnd: value.predictedEndTranslation, cardWidth: width) {
                    advance(direction, width: width)
                } else { settle() }
            }
    }

    private func advance(_ direction: GroomerDiscoveryDeckDirection, width: CGFloat) {
        guard !transition.isActive, !isRefreshing, let selection else { return }
        let next = destination(from: selection, direction: direction)
        guard next != selection else { settle(); return }
        self.direction = direction
        let token = transition.begin(from: selection, to: next)
        withAnimation(.easeOut(duration: reduceMotion ? 0.16 : 0.28), completionCriteria: .removed) {
            offset = (direction == .next ? -1 : 1) * width * 1.2
        } completion: {
            guard let next = transition.complete(token: token, current: self.selection) else { return }
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                offset = 0
                self.selection = next
            }
        }
    }

    private func settle() {
        horizontalIntent = nil
        withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .spring(duration: 0.28, bounce: 0.08)) { offset = 0 }
    }

    private func cancel() {
        transition.cancel()
        horizontalIntent = nil
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { offset = 0 }
    }
}

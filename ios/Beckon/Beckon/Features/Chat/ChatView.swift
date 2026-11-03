import SwiftUI

nonisolated struct ChatConversationListPresentation: Equatable, Sendable {
    enum Audience: Equatable, Sendable {
        case customer
        case groomer
    }

    let title = "Messages"
    let audience: Audience
    let avatarSize: CGFloat = 64
    let previewLineLimit = 2

    static let customer = Self(audience: .customer)
    static let groomer = Self(audience: .groomer)
}

struct ChatConversationsView: View {

    @Environment(\.scenePhase) private var scenePhase
    private let participantID: UUID
    private let role: UserRole
    private let bookingRepository: (any BookingRepository)?
    @Binding private var focusedBookingID: UUID?
    @State private var store: ChatStore
    @State private var focusedConversation: ChatConversation?
    private var conversationsSettled: Bool { store.hasLoadedOnce || !store.conversations.isEmpty }

    init(
        participantID: UUID,
        role: UserRole,
        repository: any ChatRepository,
        bookingRepository: (any BookingRepository)? = nil,
        debugRecorder: AppDebugEventRecorder? = nil,
        store: ChatStore? = nil,
        focusedBookingID: Binding<UUID?> = .constant(nil)
    ) {
        self.participantID = participantID
        self.role = role
        self.bookingRepository = bookingRepository
        _focusedBookingID = focusedBookingID
        _store = State(
            initialValue: store ?? ChatStore(
                participantID: participantID,
                role: role,
                repository: repository,
                bookingRepository: bookingRepository,
                debugRecorder: debugRecorder
            )
        )
    }

    var body: some View {
        ZStack {
            BeckonExpressiveBackdrop()
            conversationsContent
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .background {
            ChatStatusView(store: store, role: role)
        }
        .beckonResetsNavigation { focusedConversation = nil }
        .navigationDestination(item: $focusedConversation) { conversation in
            ChatThreadView(
                participantID: participantID,
                role: role,
                conversation: conversation,
                store: store
            )
        }
        .refreshable {
            await store.loadConversations()
            await openFocusedConversationIfPossible()
        }
        .task {
            await store.loadConversations()
        }
        .task(id: focusedBookingID) {
            await openFocusedConversationIfPossible()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await store.loadConversations()
                await openFocusedConversationIfPossible()
            }
        }
    }

    private func openFocusedConversationIfPossible() async {
        guard let bookingID = focusedBookingID else { return }
        if let conversation = await store.resolveConversation(bookingID: bookingID),
           focusedBookingID == bookingID, !Task.isCancelled {
            focusedConversation = conversation
            focusedBookingID = nil
        }
    }

    @ViewBuilder
    private var conversationsContent: some View {
        customerConversationsContent
    }

    private var customerConversationsContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Layout.sectionSpacing) {
                // The title is the page's frame: it is there from the first frame, wait or no wait.
                BeckonPageTitle(presentation.title)
                    .beckonEntrance(0)

                DesignReveal(isLoading: !conversationsSettled) {
                    conversationWorkspace
                } placeholder: {
                    ChatConversationsSkeleton()
                        .accessibilityIdentifier("chat.conversations.loading")
                        .beckonEntrance(1)
                }

                if store.canLoadMoreConversations || store.isLoadingMoreConversations {
                    BeckonLoadMoreButton(
                        isLoading: store.isLoadingMoreConversations,
                        accent: role.beckonSecondaryAccent,
                        accessibilityIdentifier: "chat.conversations.load-more"
                    ) {
                        await store.loadNextConversationsPage()
                    }
                }
            }
            // The page's own insets and title row, like Grooming and Account: the first card is at the same height on every tab (design).
            .beckonPageInsets()
            .beckonEntranceClock()
        }
            .beckonTracksScroll()
        .accessibilityIdentifier("chat.conversations.list")
    }

    @ViewBuilder
    private var conversationWorkspace: some View {
        customerConversationWorkspace
    }

    @ViewBuilder private var customerConversationWorkspace: some View {
        if store.conversations.isEmpty {
            emptyConversationsState
                .beckonEntrance(1)
        } else {
            LazyVStack(spacing: DesignTokens.Spacing.md) {
                ForEach(Array(store.conversations.enumerated()), id: \.element.id) { index, conversation in
                    conversationLink(conversation)
                        .beckonEntrance(1 + min(index, 4))
                }
            }
        }
    }

    @ViewBuilder
    private var emptyConversationsState: some View {
        customerEmptyConversationsState
    }

    private var customerEmptyConversationsState: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("No conversations yet")
                .font(DesignTokens.Typography.Expressive.title)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
            Text("Accepted bookings create participant conversations.")
                .designSupportingText()
        }
        .designCardBody()
        .accessibilityIdentifier("chat.conversations.empty")
    }

    @ViewBuilder
    private func conversationLink(_ conversation: ChatConversation) -> some View {
        customerConversationLink(conversation)
    }

    @ViewBuilder private func customerConversationLink(_ conversation: ChatConversation) -> some View {
        CustomerNavigationLink(route: .conversation(conversation.id)) {
            ChatThreadView(
                participantID: participantID,
                role: role,
                conversation: conversation,
                store: store
            )
        } label: {
            ChatConversationRow(
                conversation: conversation,
                role: role,
                store: store
            )
        }
        .buttonStyle(BeckonLedgeButtonStyle(.card))
        .accessibilityIdentifier(
            conversationAccessibilityIdentifier(conversation)
        )
    }

    private func conversationAccessibilityIdentifier(
        _ conversation: ChatConversation
    ) -> String {
        guard let requestID = conversation.latestRequestID else {
            return "chat.conversation.\(conversation.id.uuidString.lowercased())"
        }
        return AppTestOpsAccessibility.requestIdentifier(
            prefix: "chat.conversation.request",
            requestID: requestID
        )
    }

    private var presentation: ChatConversationListPresentation {
        role == .groomer ? .groomer : .customer
    }
}

private struct ChatConversationRow: View {

    let conversation: ChatConversation
    let role: UserRole
    let store: ChatStore

    @ViewBuilder
    var body: some View {
        customerBody
    }

    @ViewBuilder private var customerBody: some View {
        rowContent
            .padding(DesignTokens.Spacing.md)
            .multilineTextAlignment(.leading)
            .accessibilityElement(children: .combine)
            .accessibilityValue(store.hasUnreadMessages(in: conversation) ? "Unread" : "Read")
    }

    @ViewBuilder
    private var rowContent: some View {
        customerRowContent
    }

    @ViewBuilder private var customerRowContent: some View {
        HStack(
            alignment: .center,
            spacing: DesignTokens.Spacing.lg
        ) {
            BeckonProfileAvatar(
                data: conversation.counterpartAvatarPhotoData,
                tone: role == .customer ? .groomer : .customer,
                size: presentation.avatarSize,
                cornerRadius: DesignTokens.CornerRadius.inset,
                placeholderSize: 24
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.inset, style: .continuous)
                    .strokeBorder(DesignTokens.Colors.customerFill, lineWidth: DesignTokens.Ledge.edgeWidth + 1))

            VStack(
                alignment: .leading,
                spacing: DesignTokens.Spacing.sm
            ) {
                Text(conversation.listTitle(for: role))
                    .font(store.hasUnreadMessages(in: conversation)
                        ? DesignTokens.Typography.Expressive.headline : DesignTokens.Typography.Expressive.emphasis)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(store.previewText(for: conversation))
                    .font(DesignTokens.Typography.Expressive.supporting)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .lineLimit(presentation.previewLineLimit)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(
                alignment: .trailing,
                spacing: DesignTokens.Spacing.sm
            ) {
                if store.hasUnreadMessages(in: conversation) {
                    Circle()
                        .fill(DesignTokens.Colors.unreadDot)
                        .frame(width: 10, height: 10)
                        .accessibilityHidden(true)
                }

                Text(ChatDateFormatting.relativeSummary(from: conversation.updatedAt))
                    .font(DesignTokens.Typography.Expressive.chip)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)

                if conversation.isReadOnly() {
                    BeckonMetaChip(text: "Read-only", systemImage: "lock.fill")
                }
            }

        }
    }

    private var presentation: ChatConversationListPresentation {
        role == .groomer ? .groomer : .customer
    }
}

private struct ChatMessagesTitle: View {

    let title: String

    init(_ title: String) {
        self.title = title
    }

    @ViewBuilder
    var body: some View {
        customerBody
    }

    @ViewBuilder private var customerBody: some View {
        Text(title)
            .font(DesignTokens.Typography.Expressive.display)
            .foregroundStyle(DesignTokens.Colors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, DesignTokens.Spacing.sm)
            .accessibilityAddTraits(.isHeader)
    }

}

nonisolated enum ChatThreadScrollPolicy {
    static func shouldScrollToBottom(
        previousLatestMessageID: UUID?,
        currentLatestMessageID: UUID?
    ) -> Bool {
        guard currentLatestMessageID != nil else { return false }
        return previousLatestMessageID != currentLatestMessageID
    }
}

enum ChatThreadStatusTone: Equatable {
    case active, updating, failed, readOnly
    init(subtitle: String) {
        switch subtitle {
        case "Active chat": self = .active
        case "Read-only": self = .readOnly
        case "Couldn't update": self = .failed
        default: self = .updating
        }
    }
    var color: Color {
        switch self {
        case .active: DesignTokens.Colors.statusSuccessText
        case .updating: DesignTokens.Colors.statusWarningText
        case .failed: DesignTokens.Colors.statusErrorText
        case .readOnly: DesignTokens.Colors.textTertiary
        }
    }
}

nonisolated enum ChatComposerKeyboardPresentation {
    static let actionPlacement: BeckonKeyboardActionPlacement = .inputAccessory
    static let includesExplicitDoneAccessory = false
}

struct ChatThreadView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let participantID: UUID
    let role: UserRole
    let conversation: ChatConversation
    let store: ChatStore
    /// The route may have already prepared the subscription and first snapshot while showing its header.
    var initialMessagesPrepared = false
    @State private var draft = ""
    @State private var isVisible = false
    @State private var didActivate = false
    @FocusState private var isComposing: Bool

    private var statusText: String {
        if store.isLoadingMessages(for: conversation.id) { return "Updating…" }
        if store.messageLoadErrors[conversation.id] != nil { return "Couldn't update" }
        if store.interruptedMessageSubscriptions.contains(conversation.id) { return "Live updates paused" }
        if !store.hasLoadedMessages(for: conversation.id) { return "Updating…" }
        return store.canSendMessages(in: conversation) ? "Active chat" : "Read-only"
    }

    var body: some View {
        ZStack {
            DesignTokens.Colors.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ChatThreadHeader(
                    title: conversation.listTitle(for: role),
                    subtitle: statusText,
                    role: role,
                    avatarPhotoData: conversation.counterpartAvatarPhotoData,
                    isComposing: isComposing,
                    dismiss: dismiss
                )

                Divider()
                    .overlay(DesignTokens.Colors.borderSoft)

                threadContent
            }
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture().onEnded { isComposing = false })
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ChatComposerBar(
                draft: $draft,
                isFocused: $isComposing,
                isSending: store.isSendingMessage(for: conversation.id),
                isReadOnly: !store.canSendMessages(in: conversation),
                readOnlyMessage: conversation.readOnlyReason,
                accent: role == .customer ? .customer : .groomer,
                placeholder: "Message \(conversation.shortRecipientName(for: role))...",
                send: {
                    let body = draft
                    let sent = await store.sendMessage(in: conversation, body: body)
                    if sent, draft == body {
                        draft = ""
                    }
                }
            )
        }
        .onAppear {
            isVisible = true
            store.acknowledgeVisibleMessages(for: conversation.id)
        }
        .task(id: isVisible && scenePhase == .active) {
            guard isVisible else { return }
            guard scenePhase == .active else {
                didActivate = true
                store.stopMessageSubscription(for: conversation.id)
                return
            }
            let needsRefresh = didActivate || !initialMessagesPrepared
                || !store.hasActiveMessageSubscription(for: conversation.id)
            didActivate = true
            if needsRefresh { await refreshThread() }
        }
        .onDisappear {
            isVisible = false
            store.stopMessageSubscription(for: conversation.id)
        }
        .background {
            ChatStatusView(store: store, role: role)
        }
        .scrollDismissesKeyboard(.interactively)

    }

    @ViewBuilder
    private var threadContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    if !store.canSendMessages(in: conversation) {
                        ChatReadOnlyBanner(message: conversation.readOnlyReason)
                    }

                    if let error = store.messageLoadErrors[conversation.id] {
                        recoveryBanner(title: "Messages unavailable", message: error)
                    } else if store.interruptedMessageSubscriptions.contains(conversation.id) {
                        recoveryBanner(title: "Live updates paused", message: "Refresh to reconnect and check for new messages.")
                    }

                    if store.hasLoadedMessages(for: conversation.id),
                              store.messages(for: conversation.id).isEmpty,
                              store.messageLoadErrors[conversation.id] == nil {
                        BeckonEmptyState(
                            title: "No messages yet",
                            message: "Send the first message for this booking.",
                            systemImage: "bubble.left.and.bubble.right",
                            accent: role.beckonEmptyAccent
                        )
                        .accessibilityIdentifier("chat.messages.empty")
                    } else {
                        if store.canLoadMoreMessages(for: conversation.id)
                            || store.isLoadingEarlierMessages(for: conversation.id) {
                            BeckonLoadMoreButton(
                                isLoading: store.isLoadingEarlierMessages(
                                    for: conversation.id
                                ),
                                accent: role.beckonSecondaryAccent,
                                accessibilityIdentifier: "chat.messages.load-earlier",
                                title: "Load earlier messages",
                                systemImage: "chevron.up",
                                loadingAccessibilityLabel: "Loading earlier messages"
                            ) {
                                let anchorMessageID = store.messages(
                                    for: conversation.id
                                ).first?.id
                                await store.loadNextMessagesPage(for: conversation)
                                await Task.yield()
                                if let anchorMessageID {
                                    proxy.scrollTo(anchorMessageID, anchor: .top)
                                }
                            }
                        }

                        ForEach(store.messages(for: conversation.id)) { message in
                            ChatMessageRow(
                                message: message,
                                isOutgoing: message.isSentBy(participantID),
                                role: role,
                                bookingStore: store.bookingDetailStore(
                                    for: message
                                )
                            )
                            .id(message.id)
                        }
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("chat-thread-bottom")
                }
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.top, DesignTokens.Spacing.lg)
                .padding(.bottom, DesignTokens.Spacing.md)
            }
            .refreshable { await refreshThread() }
            .onChange(of: store.messages(for: conversation.id).last?.id) {
                previousLatestMessageID,
                currentLatestMessageID in
                guard ChatThreadScrollPolicy.shouldScrollToBottom(
                    previousLatestMessageID: previousLatestMessageID,
                    currentLatestMessageID: currentLatestMessageID
                ) else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("chat-thread-bottom", anchor: .bottom)
                }
            }
            .onAppear {
                proxy.scrollTo("chat-thread-bottom", anchor: .bottom)
            }
        }
    }

    private func refreshThread() async {
        await store.prepareMessages(for: conversation)
    }

    private func recoveryBanner(title: String, message: String) -> some View {
        BeckonErrorBanner(title: title, message: message) {
            Button {
                Task { await refreshThread() }
            } label: {
                Label("Refresh messages", systemImage: "arrow.clockwise")
            }
            .buttonStyle(BeckonSecondaryButtonStyle(accent: role.beckonSecondaryAccent))
            .disabled(store.isLoadingMessages(for: conversation.id))
            .accessibilityIdentifier("chat.messages.retry")
        }
    }
}

/// Same header and composer geometry as the destination, with no active input until verified.
struct ChatThreadLoadingView: View {
    let title: String
    let avatarPhotoData: Data?
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isComposing: Bool

    var body: some View {
        VStack(spacing: 0) {
            ChatThreadHeader(title: title, subtitle: "Updating…", role: .customer,
                avatarPhotoData: avatarPhotoData, isComposing: false, dismiss: dismiss)
            Divider().overlay(DesignTokens.Colors.borderSoft)
            Spacer(minLength: 0)
        }
        .background(DesignTokens.Colors.appBackground.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ChatComposerBar(draft: .constant(""), isFocused: $isComposing,
                isSending: false, isReadOnly: false, readOnlyMessage: "", accent: .customer,
                placeholder: "Message…", send: {})
                .disabled(true)
                .accessibilityHidden(true)
        }
        .accessibilityIdentifier("chat.thread.loading")
    }
}

private struct ChatThreadHeader: View {

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    let subtitle: String
    let role: UserRole
    let avatarPhotoData: Data?
    let isComposing: Bool
    let dismiss: DismissAction

    @ViewBuilder
    var body: some View {
        customerBody
    }

    @ViewBuilder private var customerBody: some View {
        HStack(spacing: DesignTokens.Spacing.lg) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(DesignTokens.Typography.Expressive.glyph)
                    .foregroundStyle(DesignTokens.Colors.customerDeep)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(BeckonLedgeButtonStyle(.round))
            .accessibilityLabel("Back")

            if !dynamicTypeSize.isAccessibilitySize {
              BeckonProfileAvatar(
                data: avatarPhotoData,
                tone: role == .customer ? .groomer : .customer,
                size: 56,
                cornerRadius: DesignTokens.CornerRadius.inset
            )
              .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.Expressive.title)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .lineLimit(isComposing && dynamicTypeSize.isAccessibilitySize ? 1 : nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                if !isComposing || !dynamicTypeSize.isAccessibilitySize {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Circle()
                            .fill(ChatThreadStatusTone(subtitle: subtitle).color)
                            .frame(width: 9, height: 9)
                            .accessibilityHidden(true)

                        Text(subtitle)
                            .font(DesignTokens.Typography.Expressive.chip)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
        .padding(.top, DesignTokens.Spacing.lg)
        .padding(.bottom, DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.customerTint)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.thread")
    }

}

private struct ChatMessageRow: View {

    let message: ChatMessage
    let isOutgoing: Bool
    let role: UserRole
    let bookingStore: BookingsStore?

    var body: some View {
        switch message.kind {
        case .text:
            textRow
        case .bookingCard:
            bookingCardRow
        }
    }

    @ViewBuilder
    private var textRow: some View {
        customerTextRow
    }

    @ViewBuilder private var customerTextRow: some View {
        HStack(alignment: .bottom) {
            if isOutgoing {
                Spacer(minLength: 82)
            }

            VStack(alignment: isOutgoing ? .trailing : .leading, spacing: DesignTokens.Spacing.xs) {
                Text(message.body ?? "")
                    .font(DesignTokens.Typography.Expressive.body)
                    .foregroundStyle(isOutgoing ? DesignTokens.Colors.customerInk : DesignTokens.Colors.textPrimary)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.vertical, DesignTokens.Spacing.md)
                    .background {
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.messageBubble, style: .continuous)
                            .fill(isOutgoing ? DesignTokens.Colors.customerFill : DesignTokens.Colors.surface)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.messageBubble, style: .continuous)
                            .strokeBorder(isOutgoing ? DesignTokens.Colors.customerFillPressed : DesignTokens.Colors.border,
                                lineWidth: DesignTokens.Ledge.edgeWidth)
                    }
            }
            .frame(maxWidth: 330, alignment: isOutgoing ? .trailing : .leading)
            .accessibilityElement(children: .combine)

            if !isOutgoing {
                Spacer(minLength: 82)
            }
        }
    }

    @ViewBuilder
    private var bookingCardRow: some View {
        customerBookingCardRow
    }

    @ViewBuilder private var customerBookingCardRow: some View {
        if let booking = message.booking,
           let bookingStore {
            CustomerNavigationLink(route: .grooming(.booking(booking.id))) {
                ChatBookingDetailDestination(
                    bookingID: booking.id,
                    role: role,
                    store: bookingStore
                )
            } label: {
                ChatBookingMessageCard(
                    booking: bookingStore.booking(withID: booking.id) ?? booking,
                    role: role
                )
            }
            .buttonStyle(BeckonLedgeButtonStyle(.card))
            .accessibilityIdentifier(
                "chat.message.booking.\(booking.id.uuidString.lowercased())"
            )
        } else {
            ChatBookingUnavailableCard()
        }
    }

}

private struct ChatBookingDetailDestination: View {
    @Environment(\.dismiss) private var dismiss
    let bookingID: UUID
    let role: UserRole
    let store: BookingsStore

    var body: some View {
        BookingDetailView(
            bookingID: bookingID,
            role: role,
            store: store,
            onOpenChat: { _ in dismiss() }
        )
    }
}

private struct ChatComposerBar: View {

    @Binding var draft: String
    @FocusState.Binding var isFocused: Bool
    let isSending: Bool
    let isReadOnly: Bool
    let readOnlyMessage: String
    let accent: BeckonRoleAccent
    let placeholder: String
    let send: () async -> Void

    private var hasDraft: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    @ViewBuilder
    var body: some View {
        customerBody
    }

    @ViewBuilder private var customerBody: some View {
        Group {
            if isReadOnly {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "lock.fill")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .padding(.top, DesignTokens.Layout.messageGlyphTopInset)
                        .accessibilityHidden(true)

                    Text(readOnlyMessage)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DesignTokens.Spacing.lg)
                .padding(.vertical, DesignTokens.Spacing.md)
                .background {
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
                        .fill(DesignTokens.Colors.iconTileFill)
                }
                .accessibilityIdentifier("chat.message.read-only")
            } else {
                HStack(alignment: .bottom, spacing: DesignTokens.Spacing.md) {
                    TextField(placeholder, text: $draft, axis: .vertical)
                        .focused($isFocused)
                        .font(DesignTokens.Typography.body)
                        .lineLimit(1...4)
                        .padding(.horizontal, DesignTokens.Spacing.lg)
                        .padding(.vertical, DesignTokens.Spacing.md)
                        .background(DesignTokens.Colors.iconTileFill)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous))
                        .accessibilityIdentifier("chat.message.body")
                        .accessibilityLabel("Message")

                    Button {
                        Task {
                            await send()
                        }
                    } label: {
                        ZStack {
                            if isSending {
                                ProgressView()
                                    .tint(accent.ink)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(DesignTokens.Typography.Expressive.glyph)
                                    .foregroundStyle(hasDraft ? DesignTokens.Colors.customerInk : DesignTokens.Colors.textTertiary)
                                    .offset(x: -1, y: 1)
                            }
                        }
                        .frame(width: DesignTokens.Metrics.ledgeRoundControl, height: DesignTokens.Metrics.ledgeRoundControl)
                    }
                    .buttonStyle(BeckonLedgeButtonStyle(hasDraft || isSending ? .pill : .round))
                    .disabled(isSending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("chat.message.send")
                    .accessibilityLabel(isSending ? "Sending message" : "Send message")
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
        .padding(.top, DesignTokens.Spacing.sm)
        .padding(.bottom, DesignTokens.Spacing.sm)
        .background {
            DesignTokens.Colors.appBackground
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DesignTokens.Colors.borderSoft)
                .frame(height: 1)
        }
    }

}

private struct ChatReadOnlyBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            Image(systemName: "lock.fill")
                .font(DesignTokens.Typography.body.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .accessibilityHidden(true)

            Text(message)
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DesignTokens.Spacing.lg)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
                .fill(DesignTokens.Colors.iconTileFill)
        }
        .accessibilityIdentifier("chat.read-only.banner")
    }
}

private struct ChatStatusView: View {
    let store: ChatStore
    let role: UserRole

    var body: some View {
        BeckonGlobalFeedbackForwarder(
            noticeMessage: store.noticeMessage,
            clearNotice: { message in
                guard store.noticeMessage == message else { return }
                store.noticeMessage = nil
            },
            error: errorPrompt
        )
    }

    private var errorPrompt: BeckonGlobalFeedbackError? {
        guard let errorMessage = store.errorMessage else { return nil }
        return BeckonGlobalFeedbackError(
            scope: .page("\(role.rawValue).messages"),
            sourceKey: "\(role.rawValue).messages.error",
            title: "Message update failed",
            message: errorMessage
        )
    }
}

extension ChatConversation {
    func listTitle(for role: UserRole) -> String {
        participantSummary(for: role)
    }

    func shortRecipientName(for role: UserRole) -> String {
        let title = listTitle(for: role)
        return title.split(separator: " ").first.map(String.init) ?? title
    }

}

private enum ChatDateFormatting {
    static func relativeSummary(from value: String) -> String {
        guard let date = GroomingRequestDateFormatting.parsedDate(from: value) else {
            return ""
        }

        let interval = max(0, Date().timeIntervalSince(date))
        if interval < 60 {
            return "Now"
        }

        if interval < 3_600 {
            return "\(Int(interval / 60))m"
        }

        if interval < 86_400 {
            return "\(Int(interval / 3_600))h"
        }

        if interval < 604_800 {
            return "\(Int(interval / 86_400))d"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

private extension UserRole {
    var beckonPrimaryAccent: BeckonPrimaryButtonStyle.Accent {
        switch self {
        case .customer:
            .customer
        case .groomer:
            .groomer
        }
    }

    var beckonLoadingAccent: BeckonLoadingView.Accent {
        switch self {
        case .customer:
            .customer
        case .groomer:
            .groomer
        }
    }

    var beckonSecondaryAccent: BeckonSecondaryButtonStyle.Accent {
        switch self {
        case .customer:
            .customer
        case .groomer:
            .groomer
        }
    }

    var beckonEmptyAccent: BeckonEmptyState<EmptyView>.Accent {
        switch self {
        case .customer:
            .customer
        case .groomer:
            .groomer
        }
    }

}

#if DEBUG
#Preview {
    NavigationStack {
        ChatConversationsView(
            participantID: UUID(),
            role: .customer,
            repository: ChatPreviewRepository()
        )
    }
}

@MainActor
private final class ChatPreviewRepository: ChatRepository {
    private let participantID = UUID()
    private let conversation = ChatConversation(
        id: UUID(),
        customerID: UUID(),
        groomerID: UUID(),
        latestBookingID: UUID(),
        scheduledStart: "2026-06-22T17:00:00Z",
        scheduledEnd: "2026-06-22T18:00:00Z",
        priceEstimate: 95,
        groomerBusinessName: "Fresh Coat Grooming",
        latestMessageSenderID: UUID(),
        latestMessageCreatedAt: "2026-06-21T05:01:00Z",
        latestMessageBody: "See you then.",
        createdAt: "2026-06-21T05:00:00Z",
        updatedAt: "2026-06-21T05:00:00Z"
    )

    func conversations(
        participantID: UUID,
        role: UserRole
    ) async throws -> [ChatConversation] {
        [conversation]
    }

    func messages(conversationID: UUID) async throws -> [ChatMessage] {
        [
            ChatMessage(
                id: UUID(),
                conversationID: conversationID,
                senderID: participantID,
                kind: .text,
                body: "Hi, see you tomorrow.",
                booking: nil,
                createdAt: "2026-06-21T05:01:00Z"
            ),
        ]
    }

    func sendMessage(
        conversationID: UUID,
        senderID: UUID,
        body: String
    ) async throws -> ChatMessage {
        ChatMessage(
            id: UUID(),
            conversationID: conversationID,
            senderID: senderID,
            kind: .text,
            body: body,
            booking: nil,
            createdAt: "2026-06-21T05:02:00Z"
        )
    }

    func messageEvents(
        conversationID: UUID
    ) async throws -> AsyncStream<ChatMessage> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}
#endif

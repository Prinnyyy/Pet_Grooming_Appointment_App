import SwiftUI

nonisolated struct ChatConversationListPresentation: Equatable, Sendable {
    enum Audience: Equatable, Sendable {
        case customer
        case groomer
    }

    enum PageStyle: Equatable, Sendable {
        case messagesCards
    }

    enum RowStyle: Equatable, Sendable {
        case participantCard
    }

    let title = "Messages"
    let audience: Audience
    let pageStyle: PageStyle = .messagesCards
    let rowStyle: RowStyle = .participantCard
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
            DesignTokens.Colors.background
                .ignoresSafeArea()

            conversationsContent
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .background {
            ChatStatusView(store: store, role: role)
        }
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
            await openFocusedConversationIfPossible()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await store.loadConversations()
                await openFocusedConversationIfPossible()
            }
        }
        .onChange(of: focusedBookingID) { _, _ in
            guard focusedBookingID != nil else { return }
            if store.conversations.isEmpty {
                Task {
                    await store.loadConversations()
                    await openFocusedConversationIfPossible()
                }
            } else {
                Task {
                    await openFocusedConversationIfPossible()
                }
            }
        }
    }

    private func openFocusedConversationIfPossible() async {
        guard let bookingID = focusedBookingID,
              let bookingRepository else { return }

        let bookings = try? await bookingRepository.bookings(
            bookingIDs: [bookingID]
        )
        let booking = bookings?.first

        if let booking,
           let conversation = store.conversation(for: booking) {
            focusedConversation = conversation
            focusedBookingID = nil
        } else if !store.isLoadingConversations {
            store.reportMissingConversationForBooking()
            focusedBookingID = nil
        }
    }

    @ViewBuilder
    private var conversationsContent: some View {
        if store.isLoadingConversations, store.conversations.isEmpty {
            ScrollView {
                BeckonLoadingView(
                    title: "Loading Conversations…",
                    message: "Checking accepted bookings for participant chats.",
                    accent: role.beckonLoadingAccent
                )
                .accessibilityIdentifier("chat.conversations.loading")
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.vertical, DesignTokens.Spacing.xl)
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    conversationWorkspace

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
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.top, DesignTokens.Spacing.xl)
                .padding(.bottom, DesignTokens.Spacing.xl + DesignTokens.Spacing.xl)
            }
            .accessibilityIdentifier("chat.conversations.list")
        }
    }

    @ViewBuilder
    private var conversationWorkspace: some View {
        ChatMessagesTitle(presentation.title)

        if store.conversations.isEmpty {
            emptyConversationsState
        } else {
            LazyVStack(spacing: DesignTokens.Spacing.md) {
                ForEach(store.conversations) { conversation in
                    conversationLink(conversation)
                }
            }
        }
    }

    private var emptyConversationsState: some View {
        BeckonEmptyState(
            title: "No Conversations Yet",
            message: "Accepted bookings create participant conversations.",
            systemImage: "message",
            accent: role.beckonEmptyAccent
        )
        .accessibilityIdentifier("chat.conversations.empty")
    }

    private func conversationLink(_ conversation: ChatConversation) -> some View {
        NavigationLink {
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
        .buttonStyle(.plain)
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

    var body: some View {
        BeckonCard {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(
            alignment: .center,
            spacing: DesignTokens.Spacing.lg
        ) {
            BeckonProfileAvatar(
                data: conversation.counterpartAvatarPhotoData,
                tone: role == .customer ? .groomer : .customer,
                size: presentation.avatarSize,
                cornerRadius: 18,
                placeholderSize: 24
            )

            VStack(
                alignment: .leading,
                spacing: DesignTokens.Spacing.sm
            ) {
                Text(conversation.listTitle(for: role))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(store.previewText(for: conversation))
                    .font(DesignTokens.Typography.body)
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
                        .fill(role.chatAccentColor)
                        .frame(width: 10, height: 10)
                        .accessibilityHidden(true)
                }

                Text(ChatDateFormatting.relativeSummary(from: conversation.updatedAt))
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)

                if conversation.isReadOnly() {
                    Text("Read-only")
                        .font(DesignTokens.Typography.caption.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                        .background {
                            Capsule()
                                .fill(DesignTokens.Colors.borderSoft.opacity(0.85))
                        }
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

    var body: some View {
        Text(title)
            .font(.system(size: 36, weight: .bold))
            .foregroundStyle(DesignTokens.Colors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, DesignTokens.Spacing.sm)
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

nonisolated enum ChatComposerKeyboardPresentation {
    static let actionPlacement: BeckonKeyboardActionPlacement = .inputAccessory
    static let includesExplicitDoneAccessory = true
}

private struct ChatThreadView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let participantID: UUID
    let role: UserRole
    let conversation: ChatConversation
    let store: ChatStore
    @State private var draft = ""

    var body: some View {
        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ChatThreadHeader(
                    title: conversation.listTitle(for: role),
                    subtitle: store.canSendMessages(in: conversation) ? "Active Chat" : "Read Only",
                    role: role,
                    avatarPhotoData: conversation.counterpartAvatarPhotoData,
                    dismiss: dismiss
                )

                Divider()
                    .overlay(DesignTokens.Colors.borderSoft)

                threadContent
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom) {
            ChatComposerView(
                draft: $draft,
                isSending: store.isSendingMessage(for: conversation.id),
                isReadOnly: !store.canSendMessages(in: conversation),
                readOnlyMessage: conversation.readOnlyReason,
                accentColor: role.chatAccentColor,
                placeholder: "Message \(conversation.shortRecipientName(for: role))...",
                send: {
                    let body = draft
                    await store.sendMessage(in: conversation, body: body)
                    if store.errorMessage == nil {
                        draft = ""
                    }
                }
            )
        }
        .task(id: conversation.id) {
            await store.loadMessages(for: conversation)
            await store.startMessageSubscription(for: conversation)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                Task {
                    await store.loadMessages(for: conversation)
                    await store.startMessageSubscription(for: conversation)
                }
            case .background:
                store.stopMessageSubscription(for: conversation.id)
            case .inactive:
                break
            @unknown default:
                break
            }
        }
        .onDisappear {
            store.stopMessageSubscription(for: conversation.id)
        }
        .background {
            ChatStatusView(store: store, role: role)
        }
        .scrollDismissesKeyboard(.interactively)
        .beckonKeyboardDoneAccessory()
    }

    @ViewBuilder
    private var threadContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    if !store.canSendMessages(in: conversation) {
                        ChatReadOnlyBanner(message: conversation.readOnlyReason)
                    }

                    if store.isLoadingMessages(for: conversation.id),
                       store.messages(for: conversation.id).isEmpty {
                        BeckonLoadingView(
                            title: "Loading Messages...",
                            message: "Opening this booking conversation.",
                            accent: role.beckonLoadingAccent
                        )
                        .accessibilityIdentifier("chat.messages.loading")
                    } else if store.messages(for: conversation.id).isEmpty {
                        BeckonEmptyState(
                            title: "No Messages Yet",
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
                                title: "Load Earlier Messages",
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
                .padding(.bottom, DesignTokens.Spacing.xl * 2)
            }
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
}

private struct ChatThreadHeader: View {
    let title: String
    let subtitle: String
    let role: UserRole
    let avatarPhotoData: Data?
    let dismiss: DismissAction

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.lg) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            BeckonProfileAvatar(
                data: avatarPhotoData,
                tone: role == .customer ? .groomer : .customer,
                size: 64,
                cornerRadius: 18
            )

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                HStack(spacing: DesignTokens.Spacing.xs) {
                    Circle()
                        .fill(role.chatAccentColor)
                        .frame(width: 9, height: 9)
                        .accessibilityHidden(true)

                    Text(subtitle)
                        .font(DesignTokens.Typography.body.weight(.semibold))
                        .foregroundStyle(role.chatAccentColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
        .padding(.top, DesignTokens.Spacing.lg)
        .padding(.bottom, DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.surface.opacity(0.92))
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

    private var textRow: some View {
        HStack(alignment: .bottom) {
            if isOutgoing {
                Spacer(minLength: 82)
            }

            VStack(alignment: isOutgoing ? .trailing : .leading, spacing: DesignTokens.Spacing.xs) {
                Text(message.body ?? "")
                    .font(.body.weight(.medium))
                    .foregroundStyle(isOutgoing ? DesignTokens.Colors.surface : DesignTokens.Colors.textPrimary)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.vertical, DesignTokens.Spacing.md)
                    .background {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(isOutgoing ? role.chatAccentColor : DesignTokens.Colors.surfaceRaised)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(isOutgoing ? Color.clear : DesignTokens.Colors.borderSoft, lineWidth: 1)
                    }
                    .beckonShadow(DesignTokens.Shadows.smallCard, isVisible: !isOutgoing)
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
        if let booking = message.booking,
           let bookingStore {
            NavigationLink {
                ChatBookingDetailDestination(
                    bookingID: booking.id,
                    role: role,
                    store: bookingStore
                )
            } label: {
                ChatBookingMessageCard(
                    booking: bookingStore.booking(withID: booking.id) ?? booking,
                    role: role,
                    isOutgoing: isOutgoing
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(
                "chat.message.booking.\(booking.id.uuidString.lowercased())"
            )
        } else {
            BeckonCard {
                Label(
                    "Booking details are unavailable.",
                    systemImage: "calendar.badge.exclamationmark"
                )
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
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

private struct ChatBookingMessageCard: View {
    let booking: Booking
    let role: UserRole
    let isOutgoing: Bool

    var body: some View {
        HStack(alignment: .bottom) {
            if isOutgoing {
                Spacer(minLength: 42)
            }

            BeckonCard(padding: DesignTokens.Spacing.md) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: booking.status.isCancellation
                        ? "calendar.badge.exclamationmark"
                        : "calendar.badge.checkmark")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(role.chatAccentColor)
                        .frame(width: 48, height: 48)
                        .background(role.chatAccentColor.opacity(0.16))
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: DesignTokens.CornerRadius.input,
                                style: .continuous
                            )
                        )
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(booking.status.title)
                            .font(DesignTokens.Typography.headline.weight(.bold))
                            .foregroundStyle(DesignTokens.Colors.textPrimary)

                        Text(booking.scheduledTimeSummary)
                            .font(DesignTokens.Typography.body)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                            .lineLimit(2)

                        Text("Booking \(booking.referenceCode) • \(booking.priceSummary)")
                            .font(DesignTokens.Typography.caption.weight(.semibold))
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(DesignTokens.Typography.headline.weight(.semibold))
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: 360)

            if !isOutgoing {
                Spacer(minLength: 42)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(booking.status.title), \(booking.scheduledTimeSummary), \(booking.priceSummary)"
        )
        .accessibilityHint("Opens booking details")
    }
}

private struct ChatComposerView: View {
    @Binding var draft: String
    let isSending: Bool
    let isReadOnly: Bool
    let readOnlyMessage: String
    let accentColor: Color
    let placeholder: String
    let send: () async -> Void

    var body: some View {
        Group {
            if isReadOnly {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "lock.fill")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .padding(.top, 2)
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
                        .fill(DesignTokens.Colors.borderSoft.opacity(0.62))
                }
                .accessibilityIdentifier("chat.message.read-only")
            } else {
                HStack(alignment: .bottom, spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .frame(width: 52, height: 52)
                        .background(DesignTokens.Colors.borderSoft.opacity(0.72))
                        .clipShape(DesignTokens.Shapes.circular)
                        .accessibilityLabel("Attachments unavailable")

                    TextField(placeholder, text: $draft, axis: .vertical)
                        .font(DesignTokens.Typography.body)
                        .lineLimit(1...4)
                        .padding(.horizontal, DesignTokens.Spacing.lg)
                        .padding(.vertical, DesignTokens.Spacing.md)
                        .background(DesignTokens.Colors.borderSoft.opacity(0.62))
                        .clipShape(Capsule())
                        .accessibilityIdentifier("chat.message.body")

                    Button {
                        Task {
                            await send()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(accentColor)
                                .frame(width: 56, height: 56)
                                .beckonShadow(DesignTokens.Shadows.primaryAction)

                            if isSending {
                                ProgressView()
                                    .tint(DesignTokens.Colors.surface)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(DesignTokens.Typography.cardTitle)
                                    .foregroundStyle(DesignTokens.Colors.surface)
                                    .offset(x: -1, y: 1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isSending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(
                        isSending || !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? 1
                            : 0.58
                    )
                    .accessibilityIdentifier("chat.message.send")
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
        .padding(.vertical, DesignTokens.Spacing.md)
        .background {
            DesignTokens.Colors.appBackground
                .opacity(0.96)
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
                .fill(DesignTokens.Colors.borderSoft.opacity(0.62))
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
            title: "Message Update Failed",
            message: errorMessage
        )
    }
}

private extension ChatConversation {
    func listTitle(for role: UserRole) -> String {
        switch role {
        case .customer:
            let title = participantSummary(for: role)
            return title.localizedCaseInsensitiveContains("groomer ref")
                ? "Assigned Groomer"
                : title
        case .groomer:
            return "Booking Customer"
        }
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

    var chatAccentColor: Color {
        switch self {
        case .customer:
            DesignTokens.Colors.customerAccentStrong
        case .groomer:
            DesignTokens.Colors.groomerAccentDark
        }
    }

    var chatChipTone: BeckonStatusChip.Tone {
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

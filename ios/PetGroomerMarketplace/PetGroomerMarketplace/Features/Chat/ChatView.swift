import SwiftUI

struct ChatConversationsView: View {
    private let participantID: UUID
    private let role: UserRole
    @State private var store: ChatStore

    init(
        participantID: UUID,
        role: UserRole,
        repository: any ChatRepository
    ) {
        self.participantID = participantID
        self.role = role
        _store = State(
            initialValue: ChatStore(
                participantID: participantID,
                role: role,
                repository: repository
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
        .safeAreaInset(edge: .bottom) {
            ChatStatusView(store: store)
        }
        .refreshable {
            await store.loadConversations()
        }
        .task {
            await store.loadConversations()
        }
    }

    @ViewBuilder
    private var conversationsContent: some View {
        if store.isLoadingConversations, store.conversations.isEmpty {
            ScrollView {
                GroomlyLoadingView(
                    title: "Loading Conversations…",
                    message: "Checking accepted bookings for participant chats.",
                    accent: role.groomlyLoadingAccent
                )
                .accessibilityIdentifier("chat.conversations.loading")
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.vertical, DesignTokens.Spacing.xl)
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    CustomerMessagesTitle("Messages")

                    if store.conversations.isEmpty {
                        GroomlyEmptyState(
                            title: "No Conversations Yet",
                            message: "Accepted bookings create participant conversations.",
                            systemImage: "message",
                            accent: role.groomlyEmptyAccent
                        )
                        .accessibilityIdentifier("chat.conversations.empty")
                    } else {
                        LazyVStack(spacing: DesignTokens.Spacing.md) {
                            ForEach(store.conversations) { conversation in
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
                                        role: role
                                    )
                                }
                                .buttonStyle(.plain)
                            }
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
}

private struct ChatConversationRow: View {
    let conversation: ChatConversation
    let role: UserRole

    var body: some View {
        GroomlyCard {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.lg) {
                ChatConversationAvatar(
                    title: conversation.listTitle(for: role),
                    role: role
                )

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text(conversation.listTitle(for: role))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(conversation.previewLine)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: DesignTokens.Spacing.sm) {
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
    }
}

private struct ChatConversationAvatar: View {
    let title: String
    let role: UserRole

    var body: some View {
        Text(initial)
            .font(.title3.weight(.bold))
            .foregroundStyle(role.chatAccentColor)
            .frame(width: 64, height: 64)
            .background(role.chatAccentColor.opacity(0.28))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .accessibilityHidden(true)
    }

    private var initial: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "•" }
        return String(first).uppercased()
    }
}

private struct CustomerMessagesTitle: View {
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

private struct ChatThreadView: View {
    let participantID: UUID
    let role: UserRole
    let conversation: ChatConversation
    let store: ChatStore
    @State private var draft = ""

    var body: some View {
        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()

            threadContent
        }
        .navigationTitle("Booking \(conversation.bookingReferenceCode)")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            ChatComposerView(
                draft: $draft,
                isSending: store.isSendingMessage(for: conversation.id),
                isReadOnly: !store.canSendMessages(in: conversation),
                readOnlyMessage: conversation.readOnlyReason,
                accent: role.groomlyPrimaryAccent,
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
        }
        .background {
            GroomlyNoticeForwarder(message: store.noticeMessage) { message in
                guard store.noticeMessage == message else { return }
                store.noticeMessage = nil
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .accessibilityIdentifier("chat.thread")
    }

    @ViewBuilder
    private var threadContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                GroomlySectionHeader(
                    conversation.participantSummary(for: role),
                    subtitle: conversation.bookingContextSummary
                )

                if !store.canSendMessages(in: conversation) {
                    ChatReadOnlyBanner(message: conversation.readOnlyReason)
                }

                if store.isLoadingMessages(for: conversation.id),
                   store.messages(for: conversation.id).isEmpty {
                    GroomlyLoadingView(
                        title: "Loading Messages…",
                        message: "Opening this booking conversation.",
                        accent: role.groomlyLoadingAccent
                    )
                    .accessibilityIdentifier("chat.messages.loading")
                } else if store.messages(for: conversation.id).isEmpty {
                    GroomlyEmptyState(
                        title: "No Messages Yet",
                        message: "Send the first message for this booking.",
                        systemImage: "bubble.left.and.bubble.right",
                        accent: role.groomlyEmptyAccent
                    )
                    .accessibilityIdentifier("chat.messages.empty")
                } else {
                    ForEach(store.messages(for: conversation.id)) { message in
                        ChatMessageRow(
                            message: message,
                            isOutgoing: message.isSentBy(participantID),
                            role: role
                        )
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.vertical, DesignTokens.Spacing.lg)
        }
    }
}

private struct ChatMessageRow: View {
    let message: ChatMessage
    let isOutgoing: Bool
    let role: UserRole

    var body: some View {
        HStack(alignment: .bottom) {
            if isOutgoing {
                Spacer(minLength: DesignTokens.Spacing.xl + DesignTokens.Spacing.lg)
            }

            VStack(alignment: isOutgoing ? .trailing : .leading, spacing: DesignTokens.Spacing.xs) {
                Text(message.body)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(isOutgoing ? DesignTokens.Colors.surface : DesignTokens.Colors.textPrimary)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.vertical, DesignTokens.Spacing.md)
                    .background {
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
                            .fill(isOutgoing ? role.chatAccentColor : DesignTokens.Colors.surfaceRaised)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.input, style: .continuous)
                            .stroke(isOutgoing ? Color.clear : DesignTokens.Colors.borderSoft, lineWidth: 1)
                    }
                    .groomlyShadow(DesignTokens.Shadows.smallCard, isVisible: !isOutgoing)

                Text(message.sentAtSummary)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
            .accessibilityElement(children: .combine)

            if !isOutgoing {
                Spacer(minLength: DesignTokens.Spacing.xl + DesignTokens.Spacing.lg)
            }
        }
    }
}

private struct ChatComposerView: View {
    @Binding var draft: String
    let isSending: Bool
    let isReadOnly: Bool
    let readOnlyMessage: String
    let accent: GroomlyPrimaryButtonStyle.Accent
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
                    TextField("Message", text: $draft, axis: .vertical)
                        .lineLimit(1...4)
                        .groomlyFormField()
                        .accessibilityIdentifier("chat.message.body")

                    Button {
                        Task {
                            await send()
                        }
                    } label: {
                        if isSending {
                            ProgressView()
                                .tint(DesignTokens.Colors.surface)
                        } else {
                            Label("Send", systemImage: "paperplane.fill")
                        }
                    }
                    .buttonStyle(GroomlyPrimaryButtonStyle(accent: accent, isFullWidth: false))
                    .disabled(isSending)
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

    var body: some View {
        VStack(spacing: 0) {
            GroomlyNoticeForwarder(message: store.noticeMessage) { message in
                guard store.noticeMessage == message else { return }
                store.noticeMessage = nil
            }

            if let errorMessage = store.errorMessage {
                GroomlyErrorBanner(
                    title: "Message Update Failed",
                    message: errorMessage
                )
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .animation(.easeInOut(duration: 0.24), value: store.errorMessage)
            }
        }
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

    var previewLine: String {
        if isReadOnly() {
            return "Booking chat is read-only."
        }

        if let scheduledTimeSummary {
            return "\(bookingStatusTitle) · \(scheduledTimeSummary)"
        }

        if let priceSummary {
            return "\(bookingStatusTitle) · \(priceSummary)"
        }

        return bookingStatusTitle
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
    var groomlyPrimaryAccent: GroomlyPrimaryButtonStyle.Accent {
        switch self {
        case .customer:
            .customer
        case .groomer:
            .groomer
        }
    }

    var groomlyLoadingAccent: GroomlyLoadingView.Accent {
        switch self {
        case .customer:
            .customer
        case .groomer:
            .groomer
        }
    }

    var groomlyEmptyAccent: GroomlyEmptyState<EmptyView>.Accent {
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
            DesignTokens.Colors.customerPrimaryDark
        case .groomer:
            DesignTokens.Colors.groomerAccentDark
        }
    }

    var chatChipTone: GroomlyStatusChip.Tone {
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
        bookingID: UUID(),
        requestID: UUID(),
        customerID: UUID(),
        groomerID: UUID(),
        scheduledStart: "2026-06-22T17:00:00Z",
        scheduledEnd: "2026-06-22T18:00:00Z",
        priceEstimate: 95,
        groomerBusinessName: "Fresh Coat Grooming",
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
                body: "Hi, see you tomorrow.",
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
            body: body,
            createdAt: "2026-06-21T05:02:00Z"
        )
    }
}
#endif

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
        .navigationTitle("Messages")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await store.loadConversations()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(store.isBusy)
            }
        }
        .safeAreaInset(edge: .bottom) {
            ChatStatusView(store: store)
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
                    title: "Loading conversations…",
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
                    if store.conversations.isEmpty {
                        GroomlyEmptyState(
                            title: "No conversations yet",
                            message: "Accepted bookings create participant conversations.",
                            systemImage: "message",
                            accent: role.groomlyEmptyAccent
                        )
                        .accessibilityIdentifier("chat.conversations.empty")
                    } else {
                        GroomlySectionHeader(
                            "Conversations",
                            subtitle: "Keep booking details and participant messages together."
                        )

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
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.vertical, DesignTokens.Spacing.lg)
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
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                Image(systemName: "message.fill")
                    .font(DesignTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(role.chatAccentColor)
                    .frame(
                        width: DesignTokens.Spacing.xl + DesignTokens.Spacing.sm,
                        height: DesignTokens.Spacing.xl + DesignTokens.Spacing.sm
                    )
                    .background(role.chatAccentColor.opacity(0.14))
                    .clipShape(DesignTokens.Shapes.circular)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                        Text(conversation.participantSummary(for: role))
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(DesignTokens.Colors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        GroomlyStatusChip(
                            "Booking",
                            systemImage: "calendar",
                            tone: role.chatChipTone
                        )
                    }

                    if let scheduledTimeSummary = conversation.scheduledTimeSummary {
                        Text(scheduledTimeSummary)
                            .font(DesignTokens.Typography.body)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }

                    Text(conversation.bookingReferenceAndPriceSummary)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
            }
        }
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

                if store.isLoadingMessages(for: conversation.id),
                   store.messages(for: conversation.id).isEmpty {
                    GroomlyLoadingView(
                        title: "Loading messages…",
                        message: "Opening this booking conversation.",
                        accent: role.groomlyLoadingAccent
                    )
                    .accessibilityIdentifier("chat.messages.loading")
                } else if store.messages(for: conversation.id).isEmpty {
                    GroomlyEmptyState(
                        title: "No messages yet",
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
    let accent: GroomlyPrimaryButtonStyle.Accent
    let send: () async -> Void

    var body: some View {
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

private struct ChatStatusView: View {
    let store: ChatStore

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            if let noticeMessage = store.noticeMessage {
                ChatNoticeView(message: noticeMessage)
            }

            if let errorMessage = store.errorMessage {
                GroomlyErrorBanner(
                    title: "Message update failed",
                    message: errorMessage
                )
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(.ultraThinMaterial)
    }
}

private struct ChatNoticeView: View {
    let message: String

    var body: some View {
        GroomlyCard(padding: DesignTokens.Spacing.md) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(DesignTokens.Typography.body.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.success)
                    .accessibilityHidden(true)

                Text(message)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
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

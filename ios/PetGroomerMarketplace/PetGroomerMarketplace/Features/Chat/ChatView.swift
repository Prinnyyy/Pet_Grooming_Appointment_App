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
        Group {
            if store.isLoadingConversations, store.conversations.isEmpty {
                ProgressView("Loading conversations…")
                    .accessibilityIdentifier("chat.conversations.loading")
            } else {
                List {
                    if store.conversations.isEmpty {
                        Section {
                            ContentUnavailableView(
                                "No conversations yet",
                                systemImage: "message",
                                description: Text("Accepted bookings create participant conversations.")
                            )
                            .accessibilityIdentifier("chat.conversations.empty")
                        }
                    } else {
                        Section("Conversations") {
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
                            }
                        }
                    }
                }
                .accessibilityIdentifier("chat.conversations.list")
            }
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
}

private struct ChatConversationRow: View {
    let conversation: ChatConversation
    let role: UserRole

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(conversation.participantSummary(for: role))
                .font(.headline)

            if let scheduledTimeSummary = conversation.scheduledTimeSummary {
                Text(scheduledTimeSummary)
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.Colors.secondaryText)
            }

            Text(conversation.bookingReferenceAndPriceSummary)
                .font(.caption)
                .foregroundStyle(DesignTokens.Colors.secondaryText)
        }
        .padding(.vertical, 4)
    }
}

private struct ChatThreadView: View {
    let participantID: UUID
    let role: UserRole
    let conversation: ChatConversation
    let store: ChatStore
    @State private var draft = ""

    var body: some View {
        List {
            Section {
                if store.isLoadingMessages(for: conversation.id),
                   store.messages(for: conversation.id).isEmpty {
                    ProgressView("Loading messages…")
                        .accessibilityIdentifier("chat.messages.loading")
                } else if store.messages(for: conversation.id).isEmpty {
                    ContentUnavailableView(
                        "No messages yet",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Send the first message for this booking.")
                    )
                    .accessibilityIdentifier("chat.messages.empty")
                } else {
                    ForEach(store.messages(for: conversation.id)) { message in
                        ChatMessageRow(
                            message: message,
                            isOutgoing: message.isSentBy(participantID)
                        )
                    }
                }
        } header: {
            Text(conversation.participantSummary(for: role))
        } footer: {
            Text(conversation.bookingContextSummary)
        }
        }
        .navigationTitle("Booking \(conversation.bookingReferenceCode)")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            ChatComposerView(
                draft: $draft,
                isSending: store.isSendingMessage(for: conversation.id),
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
        .accessibilityIdentifier("chat.thread")
    }
}

private struct ChatMessageRow: View {
    let message: ChatMessage
    let isOutgoing: Bool

    var body: some View {
        HStack {
            if isOutgoing {
                Spacer(minLength: 40)
            }

            VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 4) {
                Text(message.body)
                    .padding(10)
                    .foregroundStyle(isOutgoing ? .white : DesignTokens.Colors.primaryText)
                    .background(isOutgoing ? Color.accentColor : DesignTokens.Colors.surface)
                    .clipShape(
                        RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.card)
                    )

                Text(message.sentAtSummary)
                    .font(.caption2)
                    .foregroundStyle(DesignTokens.Colors.secondaryText)
            }

            if !isOutgoing {
                Spacer(minLength: 40)
            }
        }
        .listRowSeparator(.hidden)
    }
}

private struct ChatComposerView: View {
    @Binding var draft: String
    let isSending: Bool
    let send: () async -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message", text: $draft, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .accessibilityIdentifier("chat.message.body")

            Button {
                Task {
                    await send()
                }
            } label: {
                if isSending {
                    ProgressView()
                } else {
                    Label("Send", systemImage: "paperplane.fill")
                }
            }
            .disabled(isSending)
            .accessibilityIdentifier("chat.message.send")
        }
        .padding(DesignTokens.Spacing.standard)
        .background(.thinMaterial)
    }
}

private struct ChatStatusView: View {
    let store: ChatStore

    var body: some View {
        VStack(spacing: 8) {
            if let noticeMessage = store.noticeMessage {
                Text(noticeMessage)
                    .font(.footnote)
                    .foregroundStyle(DesignTokens.Colors.secondaryText)
            }

            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DesignTokens.Spacing.standard)
        .padding(.vertical, 8)
        .background(.thinMaterial)
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

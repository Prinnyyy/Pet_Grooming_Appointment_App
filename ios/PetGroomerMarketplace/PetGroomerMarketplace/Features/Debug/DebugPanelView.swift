import SwiftUI
import UIKit

struct DebugPanelView: View {
    @Environment(\.appDebugEventRecorder) private var debugRecorder
    @Environment(\.groomlyFeedbackCenter) private var feedbackCenter
    let diagnostics: DebugDiagnostics
    @State private var exportNotice: String?

    var body: some View {
        ZStack {
            DesignTokens.Colors.background
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    DebugPanelSection(title: "Runtime") {
                        row("Build", diagnostics.buildConfiguration)
                        row("Bundle", diagnostics.bundleIdentifier)
                        row("Role", diagnostics.role)
                        row("User ref", diagnostics.userReference)

                        if let emailDomain = diagnostics.emailDomain {
                            row("Email domain", emailDomain)
                        }
                    }

                    DebugPanelSection(title: "Supabase") {
                        row("URL scheme", diagnostics.supabaseScheme)
                        row("Host", diagnostics.supabaseHost)
                        row("Publishable key", diagnostics.publishableKeyStatus)
                    }

                    DebugPanelSection(title: "Safety") {
                        Label(
                            diagnostics.sensitiveDataNotice,
                            systemImage: "lock.shield"
                        )
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityElement(children: .combine)
                    }

                    DebugPanelSection(title: "Current Feedback") {
                        if let snapshot = feedbackCenter?.debugSnapshot {
                            if let active = snapshot.active {
                                DebugPanelFeedbackPromptView(
                                    label: "Active",
                                    prompt: active
                                )
                            } else {
                                row("Active", "None")
                            }

                            row("Queued", "\(snapshot.queued.count)")
                            ForEach(snapshot.queued) { prompt in
                                DebugPanelFeedbackPromptView(
                                    label: "Queued",
                                    prompt: prompt
                                )
                            }
                        } else {
                            row("Feedback center", "Unavailable")
                        }
                    }

                    DebugPanelSection(title: "Recent Events") {
                        if recentEvents.isEmpty {
                            row("Events", "No debug events recorded.")
                        } else {
                            ForEach(recentEvents) { event in
                                DebugPanelEventRow(event: event)
                            }
                        }
                    }

                    DebugPanelSection(title: "Errors Only") {
                        if errorEvents.isEmpty {
                            row("Errors", "No errors or cancellations recorded.")
                        } else {
                            ForEach(errorEvents) { event in
                                DebugPanelEventRow(event: event)
                            }
                        }
                    }

                    DebugPanelSection(title: "Tools") {
                        Button {
                            exportRecentSnapshot()
                        } label: {
                            Label("Copy Recent Snapshot", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(GroomlySecondaryButtonStyle(accent: .neutral))

                        Button(role: .destructive) {
                            debugRecorder?.clear()
                            exportNotice = "Logs cleared."
                        } label: {
                            Label("Clear Logs", systemImage: "trash")
                        }
                        .buttonStyle(GroomlySecondaryButtonStyle(accent: .neutral))

                        if let exportNotice {
                            Text(exportNotice)
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(DesignTokens.Colors.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
                .padding(.vertical, DesignTokens.Spacing.lg)
            }
        }
        .navigationTitle("Debug Console")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("debug.panel")
    }

    private var recentEvents: [AppDebugEvent] {
        Array((debugRecorder?.events ?? []).suffix(200).reversed())
    }

    private var errorEvents: [AppDebugEvent] {
        Array((debugRecorder?.recentErrorsAndCancellations ?? []).suffix(100).reversed())
    }

    private func row(_ title: String, _ value: String) -> some View {
        DebugPanelRow(title: title, value: value)
    }

    private func exportRecentSnapshot() {
        let cutoff = Date().addingTimeInterval(-5 * 60)
        let snapshot = debugRecorder?.exportSnapshot(since: cutoff) ?? ""
        UIPasteboard.general.string = snapshot
        exportNotice = snapshot.isEmpty
            ? "No events in the last 5 minutes."
            : "Copied recent JSONL snapshot."
    }
}

private struct DebugPanelSection<Content: View>: View {
    let title: String
    let content: Content

    init(
        title: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            GroomlySectionHeader(title)

            GroomlyCard {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    content
                }
            }
        }
    }
}

private struct DebugPanelRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(title)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)

            Text(value)
                .font(DesignTokens.Typography.body.monospaced())
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct DebugPanelFeedbackPromptView: View {
    let label: String
    let prompt: GroomlyFeedbackDebugPromptSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text("\(label) \(prompt.kind)")
                .font(DesignTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.textSecondary)

            Text(prompt.title)
                .font(DesignTokens.Typography.body.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let message = prompt.message {
                Text(message)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(
                [
                    prompt.scope.map { "scope=\($0)" },
                    prompt.sourceKey.map { "source=\($0)" },
                ]
                    .compactMap { $0 }
                    .joined(separator: " ")
            )
            .font(DesignTokens.Typography.caption.monospaced())
            .foregroundStyle(DesignTokens.Colors.textSecondary)
            .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DebugPanelEventRow: View {
    let event: AppDebugEvent

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text(event.level.rawValue.uppercased())
                    .font(DesignTokens.Typography.caption.weight(.bold))
                    .foregroundStyle(color)

                Text(event.category.rawValue)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)

                Spacer(minLength: 0)

                Text(event.timestamp, style: .time)
                    .font(DesignTokens.Typography.caption.monospacedDigit())
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }

            Text(event.source)
                .font(DesignTokens.Typography.body.monospaced())
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            Text(event.message)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(detail)
                .font(DesignTokens.Typography.caption.monospaced())
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var color: Color {
        switch event.level {
        case .debug:
            DesignTokens.Colors.textSecondary
        case .info:
            DesignTokens.Colors.success
        case .warning:
            DesignTokens.Colors.warning
        case .error:
            DesignTokens.Colors.error
        }
    }

    private var detail: String {
        var values = [
            event.scope.map { "scope=\($0)" },
            event.correlationID.map { "correlation=\($0)" },
            event.durationMs.map { "durationMs=\($0)" },
            event.underlyingErrorType.map { type in
                "error=\(type):\(event.underlyingErrorCode ?? "unknown")"
            },
        ].compactMap { $0 }

        values += event.metadata
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }

        return values.joined(separator: " ")
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        DebugPanelView(
            diagnostics: DebugDiagnostics.make(
                session: AuthSessionSnapshot(
                    userID: UUID(),
                    email: "owner@example.com"
                ),
                profile: MarketplaceProfile(
                    userID: UUID(),
                    role: .customer,
                    displayName: "Owner"
                ),
                configuration: nil,
                bundleIdentifier: "com.prinnyyy.PetGroomerMarketplace",
                buildConfiguration: "Debug"
            )
        )
    }
}
#endif

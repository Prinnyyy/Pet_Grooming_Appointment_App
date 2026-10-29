// S-084: the sheet is the app's own page, not a navigation stack with a system title and a "Close" button: our grabber and round
// close button on top, a round symbol and one headline that say which of the five moments this is, the fields with their symbol,
// and the one decision pinned at the bottom. The moment changes in place (the symbol and the words change, the page stays).
import SwiftUI


struct PasswordRecoveryView: View {
    @Bindable var store: AuthenticationStore
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email, newPassword, confirmation
    }

    /// What the page says for the moment the store is in.
    private struct Moment {
        let systemImage: String
        let title: String
        let line: String?
        var isCaution = false
    }

    var body: some View {
        ScrollView {
            BeckonCascade(spacing: DesignTokens.Spacing.xl) {
                header
                if let error = store.recoveryError {
                    BeckonErrorBanner(title: "Password recovery error", message: error)
                        .accessibilityIdentifier("auth.recovery.error")
                }
                fields
                if store.canRetryRecoveryLink {
                    Button {
                        Task { await store.retryRecoveryLink() }
                    } label: {
                        DesignQuietAction(title: "Retry Link", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(BeckonGuardedPlainButtonStyle())
                    .accessibilityIdentifier("auth.recovery.retry-link")
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.screenHorizontal)
            .padding(.top, DesignTokens.Spacing.lg)
            .padding(.bottom, DesignTokens.Spacing.xl)
            .disabled(store.isRecovering)
        }
        .scrollDismissesKeyboard(.interactively)
        .background { BeckonExpressiveBackdrop() }
        .safeAreaInset(edge: .top, spacing: 0) {
            DesignSheetBar(title: "Password recovery", closeIdentifier: "auth.recovery.close", isCloseDisabled: store.isRecovering) {
                Task { await store.closePasswordRecovery() }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { decisionBar }
        .environment(\.beckonCustomerDesign, true)
        .interactiveDismissDisabled(store.isRecovering)
        .designSheetStyle()
        .beckonEntranceRhythm(.detail)
        .beckonAnimation(DesignTokens.Motion.swap, value: store.recoveryState)
    }

    // MARK: What the page says

    private var moment: Moment {
        switch store.recoveryState {
        case .emailSent:
            Moment(systemImage: "envelope.open.fill", title: "Check your email",
                line: "If an account exists for this email, a reset link will arrive shortly. Open it on this device.")
        case .invalidLink:
            Moment(systemImage: "link.badge.plus", title: "Request a new link", line: nil, isCaution: true)
        case let .newPassword(session):
            Moment(systemImage: "lock.rotation", title: "New password", line: session.email)
        case .complete:
            Moment(systemImage: "checkmark.seal.fill", title: "Password changed",
                line: "Use your new password the next time you sign in.")
        case .request, nil:
            Moment(systemImage: "key.fill", title: "Reset password", line: "We will email you a link to choose a new one.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            DesignIconDisc(systemImage: moment.systemImage, size: .large,
                font: DesignTokens.Typography.Expressive.title, tone: moment.isCaution ? .caution : .solid)

            Text(moment.title)
                .font(DesignTokens.Typography.Expressive.display)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if let line = moment.line {
                Text(line)
                    .designSupportingText()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Fields

    @ViewBuilder
    private var fields: some View {
        switch store.recoveryState {
        case .newPassword:
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                labeledField("New password") {
                    fieldRow("lock.fill") {
                        SecureField("New password", text: $store.recoveryPassword)
                            .textContentType(.newPassword)
                            .submitLabel(.next)
                            .focused($focusedField, equals: .newPassword)
                            .onSubmit { focusedField = .confirmation }
                            .accessibilityIdentifier("auth.recovery.password")
                    } focus: { focusedField = .newPassword }
                }
                labeledField("Confirm password") {
                    fieldRow("lock.fill") {
                        SecureField("Confirm password", text: $store.recoveryPasswordConfirmation)
                            .textContentType(.newPassword)
                            .submitLabel(.go)
                            .focused($focusedField, equals: .confirmation)
                            .onSubmit { Task { await store.saveRecoveredPassword() } }
                            .accessibilityIdentifier("auth.recovery.confirmation")
                    } focus: { focusedField = .confirmation }
                }
            }
        case .complete:
            EmptyView()
        default:
            labeledField("Email") {
                fieldRow("envelope.fill") {
                    TextField("Email", text: $store.recoveryEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.send)
                        .focused($focusedField, equals: .email)
                        .onSubmit { Task { await store.requestPasswordRecovery() } }
                        .accessibilityIdentifier("auth.recovery.email")
                } focus: { focusedField = .email }
            }
        }
    }

    private func labeledField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .font(DesignTokens.Typography.Expressive.emphasis)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A field with its symbol; a tap anywhere on the row focuses the input.
    private func fieldRow<Input: View>(_ systemImage: String, @ViewBuilder input: () -> Input, focus: @escaping () -> Void) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.Expressive.emphasis)
                .dynamicTypeSize(...DynamicTypeSize.xLarge)
                .foregroundStyle(DesignTokens.Colors.customerDeep)
                .frame(width: DesignTokens.Spacing.xl)
                .accessibilityHidden(true)
            input()
        }
        .beckonFormField()
        .contentShape(Rectangle())
        .onTapGesture(perform: focus)
    }

    // MARK: The decision

    private var decisionBar: some View {
        BeckonPinnedBar {
            Button {
                Task { await decide() }
            } label: {
                DesignActionLabel(title: store.isRecovering ? "Please wait…" : decision.title,
                    systemImage: decision.systemImage, isBusy: store.isRecovering)
            }
            .buttonStyle(BeckonLedgeButtonStyle(.pill))
            .disabled(store.isRecovering)
            .accessibilityIdentifier(decision.identifier)
        }
    }

    private var decision: (title: String, systemImage: String, identifier: String) {
        switch store.recoveryState {
        case .newPassword: ("Save Password", "checkmark", "auth.recovery.save")
        case .complete: ("Done", "checkmark", "auth.recovery.done")
        case .emailSent: ("Resend Email", "envelope.fill", "auth.recovery.send")
        default: ("Send Reset Email", "envelope.fill", "auth.recovery.send")
        }
    }

    private func decide() async {
        focusedField = nil
        switch store.recoveryState {
        case .newPassword: await store.saveRecoveredPassword()
        case .complete: await store.closePasswordRecovery()
        default: await store.requestPasswordRecovery()
        }
    }
}

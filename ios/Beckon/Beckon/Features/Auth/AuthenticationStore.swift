import Foundation
import Observation

enum AuthenticationRootState: Equatable {
    case loading
    case signedOut
    case signedIn(AuthSessionSnapshot)
}

enum AuthenticationMode: String, CaseIterable, Identifiable {
    case signIn = "Sign In"
    case signUp = "Create Account"

    var id: Self { self }
}

enum PasswordRecoveryState: Equatable {
    case request, emailSent, invalidLink, complete
    case newPassword(AuthSessionSnapshot)
}

#if DEBUG
enum DebugQuickLoginAccount: CaseIterable, Identifiable {
    case customer
    case groomer

    var id: Self { self }

    var title: String {
        switch self {
        case .customer:
            "Customer"
        case .groomer:
            "Groomer"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .customer:
            "auth.debug-login.customer"
        case .groomer:
            "auth.debug-login.groomer"
        }
    }

    var systemImage: String {
        switch self {
        case .customer:
            "person.fill"
        case .groomer:
            "scissors"
        }
    }

    var email: String {
        switch self {
        case .customer:
            "prinnyyyyy@gmail.com"
        case .groomer:
            "liafenyua@gmail.com"
        }
    }

    var password: String {
        "Lian532911"
    }
}
#endif

@MainActor
@Observable
final class AuthenticationStore {
    private let repository: any AuthSessionRepository
    private let clearsSessionBeforeRestore: Bool
    private let localAccountCleanup: (UUID) -> Void
    private let reminderScheduler: any AppointmentReminderScheduling
    private var didRestoreSession = false
    private var isObservingSession = false

    var rootState: AuthenticationRootState = .loading {
        didSet {
            if case let .signedIn(session) = rootState { reminderScheduler.setAccount(session.userID) }
            else { reminderScheduler.setAccount(nil) }
        }
    }
    var mode: AuthenticationMode = .signIn {
        didSet {
            guard mode != oldValue else { return }
            errorMessage = nil
            noticeMessage = nil
            passwordConfirmation = ""
        }
    }
    var email = ""
    var password = ""
    var passwordConfirmation = ""
    var isSubmitting = false
    var errorMessage: String?
    var noticeMessage: String?
    var recoveryState: PasswordRecoveryState?
    var recoveryEmail = ""
    var recoveryPassword = ""
    var recoveryPasswordConfirmation = ""
    var recoveryError: String?
    private(set) var isRecovering = false
    private var recoveryOperation = UUID()
    private var recoveryPasswordWasUpdated = false
    private var recoveryRetryURL: URL?

    init(
        repository: any AuthSessionRepository,
        clearsSessionBeforeRestore: Bool = false,
        localAccountCleanup: @escaping (UUID) -> Void = { _ in },
        reminderScheduler: any AppointmentReminderScheduling = AppointmentReminderScheduler.shared
    ) {
        self.repository = repository
        self.clearsSessionBeforeRestore = clearsSessionBeforeRestore
        self.localAccountCleanup = localAccountCleanup
        self.reminderScheduler = reminderScheduler
    }

    func start() async {
        guard !isObservingSession else { return }
        isObservingSession = true
        defer { isObservingSession = false }

        if !didRestoreSession {
            didRestoreSession = true
            if let session = repository.recoverySession() {
                recoveryState = session.isExpired ? .invalidLink : .newPassword(session)
            }
            if clearsSessionBeforeRestore {
                try? await repository.signOut()
                apply(nil)
            } else {
                apply(repository.currentSession())
            }
        }

        let stateChanges = await repository.sessionStateChanges()
        for await session in stateChanges {
            guard !Task.isCancelled else { return }
            apply(session)
        }
    }

    func submit() async {
        guard !isSubmitting else { return }

        errorMessage = nil
        noticeMessage = nil

        let normalizedEmail = email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard isValidEmail(normalizedEmail) else {
            errorMessage = "Enter a valid email address."
            return
        }

        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters."
            return
        }

        if mode == .signUp, password != passwordConfirmation {
            errorMessage = "Passwords do not match."
            return
        }

        email = normalizedEmail
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            switch mode {
            case .signIn:
                let session = try await repository.signIn(
                    email: normalizedEmail,
                    password: password
                )
                clearPasswords()
                rootState = .signedIn(session)

            case .signUp:
                let outcome = try await repository.signUp(
                    email: normalizedEmail,
                    password: password,
                    redirectTo: AuthCallbackConfiguration.callbackURL
                )
                clearPasswords()

                switch outcome {
                case let .signedIn(session):
                    rootState = .signedIn(session)
                case let .confirmationRequired(confirmedEmail):
                    email = confirmedEmail
                    rootState = .signedOut
                    noticeMessage =
                        "Check your email to confirm your account, then sign in."
                }
            }
        } catch let error as AuthSessionError {
            errorMessage = message(for: error)
        } catch {
            errorMessage = message(for: .unavailable)
        }
    }

    func handleAuthCallback(_ url: URL) async {
        if AuthCallbackConfiguration.isRecoveryCallback(url) {
            await handlePasswordRecoveryCallback(url)
            return
        }
        guard !isSubmitting else { return }

        errorMessage = nil
        noticeMessage = nil

        guard AuthCallbackConfiguration.isSupportedCallback(url) else {
            errorMessage = message(for: .invalidCallback)
            return
        }

        if AuthCallbackConfiguration.callbackErrorParameters(from: url).isEmpty == false {
            errorMessage = message(for: .invalidCallback)
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let session = try await repository.handleAuthCallback(url)
            clearPasswords()
            rootState = .signedIn(session)
            noticeMessage = "Email confirmed. You are signed in."
        } catch let error as AuthSessionError {
            errorMessage = message(for: error)
        } catch {
            errorMessage = message(for: .invalidCallback)
        }
    }

    func beginPasswordRecovery() async {
        guard !isRecovering else { return }
        isRecovering = true
        defer { isRecovering = false }
        recoveryError = nil
        recoveryEmail = email
        recoveryState = .request
        clearPasswords()
        do {
            try await repository.endPasswordRecovery()
            recoveryPassword = ""
            recoveryPasswordConfirmation = ""
            recoveryPasswordWasUpdated = false
            recoveryRetryURL = nil
        } catch { recoveryError = "Could not close the previous reset session. Try again." }
    }

    func requestPasswordRecovery() async {
        guard !isRecovering else { return }
        let normalized = recoveryEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard isValidEmail(normalized) else { recoveryError = "Enter a valid email address."; return }
        recoveryEmail = normalized
        recoveryError = nil
        isRecovering = true
        defer { isRecovering = false }
        do {
            try await repository.endPasswordRecovery()
            try await repository.requestPasswordRecovery(email: normalized, redirectTo: AuthCallbackConfiguration.recoveryURL)
            try Task.checkCancellation()
            recoveryState = .emailSent
        } catch {
            recoveryError = recoveryMessage(error)
        }
    }

    func handlePasswordRecoveryCallback(_ url: URL) async {
        guard !isRecovering else { return }
        recoveryOperation = UUID()
        let operation = recoveryOperation
        isRecovering = true
        recoveryError = nil
        recoveryState = .invalidLink
        recoveryRetryURL = nil
        recoveryPasswordWasUpdated = false
        recoveryPassword = ""
        recoveryPasswordConfirmation = ""
        defer { isRecovering = false }
        do {
            guard AuthCallbackConfiguration.isRecoveryCallback(url),
                  AuthCallbackConfiguration.callbackErrorParameters(from: url).isEmpty else { throw AuthSessionError.invalidCallback }
            let session = try await repository.handleRecoveryCallback(url)
            try Task.checkCancellation()
            guard operation == recoveryOperation, !session.isExpired else { throw AuthSessionError.invalidCallback }
            recoveryState = .newPassword(session)
        } catch {
            if error as? AuthSessionError == .networkUnavailable { recoveryRetryURL = url }
            recoveryError = recoveryMessage(error)
        }
    }

    var canRetryRecoveryLink: Bool { recoveryRetryURL != nil }

    func retryRecoveryLink() async {
        guard let recoveryRetryURL else { return }
        await handlePasswordRecoveryCallback(recoveryRetryURL)
    }

    func saveRecoveredPassword() async {
        guard !isRecovering, case let .newPassword(session) = recoveryState else { return }
        if !recoveryPasswordWasUpdated {
            guard recoveryPassword.count >= 8 else { recoveryError = "Password must be at least 8 characters."; return }
            guard recoveryPassword == recoveryPasswordConfirmation else { recoveryError = "Passwords do not match."; return }
        }
        isRecovering = true
        recoveryError = nil
        defer { isRecovering = false }
        do {
            if !recoveryPasswordWasUpdated {
                try await repository.updateRecoveredPassword(recoveryPassword, userID: session.userID)
                recoveryPasswordWasUpdated = true
                recoveryPassword = ""
                recoveryPasswordConfirmation = ""
            }
            // A cleanup retry must not repeat an already successful password change.
            try await repository.endPasswordRecovery()
            recoveryState = .complete
            recoveryRetryURL = nil
        } catch {
            recoveryError = recoveryPasswordWasUpdated
                ? "Your password changed, but the reset session could not be closed. Retry to finish."
                : recoveryMessage(error)
            if error as? AuthSessionError == .invalidCallback, !recoveryPasswordWasUpdated {
                recoveryState = .invalidLink
            }
        }
    }

    func closePasswordRecovery() async {
        guard !isRecovering else { return }
        isRecovering = true
        defer { isRecovering = false }
        do {
            try await repository.endPasswordRecovery()
            recoveryOperation = UUID()
            recoveryState = nil
            recoveryError = nil
            recoveryRetryURL = nil
            recoveryPassword = ""
            recoveryPasswordConfirmation = ""
            recoveryPasswordWasUpdated = false
        } catch { recoveryError = "Could not close the reset session. Try again." }
    }

    private func recoveryMessage(_ error: any Error) -> String {
        switch error as? AuthSessionError {
        case .networkUnavailable: "Check your connection and try again."
        case .rateLimited: "Too many requests. Wait a minute and try again."
        case .weakPassword: "Choose a stronger password and try again."
        case .invalidCallback: "This reset link is expired, already used, or belongs to another device. Request a new email here."
        default: "Password recovery could not be completed. Try again."
        }
    }

    #if DEBUG
    func signInWithDebugAccount(_ account: DebugQuickLoginAccount) async {
        mode = .signIn
        email = account.email
        password = account.password
        passwordConfirmation = ""
        await submit()
    }
    #endif

    func signOut() async {
        guard !isSubmitting else { return }

        let signedInEmail: String?
        if case let .signedIn(session) = rootState {
            signedInEmail = session.email
        } else {
            signedInEmail = nil
        }

        errorMessage = nil
        noticeMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await repository.signOut()
            mode = .signIn
            email = signedInEmail ?? ""
            clearPasswords()
            rootState = .signedOut
        } catch let error as AuthSessionError {
            errorMessage = message(for: error)
        } catch {
            errorMessage = message(for: .unavailable)
        }
    }

    func deleteAccount() async {
        guard !isSubmitting else { return }
        guard case let .signedIn(session) = rootState else {
            errorMessage = message(for: .accountDeletionFailed)
            return
        }

        errorMessage = nil
        noticeMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await repository.deleteAccount()
            localAccountCleanup(session.userID)
            try? await repository.signOut()
            mode = .signIn
            email = ""
            clearPasswords()
            rootState = .signedOut
        } catch let error as AuthSessionError {
            errorMessage = message(for: error)
        } catch {
            errorMessage = message(for: .accountDeletionFailed)
        }
    }

    private func apply(_ session: AuthSessionSnapshot?) {
        guard let session else {
            rootState = .signedOut
            return
        }

        rootState = session.isExpired ? .loading : .signedIn(session)
    }

    private func clearPasswords() {
        password = ""
        passwordConfirmation = ""
    }

    private func isValidEmail(_ value: String) -> Bool {
        value.range(
            of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#,
            options: .regularExpression
        ) != nil
    }

    private func message(for error: AuthSessionError) -> String {
        switch error {
        case .invalidCredentials:
            "The email or password is incorrect."
        case .emailNotConfirmed:
            "Confirm your email before signing in."
        case .weakPassword:
            "Choose a stronger password and try again."
        case .rateLimited:
            "Too many attempts. Please wait and try again."
        case .networkUnavailable:
            "Check your connection and try again."
        case .accountDeletionFailed:
            "We could not delete your account. Please try again."
        case .invalidCallback:
            "This sign-in link is expired or invalid. Please request a new email link."
        case .unavailable:
            "Authentication is temporarily unavailable. Please try again."
        }
    }
}

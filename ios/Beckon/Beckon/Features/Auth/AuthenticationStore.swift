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
    private var didRestoreSession = false
    private var isObservingSession = false

    var rootState: AuthenticationRootState = .loading
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

    init(
        repository: any AuthSessionRepository,
        clearsSessionBeforeRestore: Bool = false,
        localAccountCleanup: @escaping (UUID) -> Void = { _ in }
    ) {
        self.repository = repository
        self.clearsSessionBeforeRestore = clearsSessionBeforeRestore
        self.localAccountCleanup = localAccountCleanup
    }

    func start() async {
        guard !isObservingSession else { return }
        isObservingSession = true
        defer { isObservingSession = false }

        if !didRestoreSession {
            didRestoreSession = true
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
        rootState = session.map(AuthenticationRootState.signedIn) ?? .signedOut
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

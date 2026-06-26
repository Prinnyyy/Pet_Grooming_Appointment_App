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
enum AuthenticationDebugQuickLoginAccount: CaseIterable, Equatable, Identifiable {
    case customer
    case groomer

    var id: Self { self }

    var title: String {
        switch self {
        case .customer:
            "Customer Quick Login"
        case .groomer:
            "Groomer Quick Login"
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

    init(repository: any AuthSessionRepository) {
        self.repository = repository
    }

    func start() async {
        guard !isObservingSession else { return }
        isObservingSession = true
        defer { isObservingSession = false }

        if !didRestoreSession {
            didRestoreSession = true
            apply(repository.currentSession())
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
                    password: password
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

    #if DEBUG
    func signIn(debugAccount account: AuthenticationDebugQuickLoginAccount) async {
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
        case .unavailable:
            "Authentication is temporarily unavailable. Please try again."
        }
    }
}

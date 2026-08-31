//
//  AuthManager.swift
//  DailyPromise
//

import Foundation
import Observation
import Supabase

/// Where the app sends the user at launch.
nonisolated enum LaunchState: Equatable {
    /// Restoring the stored session. Very short, and never blocks a device that
    /// already holds promises.
    case loading
    /// No session and nothing on this device: the account screen is shown.
    case unauthenticated
    /// No session, but promises already live here. These users are never blocked —
    /// they go straight to their ritual and are only *invited* to create an account.
    case local
    /// A Supabase session is active.
    case authenticated
}

/// How the user last identified themselves, remembered locally so the auth screen
/// can nudge them back to the same door instead of creating a duplicate account.
nonisolated enum SignInProvider: String, Equatable {
    case email
    case google
    case apple

    var label: String {
        switch self {
        case .email: "votre email"
        case .google: "Google"
        case .apple: "Apple"
        }
    }
}

/// Every auth problem, expressed as a calm French sentence. Raw server strings
/// are never shown to the user.
nonisolated enum AuthFailure: Equatable {
    case invalidCredentials
    case accountAlreadyExists
    case weakPassword
    case emailConfirmationRequired
    case linkExpired
    case rateLimited
    case network
    case unknown

    var message: String {
        switch self {
        case .invalidCredentials:
            "Email ou mot de passe incorrect."
        case .accountAlreadyExists:
            "Ce compte existe déjà."
        case .weakPassword:
            "Choisissez un mot de passe d'au moins 8 caractères."
        case .emailConfirmationRequired:
            "Confirmez votre email pour continuer."
        case .linkExpired:
            "Ce lien a expiré. Demandez-en un nouveau."
        case .rateLimited:
            "Trop de tentatives. Réessayez dans un instant."
        case .network:
            "Connexion impossible. Réessayez."
        case .unknown:
            "Quelque chose n'a pas fonctionné. Réessayez."
        }
    }

    /// Signing up with a known email quietly moves the user to the sign-in tab.
    var movesToSignIn: Bool { self == .accountAlreadyExists }

    /// Offering "continue without an account" only makes sense when the network
    /// is the thing that failed.
    var isRecoverableOffline: Bool { self == .network }
}

/// Owns the Supabase session and the launch state machine.
///
/// It never touches promises: the local cache stays the source of truth for the
/// UI, so signing in, signing out, or losing a session never removes anything
/// from the device.
@Observable
final class AuthManager {
    private(set) var state: LaunchState = .loading
    private(set) var userId: UUID?
    private(set) var email: String?
    /// Name offered by the provider at sign-up, used to pre-fill the first-name step.
    private(set) var suggestedFirstName: String?
    private(set) var isWorking: Bool = false
    var failure: AuthFailure?
    private(set) var lastProvider: SignInProvider?
    /// Set while an account waits for its confirmation email to be opened.
    private(set) var pendingConfirmation: PendingConfirmation?
    /// True while the confirmation link is being exchanged for a session.
    private(set) var isOpeningLink: Bool = false

    private var observation: Task<Void, Never>?
    private var confirmationWatch: Task<Void, Never>?
    private static let lastProviderKey = "dailypromise.lastSignInProvider"

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.lastProviderKey) {
            lastProvider = SignInProvider(rawValue: raw)
        }
    }

    deinit {
        observation?.cancel()
        confirmationWatch?.cancel()
    }

    var isSignedIn: Bool { state == .authenticated }

    // MARK: - Launch

    /// Resolves the first screen. `hasLocalPromises` keeps existing users out of
    /// any account barrier: if this device already holds a ritual, it opens.
    func start(hasLocalPromises: Bool) {
        guard state == .loading else { return }

        guard Backend.isConfigured else {
            state = hasLocalPromises ? .local : .unauthenticated
            return
        }

        if let session = Backend.client.auth.currentSession {
            adopt(session)
            validateSession()
        } else {
            state = hasLocalPromises ? .local : .unauthenticated
        }

        observeSessionChanges()
    }

    /// A local user who declines the account for now. Nothing is deleted, and the
    /// invitation stays available in Settings.
    func continueWithoutAccount() {
        failure = nil
        state = .local
    }

    /// A local user who asks for an account from Settings.
    func requestAccount() {
        guard state == .local else { return }
        failure = nil
        state = .unauthenticated
    }

    // MARK: - Email and password

    @discardableResult
    func signUp(firstName: String, email address: String, password: String) async -> Bool {
        let trimmedName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = address.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return await perform {
            let response = try await Backend.client.auth.signUp(
                email: trimmedEmail,
                password: password,
                data: trimmedName.isEmpty ? nil : ["first_name": .string(trimmedName)],
                redirectTo: Backend.authCallbackURL
            )

            self.suggestedFirstName = trimmedName.isEmpty ? nil : trimmedName

            guard let session = response.session else {
                // Email confirmation is on: the account exists but stays closed
                // until the link is opened. Not an error — a waiting room.
                self.beginConfirmationWait(
                    email: trimmedEmail,
                    firstName: trimmedName,
                    password: password
                )
                return
            }

            self.adopt(session)
            self.remember(.email)
        }
    }

    /// Sends the confirmation email again, with the same deep link.
    @discardableResult
    func resendConfirmation() async -> Bool {
        guard let pending = pendingConfirmation else { return false }

        return await perform {
            try await Backend.client.auth.resend(
                email: pending.email,
                type: .signup,
                emailRedirectTo: Backend.authCallbackURL
            )
        }
    }

    /// Leaves the waiting room to correct the address. The account already exists
    /// server-side, so coming back through "Se connecter" resumes the same flow.
    func cancelPendingConfirmation() {
        confirmationWatch?.cancel()
        confirmationWatch = nil
        pendingConfirmation = nil
        failure = nil
    }

    @discardableResult
    func signIn(email address: String, password: String) async -> Bool {
        let trimmedEmail = address.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let succeeded = await perform {
            let session = try await Backend.client.auth.signIn(
                email: trimmedEmail,
                password: password
            )
            self.adopt(session)
            self.remember(.email)
        }

        if !succeeded, failure == .emailConfirmationRequired {
            // Signing in before confirming is the same waiting room, reached from
            // the other tab. Offer the resend instead of a dead end.
            beginConfirmationWait(email: trimmedEmail, firstName: "", password: password)
            failure = nil
        }

        return succeeded
    }

    @discardableResult
    func sendPasswordReset(to address: String) async -> Bool {
        let trimmedEmail = address.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return await perform {
            try await Backend.client.auth.resetPasswordForEmail(
                trimmedEmail,
                redirectTo: Backend.authCallbackURL
            )
        }
    }

    // MARK: - Returning from an email link

    /// Completes the flow opened from an email. Supabase's PKCE code arrives on
    /// the callback URL and is exchanged here for a real session.
    func handleOpenURL(_ url: URL) {
        guard Backend.isConfigured, Backend.isAuthCallback(url) else { return }

        Task {
            isOpeningLink = true
            defer { isOpeningLink = false }

            do {
                let session = try await Backend.client.auth.session(from: url)
                finishConfirmation(with: session)
            } catch {
                // The exchange can legitimately fail even though the link worked:
                // the PKCE verifier lives on the device that started the sign-up,
                // so a link opened elsewhere lands here empty-handed. The account
                // is confirmed server-side regardless — try to walk straight in.
                if let pending = pendingConfirmation,
                   let session = try? await Backend.client.auth.signIn(
                       email: pending.email,
                       password: pending.password
                   ) {
                    finishConfirmation(with: session)
                    return
                }

                failure = Self.translate(error)
                logAuth("auth link could not be opened")
            }
        }
    }

    /// Single exit point once a session exists: stop waiting, drop the held
    /// password, and adopt the session.
    private func finishConfirmation(with session: Session) {
        confirmationWatch?.cancel()
        confirmationWatch = nil
        pendingConfirmation = nil
        failure = nil
        adopt(session)
        remember(.email)
    }

    /// Watches for a confirmation that cannot come back through the deep link —
    /// the link opened in a desktop mail client, on another device. The account
    /// unlocks server-side either way, so a quiet retry finishes the job.
    private func beginConfirmationWait(email: String, firstName: String, password: String) {
        pendingConfirmation = PendingConfirmation(
            email: email,
            firstName: firstName,
            password: password
        )

        confirmationWatch?.cancel()
        confirmationWatch = Task { [weak self] in
            // 15s x 40 = 10 minutes of patience, and 20 attempts per 5 minutes —
            // deliberately under the project's 30-per-5-minutes verify limit, so
            // the poller can never rate-limit the user's own sign-in.
            for _ in 0..<40 {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled, let self, self.pendingConfirmation != nil else { return }

                guard let session = try? await Backend.client.auth.signIn(
                    email: email,
                    password: password
                ) else { continue }

                self.finishConfirmation(with: session)
                return
            }
        }
    }

    // MARK: - Sign out

    /// Ends the session only. Promises, history and streak stay exactly where
    /// they are — on the device and on the server.
    func signOut() async {
        isWorking = true
        defer { isWorking = false }

        if Backend.isConfigured {
            do {
                try await Backend.client.auth.signOut()
            } catch {
                // A network failure must not trap the user in a signed-in shell:
                // the local session is cleared either way.
                logAuth("sign out completed locally")
            }
        }

        confirmationWatch?.cancel()
        confirmationWatch = nil
        pendingConfirmation = nil
        userId = nil
        email = nil
        suggestedFirstName = nil
        failure = nil
        state = .unauthenticated
    }

    // MARK: - Session plumbing

    private func adopt(_ session: Session) {
        userId = session.user.id
        email = session.user.email
        if suggestedFirstName == nil,
           let name = session.user.userMetadata["first_name"]?.stringValue,
           !name.isEmpty {
            suggestedFirstName = name
        }
        failure = nil
        state = .authenticated
    }

    /// Refreshes a restored session in the background. The user is already home;
    /// this only decides whether the account layer is usable right now.
    private func validateSession() {
        Task { [weak self] in
            do {
                _ = try await Backend.client.auth.session
            } catch {
                guard let self else { return }
                if Self.isSessionGone(error) {
                    // Back to the account screen — the local cache is never touched.
                    self.userId = nil
                    self.email = nil
                    self.state = .unauthenticated
                } else {
                    // Offline: stay signed in and keep working from the cache.
                    self.logAuth("session refresh deferred, working offline")
                }
            }
        }
    }

    private func observeSessionChanges() {
        observation?.cancel()
        observation = Task { [weak self] in
            for await change in Backend.client.auth.authStateChanges {
                guard let self else { return }
                switch change.event {
                case .signedIn, .tokenRefreshed, .userUpdated:
                    if let session = change.session {
                        self.adopt(session)
                    }
                case .signedOut:
                    self.userId = nil
                    self.email = nil
                    self.state = .unauthenticated
                default:
                    break
                }
            }
        }
    }

    private static func isSessionGone(_ error: Error) -> Bool {
        guard let authError = error as? AuthError else { return false }
        switch authError.errorCode {
        case .sessionNotFound, .sessionExpired, .refreshTokenNotFound, .refreshTokenAlreadyUsed:
            return true
        default:
            return authError == .sessionMissing
        }
    }

    private func remember(_ provider: SignInProvider) {
        lastProvider = provider
        UserDefaults.standard.set(provider.rawValue, forKey: Self.lastProviderKey)
    }

    // MARK: - Error handling

    /// Runs an auth call with a single busy flag and one translated failure.
    private func perform(_ work: @escaping () async throws -> Void) async -> Bool {
        guard Backend.isConfigured else {
            failure = .network
            return false
        }

        isWorking = true
        failure = nil
        defer { isWorking = false }

        do {
            try await work()
            return true
        } catch {
            failure = Self.translate(error)
            logAuth("auth call failed: \(Self.translate(error))")
            return false
        }
    }

    private static func translate(_ error: Error) -> AuthFailure {
        if let authError = error as? AuthError {
            switch authError.errorCode {
            case .invalidCredentials, .userNotFound:
                return .invalidCredentials
            case .emailExists, .userAlreadyExists, .identityAlreadyExists:
                return .accountAlreadyExists
            case .weakPassword:
                return .weakPassword
            case .emailNotConfirmed:
                return .emailConfirmationRequired
            case .overRequestRateLimit:
                return .rateLimited
            case .otpExpired, .flowStateExpired, .flowStateNotFound:
                return .linkExpired
            default:
                break
            }
            if case .weakPassword = authError { return .weakPassword }
        }

        if error is URLError { return .network }
        return .unknown
    }

    /// Diagnostic only: never contains credentials, tokens or promise text.
    private func logAuth(_ message: String) {
        print("DailyPromise auth: \(message)")
    }
}

/// A sign-up whose account exists but is still closed until the emailed link is
/// opened. Held in memory only — the password is never written to disk — so the
/// app can finish the flow the moment confirmation lands.
nonisolated struct PendingConfirmation: Equatable {
    let email: String
    let firstName: String
    fileprivate let password: String
}

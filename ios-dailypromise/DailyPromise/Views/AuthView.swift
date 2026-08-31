//
//  AuthView.swift
//  DailyPromise
//

import SwiftUI

/// The account screen: create an account or come back to one.
/// Nothing here ever removes a promise from the device.
struct AuthView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(PromiseStore.self) private var store

    private enum Tab: Hashable {
        case signUp
        case signIn
    }

    @State private var tab: Tab = .signUp
    @State private var firstName: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var fieldNote: String?
    @State private var resetNote: String?
    @State private var hasRaisedSheet: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            WarmBackground(intensity: 0.12)

            VStack(spacing: 0) {
                BrandLockup()
                    .padding(.top, 56)
                    .padding(.bottom, 32)

                sheet
                    .offset(y: hasRaisedSheet ? 0 : 60)
                    .opacity(hasRaisedSheet ? 1 : 0)
            }
        }
        .onAppear {
            guard !hasRaisedSheet else { return }
            if reduceMotion {
                hasRaisedSheet = true
            } else {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                    hasRaisedSheet = true
                }
            }
        }
        .onChange(of: auth.failure) { _, failure in
            // A known email is not a dead end: the user is quietly moved to the
            // sign-in tab with their email kept.
            guard let failure, failure.movesToSignIn else { return }
            withAnimation(.smooth(duration: 0.3)) {
                tab = .signIn
                password = ""
            }
        }
    }

    // MARK: - Sheet

    private var sheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let pending = auth.pendingConfirmation {
                    confirmationPanel(pending)
                } else {
                    tabs
                    heading
                    form
                    primaryButton
                    divider
                    socialButtons
                    providerHint
                    legalFooter
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Theme.surface)
        .clipShape(.rect(topLeadingRadius: 28, topTrailingRadius: 28))
        .shadow(color: Theme.ink.opacity(0.06), radius: 22, x: 0, y: -8)
        .ignoresSafeArea(edges: .bottom)
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            tabButton(.signUp, title: "Créer son compte")
            tabButton(.signIn, title: "Se connecter")
        }
        .padding(.top, 24)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)
        }
    }

    private func tabButton(_ value: Tab, title: String) -> some View {
        let isActive = tab == value
        return Button {
            guard tab != value else { return }
            withAnimation(.smooth(duration: 0.28)) {
                tab = value
                auth.failure = nil
                fieldNote = nil
                resetNote = nil
            }
        } label: {
            Text(title)
                .font(.system(size: 16, weight: isActive ? .bold : .medium))
                .foregroundStyle(isActive ? Theme.ink : Theme.muted)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
                .padding(.bottom, 16)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(isActive ? Theme.terracotta : .clear)
                        .frame(height: 2)
                        .clipShape(.rect(cornerRadius: 2))
                }
        }
        .buttonStyle(.plain)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tab == .signIn ? "Ravi de vous revoir." : "Bienvenue.")
                .font(.system(size: 26, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)

            Text(
                tab == .signIn
                    ? "Renseignez vos infos pour retrouver votre fil."
                    : "Quelques secondes pour créer votre compte et démarrer."
            )
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 26)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 12) {
            if tab == .signUp {
                PillField(
                    placeholder: "Votre prénom",
                    text: $firstName,
                    kind: .name,
                    focusOnAppear: true
                )
                .transition(.opacity)
            }

            PillField(placeholder: "Email", text: $email, kind: .email)

            PillField(
                placeholder: "Mot de passe",
                text: $password,
                kind: .secret,
                onSubmit: submit
            )

            if tab == .signIn {
                Button(action: sendReset) {
                    Text("Mot de passe oublié ?")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, -4)
            }

            if let note = noteToShow {
                Text(note)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(noteIsCalm ? Theme.sage : Theme.terracotta)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }

            if auth.failure?.isRecoverableOffline == true, !store.entries.isEmpty {
                Button {
                    auth.continueWithoutAccount()
                } label: {
                    Text("Continuer sans compte")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.terracotta)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 22)
        .animation(.smooth(duration: 0.24), value: tab)
        .animation(.smooth(duration: 0.24), value: noteToShow)
    }

    private var primaryButton: some View {
        Button(action: submit) {
            Group {
                if auth.isWorking {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(tab == .signIn ? "Se connecter" : "Créer mon compte")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .foregroundStyle(Color.white)
            .background(
                canSubmit ? Theme.terracotta : Theme.terracotta.opacity(0.32),
                in: .rect(cornerRadius: 18)
            )
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit || auth.isWorking)
        .padding(.top, 18)
    }

    private var divider: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
            Text(tab == .signIn ? "ou se connecter avec" : "ou continuer avec")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.muted)
                .fixedSize()
            Rectangle().fill(Theme.hairline).frame(height: 1)
        }
        .padding(.top, 22)
        .padding(.bottom, 16)
    }

    private var socialButtons: some View {
        VStack(spacing: 10) {
            SocialSignInButton(provider: .google) { noteProviderComingSoon("Google") }
            SocialSignInButton(provider: .apple) { noteProviderComingSoon("Apple") }
        }
    }

    @ViewBuilder
    private var providerHint: some View {
        // Aimed at avoiding a duplicate account before it happens.
        if let provider = auth.lastProvider {
            Text("La dernière fois, vous avez utilisé \(provider.label).")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 14)
        }
    }

    private var legalFooter: some View {
        Text("En continuant, vous acceptez nos Conditions et notre Politique de confidentialité.")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Theme.muted)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .frame(maxWidth: .infinity)
            .padding(.top, 22)
    }

    // MARK: - Waiting for the confirmation email

    /// Shown between "Créer mon compte" and the confirmed account. The app returns
    /// here on its own once the link is opened, so there is nothing to do but wait.
    private func confirmationPanel(_ pending: PendingConfirmation) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Vérifiez votre boîte mail.")
                .font(.system(size: 26, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(Theme.ink)
                .padding(.top, 44)

            Text("Nous avons envoyé un lien de confirmation à \(pending.email). Ouvrez-le et vous reviendrez ici, connecté.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.muted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            HStack(spacing: 10) {
                ProgressView()
                    .tint(Theme.sage)
                    .scaleEffect(0.8)

                Text(auth.isOpeningLink ? "Ouverture de votre compte…" : "En attente de confirmation…")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.sage)
            }
            .padding(.top, 26)

            if let note = noteToShow {
                Text(note)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(noteIsCalm ? Theme.sage : Theme.terracotta)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
                    .transition(.opacity)
            }

            Button(action: resendConfirmation) {
                Group {
                    if auth.isWorking {
                        ProgressView().tint(.white)
                    } else {
                        Text("Renvoyer l'email")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .foregroundStyle(Color.white)
                .background(Theme.terracotta, in: .rect(cornerRadius: 18))
            }
            .buttonStyle(.plain)
            .disabled(auth.isWorking)
            .padding(.top, 26)

            Button {
                password = ""
                auth.cancelPendingConfirmation()
            } label: {
                Text("Utiliser une autre adresse")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .padding(.top, 18)
            .padding(.bottom, 8)
        }
        .animation(.smooth(duration: 0.24), value: noteToShow)
    }

    // MARK: - State

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isEmailWellFormed: Bool {
        let parts = trimmedEmail.split(separator: "@")
        guard parts.count == 2, let domain = parts.last else { return false }
        return !parts[0].isEmpty && domain.contains(".") && !domain.hasSuffix(".")
    }

    private var canSubmit: Bool {
        guard isEmailWellFormed, password.count >= 8 else { return false }
        if tab == .signUp {
            return !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    private var noteToShow: String? {
        fieldNote ?? resetNote ?? auth.failure?.message
    }

    private var noteIsCalm: Bool {
        fieldNote == nil && resetNote != nil
    }

    // MARK: - Actions

    private func submit() {
        guard !auth.isWorking else { return }
        resetNote = nil

        guard isEmailWellFormed else {
            fieldNote = "Cet email ne semble pas valide."
            return
        }
        guard password.count >= 8 else {
            fieldNote = "Choisissez un mot de passe d'au moins 8 caractères."
            return
        }
        fieldNote = nil

        Task {
            if tab == .signUp {
                await auth.signUp(firstName: firstName, email: email, password: password)
            } else {
                await auth.signIn(email: email, password: password)
            }
        }
    }

    private func sendReset() {
        guard isEmailWellFormed else {
            fieldNote = "Entrez votre email pour recevoir le lien."
            return
        }
        fieldNote = nil

        Task {
            let sent = await auth.sendPasswordReset(to: email)
            if sent {
                resetNote = "Lien envoyé. Regardez votre boîte mail."
            }
        }
    }

    private func resendConfirmation() {
        fieldNote = nil
        Task {
            let sent = await auth.resendConfirmation()
            if sent {
                resetNote = "Email renvoyé. Regardez votre boîte mail."
            }
        }
    }

    private func noteProviderComingSoon(_ name: String) {
        auth.failure = nil
        resetNote = nil
        fieldNote = "\(name) arrive bientôt. Utilisez votre email pour l'instant."
    }
}

#Preview {
    AuthView()
        .environment(AuthManager())
        .environment(PromiseStore(fileName: "preview-auth.json"))
}

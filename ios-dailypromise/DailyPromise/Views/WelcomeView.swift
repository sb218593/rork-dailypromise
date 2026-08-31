//
//  WelcomeView.swift
//  DailyPromise
//

import SwiftUI

/// First launch: the app learns who it is speaking to, nothing more.
struct WelcomeView: View {
    /// Pre-filled when the account already told us a first name at sign-up.
    var initialName: String = ""
    let onContinue: (String) -> Void

    @State private var name: String = ""
    @FocusState private var isFocused: Bool

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            WarmBackground(intensity: 0.12)

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 40)

                Text("DailyPromise")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.8)
                    .foregroundStyle(Theme.muted)

                Text("Une promesse par jour, tenue.")
                    .font(.journal(34))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)

                Text("Comment vous appelez-vous ?")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 34)

                TextField("Votre prénom", text: $name)
                    .font(.journal(28))
                    .foregroundStyle(Theme.ink)
                    .textContentType(.givenName)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit(start)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(Theme.surface, in: .rect(cornerRadius: Theme.cardRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.cardRadius)
                            .stroke(Theme.hairline, lineWidth: 0.8)
                    }
                    .padding(.top, 12)

                Spacer()

                Button(action: start) {
                    Text("Commencer")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white)
                .background(
                    trimmed.isEmpty ? Theme.terracotta.opacity(0.35) : Theme.terracotta,
                    in: .rect(cornerRadius: 16)
                )
                .disabled(trimmed.isEmpty)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, Theme.margin)
        }
        .onAppear {
            if name.isEmpty { name = initialName }
            isFocused = true
        }
    }

    private func start() {
        guard !trimmed.isEmpty else { return }
        onContinue(trimmed)
    }
}

#Preview {
    WelcomeView { _ in }
}

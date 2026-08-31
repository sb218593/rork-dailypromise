//
//  PillField.swift
//  DailyPromise
//

import SwiftUI

/// The rounded 56 pt field of the auth sheet: white, hairline border that warms
/// to terracotta on focus, with a reveal eye on password fields.
struct PillField: View {
    enum Kind {
        case name
        case email
        case secret
    }

    let placeholder: String
    @Binding var text: String
    var kind: Kind = .name
    var focusOnAppear: Bool = false
    var onSubmit: () -> Void = {}

    @FocusState private var isFocused: Bool
    @State private var isRevealed: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            field
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.ink)
                .tint(Theme.terracotta)
                .focused($isFocused)
                .submitLabel(kind == .secret ? .go : .next)
                .onSubmit(onSubmit)

            if kind == .secret {
                Button {
                    isRevealed.toggle()
                } label: {
                    Image(systemName: isRevealed ? "eye" : "eye.slash")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Theme.muted)
                        .frame(width: 32, height: 32)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isRevealed ? "Masquer le mot de passe" : "Afficher le mot de passe")
            }
        }
        .padding(.leading, 22)
        .padding(.trailing, kind == .secret ? 12 : 22)
        .frame(height: 56)
        .background(Theme.surface, in: .rect(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .stroke(isFocused ? Theme.terracotta : Theme.hairline, lineWidth: 1.5)
        }
        .animation(.easeOut(duration: 0.16), value: isFocused)
        .onAppear {
            guard focusOnAppear else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { isFocused = true }
        }
    }

    @ViewBuilder
    private var field: some View {
        switch kind {
        case .name:
            TextField(placeholder, text: $text)
                .textContentType(.givenName)
                .autocorrectionDisabled()
        case .email:
            TextField(placeholder, text: $text)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        case .secret:
            if isRevealed {
                TextField(placeholder, text: $text)
                    .textContentType(.password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else {
                SecureField(placeholder, text: $text)
                    .textContentType(.password)
            }
        }
    }
}

#Preview {
    ZStack {
        WarmBackground()
        VStack(spacing: 12) {
            PillField(placeholder: "Email", text: .constant(""), kind: .email)
            PillField(placeholder: "Mot de passe", text: .constant("secret"), kind: .secret)
        }
        .padding(24)
    }
}

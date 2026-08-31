//
//  SocialSignInButton.swift
//  DailyPromise
//

import SwiftUI

/// One provider row of the auth sheet. Google and Apple are shown from the start,
/// as designed, and become live once their credentials are configured.
struct SocialSignInButton: View {
    enum Provider {
        case google
        case apple

        var title: String {
            switch self {
            case .google: "Continuer avec Google"
            case .apple: "Continuer avec Apple"
            }
        }
    }

    let provider: Provider
    let action: () -> Void

    @State private var isPressed: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                glyph
                Text(provider.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Theme.surface, in: .rect(cornerRadius: 27))
            .overlay {
                RoundedRectangle(cornerRadius: 27)
                    .stroke(Theme.hairline, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.98 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, pressing: { isPressed = $0 }, perform: {})
    }

    @ViewBuilder
    private var glyph: some View {
        switch provider {
        case .google:
            Text("G")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.259, green: 0.522, blue: 0.957))
                .frame(width: 20, height: 20)
        case .apple:
            Image(systemName: "apple.logo")
                .font(.system(size: 18))
                .foregroundStyle(Theme.ink)
                .frame(width: 20, height: 20)
        }
    }
}

#Preview {
    ZStack {
        WarmBackground()
        VStack(spacing: 10) {
            SocialSignInButton(provider: .google) {}
            SocialSignInButton(provider: .apple) {}
        }
        .padding(24)
    }
}

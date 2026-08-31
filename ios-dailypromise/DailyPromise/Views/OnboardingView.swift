//
//  OnboardingView.swift
//  DailyPromise
//

import SwiftUI
import UIKit

/// The three opening screens from the original prototype, shown once.
struct OnboardingView: View {
    let onDone: () -> Void

    private struct Step: Identifiable {
        let id: Int
        let symbol: String
        let title: String
        let subtitle: String
        let cta: String
    }

    private static let steps: [Step] = [
        Step(
            id: 0,
            symbol: "leaf",
            title: "Tu commences tout. Tu finis rarement.",
            subtitle: "La dispersion érode ta confiance. On va y aller autrement.",
            cta: "Suivant"
        ),
        Step(
            id: 1,
            symbol: "sparkles",
            title: "Une seule promesse par jour.",
            subtitle: "Une chose, simple, choisie par toi. C'est tout.",
            cta: "Suivant"
        ),
        Step(
            id: 2,
            symbol: "hands.sparkles",
            title: "Tiens-la.",
            subtitle: "Pas de pression. On avance tranquillement, un jour à la fois.",
            cta: "Commencer"
        )
    ]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var index: Int = 0
    @State private var symbolScale: CGFloat = 0.6
    @State private var symbolOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var contentOffset: CGFloat = 12

    private var step: Step { Self.steps[index] }

    var body: some View {
        ZStack {
            WarmBackground(intensity: 0.12)

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 22) {
                    Image(systemName: step.symbol)
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(Theme.terracotta)
                        .scaleEffect(symbolScale)
                        .opacity(symbolOpacity)
                        .accessibilityHidden(true)

                    Text(step.title)
                        .font(.journal(30))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(step.subtitle)
                        .font(.body)
                        .foregroundStyle(Theme.muted)
                        .lineSpacing(3)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 300)
                }
                .opacity(contentOpacity)
                .offset(y: contentOffset)
                .padding(.horizontal, 8)

                Spacer()

                VStack(spacing: 28) {
                    Button(action: advance) {
                        Text(step.cta)
                            .font(.headline)
                            .foregroundStyle(Color.white)
                            .frame(minWidth: 180)
                            .padding(.horizontal, 38)
                            .padding(.vertical, 17)
                            .background(Theme.terracotta, in: .rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)

                    PageDots(count: Self.steps.count, index: index)
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 28)
        }
        .onAppear { animateIn() }
    }

    private func advance() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()

        guard index < Self.steps.count - 1 else {
            onDone()
            return
        }

        guard !reduceMotion else {
            index += 1
            return
        }

        withAnimation(.easeOut(duration: 0.2)) {
            contentOpacity = 0
            contentOffset = -8
            symbolOpacity = 0
            symbolScale = 0.85
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            index += 1
            contentOffset = 12
            animateIn()
        }
    }

    private func animateIn() {
        guard !reduceMotion else {
            symbolScale = 1
            symbolOpacity = 1
            contentOpacity = 1
            contentOffset = 0
            return
        }

        symbolScale = 0.6
        symbolOpacity = 0

        withAnimation(.spring(response: 0.6, dampingFraction: 0.62)) {
            symbolScale = 1
            symbolOpacity = 1
        }
        withAnimation(.smooth(duration: 0.42).delay(0.06)) {
            contentOpacity = 1
            contentOffset = 0
        }
    }
}

/// The prototype's page indicator: the active dot stretches into a terracotta bar.
struct PageDots: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { dot in
                Capsule()
                    .fill(dot == index ? Theme.terracotta : Theme.hairline)
                    .frame(width: dot == index ? 26 : 10, height: 10)
                    .animation(.spring(response: 0.34, dampingFraction: 0.75), value: index)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Étape \(index + 1) sur \(count)")
    }
}

#Preview {
    OnboardingView {}
}

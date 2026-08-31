//
//  KeptMomentView.swift
//  DailyPromise
//

import SwiftUI

/// The emotional beat of the app: a calm, quiet checkmark moment.
/// One circle, one checkmark, one line. No celebration noise.
struct KeptMomentView: View {
    let streak: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var circleScale: CGFloat = 0.72
    @State private var circleOpacity: Double = 0
    @State private var checkProgress: CGFloat = 0
    @State private var textOpacity: Double = 0
    @State private var actionOpacity: Double = 0

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()

            RadialGradient(
                colors: [Theme.terracotta.opacity(0.16), Theme.terracotta.opacity(0)],
                center: .center,
                startRadius: 0,
                endRadius: 300
            )
            .blur(radius: 30)
            .ignoresSafeArea()
            .opacity(circleOpacity)

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Theme.terracotta)
                        .frame(width: 132, height: 132)

                    CheckmarkShape()
                        .trim(from: 0, to: checkProgress)
                        .stroke(
                            Color.white,
                            style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round)
                        )
                        .frame(width: 54, height: 42)
                        .offset(y: -2)
                }
                .scaleEffect(circleScale)
                .opacity(circleOpacity)
                .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text("Promesse tenue")
                        .font(.journal(30))
                        .foregroundStyle(Theme.ink)

                    if streak > 0 {
                        Text(Pluralize.streak(streak))
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(Theme.muted)
                    }
                }
                .opacity(textOpacity)
                .padding(.top, 38)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Text("Continuer")
                        .font(.headline)
                        .foregroundStyle(Theme.terracotta)
                        .padding(.horizontal, 44)
                        .padding(.vertical, 15)
                        .overlay {
                            Capsule().stroke(Theme.terracotta.opacity(0.4), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .opacity(actionOpacity)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, Theme.margin)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Promesse tenue. \(Pluralize.streak(streak)).")
        .onAppear(perform: play)
    }

    private func play() {
        guard !reduceMotion else {
            circleScale = 1
            circleOpacity = 1
            checkProgress = 1
            textOpacity = 1
            actionOpacity = 1
            return
        }

        withAnimation(.smooth(duration: 0.75)) {
            circleOpacity = 1
            circleScale = 1
        }
        withAnimation(.easeInOut(duration: 0.55).delay(0.4)) {
            checkProgress = 1
        }
        withAnimation(.easeOut(duration: 0.8).delay(1.0)) {
            textOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.7).delay(1.5)) {
            actionOpacity = 1
        }
    }
}

#Preview {
    KeptMomentView(streak: 12)
}

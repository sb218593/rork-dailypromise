//
//  RhythmView.swift
//  DailyPromise
//

import SwiftUI

/// A quiet moment of continuity, not a dashboard: one number, one trace, one line.
struct RhythmView: View {
    @Environment(PromiseStore.self) private var store

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()

            RadialGradient(
                colors: [Theme.terracotta.opacity(0.13), Theme.terracotta.opacity(0)],
                center: .center,
                startRadius: 0,
                endRadius: 260
            )
            .blur(radius: 40)
            .frame(height: 520)
            .offset(y: -170)
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 90)

                    streak

                    monthTrace
                        .padding(.top, 54)

                    Text("Record personnel : \(Pluralize.days(store.bestStreak))")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 20)

                    Spacer(minLength: 70)

                    Text("Chaque jour, une promesse tenue.")
                        .font(.journal(21))
                        .foregroundStyle(Theme.ink.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 40)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Theme.margin)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var streak: some View {
        VStack(spacing: 6) {
            Text("\(store.currentStreak)")
                .font(.system(size: 96, weight: .light))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)

            Text(store.currentStreak <= 1 ? "jour d'affilée" : "jours d'affilée")
                .font(.title3)
                .foregroundStyle(Theme.muted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Pluralize.streak(store.currentStreak))
    }

    private var monthTrace: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(DateText.month(Date()))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.ink.opacity(0.75))

            HStack(spacing: 3) {
                ForEach(store.currentMonthTrace) { day in
                    Circle()
                        .fill(color(for: day))
                        .frame(maxWidth: 9)
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .frame(height: 9)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface.opacity(0.75), in: .rect(cornerRadius: Theme.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .stroke(Theme.hairline, lineWidth: 0.8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(DateText.month(Date())) : \(store.keptThisMonthCount) promesses tenues"
        )
    }

    private func color(for day: MonthDay) -> Color {
        if day.isKept { return Theme.terracotta }
        return day.isFuture ? Theme.muted.opacity(0.14) : Theme.terracotta.opacity(0.16)
    }
}

#Preview {
    RhythmView()
        .environment(PromiseStore(fileName: "preview-rhythm.json"))
}

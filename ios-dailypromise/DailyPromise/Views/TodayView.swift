//
//  TodayView.swift
//  DailyPromise
//

import SwiftUI
import UIKit

/// The home of the ritual: one day, one promise.
/// The promise is the absolute visual and functional priority; everything else stays quiet.
struct TodayView: View {
    @Environment(PromiseStore.self) private var store

    @State private var isComposerPresented = false
    @State private var isNameEditorPresented = false
    @State private var isSettingsPresented = false
    @State private var isKeptMomentPresented = false
    @State private var keptStreak = 0
    @State private var now = Date()

    private var entry: PromiseEntry? { store.todayEntry }
    private var isKept: Bool { store.isTodayKept }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                promiseCard
                streakLine
                noteHint
            }
            .padding(.horizontal, Theme.margin)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(WarmBackground())
        .safeAreaInset(edge: .bottom) { primaryAction }
        .sheet(isPresented: $isComposerPresented) {
            PromiseComposerView(initialText: entry?.text ?? "") { text in
                store.setTodayPromise(text)
            }
        }
        .sheet(isPresented: $isNameEditorPresented) {
            NameEditorView(initialName: store.userName) { name in
                store.setUserName(name)
            }
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
        }
        .fullScreenCover(isPresented: $isKeptMomentPresented) {
            KeptMomentView(streak: keptStreak)
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)
        ) { _ in
            now = Date()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(DateText.greetingDate(now))
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)

                Button {
                    isNameEditorPresented = true
                } label: {
                    Text("Bonjour \(store.userName)")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Bonjour \(store.userName). Modifier votre prénom")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                isSettingsPresented = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 44, height: 44, alignment: .trailing)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Réglages")
            .offset(y: 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - The promise (hero)

    private var promiseCard: some View {
        Button {
            guard !isKept else { return }
            isComposerPresented = true
        } label: {
            PaperCard(padding: 26) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 8) {
                        Text("PROMESSE DU JOUR")
                            .font(.caption2.weight(.semibold))
                            .tracking(1.6)
                            .foregroundStyle(Theme.muted)

                        if isKept {
                            Image(systemName: "checkmark")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Theme.terracotta)
                                .transition(.opacity)
                        }
                    }

                    if let entry {
                        Text(entry.text)
                            .font(.journal(38))
                            .foregroundStyle(Theme.ink)
                            .lineSpacing(6)
                            .minimumScaleFactor(0.55)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Quelle promesse vous faites-vous aujourd'hui ?")
                            .font(.journal(32))
                            .foregroundStyle(Theme.muted.opacity(0.85))
                            .lineSpacing(6)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .frame(minHeight: 280, alignment: .topLeading)
            }
        }
        .buttonStyle(.plain)
        .disabled(isKept)
        .accessibilityHint(isKept ? "" : "Toucher pour modifier la promesse du jour")
    }

    // MARK: - Quiet secondary information

    @ViewBuilder
    private var streakLine: some View {
        let streak = store.currentStreak
        if streak > 0 {
            HStack(spacing: 7) {
                Image(systemName: "flame")
                    .font(.footnote)
                Text(Pluralize.streak(streak))
                    .font(.footnote)
                    .monospacedDigit()
            }
            .foregroundStyle(Theme.muted)
            .padding(.leading, 2)
        }
    }

    /// Visually present, intentionally inert in V1 — journaling arrives later.
    private var noteHint: some View {
        HStack(spacing: 10) {
            Image(systemName: "pencil.line")
                .font(.body)
            Text("Une note, si vous le souhaitez…")
                .font(.subheadline)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.muted.opacity(0.65))
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface.opacity(0.6), in: .rect(cornerRadius: Theme.cardRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .stroke(Theme.hairline.opacity(0.7), lineWidth: 0.8)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Primary action

    @ViewBuilder
    private var primaryAction: some View {
        VStack(spacing: 0) {
            if isKept {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Promesse tenue")
                }
                .font(.headline)
                .foregroundStyle(Theme.terracotta)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
            } else {
                Button {
                    if entry == nil {
                        isComposerPresented = true
                    } else {
                        keepPromise()
                    }
                } label: {
                    Text(entry == nil ? "Choisir ma promesse" : "Marquer comme tenue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white)
                .background(Theme.terracotta, in: .rect(cornerRadius: 16))
            }
        }
        .padding(.horizontal, Theme.margin)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(alignment: .top) {
            LinearGradient(
                colors: [Theme.canvas.opacity(0), Theme.canvas],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 140)
            .allowsHitTesting(false)
        }
    }

    private func keepPromise() {
        guard store.markTodayKept() else { return }
        keptStreak = store.currentStreak
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        isKeptMomentPresented = true
    }
}

#Preview {
    TodayView()
        .environment(PromiseStore(fileName: "preview-today.json"))
}

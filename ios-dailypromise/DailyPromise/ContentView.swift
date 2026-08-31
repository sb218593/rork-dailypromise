//
//  ContentView.swift
//  DailyPromise
//

import SwiftUI

/// Root shell: decides between the account door and the three quiet destinations
/// of the ritual. A device that already holds promises is never held at the door.
struct ContentView: View {
    @Environment(PromiseStore.self) private var store
    @Environment(AuthManager.self) private var auth
    @Environment(AccountMigrator.self) private var migrator
    @Environment(SyncEngine.self) private var sync
    @Environment(\.scenePhase) private var scenePhase

    private enum Destination: Hashable {
        case today, history, rhythm
    }

    @State private var selection: Destination = .today

    var body: some View {
        Group {
            switch auth.state {
            case .loading:
                LaunchVeil()
                    .transition(.opacity)
            case .unauthenticated:
                AuthView()
                    .transition(.opacity)
            case .local, .authenticated:
                ritual
            }
        }
        .preferredColorScheme(.light)
        .animation(.smooth(duration: 0.4), value: auth.state)
        .task {
            sync.configure(store: store, auth: auth)
            auth.start(hasLocalPromises: store.hasLocalPromises)
        }
        .task(id: auth.userId) {
            // Trigger 1: a successful authentication brings the account down to
            // this device, then replicates in the background.
            guard let userId = auth.userId else { return }
            let isReady = await migrator.prepare(userId: userId, store: store)
            if isReady { sync.sync(.signIn) }
        }
        .onChange(of: scenePhase) { _, phase in
            // Trigger 2: coming back to the app.
            guard phase == .active else { return }
            sync.sync(.foreground)
        }
        .fullScreenCover(item: Binding(
            get: { migrator.pendingOffer },
            set: { if $0 == nil { migrator.declineMerge() } }
        )) { offer in
            MergeInvitationView(
                offer: offer,
                isMerging: migrator.isMerging,
                onMerge: {
                    guard let userId = auth.userId else { return }
                    Task { await migrator.acceptMerge(userId: userId, store: store) }
                },
                onCancel: { migrator.declineMerge() }
            )
        }
    }

    /// The existing app, untouched.
    @ViewBuilder
    private var ritual: some View {
        if !store.hasCompletedOnboarding {
            OnboardingView {
                withAnimation(.smooth(duration: 0.5)) {
                    store.completeOnboarding()
                }
            }
            .transition(.opacity)
        } else if store.hasProfile {
            TabView(selection: $selection) {
                TodayView()
                    .tabItem { Label("Aujourd'hui", systemImage: "sun.max") }
                    .tag(Destination.today)

                HistoryView()
                    .tabItem { Label("Historique", systemImage: "book") }
                    .tag(Destination.history)

                RhythmView()
                    .tabItem { Label("Progrès", systemImage: "chart.bar") }
                    .tag(Destination.rhythm)
            }
            .tint(Theme.terracotta)
            .transition(.opacity)
        } else {
            WelcomeView(initialName: auth.suggestedFirstName ?? "") { name in
                withAnimation(.smooth(duration: 0.5)) {
                    store.setUserName(name)
                }
            }
            .transition(.opacity)
        }
    }
}

/// The very short moment while the stored session is restored.
private struct LaunchVeil: View {
    var body: some View {
        ZStack {
            WarmBackground()
            Text("DailyPromise")
                .font(.caption2.weight(.semibold))
                .tracking(1.8)
                .foregroundStyle(Theme.muted)
        }
    }
}

#Preview {
    ContentView()
        .environment(PromiseStore(fileName: "preview-root.json"))
        .environment(AuthManager())
        .environment(AccountMigrator())
        .environment(SyncEngine())
}

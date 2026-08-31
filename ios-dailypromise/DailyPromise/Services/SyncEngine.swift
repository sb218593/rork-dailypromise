//
//  SyncEngine.swift
//  DailyPromise
//

import Foundation
import Network
import Observation

/// Replicates the local cache to the account, and back.
///
/// Deliberately simple: no realtime, no websocket, no periodic background task.
/// Four triggers, one code path, and the local cache always stays the source of
/// truth for the screens — a sync round can fail entirely without the user
/// noticing anything beyond a delayed upload.
@Observable
final class SyncEngine {
    /// What woke the engine up. Kept for diagnostics only.
    nonisolated enum Trigger: String {
        case signIn
        case foreground
        case network
        case localChange
    }

    private(set) var isSyncing: Bool = false
    private(set) var lastSyncedAt: Date?
    private(set) var isOnline: Bool = true

    private var store: PromiseStore?
    private var auth: AuthManager?

    private var debounceTask: Task<Void, Never>?
    private var monitor: NWPathMonitor?
    private var hasStartedMonitoring: Bool = false

    /// Seconds to wait after a local edit, so a burst of keystrokes travels once.
    private let localChangeDelay: Duration = .seconds(3)

    deinit {
        debounceTask?.cancel()
        monitor?.cancel()
    }

    // MARK: - Wiring

    func configure(store: PromiseStore, auth: AuthManager) {
        self.store = store
        self.auth = auth

        // Trigger 4: any local change queues a deferred push.
        store.onLocalChange = { [weak self] in
            self?.scheduleLocalPush()
        }

        startNetworkMonitoring()
    }

    /// Triggers 1, 2 and 3 come in through here.
    func sync(_ trigger: Trigger) {
        Task { await run(trigger) }
    }

    // MARK: - Triggers

    private func scheduleLocalPush() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: localChangeDelay)
            guard !Task.isCancelled else { return }
            await run(.localChange)
        }
    }

    /// Trigger 3: the network coming back is the only thing worth listening to
    /// continuously, and it costs one system path monitor.
    private func startNetworkMonitoring() {
        guard !hasStartedMonitoring else { return }
        hasStartedMonitoring = true

        let monitor = NWPathMonitor()
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            let satisfied = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasOffline = !self.isOnline
                self.isOnline = satisfied
                if satisfied && wasOffline {
                    await self.run(.network)
                }
            }
        }
        monitor.start(queue: DispatchQueue(label: "dailypromise.network"))
    }

    // MARK: - One sync round

    private func run(_ trigger: Trigger) async {
        guard Backend.isConfigured,
              let store,
              let userId = auth?.userId,
              store.accountId == userId,
              !isSyncing else { return }

        isSyncing = true
        defer { isSyncing = false }

        do {
            // 1. Push what this device is ahead on.
            let pending = store.pendingEntries
            if !pending.isEmpty {
                try await PromiseRepository.upsert(pending, userId: userId)
                store.markSynced(Set(pending.map(\.id)), at: Date())
            }

            // 2. Pull the account's view of the world.
            let remote = try await PromiseRepository.fetchPromises(userId: userId)

            // 3. Reconcile, day by day, with the deterministic rules.
            let merged = PromiseMerge.merge(store.entries, remote)
            store.replaceEntries(merged)

            // 4. Send back any day where this device's answer differs from the
            //    server's. Idempotent: same ids, same business key.
            let remoteByDay = Dictionary(
                remote.map { ($0.dayKey, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            let corrections = merged.filter { entry in
                guard let server = remoteByDay[entry.dayKey] else { return true }
                return server.id != entry.id
                    || server.text != entry.text
                    || server.keptAt != entry.keptAt
            }
            if !corrections.isEmpty {
                try await PromiseRepository.upsert(corrections, userId: userId)
                store.markSynced(Set(corrections.map(\.id)), at: Date())
            }

            await syncProfile(userId: userId, store: store)

            lastSyncedAt = Date()
        } catch {
            // Offline or a transient server issue: nothing is lost, the local cache
            // is untouched, and the next trigger picks it up.
            print("DailyPromise: sync deferred (\(trigger.rawValue)).")
        }
    }

    /// The profile travels in one direction per field: the device owns the reminder
    /// it schedules locally, and the account fills in what this device is missing.
    private func syncProfile(userId: UUID, store: PromiseStore) async {
        do {
            if let remote = try await PromiseRepository.fetchProfile(userId: userId) {
                if store.userName.isEmpty || !store.hasCompletedOnboarding {
                    store.applyRemoteProfileGaps(remote)
                }
            }

            try await PromiseRepository.upsertProfile(
                userId: userId,
                firstName: store.userName.isEmpty ? nil : store.userName,
                onboardingCompletedAt: store.hasCompletedOnboarding ? Date() : nil,
                reminderEnabled: store.isReminderEnabled,
                reminderHour: store.reminderHour,
                reminderMinute: store.reminderMinute
            )
        } catch {
            print("DailyPromise: profile sync deferred.")
        }
    }
}

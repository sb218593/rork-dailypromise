//
//  AccountMigrator.swift
//  DailyPromise
//

import Foundation
import Observation

/// The single question the user may be asked: what to do when this device and the
/// account both already hold promises.
nonisolated struct MergeOffer: Equatable, Identifiable {
    let id: UUID
    let localCount: Int
    let accountCount: Int
}

/// Brings the promises already on this device into a freshly opened account.
///
/// Three guarantees shape everything here:
/// the original `dailypromise.json` is never deleted, every send is idempotent
/// (the business key is `(user_id, promise_date)`), and no path can discard the
/// local history.
@Observable
final class AccountMigrator {
    /// Non-nil while the calm merge screen should be shown.
    private(set) var pendingOffer: MergeOffer?
    private(set) var isMerging: Bool = false

    private let defaults = UserDefaults.standard

    /// Prepares the account cache for this device.
    /// Returns true when the store is attached to the account and safe to sync.
    @discardableResult
    func prepare(userId: UUID, store: PromiseStore) async -> Bool {
        let hadAccountCache = store.openAccountCache(userId)
        let legacyEntries = Self.legacyEntries()
        let hasUnmigratedLocalData = !legacyEntries.isEmpty && !isMigrated(userId)

        if hadAccountCache {
            // The account already lives on this device. The only thing left to
            // settle is local history that was never brought over.
            if hasUnmigratedLocalData {
                offerMerge(localCount: legacyEntries.count, accountCount: store.entries.count)
            }
            return true
        }

        // First time this account opens here: the server decides what happens next.
        do {
            let remoteEntries = try await PromiseRepository.fetchPromises(userId: userId)
            let remoteProfile = try await PromiseRepository.fetchProfile(userId: userId)

            if remoteEntries.isEmpty || !hasUnmigratedLocalData {
                // Nothing to arbitrate: the union of the two sides is unambiguous,
                // so the migration is silent — no question asked.
                let resolved = PromiseMerge.merge(
                    hasUnmigratedLocalData ? legacyEntries : [],
                    remoteEntries
                )
                store.adoptAccount(userId, entries: resolved)
                await applyProfile(remoteProfile, userId: userId, store: store)
                await push(
                    resolved,
                    userId: userId,
                    store: store,
                    completesMigration: hasUnmigratedLocalData
                )
                return true
            }

            // Both sides hold promises: one calm decision, taken by the user.
            store.adoptAccount(userId, entries: remoteEntries)
            await applyProfile(remoteProfile, userId: userId, store: store)
            offerMerge(localCount: legacyEntries.count, accountCount: remoteEntries.count)
            return true
        } catch {
            // Offline on the very first sign-in with this account: do not guess.
            // The device keeps working from its own cache and this runs again later.
            print("DailyPromise: account not reachable yet, staying on the local cache.")
            return false
        }
    }

    /// « Réunir mes promesses » — every day from both sides is kept, contested days
    /// are settled by the deterministic rules, nothing is thrown away.
    func acceptMerge(userId: UUID, store: PromiseStore) async {
        guard !isMerging else { return }
        isMerging = true
        defer { isMerging = false }

        let merged = PromiseMerge.merge(Self.legacyEntries(), store.entries)
        store.replaceEntries(merged)

        // The local first name and reminder fill an empty profile; a completed
        // onboarding is carried over so it never replays.
        await fillProfileFromDevice(userId: userId, store: store)
        await push(merged, userId: userId, store: store, completesMigration: true)

        pendingOffer = nil
    }

    /// « Annuler » — strictly nothing happens. The device keeps its promises, the
    /// account keeps its own, and the question comes back another time.
    func declineMerge() {
        pendingOffer = nil
    }

    // MARK: - Sending

    private func push(
        _ entries: [PromiseEntry],
        userId: UUID,
        store: PromiseStore,
        completesMigration: Bool
    ) async {
        guard !entries.isEmpty else {
            if completesMigration { markMigrated(userId) }
            return
        }

        do {
            try await PromiseRepository.upsert(entries, userId: userId)
            store.markSynced(Set(entries.map(\.id)), at: Date())
            // Only marked done once the server has confirmed the write.
            if completesMigration { markMigrated(userId) }
        } catch {
            // Every batch is idempotent, so an interrupted migration simply replays.
            print("DailyPromise: migration interrupted, will resume on the next sync.")
        }
    }

    private func applyProfile(
        _ profile: RemoteProfile?,
        userId: UUID,
        store: PromiseStore
    ) async {
        if let profile, profile.firstName?.isEmpty == false || profile.onboardingCompletedAt != nil {
            store.applyRemoteProfile(profile)
        } else {
            await fillProfileFromDevice(userId: userId, store: store)
        }
    }

    private func fillProfileFromDevice(userId: UUID, store: PromiseStore) async {
        let name = store.userName.isEmpty ? Self.legacyState()?.userName : store.userName
        do {
            try await PromiseRepository.upsertProfile(
                userId: userId,
                firstName: name?.isEmpty == false ? name : nil,
                onboardingCompletedAt: store.hasCompletedOnboarding ? Date() : nil,
                reminderEnabled: store.isReminderEnabled,
                reminderHour: store.reminderHour,
                reminderMinute: store.reminderMinute
            )
        } catch {
            print("DailyPromise: profile will be sent again on the next sync.")
        }
    }

    // MARK: - Flags and local reads

    private func offerMerge(localCount: Int, accountCount: Int) {
        pendingOffer = MergeOffer(
            id: UUID(),
            localCount: localCount,
            accountCount: accountCount
        )
    }

    private func migratedKey(_ userId: UUID) -> String {
        "dailypromise.migrated.\(userId.uuidString.lowercased())"
    }

    private func isMigrated(_ userId: UUID) -> Bool {
        defaults.bool(forKey: migratedKey(userId))
    }

    private func markMigrated(_ userId: UUID) {
        defaults.set(true, forKey: migratedKey(userId))
    }

    /// The promises made before accounts existed. Read only — this file is never
    /// modified or deleted by the migration.
    private static func legacyState() -> StoredState? {
        LocalPromiseCache(fileName: LocalPromiseCache.legacyFileName).load()
    }

    private static func legacyEntries() -> [PromiseEntry] {
        legacyState()?.entries ?? []
    }
}

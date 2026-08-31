//
//  PromiseRepository.swift
//  DailyPromise
//

import Foundation
import Supabase

/// One promise as the database stores it.
nonisolated struct RemotePromise: Codable, Sendable {
    let id: UUID
    let userId: UUID
    let text: String
    /// Bare calendar day, "2026-08-30". Never a timestamp: a promise belongs to
    /// the day it was made on this device, and travel must not rewrite the past.
    let promiseDate: String
    let keptAt: Date?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case text
        case promiseDate = "promise_date"
        case keptAt = "kept_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Falls back to the row's creation day if the stored key is ever unreadable.
    var localEntry: PromiseEntry {
        PromiseEntry(
            id: id,
            text: text,
            date: AppCalendar.date(fromDayKey: promiseDate) ?? AppCalendar.startOfDay(createdAt),
            keptAt: keptAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncedAt: updatedAt
        )
    }
}

/// The profile row: everything about the person that is not a promise.
nonisolated struct RemoteProfile: Codable, Sendable {
    let id: UUID
    let firstName: String?
    let onboardingCompletedAt: Date?
    let reminderEnabled: Bool
    let reminderHour: Int
    let reminderMinute: Int

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case onboardingCompletedAt = "onboarding_completed_at"
        case reminderEnabled = "reminder_enabled"
        case reminderHour = "reminder_hour"
        case reminderMinute = "reminder_minute"
    }
}

nonisolated private struct PromiseUpsert: Encodable, Sendable {
    let id: UUID
    let userId: UUID
    let text: String
    let promiseDate: String
    let keptAt: Date?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case text
        case promiseDate = "promise_date"
        case keptAt = "kept_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

nonisolated private struct ProfileUpsert: Encodable, Sendable {
    let id: UUID
    let firstName: String?
    let onboardingCompletedAt: Date?
    let reminderEnabled: Bool
    let reminderHour: Int
    let reminderMinute: Int

    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case onboardingCompletedAt = "onboarding_completed_at"
        case reminderEnabled = "reminder_enabled"
        case reminderHour = "reminder_hour"
        case reminderMinute = "reminder_minute"
    }
}

/// Every conversation with the promises and profiles tables.
///
/// It only moves rows: all decisions about who wins a contested day are taken by
/// `PromiseMerge` before anything is sent.
nonisolated enum PromiseRepository {
    /// Rows per network call during migration and large pushes.
    static let batchSize = 100

    // MARK: - Promises

    static func fetchPromises(userId: UUID) async throws -> [PromiseEntry] {
        let rows: [RemotePromise] = try await Backend.client
            .from("promises")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("promise_date", ascending: false)
            .execute()
            .value
        return rows.map(\.localEntry)
    }

    static func countPromises(userId: UUID) async throws -> Int {
        let response = try await Backend.client
            .from("promises")
            .select("id", head: true, count: .exact)
            .eq("user_id", value: userId.uuidString)
            .execute()
        return response.count ?? 0
    }

    /// Idempotent by design: the business key is `(user_id, promise_date)`, so
    /// replaying a batch rewrites the same rows instead of duplicating a day.
    static func upsert(_ entries: [PromiseEntry], userId: UUID) async throws {
        guard !entries.isEmpty else { return }

        for batch in entries.chunked(into: batchSize) {
            let payload = batch.map { entry in
                PromiseUpsert(
                    id: entry.id,
                    userId: userId,
                    text: entry.text,
                    promiseDate: entry.dayKey,
                    keptAt: entry.keptAt,
                    createdAt: entry.createdAt,
                    updatedAt: entry.updatedAt
                )
            }

            try await Backend.client
                .from("promises")
                .upsert(payload, onConflict: "user_id,promise_date")
                .execute()
        }
    }

    // MARK: - Profile

    static func fetchProfile(userId: UUID) async throws -> RemoteProfile? {
        let rows: [RemoteProfile] = try await Backend.client
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    static func upsertProfile(
        userId: UUID,
        firstName: String?,
        onboardingCompletedAt: Date?,
        reminderEnabled: Bool,
        reminderHour: Int,
        reminderMinute: Int
    ) async throws {
        try await Backend.client
            .from("profiles")
            .upsert(
                ProfileUpsert(
                    id: userId,
                    firstName: firstName,
                    onboardingCompletedAt: onboardingCompletedAt,
                    reminderEnabled: reminderEnabled,
                    reminderHour: reminderHour,
                    reminderMinute: reminderMinute
                )
            )
            .execute()
    }
}

extension Array {
    /// Splits into fixed-size batches so one network hiccup costs one batch.
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

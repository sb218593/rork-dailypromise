//
//  PromiseEntry.swift
//  DailyPromise
//

import Foundation

/// One promise, belonging to exactly one day.
///
/// `createdAt` and `updatedAt` are what let two devices agree on the same day
/// without talking to each other; `syncedAt` is what marks a row as already
/// delivered to the account. Files written before these existed decode fine.
nonisolated struct PromiseEntry: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var text: String
    /// Start of the day this promise belongs to.
    var date: Date
    /// Set when the user marks the promise as kept.
    var keptAt: Date?
    /// When the commitment was first made. Decides who wins a contested day.
    var createdAt: Date
    /// Last local edit. Decides the text of an unkept, twice-edited day.
    var updatedAt: Date
    /// Last time this exact version reached the server. `nil` = never sent.
    var syncedAt: Date?

    init(
        id: UUID = UUID(),
        text: String,
        date: Date,
        keptAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncedAt: Date? = nil
    ) {
        self.id = id
        self.text = text
        self.date = date
        self.keptAt = keptAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncedAt = syncedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        text = try container.decode(String.self, forKey: .text)
        date = try container.decode(Date.self, forKey: .date)
        keptAt = try container.decodeIfPresent(Date.self, forKey: .keptAt)
        // Promises written before sync existed: the day itself is the best known
        // moment of commitment, and they have never been sent anywhere.
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? date
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
            ?? keptAt
            ?? date
        syncedAt = try container.decodeIfPresent(Date.self, forKey: .syncedAt)
    }

    var isKept: Bool { keptAt != nil }
    var dayKey: String { AppCalendar.dayKey(date) }

    /// True when the local version is ahead of what the server acknowledged.
    var needsSync: Bool {
        guard let syncedAt else { return true }
        return updatedAt > syncedAt
    }
}

/// A week of kept promises, used by the history record.
nonisolated struct PromiseWeek: Identifiable, Hashable {
    let id: String
    let title: String
    let entries: [PromiseEntry]
}

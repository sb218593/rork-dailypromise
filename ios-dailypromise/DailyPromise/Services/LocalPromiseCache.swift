//
//  LocalPromiseCache.swift
//  DailyPromise
//

import Foundation

/// Persisted shape of everything the app remembers on this device.
/// Decoding tolerates files written by earlier versions that lacked some fields.
nonisolated struct StoredState: Codable, Sendable {
    var userName: String
    var entries: [PromiseEntry]
    var hasCompletedOnboarding: Bool
    var isReminderEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int

    init(
        userName: String,
        entries: [PromiseEntry],
        hasCompletedOnboarding: Bool,
        isReminderEnabled: Bool,
        reminderHour: Int,
        reminderMinute: Int
    ) {
        self.userName = userName
        self.entries = entries
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.isReminderEnabled = isReminderEnabled
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userName = try container.decodeIfPresent(String.self, forKey: .userName) ?? ""
        entries = try container.decodeIfPresent([PromiseEntry].self, forKey: .entries) ?? []
        // Installs that predate onboarding already know the user: never show it again.
        hasCompletedOnboarding = try container.decodeIfPresent(
            Bool.self,
            forKey: .hasCompletedOnboarding
        ) ?? !userName.isEmpty
        isReminderEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .isReminderEnabled
        ) ?? false
        reminderHour = try container.decodeIfPresent(Int.self, forKey: .reminderHour) ?? 20
        reminderMinute = try container.decodeIfPresent(Int.self, forKey: .reminderMinute) ?? 0
    }
}

/// Reads and writes one JSON file in the app's documents directory.
///
/// There is one cache per account (`dailypromise-<userId>.json`) plus the original
/// device file (`dailypromise.json`), which is **never** deleted: it belongs to the
/// people who used the app before accounts existed.
nonisolated struct LocalPromiseCache: Sendable {
    static let legacyFileName = "dailypromise.json"

    let fileURL: URL

    init(fileName: String) {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = directory.appendingPathComponent(fileName)
    }

    static func forAccount(_ userId: UUID) -> LocalPromiseCache {
        LocalPromiseCache(fileName: "dailypromise-\(userId.uuidString.lowercased()).json")
    }

    var exists: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    func load() -> StoredState? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(StoredState.self, from: data)
        } catch {
            print("DailyPromise: unable to read saved promises, starting fresh.")
            return nil
        }
    }

    func save(_ state: StoredState) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(state)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("DailyPromise: unable to save promises.")
        }
    }
}

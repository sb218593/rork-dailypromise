//
//  PromiseStore.swift
//  DailyPromise
//

import Foundation
import Observation

/// Single source of truth for the UI: the user's profile name and every promise
/// they have made.
///
/// The screens talk only to this object, exactly as before. Everything the account
/// layer added — per-account cache files, sync bookkeeping, merges — lives behind
/// this same public surface, and the local cache is always read and written first
/// so the app keeps working with no network at all.
@Observable
final class PromiseStore {
    private(set) var entries: [PromiseEntry] = []
    private(set) var userName: String = ""
    private(set) var hasCompletedOnboarding: Bool = false
    private(set) var isReminderEnabled: Bool = false
    private(set) var reminderHour: Int = 20
    private(set) var reminderMinute: Int = 0

    /// The account this cache belongs to, or `nil` for the original device file.
    private(set) var accountId: UUID?

    /// Called after any local change so the sync engine can queue a push.
    /// Never blocks a write: the local file is already saved when this fires.
    var onLocalChange: (() -> Void)?

    private var cache: LocalPromiseCache

    init(fileName: String = LocalPromiseCache.legacyFileName) {
        cache = LocalPromiseCache(fileName: fileName)
        if let state = cache.load() {
            apply(state)
        }
    }

    // MARK: - Profile

    var hasProfile: Bool { !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    func setUserName(_ name: String) {
        userName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        save()
        onLocalChange?()
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        save()
        onLocalChange?()
    }

    // MARK: - Daily reminder

    /// The reminder time expressed on today's date, for `DatePicker`.
    var reminderTime: Date {
        let calendar = AppCalendar.calendar
        return calendar.date(
            bySettingHour: reminderHour,
            minute: reminderMinute,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    func setReminderEnabled(_ enabled: Bool) {
        isReminderEnabled = enabled
        save()
        onLocalChange?()
    }

    func setReminderTime(_ date: Date) {
        let components = AppCalendar.calendar.dateComponents([.hour, .minute], from: date)
        reminderHour = components.hour ?? 20
        reminderMinute = components.minute ?? 0
        save()
        onLocalChange?()
    }

    // MARK: - Today

    /// Today's promise, if the user has already chosen one.
    var todayEntry: PromiseEntry? {
        let key = AppCalendar.dayKey(Date())
        return entries.first { $0.dayKey == key }
    }

    var isTodayKept: Bool { todayEntry?.isKept ?? false }

    func setTodayPromise(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let today = AppCalendar.startOfDay(Date())
        if let index = entries.firstIndex(where: { $0.dayKey == AppCalendar.dayKey(today) }) {
            entries[index].text = trimmed
            entries[index].updatedAt = Date()
        } else {
            entries.append(PromiseEntry(text: trimmed, date: today))
        }
        save()
        onLocalChange?()
    }

    /// Marks today's promise as kept. Returns false when there is nothing to keep.
    @discardableResult
    func markTodayKept() -> Bool {
        let key = AppCalendar.dayKey(Date())
        guard let index = entries.firstIndex(where: { $0.dayKey == key }),
              entries[index].keptAt == nil else { return false }
        entries[index].keptAt = Date()
        entries[index].updatedAt = Date()
        save()
        onLocalChange?()
        return true
    }

    // MARK: - Record

    /// Every kept promise, most recent first.
    var keptEntries: [PromiseEntry] {
        entries.filter(\.isKept).sorted { $0.date > $1.date }
    }

    /// Kept promises grouped into weeks, most recent week first.
    var keptWeeks: [PromiseWeek] {
        let calendar = AppCalendar.calendar
        let now = Date()
        let currentWeek = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)

        var order: [String] = []
        var buckets: [String: [PromiseEntry]] = [:]

        for entry in keptEntries {
            let components = calendar.dateComponents(
                [.yearForWeekOfYear, .weekOfYear],
                from: entry.date
            )
            let key = "\(components.yearForWeekOfYear ?? 0)-\(components.weekOfYear ?? 0)"
            if buckets[key] == nil {
                buckets[key] = []
                order.append(key)
            }
            buckets[key]?.append(entry)
        }

        return order.compactMap { key in
            guard let bucket = buckets[key], let first = bucket.first else { return nil }
            let components = calendar.dateComponents(
                [.yearForWeekOfYear, .weekOfYear],
                from: first.date
            )
            let title: String
            if components.yearForWeekOfYear == currentWeek.yearForWeekOfYear,
               components.weekOfYear == currentWeek.weekOfYear {
                title = "Cette semaine"
            } else if let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: now),
                      calendar.isDate(first.date, equalTo: previous, toGranularity: .weekOfYear) {
                title = "Semaine précédente"
            } else if let start = calendar.dateInterval(of: .weekOfYear, for: first.date)?.start {
                title = "Semaine du \(DateText.dayMonth(start))"
            } else {
                title = DateText.monthYear(first.date)
            }
            return PromiseWeek(id: key, title: title, entries: bucket)
        }
    }

    /// Kept promises in the current calendar month.
    var keptThisMonthCount: Int {
        let calendar = AppCalendar.calendar
        return keptEntries.filter {
            calendar.isDate($0.date, equalTo: Date(), toGranularity: .month)
        }.count
    }

    // MARK: - Rhythm

    private var keptDayKeys: Set<String> {
        Set(entries.filter(\.isKept).map(\.dayKey))
    }

    /// Consecutive days kept, counting back from today (or yesterday if today is still open).
    var currentStreak: Int {
        let calendar = AppCalendar.calendar
        let kept = keptDayKeys
        var cursor = calendar.startOfDay(for: Date())

        if !kept.contains(AppCalendar.dayKey(cursor)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                return 0
            }
            cursor = yesterday
        }

        var streak = 0
        while kept.contains(AppCalendar.dayKey(cursor)) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    /// The longest run of consecutive kept days the user has ever reached.
    var bestStreak: Int {
        let calendar = AppCalendar.calendar
        let days = entries
            .filter(\.isKept)
            .map { calendar.startOfDay(for: $0.date) }
            .sorted()

        guard !days.isEmpty else { return 0 }

        var best = 1
        var run = 1
        for index in 1..<days.count {
            let previous = days[index - 1]
            let current = days[index]
            if let next = calendar.date(byAdding: .day, value: 1, to: previous),
               calendar.isDate(next, inSameDayAs: current) {
                run += 1
            } else if !calendar.isDate(previous, inSameDayAs: current) {
                run = 1
            }
            best = max(best, run)
        }
        return max(best, currentStreak)
    }

    /// One entry per day of the current month, used by the quiet dot trace.
    var currentMonthTrace: [MonthDay] {
        let calendar = AppCalendar.calendar
        let today = calendar.startOfDay(for: Date())
        guard let range = calendar.range(of: .day, in: .month, for: today),
              let monthStart = calendar.dateInterval(of: .month, for: today)?.start else {
            return []
        }
        let kept = keptDayKeys

        return range.compactMap { day in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else {
                return nil
            }
            return MonthDay(
                id: AppCalendar.dayKey(date),
                isKept: kept.contains(AppCalendar.dayKey(date)),
                isFuture: date > today
            )
        }
    }

    // MARK: - Account cache

    /// Promises that exist here but have not been acknowledged by the server.
    var pendingEntries: [PromiseEntry] {
        entries.filter(\.needsSync)
    }

    /// True when this device holds a ritual that predates any account.
    var hasLocalPromises: Bool { !entries.isEmpty }

    /// Does a cache already exist for this account on this device?
    func hasCache(for userId: UUID) -> Bool {
        LocalPromiseCache.forAccount(userId).exists
    }

    /// Loads the account's own cache, if this device already holds one.
    /// Returns false when there is nothing stored for that account yet.
    @discardableResult
    func openAccountCache(_ userId: UUID) -> Bool {
        let accountCache = LocalPromiseCache.forAccount(userId)
        guard let state = accountCache.load() else { return false }
        cache = accountCache
        accountId = userId
        apply(state)
        return true
    }

    /// Switches this device to the account's cache with an already-resolved set of
    /// promises. The original `dailypromise.json` is left exactly where it is.
    func adoptAccount(_ userId: UUID, entries resolved: [PromiseEntry]) {
        cache = LocalPromiseCache.forAccount(userId)
        accountId = userId
        entries = resolved.sorted { $0.date < $1.date }
        save()
    }

    /// Replaces the promise set after a sync round. Profile values are untouched.
    func replaceEntries(_ resolved: [PromiseEntry]) {
        entries = resolved.sorted { $0.date < $1.date }
        save()
    }

    /// Records that these exact versions reached the server.
    func markSynced(_ ids: Set<UUID>, at moment: Date) {
        guard !ids.isEmpty else { return }
        for index in entries.indices where ids.contains(entries[index].id) {
            entries[index].syncedAt = moment
        }
        save()
    }

    /// Fills only what this device is missing. Used on every sync round, so the
    /// reminder the user just set here is never overwritten by an older server copy.
    func applyRemoteProfileGaps(_ profile: RemoteProfile) {
        var changed = false
        if userName.isEmpty,
           let name = profile.firstName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            userName = name
            changed = true
        }
        if !hasCompletedOnboarding, profile.onboardingCompletedAt != nil {
            hasCompletedOnboarding = true
            changed = true
        }
        if changed { save() }
    }

    /// Applies the server profile without ever downgrading what the device knows:
    /// a completed onboarding and an existing first name are never unset.
    func applyRemoteProfile(_ profile: RemoteProfile) {
        if let name = profile.firstName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            userName = name
        }
        if profile.onboardingCompletedAt != nil {
            hasCompletedOnboarding = true
        }
        isReminderEnabled = profile.reminderEnabled
        reminderHour = profile.reminderHour
        reminderMinute = profile.reminderMinute
        save()
    }

    // MARK: - Persistence

    private func apply(_ state: StoredState) {
        userName = state.userName
        entries = state.entries
        hasCompletedOnboarding = state.hasCompletedOnboarding
        isReminderEnabled = state.isReminderEnabled
        reminderHour = state.reminderHour
        reminderMinute = state.reminderMinute
    }

    private func save() {
        cache.save(
            StoredState(
                userName: userName,
                entries: entries,
                hasCompletedOnboarding: hasCompletedOnboarding,
                isReminderEnabled: isReminderEnabled,
                reminderHour: reminderHour,
                reminderMinute: reminderMinute
            )
        )
    }
}

/// One day in the current month's quiet dot trace.
nonisolated struct MonthDay: Identifiable, Hashable {
    let id: String
    let isKept: Bool
    let isFuture: Bool
}

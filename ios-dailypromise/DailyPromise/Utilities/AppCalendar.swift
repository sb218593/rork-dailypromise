//
//  AppCalendar.swift
//  DailyPromise
//

import Foundation

/// Calendar and French date formatting helpers shared across the app.
/// All dates come from the device clock — nothing is hardcoded.
nonisolated enum AppCalendar {
    static let locale = Locale(identifier: "fr_FR")

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        calendar.firstWeekday = 2
        return calendar
    }

    static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    /// Stable per-day identity, e.g. "2026-08-30".
    static func dayKey(_ date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    /// The inverse of `dayKey`: "2026-08-30" becomes the start of that local day.
    /// The stored day is a human, local notion — it is never re-derived from a timezone.
    static func date(fromDayKey key: String) -> Date? {
        let parts = key.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else { return nil }
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    static func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }
}

/// French, sentence-cased date strings.
nonisolated enum DateText {
    /// "Samedi 30 août"
    static func greetingDate(_ date: Date) -> String {
        capitalizingFirst(
            date.formatted(
                .dateTime.weekday(.wide).day().month(.wide).locale(AppCalendar.locale)
            )
        )
    }

    /// "30 août"
    static func dayMonth(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.wide).locale(AppCalendar.locale))
    }

    /// "Août 2026"
    static func monthYear(_ date: Date) -> String {
        capitalizingFirst(
            date.formatted(.dateTime.month(.wide).year().locale(AppCalendar.locale))
        )
    }

    /// "Août"
    static func month(_ date: Date) -> String {
        capitalizingFirst(date.formatted(.dateTime.month(.wide).locale(AppCalendar.locale)))
    }

    private static func capitalizingFirst(_ value: String) -> String {
        guard let first = value.first else { return value }
        return String(first).uppercased(with: AppCalendar.locale) + value.dropFirst()
    }
}

nonisolated enum Pluralize {
    /// "1 jour d'affilée" / "12 jours d'affilée"
    static func streak(_ days: Int) -> String {
        days <= 1 ? "\(days) jour d'affilée" : "\(days) jours d'affilée"
    }

    /// "1 jour" / "31 jours"
    static func days(_ days: Int) -> String {
        days <= 1 ? "\(days) jour" : "\(days) jours"
    }
}

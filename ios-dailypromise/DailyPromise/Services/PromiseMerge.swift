//
//  PromiseMerge.swift
//  DailyPromise
//

import Foundation

/// The deterministic conflict rules, in one place.
///
/// Two devices that never talk to each other must reach the same answer, so every
/// rule here is a total order over facts both sides already hold. No clock skew
/// tolerance, no "last writer wins" shortcut, and never a question for the user.
nonisolated enum PromiseMerge {
    /// Resolves one contested day.
    ///
    /// Priority: kept beats pending, then the earliest `keptAt`, then the earliest
    /// commitment (`createdAt`), then UUID order as a final tiebreak.
    static func resolve(_ lhs: PromiseEntry, _ rhs: PromiseEntry) -> PromiseEntry {
        // The same promise edited in two places: merge field by field.
        if lhs.id == rhs.id {
            var merged = lhs.updatedAt >= rhs.updatedAt ? lhs : rhs
            merged.keptAt = earliestKeptAt(lhs, rhs)
            merged.createdAt = min(lhs.createdAt, rhs.createdAt)
            merged.updatedAt = max(lhs.updatedAt, rhs.updatedAt)
            return merged
        }

        var winner = pickWinner(lhs, rhs)
        // `keptAt` is monotone: once a promise has been honoured, no sync may undo it.
        winner.keptAt = earliestKeptAt(lhs, rhs) ?? winner.keptAt
        winner.updatedAt = max(lhs.updatedAt, rhs.updatedAt)

        let loser = winner.id == lhs.id ? rhs : lhs
        if loser.text != winner.text {
            // Diagnostic only: stays on this device, never synced, never displayed.
            print("DailyPromise: day \(winner.dayKey) resolved, replaced text kept in local log only")
        }
        return winner
    }

    /// Merges two whole sets, one calendar day at a time.
    /// A day present on a single side is simply preserved.
    static func merge(_ lhs: [PromiseEntry], _ rhs: [PromiseEntry]) -> [PromiseEntry] {
        var byDay: [String: PromiseEntry] = [:]
        for entry in lhs {
            byDay[entry.dayKey] = entry
        }
        for entry in rhs {
            if let existing = byDay[entry.dayKey] {
                byDay[entry.dayKey] = resolve(existing, entry)
            } else {
                byDay[entry.dayKey] = entry
            }
        }
        return byDay.values.sorted { $0.date < $1.date }
    }

    private static func pickWinner(_ lhs: PromiseEntry, _ rhs: PromiseEntry) -> PromiseEntry {
        switch (lhs.keptAt, rhs.keptAt) {
        case (.some(let left), .some(let right)):
            if left != right { return left < right ? lhs : rhs }
        case (.some, .none):
            return lhs
        case (.none, .some):
            return rhs
        case (.none, .none):
            break
        }

        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt ? lhs : rhs
        }
        return lhs.id.uuidString < rhs.id.uuidString ? lhs : rhs
    }

    private static func earliestKeptAt(_ lhs: PromiseEntry, _ rhs: PromiseEntry) -> Date? {
        switch (lhs.keptAt, rhs.keptAt) {
        case (.some(let left), .some(let right)): min(left, right)
        case (.some(let left), .none): left
        case (.none, .some(let right)): right
        case (.none, .none): nil
        }
    }
}

//
//  HistoryView.swift
//  DailyPromise
//

import SwiftUI

/// A calm record of promises kept — a journal to reread, never a todo list.
struct HistoryView: View {
    @Environment(PromiseStore.self) private var store

    private var weeks: [PromiseWeek] { store.keptWeeks }

    var body: some View {
        ZStack {
            WarmBackground(intensity: 0.05)

            if weeks.isEmpty {
                emptyState
            } else {
                record
            }
        }
    }

    private var record: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header

                ForEach(weeks) { week in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(week.title.uppercased(with: AppCalendar.locale))
                            .font(.caption2.weight(.semibold))
                            .tracking(1.4)
                            .foregroundStyle(Theme.muted)
                            .padding(.leading, 4)

                        VStack(spacing: 0) {
                            ForEach(Array(week.entries.enumerated()), id: \.element.id) { index, entry in
                                if index > 0 {
                                    Divider()
                                        .overlay(Theme.hairline.opacity(0.7))
                                        .padding(.leading, 18)
                                }
                                row(for: entry)
                            }
                        }
                        .background(Theme.surface, in: .rect(cornerRadius: Theme.cardRadius))
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.cardRadius)
                                .stroke(Theme.hairline, lineWidth: 0.8)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.margin)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(DateText.monthYear(Date()))
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(Theme.ink)

            Text(monthSubtitle)
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var monthSubtitle: String {
        let count = store.keptThisMonthCount
        switch count {
        case 0: return "Un mois de promesses tenues"
        case 1: return "1 promesse tenue ce mois-ci"
        default: return "\(count) promesses tenues ce mois-ci"
        }
    }

    private func row(for entry: PromiseEntry) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(entry.text)
                .font(.body)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(DateText.dayMonth(entry.date))
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .monospacedDigit()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 17)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.text), tenue le \(DateText.dayMonth(entry.date))")
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "book.closed")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Theme.muted.opacity(0.7))

            Text("Votre carnet est encore vierge.")
                .font(.journal(24))
                .foregroundStyle(Theme.ink)

            Text("Chaque promesse tenue viendra s'y inscrire.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }
}

#Preview {
    HistoryView()
        .environment(PromiseStore(fileName: "preview-history.json"))
}

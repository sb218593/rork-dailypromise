//
//  MergeInvitationView.swift
//  DailyPromise
//

import SwiftUI

/// The single question the migration may ask: this device and this account both
/// hold promises. Two paths only — bring them together, or leave everything
/// exactly as it is. Nothing here can discard the local history.
struct MergeInvitationView: View {
    let offer: MergeOffer
    let isMerging: Bool
    let onMerge: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            WarmBackground(intensity: 0.12)

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 30)

                Text("VOS PROMESSES")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.8)
                    .foregroundStyle(Theme.muted)

                Text("Deux fils à réunir.")
                    .font(.journal(32))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 12)

                PaperCard {
                    VStack(alignment: .leading, spacing: 18) {
                        countRow(
                            value: offer.localCount,
                            label: "sur cet appareil",
                            symbol: "iphone"
                        )
                        Rectangle()
                            .fill(Theme.hairline)
                            .frame(height: 0.8)
                        countRow(
                            value: offer.accountCount,
                            label: "sur votre compte",
                            symbol: "icloud"
                        )
                    }
                }
                .padding(.top, 26)

                Text("Les réunir garde chaque journée des deux côtés. Rien n'est effacé, ici comme sur votre compte.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 20)

                Spacer()

                Button(action: onMerge) {
                    Group {
                        if isMerging {
                            ProgressView().tint(.white)
                        } else {
                            Text("Réunir mes promesses")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.white)
                .background(Theme.terracotta, in: .rect(cornerRadius: 16))
                .disabled(isMerging)

                Button(action: onCancel) {
                    Text("Annuler")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .disabled(isMerging)
                .padding(.top, 4)
                .padding(.bottom, 20)
            }
            .padding(.horizontal, Theme.margin)
        }
    }

    private func countRow(value: Int, label: String, symbol: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 17))
                .foregroundStyle(Theme.terracotta)
                .frame(width: 26)

            Text("\(value)")
                .font(.journal(26, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())

            Text(value <= 1 ? "promesse \(label)" : "promesses \(label)")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    MergeInvitationView(
        offer: MergeOffer(id: UUID(), localCount: 23, accountCount: 47),
        isMerging: false,
        onMerge: {},
        onCancel: {}
    )
}

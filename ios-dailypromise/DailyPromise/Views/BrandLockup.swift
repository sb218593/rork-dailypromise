//
//  BrandLockup.swift
//  DailyPromise
//

import SwiftUI

/// The account screen's brand header: terracotta pebble with the app's own
/// checkmark, the wordmark, and the serif promise underneath.
struct BrandLockup: View {
    @State private var hasDrawn: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let deepTerracotta = Color(red: 0.545, green: 0.235, blue: 0.106)

    var body: some View {
        VStack(spacing: 14) {
            CheckmarkShape()
                .trim(from: 0, to: hasDrawn ? 1 : 0)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                .frame(width: 30, height: 22)
                .frame(width: 68, height: 68)
                .background(
                    LinearGradient(
                        colors: [Theme.terracotta, Self.deepTerracotta],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: .rect(cornerRadius: 22)
                )
                .shadow(color: Theme.terracotta.opacity(0.32), radius: 14, x: 0, y: 10)

            Text("DailyPromise")
                .font(.system(size: 32, weight: .bold))
                .tracking(-0.8)
                .foregroundStyle(Theme.ink)

            Text("Tenez votre promesse du jour.")
                .font(.journal(15))
                .italic()
                .foregroundStyle(Theme.muted)
        }
        .onAppear {
            guard !hasDrawn else { return }
            if reduceMotion {
                hasDrawn = true
            } else {
                withAnimation(.smooth(duration: 0.7).delay(0.15)) { hasDrawn = true }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ZStack {
        WarmBackground()
        BrandLockup()
    }
}

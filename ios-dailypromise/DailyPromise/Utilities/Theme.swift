//
//  Theme.swift
//  DailyPromise
//

import SwiftUI

/// The single app-wide visual system: warm paper canvas, terracotta accent, warm ink type.
enum Theme {
    /// Warm bone paper canvas (#F7F3EC).
    static let canvas = Color(red: 0.969, green: 0.953, blue: 0.925)
    /// Elevated surface (#FFFFFF).
    static let surface = Color.white
    /// Terracotta accent (#B4552D), used sparingly.
    static let terracotta = Color(red: 0.706, green: 0.333, blue: 0.176)
    /// Deep warm ink for primary text (#2E2A24).
    static let ink = Color(red: 0.180, green: 0.165, blue: 0.141)
    /// Muted warm gray for secondary text (#8A8378).
    static let muted = Color(red: 0.541, green: 0.514, blue: 0.471)
    /// Soft sage, gentle positive tone (#7C8B6F).
    static let sage = Color(red: 0.486, green: 0.545, blue: 0.435)
    /// Hairline border on elevated surfaces.
    static let hairline = Color(red: 0.859, green: 0.835, blue: 0.796)

    static let cardRadius: CGFloat = 20
    static let margin: CGFloat = 20
}

/// Warm paper background with a single soft radial warmth near the top.
struct WarmBackground: View {
    var intensity: Double = 0.10

    var body: some View {
        Theme.canvas
            .overlay(alignment: .top) {
                RadialGradient(
                    colors: [Theme.terracotta.opacity(intensity), Theme.terracotta.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: 340
                )
                .frame(height: 620)
                .offset(y: -120)
                .blur(radius: 40)
            }
            .ignoresSafeArea()
    }
}

/// Elevated white surface with a soft hairline border, no heavy shadow.
struct PaperCard<Content: View>: View {
    var padding: CGFloat = 22
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.cardRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .stroke(Theme.hairline, lineWidth: 0.8)
            }
    }
}

extension Font {
    /// Journal-like serif used for promise text and reflective lines.
    static func journal(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}

//
//  ScoreRingView.swift
//  Yala
//
//  Circular progress ring used by the Panel 2.0 "Salud Financiera" section.
//  Renders a track + trimmed arc with an animated spring. No Canvas — keeps
//  re-draws cheap and predictable inside the Panel ScrollView.
//

import SwiftUI

struct ScoreRingView<Foreground: ShapeStyle>: View {
    /// 0.0 … 1.0. Values outside are clamped inside the view.
    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat
    let foreground: Foreground
    var trackOpacity: Double = 0.15

    var body: some View {
        let clamped = max(0, min(1, progress))
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(trackOpacity), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    foreground,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.6), value: clamped)
        }
        .frame(width: size, height: size)
    }
}

#if DEBUG
#Preview("ScoreRingView") {
    HStack(spacing: 24) {
        ScoreRingView(
            progress: 0.88,
            size: 100,
            lineWidth: 10,
            foreground: LinearGradient(colors: DS.Gradients.heroCalm, startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        ScoreRingView(
            progress: 0.55,
            size: 44,
            lineWidth: 5,
            foreground: Color.purple
        )
        ScoreRingView(
            progress: 0,
            size: 44,
            lineWidth: 5,
            foreground: DS.Semantic.disabledForeground
        )
    }
    .padding()
}
#endif

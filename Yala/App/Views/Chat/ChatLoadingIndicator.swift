//
//  ChatLoadingIndicator.swift
//  Yala
//
//  Pulsating dots indicator for chat loading state.
//

import SwiftUI

struct ChatLoadingIndicator: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack {
            HStack(spacing: DS.Spacing.xs) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(.secondary)
                        .frame(width: 8, height: 8) // A11Y-DT: fixed decorative dot
                        .phaseAnimator(reduceMotion ? [0] : [0, 1, 2]) { content, phase in
                            content
                                .scaleEffect(phase == index ? 1.3 : 0.8)
                                .opacity(phase == index ? 1.0 : 0.4)
                        } animation: { _ in
                            .easeInOut(duration: 0.4)
                        }
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.md)
            .background(.thCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))

            Spacer()
        }
    }
}

//
//  WidgetProgressBar.swift
//  YalaWidgets
//
//  Horizontal progress bar for budget widgets.
//  Supports overflow indication for over-budget states.
//

import SwiftUI
import WidgetKit

/// Horizontal progress bar with color coding
struct WidgetProgressBar: View {
    let progress: Double  // 0.0 - 1.0+ (can exceed 1.0 for over-budget)
    let color: Color
    let height: CGFloat

    init(
        progress: Double,
        color: Color = WidgetColors.success,
        height: CGFloat = WDS.Progress.height
    ) {
        self.progress = progress
        self.color = color
        self.height = height
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.gray.opacity(0.2))

                // Progress fill
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: progressWidth(in: geometry.size.width))
                    .widgetAccentable()
            }
        }
        .frame(height: height)
    }

    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        // Clamp between 0 and 100% of width
        let clampedProgress = min(max(progress, 0), 1.0)
        return totalWidth * clampedProgress
    }
}

// MARK: - Convenience Initializers

extension WidgetProgressBar {
    /// Creates a progress bar with automatic color based on progress percentage
    static func budget(percentUsed: Double, height: CGFloat = WDS.Progress.height) -> WidgetProgressBar {
        WidgetProgressBar(
            progress: percentUsed / 100.0,
            color: WidgetColors.forBudget(percentUsed: percentUsed),
            height: height
        )
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        // Healthy (green)
        WidgetProgressBar(progress: 0.5, color: WidgetColors.success)

        // Warning (amber)
        WidgetProgressBar(progress: 0.8, color: WidgetColors.warning)

        // Over budget (red)
        WidgetProgressBar(progress: 1.0, color: WidgetColors.negative)

        // Using convenience initializer
        WidgetProgressBar.budget(percentUsed: 45)
        WidgetProgressBar.budget(percentUsed: 85)
        WidgetProgressBar.budget(percentUsed: 110)
    }
    .padding()
}

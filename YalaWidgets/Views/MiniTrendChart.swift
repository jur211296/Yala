//
//  MiniTrendChart.swift
//  YalaWidgets
//
//  A lightweight trend chart using Path instead of Charts framework.
//  Optimized for widget performance.
//

import SwiftUI

struct MiniTrendChart: View {
    let dataPoints: [WidgetTrendPoint]
    let lineColor: Color
    let fillColor: Color

    init(
        dataPoints: [WidgetTrendPoint],
        lineColor: Color = WidgetColors.accent,
        fillColor: Color = WidgetColors.accent.opacity(0.2)
    ) {
        self.dataPoints = dataPoints
        self.lineColor = lineColor
        self.fillColor = fillColor
    }

    var body: some View {
        GeometryReader { geometry in
            if dataPoints.count >= 2 {
                ZStack {
                    // Fill area
                    fillPath(in: geometry.size)
                        .fill(fillColor)

                    // Line
                    linePath(in: geometry.size)
                        .stroke(lineColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            } else {
                // Empty state - flat line
                Path { path in
                    let midY = geometry.size.height / 2
                    path.move(to: CGPoint(x: 0, y: midY))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: midY))
                }
                .stroke(lineColor.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
            }
        }
    }

    private func linePath(in size: CGSize) -> Path {
        guard dataPoints.count >= 2 else { return Path() }

        let minBalance = dataPoints.map(\.balance).min() ?? 0
        let maxBalance = dataPoints.map(\.balance).max() ?? 0
        let range = maxBalance - minBalance

        // Add padding to prevent line touching edges
        let effectiveRange = range > 0 ? range : 1
        let verticalPadding: CGFloat = 4

        return Path { path in
            for (index, point) in dataPoints.enumerated() {
                let x = size.width * CGFloat(index) / CGFloat(dataPoints.count - 1)
                let normalizedY = (point.balance - minBalance) / effectiveRange
                let y = verticalPadding + (size.height - 2 * verticalPadding) * (1 - CGFloat(normalizedY))

                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }

    private func fillPath(in size: CGSize) -> Path {
        guard dataPoints.count >= 2 else { return Path() }

        let minBalance = dataPoints.map(\.balance).min() ?? 0
        let maxBalance = dataPoints.map(\.balance).max() ?? 0
        let range = maxBalance - minBalance

        let effectiveRange = range > 0 ? range : 1
        let verticalPadding: CGFloat = 4

        return Path { path in
            // Start at bottom-left
            path.move(to: CGPoint(x: 0, y: size.height))

            // Draw line to first data point
            let firstNormalizedY = (dataPoints[0].balance - minBalance) / effectiveRange
            let firstY = verticalPadding + (size.height - 2 * verticalPadding) * (1 - CGFloat(firstNormalizedY))
            path.addLine(to: CGPoint(x: 0, y: firstY))

            // Draw through all data points
            for (index, point) in dataPoints.enumerated() {
                let x = size.width * CGFloat(index) / CGFloat(dataPoints.count - 1)
                let normalizedY = (point.balance - minBalance) / effectiveRange
                let y = verticalPadding + (size.height - 2 * verticalPadding) * (1 - CGFloat(normalizedY))
                path.addLine(to: CGPoint(x: x, y: y))
            }

            // Close path at bottom-right and back to start
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.closeSubpath()
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleData: [WidgetTrendPoint] = [
        WidgetTrendPoint(date: Date().addingTimeInterval(-6 * 86400), balance: 1000),
        WidgetTrendPoint(date: Date().addingTimeInterval(-5 * 86400), balance: 1200),
        WidgetTrendPoint(date: Date().addingTimeInterval(-4 * 86400), balance: 1100),
        WidgetTrendPoint(date: Date().addingTimeInterval(-3 * 86400), balance: 1400),
        WidgetTrendPoint(date: Date().addingTimeInterval(-2 * 86400), balance: 1300),
        WidgetTrendPoint(date: Date().addingTimeInterval(-1 * 86400), balance: 1500),
        WidgetTrendPoint(date: Date(), balance: 1450),
    ]

    return MiniTrendChart(dataPoints: sampleData)
        .frame(width: 200, height: 60)
        .padding()
}

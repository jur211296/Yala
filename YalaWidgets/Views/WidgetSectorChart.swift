//
//  WidgetSectorChart.swift
//  YalaWidgets
//
//  Swift Charts-based pie/donut chart with bubble icons and connector lines.
//  Matches the visual design of PanelView's CategoriesPieWidget.
//

import SwiftUI
import Charts

// MARK: - Segment Data

/// Data for a single pie chart segment
struct WidgetSectorSegment: Identifiable {
    let id: String
    let name: String
    let iconName: String?
    let amount: Double
    let percentage: Double
    let colorHex: String

    // Calculated angles (internal, set during processing)
    var startAngle: Double = 0
    var endAngle: Double = 0

    var midAngle: Double {
        (startAngle + endAngle) / 2
    }

    /// Public initializer (angles are calculated internally)
    init(id: String, name: String, iconName: String?, amount: Double, percentage: Double, colorHex: String) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.amount = amount
        self.percentage = percentage
        self.colorHex = colorHex
    }
}

// MARK: - Widget Sector Chart

/// Donut chart using Swift Charts with bubble icons and connector lines
struct WidgetSectorChart: View {
    let segments: [WidgetSectorSegment]
    let innerRadiusRatio: CGFloat
    let showBubbles: Bool

    init(
        segments: [WidgetSectorSegment],
        innerRadiusRatio: CGFloat = 0.50,
        showBubbles: Bool = true
    ) {
        self.segments = segments
        self.innerRadiusRatio = innerRadiusRatio
        self.showBubbles = showBubbles
    }

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let diameter = min(geo.size.width, geo.size.height)
            // Leave space for bubbles (65% of available space for chart)
            let chartRadius = diameter / 2 * (showBubbles ? 0.65 : 0.95)

            ZStack {
                // 1. Connector lines (behind chart)
                if showBubbles {
                    connectorLines(center: center, chartRadius: chartRadius)
                }

                // 2. SectorMark chart
                chartView
                    .frame(width: chartRadius * 2, height: chartRadius * 2)
                    .position(center)

                // 3. Bubbles (on top)
                if showBubbles {
                    bubblesLayer(center: center, chartRadius: chartRadius)
                }
            }
        }
    }

    // MARK: - Chart View

    @ViewBuilder
    private var chartView: some View {
        let safeData = processedSegments.filter { $0.amount.isFinite && $0.amount > 0 }
        let totalAmount = safeData.reduce(0) { $0 + $1.amount }

        if safeData.isEmpty || !totalAmount.isFinite || totalAmount <= 0 {
            Color.clear
        } else {
            Chart(safeData) { item in
                SectorMark(
                    angle: .value("Amount", item.amount),
                    innerRadius: .ratio(innerRadiusRatio),
                    angularInset: 1.5
                )
                .cornerRadius(WDS.Radius.xs)
                .foregroundStyle(Color(hex: item.colorHex))
            }
            .chartLegend(.hidden)
        }
    }

    // MARK: - Connector Lines

    private func connectorLines(center: CGPoint, chartRadius: CGFloat) -> some View {
        Path { path in
            for item in processedSegments {
                // Only show line for segments > 4%
                if shouldShowBubble(for: item) {
                    let angle = item.midAngle

                    // Start: Edge of the pie slice
                    let startX = center.x + cos(angle) * chartRadius
                    let startY = center.y + sin(angle) * chartRadius

                    // End: Center of the bubble icon
                    let bubbleOffset: CGFloat = 30.0
                    let bubbleDistance = chartRadius + bubbleOffset
                    let endX = center.x + cos(angle) * bubbleDistance
                    let endY = center.y + sin(angle) * bubbleDistance

                    path.move(to: CGPoint(x: startX, y: startY))
                    path.addLine(to: CGPoint(x: endX, y: endY))
                }
            }
        }
        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
    }

    // MARK: - Bubbles Layer

    private func bubblesLayer(center: CGPoint, chartRadius: CGFloat) -> some View {
        ZStack {
            ForEach(processedSegments) { item in
                bubbleView(for: item, center: center, chartRadius: chartRadius)
            }
        }
    }

    @ViewBuilder
    private func bubbleView(for item: WidgetSectorSegment, center: CGPoint, chartRadius: CGFloat) -> some View {
        if shouldShowBubble(for: item), let iconName = item.iconName {
            let angle = item.midAngle
            let bubbleOffset: CGFloat = 30.0
            let bubbleDistance = chartRadius + bubbleOffset
            let iconSize: CGFloat = 28
            let fontSize: CGFloat = 10

            let bubbleX = center.x + cos(angle) * bubbleDistance
            let bubbleY = center.y + sin(angle) * bubbleDistance

            ZStack {
                // Bubble icon
                Circle()
                    .fill(Color(hex: item.colorHex))
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                    .frame(width: iconSize, height: iconSize)

                Image(systemName: iconName)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundStyle(.white)

                // Percentage label (only for segments > 10%)
                if item.percentage > 10.0 {
                    Text("\(Int(item.percentage))%")
                        .font(WDS.Typography.tiny)
                        .foregroundStyle(Color(hex: item.colorHex))
                        .offset(
                            x: cos(angle) * 30,
                            y: sin(angle) * 30
                        )
                }
            }
            .position(x: bubbleX, y: bubbleY)
        }
    }

    // MARK: - Visibility Threshold

    /// Show bubble only for segments > 4% (matches PanelView)
    private func shouldShowBubble(for segment: WidgetSectorSegment) -> Bool {
        segment.percentage > 4.0
    }

    // MARK: - Process Segments with Angles

    private var processedSegments: [WidgetSectorSegment] {
        // Start at 12 o'clock (-π/2)
        var currentAngle: Double = -Double.pi / 2
        let total = segments.reduce(0) { $0 + $1.amount }

        return segments.map { segment in
            var processed = segment
            let ratio = total > 0 ? segment.amount / total : 0
            let sweep = ratio * 2 * Double.pi

            processed.startAngle = currentAngle
            processed.endAngle = currentAngle + sweep
            currentAngle += sweep

            return processed
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleSegments = [
        WidgetSectorSegment(id: "1", name: "Alimentación", iconName: "fork.knife", amount: 1200, percentage: 37, colorHex: "6366F1"),
        WidgetSectorSegment(id: "2", name: "Transporte", iconName: "car.fill", amount: 800, percentage: 25, colorHex: "FF0080"),
        WidgetSectorSegment(id: "3", name: "Servicios", iconName: "bolt.fill", amount: 600, percentage: 18, colorHex: "00C2CB"),
        WidgetSectorSegment(id: "4", name: "Entretenimiento", iconName: "gamecontroller.fill", amount: 400, percentage: 12, colorHex: "F59E0B"),
        WidgetSectorSegment(id: "5", name: "Otros", iconName: "ellipsis.circle", amount: 250, percentage: 8, colorHex: "6B7280"),
    ]

    VStack(spacing: 20) {
        // With bubbles
        WidgetSectorChart(segments: sampleSegments, innerRadiusRatio: 0.50, showBubbles: true)
            .frame(width: 200, height: 200)
            .background(Color.gray.opacity(0.1))

        // Without bubbles (compact mode)
        WidgetSectorChart(segments: sampleSegments, innerRadiusRatio: 0.55, showBubbles: false)
            .frame(width: 100, height: 100)
            .background(Color.gray.opacity(0.1))
    }
    .padding()
}

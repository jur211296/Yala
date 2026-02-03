//
//  MiniDonutChart.swift
//  YalaWidgets
//
//  Donut chart for category/subcategory distribution in Large widgets.
//  Lightweight implementation using Path instead of Charts framework.
//

import SwiftUI

/// Data point for donut chart segment
struct DonutSegment: Identifiable {
    let id: String
    let value: Double
    let color: Color
    let label: String
}

/// Donut chart optimized for widget performance
struct MiniDonutChart: View {
    let segments: [DonutSegment]
    let innerRadiusRatio: CGFloat  // 0.5 = half of outer radius
    let showHole: Bool

    init(
        segments: [DonutSegment],
        innerRadiusRatio: CGFloat = 0.6,
        showHole: Bool = true
    ) {
        self.segments = segments
        self.innerRadiusRatio = innerRadiusRatio
        self.showHole = showHole
    }

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let outerRadius = size / 2
            let innerRadius = showHole ? outerRadius * innerRadiusRatio : 0

            ZStack {
                // Draw segments
                ForEach(Array(segmentData.enumerated()), id: \.offset) { index, data in
                    DonutSegmentShape(
                        startAngle: data.startAngle,
                        endAngle: data.endAngle,
                        innerRadius: innerRadius,
                        outerRadius: outerRadius
                    )
                    .fill(segments[index].color)
                }
            }
            .frame(width: size, height: size)
            .position(center)
        }
    }

    private var segmentData: [(startAngle: Angle, endAngle: Angle)] {
        let total = segments.reduce(0) { $0 + $1.value }
        guard total > 0 else { return [] }

        var currentAngle = Angle.degrees(-90)  // Start from top
        var result: [(startAngle: Angle, endAngle: Angle)] = []

        for segment in segments {
            let segmentAngle = Angle.degrees(360 * (segment.value / total))
            let endAngle = currentAngle + segmentAngle
            result.append((startAngle: currentAngle, endAngle: endAngle))
            currentAngle = endAngle
        }

        return result
    }
}

/// Shape for a single donut segment
struct DonutSegmentShape: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let innerRadius: CGFloat
    let outerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)

        var path = Path()

        // Outer arc
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )

        // Line to inner arc
        if innerRadius > 0 {
            let innerEndPoint = CGPoint(
                x: center.x + innerRadius * CGFloat(cos(endAngle.radians)),
                y: center.y + innerRadius * CGFloat(sin(endAngle.radians))
            )
            path.addLine(to: innerEndPoint)

            // Inner arc (reverse direction)
            path.addArc(
                center: center,
                radius: innerRadius,
                startAngle: endAngle,
                endAngle: startAngle,
                clockwise: true
            )
        } else {
            // For pie chart (no hole), just line to center
            path.addLine(to: center)
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview {
    let sampleSegments = [
        DonutSegment(id: "1", value: 1200, color: Color(hex: "6366F1"), label: "Alimentación"),
        DonutSegment(id: "2", value: 800, color: Color(hex: "FF0080"), label: "Transporte"),
        DonutSegment(id: "3", value: 600, color: Color(hex: "00C2CB"), label: "Servicios"),
        DonutSegment(id: "4", value: 400, color: Color(hex: "F59E0B"), label: "Otros"),
    ]

    VStack(spacing: 20) {
        MiniDonutChart(segments: sampleSegments)
            .frame(width: 120, height: 120)

        MiniDonutChart(segments: sampleSegments, showHole: false)
            .frame(width: 100, height: 100)
    }
    .padding()
}

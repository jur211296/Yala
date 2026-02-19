//
//  YalaSpark.swift
//  Yala
//
//  Distinctive 4-pointed star icon representing Yala PRO.
//  Inspired by the spark element in the Yala logo.
//

import SwiftUI

// MARK: - YalaSparkShape

/// A 4-pointed star shape drawn with Path.
struct YalaSparkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let width = rect.width
        let height = rect.height

        // 4-pointed star: points at top, right, bottom, left
        // Inner points at 45° angles
        let outerRadius = min(width, height) / 2
        let innerRadius = outerRadius * 0.35 // Inner indent

        // Start at top point
        path.move(to: CGPoint(x: center.x, y: center.y - outerRadius))

        // Top-right inner
        path.addLine(to: CGPoint(
            x: center.x + innerRadius * cos(.pi / 4),
            y: center.y - innerRadius * sin(.pi / 4)
        ))

        // Right point
        path.addLine(to: CGPoint(x: center.x + outerRadius, y: center.y))

        // Bottom-right inner
        path.addLine(to: CGPoint(
            x: center.x + innerRadius * cos(.pi / 4),
            y: center.y + innerRadius * sin(.pi / 4)
        ))

        // Bottom point
        path.addLine(to: CGPoint(x: center.x, y: center.y + outerRadius))

        // Bottom-left inner
        path.addLine(to: CGPoint(
            x: center.x - innerRadius * cos(.pi / 4),
            y: center.y + innerRadius * sin(.pi / 4)
        ))

        // Left point
        path.addLine(to: CGPoint(x: center.x - outerRadius, y: center.y))

        // Top-left inner
        path.addLine(to: CGPoint(
            x: center.x - innerRadius * cos(.pi / 4),
            y: center.y - innerRadius * sin(.pi / 4)
        ))

        path.closeSubpath()

        return path
    }
}

// MARK: - YalaSpark View

/// Yala's distinctive 4-pointed star icon for PRO indicators.
/// Usage: `YalaSpark(size: .medium)` or `YalaSpark(size: .large, animated: true)`
struct YalaSpark: View {

    // MARK: - Size Variants

    enum Size {
        case small   // 12pt - inline badges
        case medium  // 16pt - header badge
        case large   // 24pt - hero sections

        var dimension: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 16
            case .large: return 24
            }
        }
    }

    // MARK: - Properties

    var size: Size = .medium
    var animated: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    private var shouldAnimate: Bool {
        animated && !reduceMotion
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Main spark shape
            YalaSparkShape()
                .fill(
                    LinearGradient(
                        colors: DS.Gradients.proBadge,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Center glow accent
            Circle()
                .fill(Color.white.opacity(0.6))
                .frame(width: size.dimension * 0.25, height: size.dimension * 0.25)
        }
        .frame(width: size.dimension, height: size.dimension)
        .rotationEffect(.degrees(isAnimating ? 15 : -15))
        .scaleEffect(isAnimating ? 1.05 : 1.0)
        .onAppear {
            guard shouldAnimate else { return }
            withAnimation(
                .easeInOut(duration: 3.0)
                .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Preview

#Preview("Sizes") {
    VStack(spacing: DS.Spacing.xl) {
        HStack {
            Text("Small (12pt):")
            YalaSpark(size: .small)
        }
        HStack {
            Text("Medium (16pt):")
            YalaSpark(size: .medium)
        }
        HStack {
            Text("Large (24pt):")
            YalaSpark(size: .large)
        }
        HStack {
            Text("Large Animated:")
            YalaSpark(size: .large, animated: true)
        }
    }
    .padding()
    .background(.thBackground)
}

#Preview("In Context") {
    VStack(spacing: DS.Spacing.lg) {
        // With ProBadge style
        HStack(spacing: DS.Spacing.xs) {
            YalaSpark(size: .small)
            Text("PRO")
                .font(DS.Typography.badgeLabel)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(
            LinearGradient(
                colors: DS.Gradients.proBadge,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(Capsule())

        // Hero spark
        ZStack {
            Circle()
                .fill(.thCard)
                .frame(width: 40, height: 40)
            YalaSpark(size: .large, animated: true)
        }
    }
    .padding()
    .background(.thBackground)
}

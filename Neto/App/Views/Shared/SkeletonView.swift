//
//  SkeletonView.swift
//  Neto
//
//  Reusable skeleton loading component with shimmer animation.
//

import SwiftUI

// MARK: - Shimmer Effect

/// A view modifier that adds a shimmer animation effect.
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.white.opacity(0.4),
                            .clear,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (phase * geometry.size.width * 2))
                }
            )
            .mask(content)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    /// Adds a shimmer loading effect to the view.
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton View

/// A basic skeleton placeholder with configurable size and shape.
struct SkeletonView: View {
    var width: CGFloat? = nil
    var height: CGFloat = 20
    var cornerRadius: CGFloat = CornerRadius.sm

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.netoSecondaryText.opacity(0.12))
            .frame(width: width, height: height)
            .shimmer()
    }
}

// MARK: - Skeleton Shapes

/// Circle skeleton for avatars/icons
struct SkeletonCircle: View {
    var size: CGFloat = 40

    var body: some View {
        Circle()
            .fill(Color.netoSecondaryText.opacity(0.12))
            .frame(width: size, height: size)
            .shimmer()
    }
}

// MARK: - Widget Skeleton Templates

/// Skeleton for TrendCardView
struct TrendCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonView(width: 140, height: 16)
                    SkeletonView(width: 100, height: 28)
                }
                Spacer()
                SkeletonView(width: 120, height: 32, cornerRadius: CornerRadius.full)
            }

            // Chart area
            SkeletonView(height: 220, cornerRadius: CornerRadius.md)
                .padding(.top, 8)
        }
        .padding(20)
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.xLarge, style: .continuous))
    }
}

/// Skeleton for CategoriesPieChartCardView
struct CategoriesPieSkeleton: View {
    var body: some View {
        VStack(spacing: 16) {
            // Title
            SkeletonView(width: 120, height: 16)

            // Pie chart placeholder
            SkeletonCircle(size: 160)

            // Legend items
            VStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    HStack {
                        SkeletonCircle(size: 12)
                        SkeletonView(width: 80, height: 14)
                        Spacer()
                        SkeletonView(width: 60, height: 14)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.xLarge, style: .continuous))
    }
}

/// Skeleton for CashFlowCardView
struct CashFlowSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            SkeletonView(width: 120, height: 16)

            // Summary row
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    SkeletonView(width: 60, height: 12)
                    SkeletonView(width: 80, height: 20)
                }
                VStack(alignment: .leading, spacing: 4) {
                    SkeletonView(width: 60, height: 12)
                    SkeletonView(width: 80, height: 20)
                }
                Spacer()
            }

            // Chart
            SkeletonView(height: 120, cornerRadius: CornerRadius.md)
        }
        .padding(20)
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.xLarge, style: .continuous))
    }
}

/// Skeleton for LatestRecordsCardView
struct LatestRecordsSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            SkeletonView(width: 130, height: 16)

            // Record items
            ForEach(0..<3, id: \.self) { _ in
                HStack {
                    SkeletonCircle(size: 36)
                    VStack(alignment: .leading, spacing: 4) {
                        SkeletonView(width: 100, height: 14)
                        SkeletonView(width: 70, height: 12)
                    }
                    Spacer()
                    SkeletonView(width: 60, height: 16)
                }
            }
        }
        .padding(20)
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.xLarge, style: .continuous))
    }
}

// MARK: - Generic Widget Skeleton

/// A generic skeleton that matches widget card styling
struct WidgetSkeleton: View {
    var height: CGFloat = 200

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SkeletonView(width: 100, height: 16)
            Spacer()
            SkeletonView(height: height * 0.6, cornerRadius: CornerRadius.md)
        }
        .padding(20)
        .frame(height: height)
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.xLarge, style: .continuous))
    }
}

// MARK: - Preview

#Preview("Skeleton Components") {
    ScrollView {
        VStack(spacing: 20) {
            SkeletonView(width: 200, height: 20)
            SkeletonCircle()
            TrendCardSkeleton()
            CashFlowSkeleton()
            LatestRecordsSkeleton()
        }
        .padding()
    }
    .background(Color.netoBackground)
}

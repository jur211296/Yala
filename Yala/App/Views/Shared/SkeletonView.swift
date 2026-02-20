//
//  SkeletonView.swift
//  Yala
//
//  Skeleton loading views for widget placeholders.
//

import SwiftUI

// MARK: - Generic Widget Skeleton

struct WidgetSkeleton: View {
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: DS.Radius.lg)
            .fill(.thSecondaryText.opacity(0.1))
            .frame(height: height)
            .shimmer()
    }
}

// MARK: - Trend Card Skeleton

struct TrendWidgetSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            HStack {
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(.thSecondaryText.opacity(0.15))
                    .frame(width: 120, height: 20)
                Spacer()
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(.thSecondaryText.opacity(0.1))
                    .frame(width: 100, height: 28)
            }

            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(.thSecondaryText.opacity(0.15))
                .frame(width: 150, height: 32)

            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(.thSecondaryText.opacity(0.1))
                .frame(height: 180)
        }
        .padding(DS.Card.padding)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .shimmer()
    }
}

// MARK: - Cash Flow Skeleton

struct CashFlowSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(.thSecondaryText.opacity(0.15))
                .frame(width: 100, height: 18)

            HStack(spacing: DS.Spacing.lg) {
                ForEach(0..<2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                        .fill(.thSecondaryText.opacity(0.1))
                        .frame(height: 60)
                }
            }

            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(.thSecondaryText.opacity(0.1))
                .frame(height: 120)
        }
        .padding(DS.Card.padding)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .shimmer()
    }
}

// MARK: - Latest Records Skeleton

struct LatestRecordsSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(.thSecondaryText.opacity(0.15))
                .frame(width: 120, height: 18)

            ForEach(0..<4, id: \.self) { _ in
                HStack {
                    Circle()
                        .fill(.thSecondaryText.opacity(0.1))
                        .frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        RoundedRectangle(cornerRadius: DS.Radius.xs)
                            .fill(.thSecondaryText.opacity(0.15))
                            .frame(width: 100, height: 14)
                        RoundedRectangle(cornerRadius: DS.Radius.xs)
                            .fill(.thSecondaryText.opacity(0.1))
                            .frame(width: 60, height: 12)
                    }
                    Spacer()
                    RoundedRectangle(cornerRadius: DS.Radius.xs)
                        .fill(.thSecondaryText.opacity(0.15))
                        .frame(width: 60, height: 16)
                }
            }
        }
        .padding(DS.Card.padding)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .shimmer()
    }
}

// MARK: - Categories Pie Skeleton

struct CategoriesPieSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            RoundedRectangle(cornerRadius: DS.Radius.sm)
                .fill(.thSecondaryText.opacity(0.15))
                .frame(width: 100, height: 18)

            HStack(spacing: DS.Spacing.xl) {
                Circle()
                    .fill(.thSecondaryText.opacity(0.1))
                    .frame(width: 120, height: 120)

                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    ForEach(0..<4, id: \.self) { _ in
                        HStack {
                            Circle()
                                .fill(.thSecondaryText.opacity(0.15))
                                .frame(width: 12, height: 12)
                            RoundedRectangle(cornerRadius: DS.Radius.xs)
                                .fill(.thSecondaryText.opacity(0.1))
                                .frame(width: 60, height: 12)
                        }
                    }
                }
            }
        }
        .padding(DS.Card.padding)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
        .shimmer()
    }
}

// MARK: - Shimmer Modifier

struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    if !reduceMotion {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .clear,
                                        .white.opacity(0.2),
                                        .clear,
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * 0.5)
                            .offset(x: phase * geometry.size.width * 1.5 - geometry.size.width * 0.25)
                    }
                }
                .mask(content)
            )
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

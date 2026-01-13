//
//  SkeletonView.swift
//  Neto
//
//  Skeleton loading views for widget placeholders.
//

import SwiftUI

// MARK: - Generic Widget Skeleton

struct WidgetSkeleton: View {
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.netoSecondaryText.opacity(0.1))
            .frame(height: height)
            .shimmer()
    }
}

// MARK: - Trend Card Skeleton

struct TrendWidgetSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.netoSecondaryText.opacity(0.15))
                    .frame(width: 120, height: 20)
                Spacer()
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.netoSecondaryText.opacity(0.1))
                    .frame(width: 100, height: 28)
            }

            RoundedRectangle(cornerRadius: 8)
                .fill(Color.netoSecondaryText.opacity(0.15))
                .frame(width: 150, height: 32)

            RoundedRectangle(cornerRadius: 8)
                .fill(Color.netoSecondaryText.opacity(0.1))
                .frame(height: 180)
        }
        .padding(DS.Card.padding)
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shimmer()
    }
}

// MARK: - Cash Flow Skeleton

struct CashFlowSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.netoSecondaryText.opacity(0.15))
                .frame(width: 100, height: 18)

            HStack(spacing: 16) {
                ForEach(0..<2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.netoSecondaryText.opacity(0.1))
                        .frame(height: 60)
                }
            }

            RoundedRectangle(cornerRadius: 8)
                .fill(Color.netoSecondaryText.opacity(0.1))
                .frame(height: 120)
        }
        .padding(DS.Card.padding)
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shimmer()
    }
}

// MARK: - Latest Records Skeleton

struct LatestRecordsSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.netoSecondaryText.opacity(0.15))
                .frame(width: 120, height: 18)

            ForEach(0..<4, id: \.self) { _ in
                HStack {
                    Circle()
                        .fill(Color.netoSecondaryText.opacity(0.1))
                        .frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.netoSecondaryText.opacity(0.15))
                            .frame(width: 100, height: 14)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.netoSecondaryText.opacity(0.1))
                            .frame(width: 60, height: 12)
                    }
                    Spacer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.netoSecondaryText.opacity(0.15))
                        .frame(width: 60, height: 16)
                }
            }
        }
        .padding(DS.Card.padding)
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shimmer()
    }
}

// MARK: - Categories Pie Skeleton

struct CategoriesPieSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.netoSecondaryText.opacity(0.15))
                .frame(width: 100, height: 18)

            HStack(spacing: 20) {
                Circle()
                    .fill(Color.netoSecondaryText.opacity(0.1))
                    .frame(width: 120, height: 120)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(0..<4, id: \.self) { _ in
                        HStack {
                            Circle()
                                .fill(Color.netoSecondaryText.opacity(0.15))
                                .frame(width: 12, height: 12)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.netoSecondaryText.opacity(0.1))
                                .frame(width: 60, height: 12)
                        }
                    }
                }
            }
        }
        .padding(DS.Card.padding)
        .background(Color.netoCard)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shimmer()
    }
}

// MARK: - Shimmer Modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
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
                .mask(content)
            )
            .onAppear {
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

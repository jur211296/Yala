//
//  ProBadge.swift
//  Yala
//
//  Visual badge indicating Pro tier features.
//

import SwiftUI

/// Badge "PRO" to mark premium features
struct ProBadge: View {

    // MARK: - Size Variants

    enum Size {
        case small
        case medium
        case large

        var font: Font {
            switch self {
            case .small: return .caption2.weight(.bold)
            case .medium: return .caption.weight(.bold)
            case .large: return .subheadline.weight(.bold)
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small: return DS.Spacing.xs
            case .medium: return DS.Spacing.sm
            case .large: return DS.Spacing.md
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .small: return DS.Spacing.xxs
            case .medium: return DS.Spacing.xs
            case .large: return DS.Chip.paddingV
            }
        }

        var sparkSize: YalaSpark.Size {
            switch self {
            case .small: return .small
            case .medium: return .small
            case .large: return .medium
            }
        }

        var iconSpacing: CGFloat {
            switch self {
            case .small: return DS.Spacing.xxs
            case .medium: return DS.Spacing.xs
            case .large: return DS.Spacing.xs
            }
        }
    }

    // MARK: - Properties

    var size: Size = .small

    // MARK: - Body

    var body: some View {
        HStack(spacing: size.iconSpacing) {
            YalaSpark(size: size.sparkSize, animated: false)
            Text("PRO")
                .font(size.font)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .background(
            LinearGradient(
                colors: DS.Gradients.proBadge,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(Capsule())
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: DS.Spacing.xl) {
        HStack {
            Text("Small:")
            ProBadge(size: .small)
        }
        HStack {
            Text("Medium:")
            ProBadge(size: .medium)
        }
        HStack {
            Text("Large:")
            ProBadge(size: .large)
        }
    }
    .padding()
}

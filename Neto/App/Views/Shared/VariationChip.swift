//
//  VariationChip.swift
//  Neto
//
//  Reusable chip component for displaying percentage variation.
//

import SwiftUI

/// Compact chip showing percentage variation (e.g., "+12.5%", "-3.2%", "N/A")
struct VariationChip: View {

    // MARK: - Properties

    /// The variation percentage (nil shows "N/A")
    let variation: Double?

    /// Size of the chip
    var size: ChipSize = .small

    // MARK: - Size Configuration

    enum ChipSize {
        case small   // For row items (smaller font, less padding)
        case medium  // For headers (larger font, more padding)

        var font: Font {
            switch self {
            case .small: return .caption2.weight(.medium)
            case .medium: return .caption.weight(.semibold)
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .small: return DS.Spacing.xs
            case .medium: return DS.Spacing.sm
            }
        }

        var verticalPadding: CGFloat {
            switch self {
            case .small: return DS.Spacing.xxs
            case .medium: return DS.Spacing.xs
            }
        }
    }

    // MARK: - Computed Properties

    private var variationText: String {
        PreviousPeriodHelper.formatVariation(variation)
    }

    private var variationColor: Color {
        guard let variation = variation else { return .gray }
        // For expenses: negative variation (spending less) is good (green/indigo)
        // positive variation (spending more) is bad (red/pink)
        return variation >= 0 ? .hotPink : .electricIndigo
    }

    // MARK: - Body

    var body: some View {
        Text(variationText)
            .font(size.font)
            .foregroundStyle(variationColor)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(
                Capsule()
                    .fill(variationColor.opacity(0.1))
            )
    }
}

// MARK: - Convenience Initializers

extension VariationChip {
    /// Create chip from current and previous amounts
    init(currentAmount: Double, previousAmount: Double?, size: ChipSize = .small) {
        self.variation = PreviousPeriodHelper.calculateVariation(
            currentAmount: currentAmount,
            previousAmount: previousAmount ?? 0
        )
        self.size = size
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: DS.Spacing.lg) {
        // Small size (for rows)
        HStack(spacing: DS.Spacing.md) {
            VariationChip(variation: 12.5, size: .small)
            VariationChip(variation: -8.3, size: .small)
            VariationChip(variation: nil, size: .small)
        }

        // Medium size (for headers)
        HStack(spacing: DS.Spacing.md) {
            VariationChip(variation: 25.0, size: .medium)
            VariationChip(variation: -15.7, size: .medium)
            VariationChip(variation: nil, size: .medium)
        }

        // From amounts
        HStack(spacing: DS.Spacing.md) {
            VariationChip(currentAmount: 1000, previousAmount: 800, size: .small)
            VariationChip(currentAmount: 500, previousAmount: 600, size: .small)
            VariationChip(currentAmount: 300, previousAmount: nil, size: .small)
        }
    }
    .padding()
    .background(Color.netoBackground)
}

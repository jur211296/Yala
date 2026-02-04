//
//  VariationChip.swift
//  Yala
//
//  Reusable chip component for displaying percentage variation.
//

import SwiftUI

/// Compact chip showing percentage variation (e.g., "+12.5%", "-3.2%", "N/A")
struct VariationChip: View {

    // MARK: - Settings

    @AppStorage("showVariations") private var showVariations: Bool = true

    // MARK: - Properties

    /// The variation percentage (nil shows "N/A" or hides based on showNAWhenNil)
    let variation: Double?

    /// Size of the chip
    var size: ChipSize = .small

    /// If true, shows "N/A" when variation is nil. If false, hides completely.
    /// Use true for row items (categories, etc.), false for headers.
    var showNAWhenNil: Bool = false

    /// If true, colors are inverted for expense context:
    /// - Expense context: +% = pink (bad, spent more), -% = purple (good, spent less)
    /// - Income/Balance context: +% = purple (good, earned more), -% = pink (bad, earned less)
    var isExpenseContext: Bool = true

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

        if isExpenseContext {
            // Expense context: +% = pink (bad, spent more), -% = purple (good, spent less)
            return variation >= 0 ? .hotPink : .electricIndigo
        } else {
            // Income/Balance context: +% = purple (good, earned more), -% = pink (bad, earned less)
            return variation >= 0 ? .electricIndigo : .hotPink
        }
    }

    // MARK: - Body

    @ViewBuilder
    var body: some View {
        // Hide entirely when showVariations is OFF
        if !showVariations {
            EmptyView()
        } else if let variation = variation {
            // Show formatted variation percentage
            Text(PreviousPeriodHelper.formatVariationValue(variation))
                .font(size.font)
                .foregroundStyle(variationColor)
                .padding(.horizontal, size.horizontalPadding)
                .padding(.vertical, size.verticalPadding)
                .background(
                    Capsule()
                        .fill(variationColor.opacity(0.1))
                )
        } else if showNAWhenNil {
            // Show "N/A" for items without previous data (when comparison is active)
            Text("N/A")
                .font(size.font)
                .foregroundStyle(Color.gray)
                .padding(.horizontal, size.horizontalPadding)
                .padding(.vertical, size.verticalPadding)
                .background(
                    Capsule()
                        .fill(Color.gray.opacity(0.1))
                )
        }
        // When variation is nil and showNAWhenNil is false, show nothing (for headers)
    }
}

// MARK: - Convenience Initializers

extension VariationChip {
    /// Create chip from current and previous amounts
    init(
        currentAmount: Double,
        previousAmount: Double?,
        size: ChipSize = .small,
        showNAWhenNil: Bool = false,
        isExpenseContext: Bool = true
    ) {
        self.variation = PreviousPeriodHelper.calculateVariation(
            currentAmount: currentAmount,
            previousAmount: previousAmount ?? 0
        )
        self.size = size
        self.showNAWhenNil = showNAWhenNil
        self.isExpenseContext = isExpenseContext
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
    .background(Color.yalaBackground)
}

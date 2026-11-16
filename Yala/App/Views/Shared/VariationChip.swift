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

    @Environment(AppPreferences.self) private var appPreferences
    /// Los días 1 y 2 de «Este mes» el Panel no compara con el período anterior: solo el monto (decisión 10 de 2.3).
    @Environment(\.hidesPeriodVariations) private var hidesPeriodVariations

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

    /// La Comparativa de Reportes (decisión 32 de 2.3): «igual» en vez de «= +0 %» y «nuevo» en vez de «N/A». El resto de
    /// la app sigue con el signo y las siglas.
    var usesWords: Bool = false

    /// El texto en los tokens que pasan AA sobre la tarjeta (`incomeAmount` lo bueno, `groupOweAmount` lo malo) en vez de
    /// índigo y rosa de la paleta, que como texto no llegan. Hoy solo lo pide «Te quedó» de la Comparativa (lote 08 de
    /// 2.3); el resto de la app sigue con la paleta.
    var usesAccessibleTextTone: Bool = false

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
        guard let variation = variation else { return DS.Semantic.disabledForeground }

        if abs(variation) < 0.05 {
            return DS.Semantic.disabledForeground
        }

        if usesAccessibleTextTone {
            let isGood = isExpenseContext ? variation < 0 : variation >= 0
            return isGood ? .incomeAmount : .groupOweAmount
        }

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
        // Hide entirely when showVariations is OFF, or when the Panel says the month just started.
        if !appPreferences.showVariations || hidesPeriodVariations {
            EmptyView()
        } else if usesWords, let variation, abs(variation) < 0.05 {
            wordChip(L10n.UXL18.changeSame)
                .accessibilityLabel(Self.accessibilityText(for: variation))
        } else if let variation = variation {
            // Show formatted variation percentage
            HStack(spacing: DS.Spacing.xxs) {
                if abs(variation) < 0.05 {
                    Image(systemName: "equal")
                        .font(size.font)
                        .accessibilityHidden(true)
                }
                Text(PreviousPeriodHelper.formatVariationValue(variation))
                    .font(size.font)
            }
            .foregroundStyle(variationColor)
                .padding(.horizontal, size.horizontalPadding)
                .padding(.vertical, size.verticalPadding)
                .background(
                    Capsule()
                        .fill(variationColor.opacity(0.1))
                )
                .accessibilityLabel(Self.accessibilityText(for: variation))
        } else if showNAWhenNil && usesWords {
            wordChip(L10n.UXL18.changeNew)
        } else if showNAWhenNil {
            // Show "N/A" for items without previous data (when comparison is active)
            Text("N/A")
                .font(size.font)
                .foregroundStyle(DS.Semantic.disabledForeground)
                .padding(.horizontal, size.horizontalPadding)
                .padding(.vertical, size.verticalPadding)
                .background(
                    Capsule()
                        .fill(DS.Semantic.neutralBackground)
                )
        }
        // When variation is nil and showNAWhenNil is false, show nothing (for headers)
    }

    /// «igual» / «nuevo»: el mismo gris que «N/A», sin color de bueno o malo.
    private func wordChip(_ text: String) -> some View {
        Text(text)
            .font(size.font)
            .foregroundStyle(DS.Semantic.disabledForeground)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(
                Capsule()
                    .fill(DS.Semantic.neutralBackground)
            )
    }
}

// MARK: - Mes recién empezado

extension EnvironmentValues {
    /// `true` en el Panel los días 1 y 2 de «Este mes» (`PanelEarlyMonthLogic`): las comparaciones con el período
    /// anterior (chips de variación, «vs S/ X») no se pintan; queda el monto. Fuera del Panel, siempre `false`.
    @Entry var hidesPeriodVariations: Bool = false
}

// MARK: - Accesibilidad

extension VariationChip {
    /// Lo que lee VoiceOver. Sin cambio (la misma franja en la que el chip pinta «=») dice «Sin cambio», no
    /// «Aumento +0 %» (UX 2.2 · L18-4).
    static func accessibilityText(for variation: Double) -> String {
        if abs(variation) < 0.05 { return L10n.Accessibility.variationNoChange }
        return variation >= 0
            ? L10n.Accessibility.variationIncrease(PreviousPeriodHelper.formatVariationValue(variation))
            : L10n.Accessibility.variationDecrease(PreviousPeriodHelper.formatVariationValue(variation))
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
    .background(.thBackground)
    .previewAppPreferences()
}

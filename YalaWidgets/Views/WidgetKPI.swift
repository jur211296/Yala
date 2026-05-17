//
//  WidgetKPI.swift
//  YalaWidgets
//
//  Key Performance Indicator display for widgets.
//  Delegates en `WidgetAmountText` para aplicar la jerarquía visual del
//  app principal (entero domina; símbolo + decimales secondary).
//

import SwiftUI
import WidgetKit

/// Displays a formatted monetary amount.
struct WidgetKPI: View {
    let amount: Double
    let currencyCode: String
    let displayFormat: String  // "symbol" or "code"
    let color: Color
    let size: Size

    enum Size {
        case large   // For Small widgets
        case medium  // For Medium widgets (currently unused — kept for API stability)
        case small   // For compact displays

        var font: Font {
            switch self {
            case .large:  return WDS.Typography.kpiLarge
            case .medium: return WDS.Typography.kpiMedium
            case .small:  return WDS.Typography.kpiSmall
            }
        }

        /// Font para símbolo + decimales: un tier menos que el primary.
        var secondaryFont: Font {
            switch self {
            case .large:  return WDS.Typography.kpiLargeSecondary
            case .medium: return WDS.Typography.kpiSmallSecondary
            case .small:  return WDS.Typography.kpiSmallSecondary
            }
        }
    }

    init(
        amount: Double,
        currencyCode: String,
        displayFormat: String = "symbol",
        color: Color = .primary,
        size: Size = .large
    ) {
        self.amount = amount
        self.currencyCode = currencyCode
        self.displayFormat = displayFormat
        self.color = color
        self.size = size
    }

    var body: some View {
        WidgetAmountText(
            value: amount,
            currencyCode: currencyCode,
            displayFormat: displayFormat,
            font: size.font,
            secondaryFont: size.secondaryFont,
            tint: tint,
            fractionDigits: 0
        )
        .widgetAccentable()
    }

    /// Mapea `color` a `WidgetAmountText.Tint`. `.primary` se traduce a
    /// jerarquía SwiftUI nativa; cualquier otro Color va como tint custom.
    private var tint: WidgetAmountText.Tint {
        color == .primary ? .primary : .color(color)
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: WDS.Spacing.xl) {
        WidgetKPI(
            amount: 15420.50,
            currencyCode: "PEN",
            displayFormat: "symbol",
            color: WidgetColors.balance,
            size: .large
        )

        WidgetKPI(
            amount: -3250.00,
            currencyCode: "PEN",
            displayFormat: "code",
            color: WidgetColors.negative,
            size: .medium
        )

        WidgetKPI(
            amount: 1200.00,
            currencyCode: "USD",
            color: WidgetColors.income,
            size: .small
        )
    }
    .padding()
}

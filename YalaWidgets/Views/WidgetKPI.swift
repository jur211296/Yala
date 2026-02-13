//
//  WidgetKPI.swift
//  YalaWidgets
//
//  Key Performance Indicator display for widgets.
//  Shows formatted amounts with currency, respecting user preferences.
//

import SwiftUI
import WidgetKit

/// Displays a formatted monetary amount
struct WidgetKPI: View {
    let amount: Double
    let currencyCode: String
    let displayFormat: String  // "symbol" or "code"
    let color: Color
    let size: Size

    enum Size {
        case large   // For Small widgets
        case medium  // For Medium widgets
        case small   // For compact displays

        var font: Font {
            switch self {
            case .large: return WDS.Typography.kpiLarge
            case .medium: return WDS.Typography.kpiMedium
            case .small: return WDS.Typography.kpiSmall
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
        Text(formattedAmount)
            .font(size.font)
            .foregroundStyle(color)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .widgetAccentable()
    }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0

        let absAmount = abs(amount)
        let formatted = formatter.string(from: NSNumber(value: absAmount)) ?? "0"

        let prefix = amount < 0 ? "-" : ""
        let currency = displayFormat == "symbol"
            ? CurrencySymbols.symbol(for: currencyCode)
            : currencyCode

        return "\(prefix)\(currency) \(formatted)"
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

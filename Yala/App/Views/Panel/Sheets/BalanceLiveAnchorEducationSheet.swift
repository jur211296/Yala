//
//  BalanceLiveAnchorEducationSheet.swift
//  Yala
//

import SwiftUI

/// Sheet educativo que explica al usuario por qué su saldo "hoy" puede
/// diferir del último punto de la curva histórica cuando tiene dinero en
/// varias monedas. Se abre desde la pill "Hoy" y desde el overlay del dot.
struct BalanceLiveAnchorEducationSheet: View {
    let liveAnchorValue: Double
    let historicalValue: Double?
    let nativeBalances: [String: Decimal]
    let preferredCurrencyCode: String

    @Environment(\.dismiss) private var dismiss
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(CurrencyConverter.self) private var currencyConverter

    /// Umbral para considerar un balance multi-moneda "esencialmente cero"
    /// tras la conversión al TC actual. Filtra rows del breakdown con saldo
    /// residual (EUR -0.00, etc.) y omite la línea histórica del párrafo
    /// cuando la diferencia con `liveAnchorValue` es despreciable.
    private static let nearZeroEpsilon: Double = 0.01

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    todayBalanceSection
                    explanationSection
                    breakdownSection
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            .yalaScreenBackground()
            .navigationTitle(L10n.Panel.LiveAnchorEducation.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Today balance

    private var todayBalanceSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(L10n.Panel.LiveAnchorEducation.todayQuestion)
                .font(DS.Typography.headline)
                .foregroundStyle(.thPrimaryText)
            AmountText(
                value: liveAnchorValue,
                currencyCode: preferredCurrencyCode,
                font: DS.Typography.heroAmount,
                secondaryFont: DS.Typography.heroAmountSecondary
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Explanation

    private var explanationSection: some View {
        let identifier = appPreferences.currencyIdentifier(for: preferredCurrencyCode)
        return VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(L10n.Panel.LiveAnchorEducation.whyQuestion)
                .font(DS.Typography.headline)
                .foregroundStyle(.thPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text(explanationBody(preferredIdentifier: identifier))
                .font(DS.Typography.subheadline)
                .foregroundStyle(.thSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func explanationBody(preferredIdentifier: String) -> String {
        var parts: [String] = [
            L10n.Panel.LiveAnchorEducation.bodyLineOneFormat(preferredIdentifier)
        ]
        if let historical = historicalValue, abs(historical - liveAnchorValue) > Self.nearZeroEpsilon {
            let formatted = appPreferences.currency(
                historical,
                currencyCode: preferredCurrencyCode,
                forceFullPrecision: false
            )
            parts.append(L10n.Panel.LiveAnchorEducation.bodyLineTwoFormat(formatted))
        }
        parts.append(L10n.Panel.LiveAnchorEducation.bodyLineThree)
        return parts.joined(separator: " ")
    }

    // MARK: - Breakdown

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Panel.LiveAnchorEducation.breakdownToggle)
                .font(DS.Typography.headline)
                .foregroundStyle(.thPrimaryText)

            VStack(spacing: 0) {
                ForEach(Array(orderedBreakdown.enumerated()), id: \.element.code) { index, row in
                    if index > 0 {
                        Divider()
                    }
                    breakdownRow(row)
                        .padding(.vertical, DS.Spacing.sm)
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .background(.thCard, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func breakdownRow(_ row: BreakdownRow) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
            Text(row.code)
                .font(DS.Typography.label)
                .foregroundStyle(.thPrimaryText)
                .frame(width: 44, alignment: .leading)

            AmountText(
                value: row.nativeDouble,
                currencyCode: row.code,
                font: DS.Typography.label,
                secondaryFont: DS.Typography.caption,
                forceFullPrecision: false
            )

            Spacer()

            if row.code != preferredCurrencyCode {
                let convertedFormatted = appPreferences.currency(
                    row.convertedToday,
                    currencyCode: preferredCurrencyCode,
                    forceFullPrecision: false
                )
                Text(L10n.Panel.LiveAnchorEducation.breakdownRowConvertedFormat(convertedFormatted))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.thSecondaryText)
            }
        }
    }

    // MARK: - Ordering

    private struct BreakdownRow: Hashable {
        let code: String
        let native: Decimal
        let convertedToday: Double
        var nativeDouble: Double { (native as NSDecimalNumber).doubleValue }
    }

    /// Filtra balances ~cero (≤0.01 en la moneda preferida) y ordena con la
    /// moneda preferida primero, resto descendente por valor convertido.
    private var orderedBreakdown: [BreakdownRow] {
        nativeBalances.compactMap { (code, native) -> BreakdownRow? in
            let converted: Double
            if code == preferredCurrencyCode {
                converted = (native as NSDecimalNumber).doubleValue
            } else {
                let convertedDecimal = currencyConverter.convertWithLatestRate(
                    native, from: code, to: preferredCurrencyCode
                )
                converted = (convertedDecimal as NSDecimalNumber).doubleValue
            }
            guard abs(converted) > Self.nearZeroEpsilon else { return nil }
            return BreakdownRow(code: code, native: native, convertedToday: converted)
        }
        .sorted { lhs, rhs in
            if lhs.code == preferredCurrencyCode { return true }
            if rhs.code == preferredCurrencyCode { return false }
            return abs(lhs.convertedToday) > abs(rhs.convertedToday)
        }
    }
}

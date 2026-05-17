//
//  BalanceLiveAnchorEducationSheet.swift
//  Yala
//

import SwiftUI

/// Sheet educativo que explica al usuario por qué su saldo "hoy" puede
/// diferir del último punto de la curva histórica cuando tiene dinero en
/// varias monedas. Se abre desde la `TodayHintGlassPill` y desde el overlay
/// del dot en `TrendChartView`.
struct BalanceLiveAnchorEducationSheet: View {
    let liveAnchorValue: Double
    let historicalValue: Double?
    let nativeBalances: [String: Decimal]
    let preferredCurrencyCode: String

    @Environment(\.dismiss) private var dismiss
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(CurrencyConverter.self) private var currencyConverter
    @State private var showBreakdown = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    heroSection
                    explanationSection
                    breakdownAccordion
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)
            }
            .scrollBounceBehavior(.basedOnSize)
            .yalaScreenBackground(.compact)
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

    // MARK: - Hero

    private var heroSection: some View {
        let formatted = appPreferences.currency(
            liveAnchorValue,
            currencyCode: preferredCurrencyCode,
            forceFullPrecision: false
        )
        return VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(L10n.Panel.LiveAnchorEducation.heroFormat(formatted))
                .font(DS.Typography.heroAmount)
                .foregroundStyle(.thPrimaryText)
                .minimumScaleFactor(0.7)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Explanation (variante 1)

    private var explanationSection: some View {
        let identifier = appPreferences.currencyIdentifier(for: preferredCurrencyCode)
        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(L10n.Panel.LiveAnchorEducation.bodyLineOneFormat(identifier))
                .font(DS.Typography.body)
                .foregroundStyle(.thPrimaryText)

            if let historical = historicalValue {
                let historicalFormatted = appPreferences.currency(
                    historical,
                    currencyCode: preferredCurrencyCode,
                    forceFullPrecision: false
                )
                Text(L10n.Panel.LiveAnchorEducation.bodyLineTwoFormat(historicalFormatted))
                    .font(DS.Typography.body)
                    .foregroundStyle(.thPrimaryText)
            }

            Text(L10n.Panel.LiveAnchorEducation.bodyLineThree)
                .font(DS.Typography.body)
                .foregroundStyle(.thPrimaryText)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Breakdown accordion

    private var breakdownAccordion: some View {
        DisclosureGroup(isExpanded: $showBreakdown) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                ForEach(orderedBreakdown, id: \.code) { row in
                    breakdownRow(row)
                }

                Divider()
                    .padding(.vertical, DS.Spacing.xxs)

                HStack {
                    Text(L10n.Panel.LiveAnchorEducation.breakdownTotalLabel)
                        .font(DS.Typography.label)
                        .foregroundStyle(.thSecondaryText)
                    Spacer()
                    AmountText(
                        value: liveAnchorValue,
                        currencyCode: preferredCurrencyCode,
                        font: DS.Typography.subheadlineEmphasized,
                        secondaryFont: DS.Typography.caption,
                        forceFullPrecision: false
                    )
                }
            }
            .padding(.top, DS.Spacing.sm)
        } label: {
            Text(L10n.Panel.LiveAnchorEducation.breakdownToggle)
                .font(DS.Typography.label)
                .foregroundStyle(.thPrimaryText)
        }
        .tint(.primary)
        .padding(DS.Spacing.md)
        .background(.thCard, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
    }

    private func breakdownRow(_ row: BreakdownRow) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(row.code)
                .font(DS.Typography.label)
                .foregroundStyle(.thPrimaryText)
                .frame(width: 48, alignment: .leading)

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

    private var orderedBreakdown: [BreakdownRow] {
        nativeBalances.map { (code, native) -> BreakdownRow in
            let converted: Double
            if code == preferredCurrencyCode {
                converted = (native as NSDecimalNumber).doubleValue
            } else {
                let convertedDecimal = currencyConverter.convertWithLatestRate(
                    native, from: code, to: preferredCurrencyCode
                )
                converted = (convertedDecimal as NSDecimalNumber).doubleValue
            }
            return BreakdownRow(code: code, native: native, convertedToday: converted)
        }
        .sorted { lhs, rhs in
            if lhs.code == preferredCurrencyCode { return true }
            if rhs.code == preferredCurrencyCode { return false }
            return lhs.convertedToday > rhs.convertedToday
        }
    }
}

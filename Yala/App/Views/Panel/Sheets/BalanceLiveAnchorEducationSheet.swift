//
//  BalanceLiveAnchorEducationSheet.swift
//  Yala
//

import SwiftUI

/// Sheet educativo que explica al usuario por qué su saldo "hoy" puede
/// diferir del último punto de la curva histórica cuando tiene dinero en
/// varias monedas. Se abre desde la pill "Hoy" y desde el overlay del dot.
///
/// UX 2.2 · L3-15 (opción B): un solo título (el de la barra), la explicación en dos frases y la SUMA a la vista,
/// moneda por moneda al cambio de hoy, hasta el total. Antes listaba PEN y USD sin decir que sumados daban el saldo,
/// y explicaba la diferencia en un párrafo de cinco líneas.
struct BalanceLiveAnchorEducationSheet: View {
    let liveAnchorValue: Double
    /// `true` si las divisas de abajo convertidas con una tasa que no era la de hoy pesan en el
    /// saldo. Sale del mismo `LiveBalanceCalculator.Breakdown` que el propio `liveAnchorValue`.
    ///
    /// **Su criterio es el umbral del 5 % del resto de los totales** (`ApproximateMarkThreshold`),
    /// decisión de Jürgen del 2026-10-12 (`dos-criterios-de-aproximado-en-la-misma-pantalla`,
    /// opción B), que sustituye al OR por divisa del 2026-09-08. Consecuencia aceptada: 30 USD con
    /// la tasa caducada ya no marcan un saldo de 42.000 €; su fila del desglose sí lleva «≈».
    let liveAnchorIsApproximate: Bool
    let nativeBalances: [String: Decimal]
    let preferredCurrencyCode: String

    @Environment(\.dismiss) private var dismiss
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(CurrencyConverter.self) private var currencyConverter

    @State private var selectedDetent: PresentationDetent = .medium

    /// Umbral para considerar un balance multi-moneda "esencialmente cero"
    /// tras la conversión al TC actual. Filtra rows del breakdown con saldo
    /// residual (EUR -0.00, etc.).
    private static let nearZeroEpsilon: Double = 0.01

    private var isLargeDetent: Bool { selectedDetent == .large }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        todayBalanceSection
                        explanationSection
                        sumSection
                    }
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.vertical, DS.Spacing.lg)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .yalaScreenBackground(isLargeDetent ? .subtle : .transparent)
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
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
    }

    // MARK: - Today balance

    private var todayBalanceSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            AmountText(
                value: liveAnchorValue,
                currencyCode: preferredCurrencyCode,
                font: DS.Typography.heroAmount,
                secondaryFont: DS.Typography.heroAmountSecondary,
                isEstimate: liveAnchorIsApproximate
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Explanation

    /// Dos frases: qué es el número y por qué se mueve solo.
    private var explanationSection: some View {
        let identifier = appPreferences.currencyIdentifier(for: preferredCurrencyCode)
        return Text(
            L10n.Panel.LiveAnchorEducation.bodyLineOneFormat(identifier) + " "
                + L10n.Panel.LiveAnchorEducation.bodyShortWhy
        )
        .font(DS.Typography.subheadline)
        .foregroundStyle(.thSecondaryText)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Breakdown

    /// La suma: cada moneda pasada a la principal al cambio de hoy, y el total, que es la cifra de arriba.
    private var sumSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Panel.LiveAnchorEducation.sumTitle)
                .font(DS.Typography.headline)
                .foregroundStyle(.thPrimaryText)

            VStack(spacing: 0) {
                ForEach(Array(orderedBreakdown.enumerated()), id: \.element.code) { index, row in
                    if index > 0 {
                        Divider()
                    }
                    breakdownRow(row, sign: index == 0 ? nil : "+")
                        .padding(.vertical, DS.Spacing.sm)
                }
                Divider()
                totalRow
                    .padding(.vertical, DS.Spacing.sm)
            }
            .padding(.horizontal, DS.Spacing.md)
            .background(.thCard, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var totalRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
            Text(verbatim: "=")
                .font(DS.Typography.label)
                .foregroundStyle(.thSecondaryText)
                .frame(width: DS.Spacing.md, alignment: .center)
                .accessibilityHidden(true)
            Text(L10n.Panel.LiveAnchorEducation.title)
                .font(DS.Typography.label)
                .foregroundStyle(.thPrimaryText)
            Spacer()
            AmountText(
                value: liveAnchorValue,
                currencyCode: preferredCurrencyCode,
                font: DS.Typography.headline,
                secondaryFont: DS.Typography.caption,
                isEstimate: liveAnchorIsApproximate
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("live_anchor_sum_total")
    }

    private func breakdownRow(_ row: BreakdownRow, sign: String?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
            Text(verbatim: sign ?? " ")
                .font(DS.Typography.label)
                .foregroundStyle(.thSecondaryText)
                .frame(width: DS.Spacing.md, alignment: .center)
                .accessibilityHidden(true)
            Text(row.code)
                .font(DS.Typography.label)
                .foregroundStyle(.thPrimaryText)
                .frame(width: 44, alignment: .leading)

            // El saldo en su PROPIA divisa nunca lleva marca: no hubo conversión que juzgar. La
            // marca, si toca, va en la traducción a la divisa preferida de la derecha.
            AmountText(
                value: row.nativeDouble,
                currencyCode: row.code,
                font: DS.Typography.label,
                secondaryFont: DS.Typography.caption,
                forceFullPrecision: false
            )

            Spacer()

            // El «≈» de esta fila significa SOLO «tasa de otro día», como en el resto de la app: lo
            // antepone el formateador con `isEstimate:`. El formato del copy
            // (`breakdownRowConvertedFormat`, «%@ hoy») ya no trae glifo propio — lo llevó hasta el
            // 2026-10-12 y con la tasa dudosa salía «≈ ≈», indistinguible de la buena (decisión A de
            // Jürgen en `live-anchor-breakdown-doubles-the-approximate-glyph`). Pin en las 16
            // locales: `LiveAnchorBreakdownGlyphTests`.
            if row.code != preferredCurrencyCode {
                let convertedFormatted = appPreferences.currency(
                    row.convertedToday,
                    currencyCode: preferredCurrencyCode,
                    forceFullPrecision: false,
                    isEstimate: row.convertedIsApproximate
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
        /// Calidad de ESTA conversión, no la del total. La hoja desglosa divisa a divisa, así que
        /// heredar la marca del saldo marcaría como dudosa una divisa cuya tasa sí era la de hoy.
        let convertedIsApproximate: Bool
        var nativeDouble: Double { (native as NSDecimalNumber).doubleValue }
    }

    /// Filtra balances ~cero (≤0.01 en la moneda preferida) y ordena con la
    /// moneda preferida primero, resto descendente por valor convertido.
    private var orderedBreakdown: [BreakdownRow] {
        nativeBalances.compactMap { (code, native) -> BreakdownRow? in
            let converted: Double
            let isApproximate: Bool
            if code == preferredCurrencyCode {
                converted = (native as NSDecimalNumber).doubleValue
                isApproximate = false
            } else {
                // `convertChecked…` en vez de `convertWithLatestRate`: mismo número, y además la
                // calidad. Es la misma llamada que hace `LiveBalanceCalculator` para decidir la
                // marca del total, así que fila y total no pueden contradecirse.
                let outcome = currencyConverter.convertCheckedWithLatestRate(
                    native, from: code, to: preferredCurrencyCode
                )
                converted = (outcome.amount as NSDecimalNumber).doubleValue
                isApproximate = !outcome.quality.isExact
            }
            guard abs(converted) > Self.nearZeroEpsilon else { return nil }
            return BreakdownRow(
                code: code, native: native, convertedToday: converted,
                convertedIsApproximate: isApproximate
            )
        }
        .sorted { lhs, rhs in
            if lhs.code == preferredCurrencyCode { return true }
            if rhs.code == preferredCurrencyCode { return false }
            return abs(lhs.convertedToday) > abs(rhs.convertedToday)
        }
    }
}

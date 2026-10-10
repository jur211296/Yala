//
//  FXPnLDetailSheet.swift
//  Yala
//
//  Detalle de la ganancia/pérdida cambiaria: una fila por divisa, con el tipo de cambio al que
//  entró el dinero y al que está hoy.
//
//  Hoja propia y no una ampliación de `BalanceLiveAnchorEducationSheet`: aquella responde a otra
//  pregunta —«¿por qué mi saldo de hoy no cuadra con la curva?»— y la abren dos sitios distintos
//  cuyo contrato heredaríamos. Se reutiliza su vocabulario visual, no su código.
//

import SwiftUI

struct FXPnLDetailSheet: View {
    let summary: FXPnLLogic.Summary

    @Environment(\.dismiss) private var dismiss
    @Environment(AppPreferences.self) private var appPreferences

    @State private var selectedDetent: PresentationDetent = .medium

    private var isLargeDetent: Bool { selectedDetent == .large }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    totalSection
                    explanationSection
                    breakdownSection
                    notesSection
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            .yalaScreenBackground(isLargeDetent ? .subtle : .transparent)
            .navigationTitle(L10n.Panel.FXPnL.sheetTitle)
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

    // MARK: - Total

    private var totalSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(L10n.Panel.FXPnL.totalLabel)
                .font(DS.Typography.headline)
                .foregroundStyle(.thPrimaryText)

            AmountText(
                value: (summary.totalPnL as NSDecimalNumber).doubleValue,
                currencyCode: summary.preferredCurrencyCode,
                font: DS.Typography.heroAmount,
                secondaryFont: DS.Typography.heroAmountSecondary,
                tint: summary.totalPnL >= 0 ? .color(Color.incomeAmount) : .primary,
                forceSign: true,
                isEstimate: summary.isApproximate
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Explicación

    private var explanationSection: some View {
        Text(
            L10n.Panel.FXPnL.sheetIntroFormat(
                appPreferences.currencyIdentifier(for: summary.preferredCurrencyCode)
            )
        )
        .font(DS.Typography.subheadline)
        .foregroundStyle(.thSecondaryText)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Desglose

    private var breakdownSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(summary.rows.enumerated()), id: \.element.code) { index, row in
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

    private func breakdownRow(_ row: FXPnLLogic.CurrencyRow) -> some View {
        let rowIsGain = row.pnl >= 0
        return VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                Text(row.code)
                    .font(DS.Typography.label)
                    .foregroundStyle(.thPrimaryText)
                    .frame(width: 44, alignment: .leading)

                AmountText(
                    value: (row.nativeBalance as NSDecimalNumber).doubleValue,
                    currencyCode: row.code,
                    font: DS.Typography.label,
                    secondaryFont: DS.Typography.caption
                )

                Spacer(minLength: DS.Spacing.sm)

                AmountText(
                    value: (row.pnl as NSDecimalNumber).doubleValue,
                    currencyCode: summary.preferredCurrencyCode,
                    font: DS.Typography.label,
                    secondaryFont: DS.Typography.caption,
                    tint: rowIsGain ? .color(Color.incomeAmount) : .primary,
                    forceSign: true,
                    // La calidad de ESTA divisa, no la del resumen: con dólares exactos y yenes
                    // arrastrados, marcar las dos filas erosiona la marca donde sí importa.
                    isEstimate: row.isApproximate
                )
            }

            HStack(spacing: DS.Spacing.xs) {
                Spacer().frame(width: 44)
                Text(
                    L10n.Panel.FXPnL.rowRatesFormat(
                        Self.rateString(row.averageEntryRate),
                        Self.rateString(row.currentRate)
                    )
                )
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.thSecondaryText)

                Spacer(minLength: DS.Spacing.xs)

                // Cuánto valen HOY, para no obligar a multiplicar de cabeza el saldo por la tasa.
                Text(
                    L10n.Panel.FXPnL.rowValueTodayFormat(
                        appPreferences.currency(
                            (row.valueToday as NSDecimalNumber).doubleValue,
                            currencyCode: summary.preferredCurrencyCode,
                            forceFullPrecision: false
                        )
                    )
                )
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.thSecondaryText)
            }
        }
    }

    // MARK: - Notas

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            noteRow(icon: "chart.line.uptrend.xyaxis", text: L10n.Panel.FXPnL.averageNote)
            if summary.isApproximate {
                noteRow(icon: "exclamationmark.triangle", text: L10n.Panel.FXPnL.estimatedRateNote)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func noteRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.thSecondaryText)
                .frame(width: 16)
            Text(text)
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.thSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Formato de tipos de cambio

    /// Un tipo de cambio no es un monto: no lleva símbolo de divisa y necesita más decimales que
    /// dos (con JPY o COP, redondear a dos céntimos deja la tasa en 0,00 y la fila sin sentido).
    /// Lo escribe el formateador único de tasas, el mismo que el widget de tipos de cambio.
    static func rateString(_ value: Decimal) -> String {
        ExchangeRateDisplayFormatter.string(value)
    }
}

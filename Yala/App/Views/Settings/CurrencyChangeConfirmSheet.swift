//
//  CurrencyChangeConfirmSheet.swift
//  Yala
//
//  UX 2.2 · L16-3 (variante 2 elegida por Jürgen el 2026-10-15). Elegir otra moneda principal la aplicaba al momento
//  y recalculaba todos los registros, sin preguntar ni deshacer. Ahora sale esta hoja: el saldo de hoy y cuánto es en
//  la moneda nueva, qué cambia y qué no, y «Cambiar a EUR». Es una decisión que mueve todos los datos: la persona ve
//  el efecto antes de aceptar, en su moneda.
//
//  Los textos usan el código de la moneda (EUR, PEN) y no su nombre en plural, que el sistema no da en los 16 idiomas.
//

import SwiftData
import SwiftUI

struct CurrencyChangeConfirmSheet: View {
    let from: CurrencyCode
    let to: CurrencyCode
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme

    @State private var balance: Double?
    @State private var convertedBalance: Double?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    Text(L10n.UXL16.currencyChangeTitle(currencyInfo(for: to).name.capitalized))
                        .font(DS.Typography.title3.bold())
                        .foregroundStyle(.thPrimaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)

                    beforeAfterCard

                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        effectRow("checkmark.circle.fill", L10n.UXL16.currencyChangeTotals(to.rawValue))
                        effectRow("checkmark.circle.fill", L10n.UXL16.currencyChangeRates)
                        effectRow("lock.fill", L10n.UXL16.currencyChangeRecordsKeep)
                        effectRow("arrow.uturn.backward.circle.fill", L10n.UXL16.currencyChangeCanReturn(from.rawValue))
                    }
                }
                .padding(DS.Spacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: DS.Spacing.sm) {
                    YalaPrimaryButton(L10n.UXL16.currencyChangeConfirm(to.rawValue)) {
                        onConfirm()
                    }
                    .accessibilityIdentifier("currency_change_confirm")

                    YalaSecondaryButton(L10n.Common.cancel) {
                        dismiss()
                    }
                    .accessibilityIdentifier("currency_change_cancel")
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.sm)
            }
            .navigationBarTitleDisplayMode(.inline)
            .yalaScreenBackground(.partialSheet)
        }
        .task { computeBalances() }
    }

    // MARK: - Antes y después

    private var beforeAfterCard: some View {
        HStack(alignment: .center, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.UXL16.currencyChangeToday)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.thSecondaryText)
                if let balance {
                    AmountText(
                        value: balance,
                        currencyCode: from.rawValue,
                        font: DS.Typography.title3.bold(), secondaryFont: DS.Typography.caption
                    )
                }
            }

            Image(systemName: "arrow.right")
                .font(DS.Typography.subheadline)
                .foregroundStyle(.thSecondaryText)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.UXL16.currencyChangeIn(to.rawValue))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.thSecondaryText)
                if let convertedBalance {
                    AmountText(
                        value: convertedBalance,
                        currencyCode: to.rawValue,
                        font: DS.Typography.title3.bold(), secondaryFont: DS.Typography.caption,
                        tint: .color(theme.accent),
                        isEstimate: true
                    )
                }
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(theme.accent.opacity(0.18))
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("currency_change_before_after")
    }

    private func effectRow(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(DS.Typography.subheadline)
                .foregroundStyle(theme.accent)
                .frame(width: 20)
                .accessibilityHidden(true)
            Text(text)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.thPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Cifras

    /// El saldo de las cuentas en la moneda de hoy (`LiveBalanceCalculator`, el de «Saldo de cuentas») y cuánto es en
    /// la nueva al cambio de hoy. Es una referencia: la migración convierte cada registro con la tasa de su día.
    private func computeBalances() {
        do {
            let accounts = try modelContext.fetch(FetchDescriptor<Account>())
            let transactions = try modelContext.fetch(FetchDescriptor<TransactionItem>())
            let live = LiveBalanceCalculator.liveBalance(
                accounts: accounts,
                transactions: transactions,
                preferredCurrencyCode: from.rawValue
            )
            balance = live
            let converted = CurrencyConverter.shared.convertCheckedWithLatestRate(
                Decimal(live), from: from.rawValue, to: to.rawValue
            )
            convertedBalance = (converted.amount as NSDecimalNumber).doubleValue
        } catch {
            #if DEBUG
            print("CurrencyChangeConfirmSheet: Error: \(error)")
            #endif
        }
    }
}

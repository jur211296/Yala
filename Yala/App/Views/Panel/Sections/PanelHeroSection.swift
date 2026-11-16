//
//  PanelHeroSection.swift
//  Yala
//
//  Gating wrapper: renders `HeroMonthView` only once `PanelViewModel` has
//  computed the hero payload (otherwise the skeleton flashes an empty card).
//  Propaga el binding del period picker para que `PanelFilterControlBar`
//  pueda quedarse en chips-only. La frase motivacional y el upsellCTA viven
//  en `PanelPanoramaSection` (subtítulo de "Tus finanzas" colapsado).
//
//  Intentionally NOT a `PanelSectionKind` — the hero is a permanent header
//  of the Panel, not a thematic section the user can hide.
//

import SwiftData
import SwiftUI

struct PanelHeroSection: View {
    @Bindable var viewModel: PanelViewModel
    let sessionState: SessionState
    @Environment(SceneNavigation.self) private var navigation
    @Environment(AppPreferences.self) private var appPreferences
    @Binding var showCustomPeriodPicker: Bool

    var body: some View {
        if let data = viewModel.heroWidget.data {
            HeroMonthView(
                data: data,
                currencyCode: viewModel.defaultCurrencyCode,
                selectedPeriod: sessionState.selectedPeriod,
                customDateRange: sessionState.customDateRange,
                // Una elección de la persona: cierra la visita de un informe, si la hay (UX 2.2 · L11-2).
                onSelectPeriod: { sessionState.choosePeriod($0) },
                onCustomPeriodTapped: { showCustomPeriodPicker = true },
                periodSummary: viewModel.heroPeriodWidget,
                totalBalance: viewModel.accounts.isEmpty ? nil : viewModel.panelTotalBalance,
                totalBalanceIsApproximate: viewModel.panelTotalBalanceIsApproximate,
                moneyBalance: money?.value,
                moneyBalanceIsApproximate: money?.isApproximate ?? false,
                accounts: viewModel.accounts
            )
            .contentShape(Rectangle())
            .onTapGesture {
                navigation.navigateToDetail(.insights)
            }
            .accessibilityAction(named: L10n.Accessibility.viewDetails) {
                navigation.navigateToDetail(.insights)
            }
            // «Tu dinero hoy» se calcula aquí, con los movimientos que ya cargó el Panel, cuando cambia algo de lo que
            // depende: el saldo grande, el saldo de alguna cuenta, las cuentas que suma o qué cuentas cuentan. No en
            // cada repintado: recorre todos los movimientos.
            .onChange(of: moneyInputs, initial: true) { _, inputs in
                money = Self.computeMoney(inputs, viewModel: viewModel)
            }
        }
    }

    /// «Tu dinero hoy» ya calculado, o `nil` si ninguna cuenta del saldo queda fuera (las dos cifras serían la misma).
    @State private var money: MoneyFigure?

    struct MoneyFigure: Equatable {
        let value: Double
        let isApproximate: Bool
    }

    /// Lo que mueve «Tu dinero hoy». `accountBalances` cambia con cualquier movimiento que toque un saldo (también un
    /// pago de la tarjeta, que deja igual el saldo grande).
    struct MoneyInputs: Equatable {
        let totalBalance: Double
        let accountBalances: [PersistentIdentifier: Double]
        let totalAccountIDs: Set<PersistentIdentifier>
        let overrides: String
        let currencyCode: String
        let transactionCount: Int
        /// Tipo y enlace a tarjeta de cada cuenta: deciden si cuenta como dinero sin mover ningún saldo (pasar una cuenta
        /// a tarjeta, o vincularla a una, deja igual las demás entradas).
        let accountScopes: [String]
    }

    private var moneyInputs: MoneyInputs {
        MoneyInputs(
            totalBalance: viewModel.panelTotalBalance,
            accountBalances: viewModel.accountBalances,
            totalAccountIDs: viewModel.panelTotalAccountIDs,
            overrides: appPreferences.panelMoneyAccountOverrides,
            currencyCode: viewModel.defaultCurrencyCode,
            transactionCount: viewModel.transactions.count,
            accountScopes: viewModel.accounts.map { "\($0.shortcutID.uuidString)|\($0.type)|\($0.parentAccountID?.uuidString ?? "")" }
        )
    }

    private static func computeMoney(_ inputs: MoneyInputs, viewModel: PanelViewModel) -> MoneyFigure? {
        let overrides = PanelMoneyScopeLogic.decode(inputs.overrides)
        let accounts = viewModel.accounts
        guard PanelMoneyScopeLogic.showsMoneyLine(accounts, totalAccountIDs: inputs.totalAccountIDs, overrides: overrides)
        else { return nil }
        let breakdown = PanelMoneyScopeLogic.moneyBreakdown(
            accounts: accounts,
            totalAccountIDs: inputs.totalAccountIDs,
            overrides: overrides,
            transactions: viewModel.transactions,
            preferredCurrencyCode: inputs.currencyCode
        )
        return MoneyFigure(
            value: (breakdown.convertedTotal as NSDecimalNumber).doubleValue,
            isApproximate: breakdown.amountsAreApproximate
        )
    }
}

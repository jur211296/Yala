//
//  PanelSaldoInfoSheet.swift
//  Yala
//
//  La hoja del «?» del hero del Panel (2026-11-16): qué es «Tu saldo hoy», qué es «Tu dinero hoy», un ejemplo con dos
//  cuentas y el acceso a elegir qué cuentas suman. Para alguien que no sabe nada de dinero: frases cortas, sin términos
//  financieros, y el ejemplo con números, no con definiciones.
//
//  La lista de cuentas va en la misma hoja (`PanelMoneyAccountsList`, empujada): escribe la misma preferencia que el
//  interruptor del formulario de la cuenta, y la cifra del Panel cambia al volver.
//

import SwiftData
import SwiftUI

struct PanelSaldoInfoSheet: View {
    /// Las cuentas del Panel; la lista enseña las que tienen interruptor propio (`PanelMoneyScopeLogic.switchableAccounts`).
    let accounts: [Account]
    let currencyCode: String

    @Environment(\.dismiss) private var dismiss

    /// Las cifras del ejemplo, en la moneda principal de la persona: 1.000 en ahorros y 300 gastados con tarjeta.
    private static let exampleSavings: Double = 1_000
    private static let exampleCard: Double = -300

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    figureCard(
                        systemName: "building.columns.fill",
                        title: L10n.Panel.Hero.haveToday,
                        body: L10n.SaldoPanel.Info.balanceBody,
                        identifier: "panel_saldo_info_balance"
                    )
                    figureCard(
                        systemName: "banknote.fill",
                        title: L10n.SaldoPanel.moneyToday,
                        body: L10n.SaldoPanel.Info.moneyBody,
                        identifier: "panel_saldo_info_money"
                    )
                    exampleSection
                    chooseAccountsSection
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.vertical, DS.Spacing.lg)
                .readableColumn()
            }
            .scrollBounceBehavior(.basedOnSize)
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.SaldoPanel.Info.title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: PanelMoneyAccountsRoute.self) { _ in
                PanelMoneyAccountsList(accounts: accounts)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Accessibility.close) {
                        dismiss()
                    }
                    .accessibilityIdentifier("panel_saldo_info_close")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Las dos cifras

    private func figureCard(systemName: String, title: String, body: String, identifier: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: systemName)
                .font(DS.Typography.headline)
                .foregroundStyle(.thAccentText)
                .frame(width: DS.Icon.badgeMedium, height: DS.Icon.badgeMedium)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)
                Text(body)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.thSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thCard, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - El ejemplo

    private var exampleSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.SaldoPanel.Info.exampleTitle)
                .font(DS.Typography.headline)
                .foregroundStyle(.thPrimaryText)

            VStack(spacing: DS.Spacing.none) {
                exampleRow(L10n.SaldoPanel.Info.exampleSavings, value: Self.exampleSavings, emphasized: false)
                Divider()
                exampleRow(L10n.SaldoPanel.Info.exampleCard, value: Self.exampleCard, emphasized: false)
                Divider()
                exampleRow(L10n.Panel.Hero.haveToday, value: Self.exampleSavings + Self.exampleCard, emphasized: true)
                Divider()
                exampleRow(L10n.SaldoPanel.moneyToday, value: Self.exampleSavings, emphasized: true)
            }
            .padding(.horizontal, DS.Spacing.md)
            .background(.thCard, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            // El ejemplo no son montos de la persona: el ojo del Panel no lo tapa.
            .environment(\.amountsHidden, false)
            .accessibilityIdentifier("panel_saldo_info_example")

            Text(L10n.SaldoPanel.Info.exampleNote)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.thSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func exampleRow(_ label: String, value: Double, emphasized: Bool) -> some View {
        AdaptiveRowStack(spacing: DS.Spacing.sm, stackedSpacing: DS.Spacing.xxs) {
            Text(label)
                .font(emphasized ? DS.Typography.subheadlineEmphasized : DS.Typography.subheadline)
                .foregroundStyle(emphasized ? .thPrimaryText : .thSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        } trailing: {
            AmountText(
                value: value,
                currencyCode: currencyCode,
                font: emphasized ? DS.Typography.headline : DS.Typography.subheadline,
                secondaryFont: DS.Typography.caption
            )
        }
        .padding(.vertical, DS.Spacing.sm)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Elegir qué cuentas suman

    private var chooseAccountsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            NavigationLink(value: PanelMoneyAccountsRoute()) {
                HStack {
                    Text(L10n.SaldoPanel.Info.chooseAccounts)
                        .font(DS.Typography.body)
                        .foregroundStyle(.thPrimaryText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(DS.Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.thSecondaryText)
                        .accessibilityHidden(true)
                }
                .padding(DS.Spacing.md)
                .contentShape(Rectangle())
                .background(.thCard, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("panel_saldo_info_choose_accounts")

            Text(L10n.SaldoPanel.Info.chooseHint)
                .font(DS.Typography.caption)
                .foregroundStyle(.thSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, DS.Spacing.xs)
        }
    }
}

/// El destino de «Elegir qué cuentas suman» dentro de la hoja.
struct PanelMoneyAccountsRoute: Hashable {}

/// Un interruptor por cuenta: si suma en «Tu dinero hoy». Escribe la misma preferencia que el formulario de la cuenta.
struct PanelMoneyAccountsList: View {
    let accounts: [Account]

    @Environment(AppPreferences.self) private var appPreferences

    private var liveAccounts: [Account] { accounts.filter { !$0.isDeleted && $0.modelContext != nil } }

    var body: some View {
        let live = liveAccounts
        let overrides = PanelMoneyScopeLogic.decode(appPreferences.panelMoneyAccountOverrides)
        YalaSettingsList {
            Section {
                ForEach(PanelMoneyScopeLogic.switchableAccounts(live), id: \.persistentModelID) { account in
                    PanelMoneyAccountRow(account: account, accounts: live, overrides: overrides)
                }
            } header: {
                Text(L10n.SaldoPanel.countsToggle)
            } footer: {
                Text(L10n.SaldoPanel.countsHint)
            }
        }
        .navigationTitle(L10n.SaldoPanel.accountsTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Una fila de la lista: el interruptor de una cuenta. Su estado nace de la preferencia y la escribe al cambiar
/// (`swiftui-ds.md`: nada de `Binding(get:set:)` en el body).
private struct PanelMoneyAccountRow: View {
    let account: Account
    let accounts: [Account]

    @Environment(AppPreferences.self) private var appPreferences
    @State private var isOn: Bool

    init(account: Account, accounts: [Account], overrides: [UUID: Bool]) {
        self.account = account
        self.accounts = accounts
        _isOn = State(initialValue: PanelMoneyScopeLogic.counts(account, among: accounts, overrides: overrides))
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(account.name)
        }
        .accessibilityIdentifier("panel_saldo_account_toggle_\(account.name)")
        .onChange(of: isOn) { _, counts in
            DS.Haptic.selection()
            appPreferences.panelMoneyAccountOverrides = PanelMoneyScopeLogic.setting(
                counts,
                for: account.shortcutID,
                type: PanelMoneyScopeLogic.accountType(account),
                in: appPreferences.panelMoneyAccountOverrides
            )
        }
    }
}

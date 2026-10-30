//
//  GroupBalanceHero.swift
//  Yala
//
//  La cifra de arriba de Grupos con la maqueta de la app (`HeroHeader`: rótulo gris, cifra de 36 pt y la línea de
//  debajo), como «Balance del período» en Estadísticas. Lienzo «Una sola Yala», pregunta 3A (Jürgen, 2026-10-19): la
//  misma cifra en Gastos y en Saldos, para que al cambiar de pestaña no se mueva; y la lista de grupos abre igual.
//
//  - La cifra va en el color del texto, te deban o debas: en Grupos los montos no llevan color (Jürgen, 2026-10-30).
//  - La primera divisa es la cifra grande; las demás y la frase van en la línea de abajo («+ $ 46.67 · Tú no le debes
//    nada a nadie.»), como «Entró / Salió» bajo el balance.
//

import SwiftUI

struct GroupBalanceHero: View {

    enum Scope {
        /// Detalle de un grupo: el neto del grupo («En este grupo te deben»).
        case group
        /// Lista de grupos: los dos lados por separado, sin netear (se debe a personas distintas en grupos distintos).
        case allGroups
    }

    let owedToMe: [GroupBalancesPresentationLogic.CurrencyAmount]
    let iOwe: [GroupBalancesPresentationLogic.CurrencyAmount]
    let scope: Scope
    var isEstimate = false
    /// Tocar la cifra lleva a Saldos (desde Gastos). `nil`: no se toca.
    var onTap: (() -> Void)?

    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        if let onTap {
            Button(action: onTap) { hero.contentShape(Rectangle()) }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityHint(L10n.Groups.Detail.balances)
                .accessibilityIdentifier("group_header_balance")
        } else {
            hero
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(scope == .group ? "group_balance_summary" : "groups_balance_hero")
        }
    }

    private var hero: some View {
        HeroHeader {
            HeroHeaderLabel(text: caption)
        } period: {
            EmptyView()
        } content: {
            if let main = mainAmount {
                AmountText(
                    value: main.amount,
                    currencyCode: main.currencyCode,
                    font: DS.Typography.panelHeroAmount,
                    secondaryFont: DS.Typography.panelHeroAmountSecondary,
                    tint: .primary,
                    isEstimate: isEstimate,
                    forceFullPrecision: true
                )
            }
            if let line = detailLine {
                Text(line)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Qué se cuenta

    private var isOwedSide: Bool { !owedToMe.isEmpty }

    private var mainAmount: GroupBalancesPresentationLogic.CurrencyAmount? {
        (isOwedSide ? owedToMe : iOwe).first
    }

    private var caption: String {
        switch (scope, isOwedSide, iOwe.isEmpty) {
        case (.group, true, _): L10n.UXL13.summaryOwedToMe
        case (.group, false, false): L10n.UXL13.summaryIOwe
        case (.group, false, true): L10n.UXL13.summarySettled
        case (.allGroups, true, _): L10n.UXL13.heroAllOwedToMe
        case (.allGroups, false, false): L10n.UXL13.heroAllIOwe
        case (.allGroups, false, true): L10n.Groups.Summary.allSettled
        }
    }

    /// «+ $ 46.67 · Y tú debes S/ 20.00.» — las otras divisas del lado de la cifra y, después, la frase.
    private var detailLine: String? {
        var parts: [String] = []
        let side = isOwedSide ? owedToMe : iOwe
        let rest = side.dropFirst().map { formatted($0) }
        if !rest.isEmpty { parts.append("+ " + rest.joined(separator: " + ")) }
        if let sentence { parts.append(sentence) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var sentence: String? {
        if isOwedSide, !iOwe.isEmpty {
            return L10n.UXL13.summaryAlsoOwe(iOwe.map { formatted($0) }.joined(separator: " + "))
        }
        // En la lista de grupos la frase de «nadie te debe» sobra: el rótulo ya lo dice todo.
        guard scope == .group else { return nil }
        if isOwedSide { return L10n.UXL13.summaryOwedToMeDetail }
        if !iOwe.isEmpty { return L10n.UXL13.summaryIOweDetail }
        return L10n.UXL13.summarySettledDetail
    }

    private func formatted(_ amount: GroupBalancesPresentationLogic.CurrencyAmount) -> String {
        appPreferences.currency(amount.amount, currencyCode: amount.currencyCode, isEstimate: isEstimate)
    }
}

extension GroupBalanceHero {
    /// Desde el saldo neto del grupo (`GroupHeaderBalance`, el de la banda de antes), ordenado por divisa.
    init(balance: GroupHeaderBalance, scope: Scope, isEstimate: Bool = false, onTap: (() -> Void)? = nil) {
        func amounts(_ byCurrency: [String: Double]) -> [GroupBalancesPresentationLogic.CurrencyAmount] {
            byCurrency
                .filter { $0.value > 0.01 }
                .sorted { $0.key < $1.key }
                .map { GroupBalancesPresentationLogic.CurrencyAmount(currencyCode: $0.key, amount: $0.value) }
        }
        self.init(
            owedToMe: amounts(balance.owedToMe), iOwe: amounts(balance.iOwe), scope: scope,
            isEstimate: isEstimate, onTap: onTap
        )
    }
}

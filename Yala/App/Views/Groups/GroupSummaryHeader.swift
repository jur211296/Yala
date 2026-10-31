//
//  GroupSummaryHeader.swift
//  Yala
//
//  Resumen global de la lista de grupos (decisión de Jürgen, 2026-10-30, sobre las propuestas de
//  `docs/disenos/grupos-rediseno-2-2/`): «↗ Debes» y debajo lo que debes, en rosa rojizo; «↙ Te deben» y debajo lo que
//  te deben, en verde. Los rótulos van en gris y fuente ligera; los montos, en fuente regular y algo menores que la
//  cifra del Panel. Primero lo que debes. A diferencia del detalle de un grupo, el global NO se netea (se debe a
//  personas distintas en grupos distintos): cada lado lleva sus divisas unidas con « + ».
//
//  Con Yala completo, debajo va un aviso morado a lo ancho con el neto en tu moneda principal
//  (`GroupsListBalanceLogic.net`). En Yala gratis (solo grupos) no hay moneda principal que elegir y no sale.
//

import SwiftUI

struct GroupSummaryHeader: View {

    let summary: GroupGlobalSummary
    /// Yala completo: el aviso con el neto en la moneda principal. `false` en solo grupos.
    var showsNetInMainCurrency = false

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let iOwe = Self.amounts(summary.totalIOwe)
        let owedToMe = Self.amounts(summary.totalOwedToMe)
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if iOwe.isEmpty && owedToMe.isEmpty {
                HeroHeaderLabel(text: L10n.Groups.Summary.allSettled)
                    .accessibilityIdentifier("groups_hero_settled")
            } else {
                if !iOwe.isEmpty {
                    side(label: L10n.Groups.Summary.iOwe, systemImage: "arrow.up.right", amounts: iOwe,
                         color: .groupOweAmount, identifier: "groups_hero_iowe")
                }
                if !owedToMe.isEmpty {
                    side(label: L10n.Groups.Summary.owedToMe, systemImage: "arrow.down.left", amounts: owedToMe,
                         color: .groupOwedAmount, identifier: "groups_hero_owed")
                }
                if showsNetInMainCurrency, let net = netInMainCurrency {
                    netNotice(net)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("groups_balance_hero")
    }

    // MARK: - Piezas

    private func side(
        label: String,
        systemImage: String,
        amounts: [GroupBalancesPresentationLogic.CurrencyAmount],
        color: Color,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Label(label, systemImage: systemImage)
                .font(DS.Typography.groupsHeroSideLabel)
                .foregroundStyle(.secondary)
            Text(amounts.map { formatted($0.amount, $0.currencyCode) }.joined(separator: " + "))
                .font(DS.Typography.groupsHeroSideAmount)
                .foregroundStyle(color)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    /// El aviso morado del neto, a lo ancho y sin icono (Jürgen eligió «sin el ícono» entre las dos opciones).
    private func netNotice(_ net: GroupsListBalanceLogic.Net) -> some View {
        Text(GroupsListBalanceLogic.netText(
            net,
            currencySymbol: appPreferences.currencyIdentifier(for: net.currencyCode),
            formattedAmount: formatted(net.amount, net.currencyCode, isEstimate: net.isEstimate)
        ))
        .font(DS.Typography.subheadline)
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .glassEffect(.regular.tint(Color.groupsNetNoticeTint), in: .rect(cornerRadius: DS.Radius.card))
        .accessibilityIdentifier("groups_hero_net_notice")
    }

    // MARK: - Datos

    private var netInMainCurrency: GroupsListBalanceLogic.Net? {
        GroupsListBalanceLogic.net(
            owedToMe: summary.totalOwedToMe,
            iOwe: summary.totalIOwe,
            mainCurrency: appPreferences.defaultCurrencyCode.rawValue,
            converter: CurrencyConverter.shared
        )
    }

    private func formatted(_ amount: Double, _ currencyCode: String, isEstimate: Bool = false) -> String {
        appPreferences.currency(amount, currencyCode: currencyCode, forceFullPrecision: true, isEstimate: isEstimate)
    }

    /// Las divisas de un lado con algo pendiente, por código (el orden de siempre del resumen).
    static func amounts(_ byCurrency: [String: Double]) -> [GroupBalancesPresentationLogic.CurrencyAmount] {
        byCurrency
            .filter { $0.value > 0.01 }
            .sorted { $0.key < $1.key }
            .map { GroupBalancesPresentationLogic.CurrencyAmount(currencyCode: $0.key, amount: $0.value) }
    }
}

/// L19-9 · «+ S/ 190.00 y $ 46.67 que te deben en grupos archivados», bajo el total de la lista. Archivar ordena la
/// lista, no salda nada: sin esta línea «Te deben» bajaba al archivar como si te hubieran pagado. Sin nada pendiente
/// en los archivados no pinta nada.
struct ArchivedDebtLine: View {
    @Environment(AppPreferences.self) private var appPreferences

    let summary: GroupGlobalSummary

    private func amounts(_ byCurrency: [String: Double]) -> String? {
        let items = byCurrency
            .filter { $0.value > 0.01 }
            .sorted { $0.key < $1.key }
            .map { appPreferences.currency($0.value, currencyCode: $0.key) }
        return items.isEmpty ? nil : GroupDebtCopyLogic.joined(items)
    }

    var body: some View {
        let owed = amounts(summary.totalOwedToMe)
        let owe = amounts(summary.totalIOwe)
        if owed != nil || owe != nil {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                if let owed {
                    Text(L10n.UXL19.archivedOwedLine(owed))
                }
                if let owe {
                    Text(L10n.UXL19.archivedOweLine(owe))
                }
            }
            .font(DS.Typography.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("groups_archived_debt_line")
        }
    }
}

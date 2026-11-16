//
//  GroupSplitLinesSummaryLine.swift
//  Yala
//
//  Grupos B · la línea resumen bajo la tarjeta «Tu parte»: «Debes S/ 510.00 a Pía · Sip sube S/ 500.00» (maqueta
//  `opcion-b.html`, escenarios 1 y 2). La montan la hoja de la Bandeja con «Partir» abierto y la hoja «Tu parte». Qué
//  dice lo decide `GroupSplitLinesSummaryLogic`; sin nada que decir, no ocupa sitio.
//

import SwiftData
import SwiftUI

struct GroupSplitLinesSummaryLine: View {
    let target: GroupSplitLinesService.Target
    let lines: [GroupSplitLinesRecipe.Line]

    @Environment(AppPreferences.self) private var appPreferences
    @Query private var accounts: [Account]

    var body: some View {
        let text = summary
        if !text.isEmpty {
            Text(text)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("split_lines_summary")
        }
    }

    private var summary: String {
        var names: [UUID: String] = [:]
        for account in accounts where !account.isDeleted { names[account.shortcutID] = account.name }
        let parts = GroupSplitLinesSummaryLogic.parts(
            paidByOther: !target.isCaseA, payerName: target.payerName, share: target.share, lines: lines,
            accountNames: names)
        return parts.map { part in
            switch part {
            case .owe(let amount, let name): L10n.Groups.SplitLines.summaryOwe(format(amount), name)
            case .raises(let account, let amount): L10n.Groups.SplitLines.summaryRaises(account, format(amount))
            }
        }
        .joined(separator: " · ")
    }

    private func format(_ amount: Decimal) -> String {
        appPreferences.currency(NSDecimalNumber(decimal: amount).doubleValue, currencyCode: target.currencyCode,
                                forceFullPrecision: true)
    }
}

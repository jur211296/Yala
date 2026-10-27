//
//  GroupSummaryHeader.swift
//  Yala
//
//  Resumen global de la lista de grupos: la cifra grande de la app (`GroupBalanceHero`), como el detalle de un
//  grupo, sin tocarse. A diferencia del detalle, el global NO se netea (se debe a personas
//  distintas en grupos distintos): mantiene ambos lados → cae en el caso de ambos lados.
//

import SwiftUI

struct GroupSummaryHeader: View {

    let summary: GroupGlobalSummary

    var body: some View {
        // Lienzo «Una sola Yala»: la cifra grande del Panel, no la línea pequeña de antes.
        GroupBalanceHero(balance: headerBalance, scope: .allGroups)
    }

    /// Mapea el resumen global (ambos lados por separado, por moneda) al modelo de la banda.
    private var headerBalance: GroupHeaderBalance {
        let owed = summary.totalOwedToMe.filter { $0.value > 0.01 }
        let owe = summary.totalIOwe.filter { $0.value > 0.01 }
        let state: GroupHeaderBalance.State
        switch (owed.isEmpty, owe.isEmpty) {
        case (true, true): state = .settled
        case (false, true): state = .theyOweMe
        case (true, false): state = .iOwe
        case (false, false): state = .mixed
        }
        return GroupHeaderBalance(state: state, owedToMe: owed, iOwe: owe)
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

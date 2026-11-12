//
//  RestoreFoundRowsLogic.swift
//  Yala
//
//  Qué filas enseña «Encontramos tus datos» y en qué orden (UX 2.2 · L6-5, variante 2: una lista tipo recibo,
//  el nombre a la izquierda y el número a la derecha, una sola vez).
//
//  Puro y fuera de la vista por la invariante que ya rompió dos veces esta pantalla y su hermana
//  (`WelcomePrivateICloudGateView.countsLine`): **toda cifra que enciende `ICloudAccountSummary.hasAnyData`
//  tiene que tener su fila**, o la pantalla afirma «Encontramos tus datos» sobre una lista vacía. Los grupos
//  van además, sin encender `hasAnyData` (no viajan por iCloud): se enseñan si hay algo más que restaurar.
//

import SwiftUI

enum RestoreFoundRowsLogic {

    enum Kind: CaseIterable, Hashable {
        case transactions, accounts, categories, budgets, groups

        var icon: String {
            switch self {
            case .transactions: "list.bullet.rectangle.fill"
            case .accounts: "creditcard.fill"
            case .categories: "tag.fill"
            case .budgets: "chart.pie.fill"
            case .groups: "person.2.fill"
            }
        }

        var fill: Color {
            switch self {
            case .transactions: SolidIconTilePalette.transactions
            case .accounts: SolidIconTilePalette.accounts
            case .categories: SolidIconTilePalette.categories
            case .budgets: SolidIconTilePalette.budgets
            case .groups: SolidIconTilePalette.groups
            }
        }

        /// El nombre de la fila: la palabra sola, como el encabezado de una columna. El número va a la derecha.
        var name: String {
            switch self {
            case .transactions: L10n.UXLote6.restoreRowTransactions
            case .accounts: L10n.UXLote6.restoreRowAccounts
            case .categories: L10n.UXLote6.restoreRowCategories
            case .budgets: L10n.UXLote6.restoreRowBudgets
            case .groups: L10n.UXLote6.restoreRowGroups
            }
        }

        /// Lo que oye VoiceOver: la cifra con su plural («3 cuentas»), que es como se dice en voz alta.
        func spokenCount(_ count: Int) -> String {
            switch self {
            case .transactions: L10n.Welcome.Restore.foundTransactions(count)
            case .accounts: L10n.Welcome.Restore.foundAccounts(count)
            case .categories: L10n.Welcome.PrivateICloud.foundCategories(count)
            case .budgets: L10n.Welcome.Restore.foundBudgets(count)
            case .groups: L10n.Welcome.Restore.foundGroups(count)
            }
        }
    }

    struct Row: Equatable {
        let kind: Kind
        let count: Int
    }

    /// Las filas con cifra mayor que cero, registros primero: es lo que la persona reconoce como «sus datos».
    static func rows(for summary: ICloudAccountSummary) -> [Row] {
        let all: [Row] = [
            Row(kind: .transactions, count: summary.transactionsCount),
            Row(kind: .accounts, count: summary.accountsCount),
            Row(kind: .categories, count: summary.categoriesCount),
            Row(kind: .budgets, count: summary.budgetsCount),
            Row(kind: .groups, count: summary.groupsCount),
        ]
        return all.filter { $0.count > 0 }
    }
}

//
//  ICloudCorpusChipsLogic.swift
//  Yala
//
//  Las cifras del aviso tardío de iCloud como píldoras (UX 2.2 · L6-6, variante 1). Antes iban dentro de un párrafo
//  de seis líneas y había que leerlo entero para saber cuánto había.
//
//  **Las mismas cifras, en el mismo orden y con el mismo texto que `WelcomePrivateICloudGateView.countsLine`**: es el
//  mismo hecho contado en dos sitios —la puerta del Welcome y el aviso tardío— y un test fija que las píldoras unidas
//  con « · » son esa línea. Si una cifra nueva entra en una, entra en la otra.
//

import Foundation

enum ICloudCorpusChipsLogic {

    struct Chip: Equatable, Hashable {
        let icon: String
        let text: String
    }

    /// `monthYear` formatea el «desde <mes año>»: se pasa de fuera porque el formatter vive en el MainActor con la
    /// puerta, que es su dueña, y así esta lógica no fija un locale propio.
    static func chips(for corpus: ICloudPersonalCorpus, monthYear: (Date) -> String) -> [Chip] {
        var chips: [Chip] = []
        if corpus.transactions > 0 {
            chips.append(Chip(icon: "list.bullet.rectangle.fill",
                              text: corpus.truncated
                                ? L10n.Welcome.PrivateICloud.foundAtLeast(corpus.transactions)
                                : L10n.Welcome.Restore.foundTransactions(corpus.transactions)))
        }
        if corpus.accounts > 0 {
            chips.append(Chip(icon: "creditcard.fill", text: L10n.Welcome.Restore.foundAccounts(corpus.accounts)))
        }
        if corpus.categories > 0 {
            chips.append(Chip(icon: "tag.fill", text: L10n.Welcome.PrivateICloud.foundCategories(corpus.categories)))
        }
        if corpus.budgets > 0 {
            chips.append(Chip(icon: "chart.pie.fill", text: L10n.Welcome.Restore.foundBudgets(corpus.budgets)))
        }
        if let oldest = corpus.oldestTransactionDate {
            chips.append(Chip(icon: "calendar", text: L10n.Welcome.PrivateICloud.foundSince(monthYear(oldest))))
        }
        // El corpus truncado sin cifras dice ALGO, como la línea de la puerta: un aviso que ofrece borrar no sale vacío.
        if chips.isEmpty && corpus.truncated {
            chips.append(Chip(icon: "tray.full.fill", text: L10n.Welcome.PrivateICloud.foundUnknownAmount))
        }
        return chips
    }
}

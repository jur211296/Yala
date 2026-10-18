//
//  AccountCardChips.swift
//  Yala
//
//  Tarjeta con varias divisas, entrega 3 (decisiones D5 y D6 del encargo): la pastilla de cuenta de una hoja de captura
//  enseña la TARJETA (no «Visa · USD»), y a su lado una pastilla por divisa de la tarjeta. Elegir una divisa es elegir su
//  línea: `selectedAccount` sigue siendo siempre la cuenta concreta en la que se guarda. Con una cuenta sin líneas pinta
//  la pastilla de cuenta de siempre y nada más.
//
//  Lo usa la hoja de aprobar un borrador de la Bandeja. El formulario de transacción hace lo mismo con su ViewModel
//  (`NewTransactionViewModel.cardMembers`), que ya tiene las cuentas cargadas.
//

import SwiftData
import SwiftUI

struct AccountCardChips: View {
    @Environment(\.modelContext) private var modelContext

    @Binding var selectedAccount: Account?
    /// Abre el selector de cuentas.
    let onOpenSelector: () -> Void

    /// La tarjeta de `selectedAccount`: la principal primero y sus líneas vivas. Vacío si no tiene líneas.
    @State private var members: [Account] = []

    var body: some View {
        Group {
            SelectionChip(
                icon: "creditcard",
                text: members.first?.name ?? selectedAccount?.name ?? L10n.Transaction.account,
                isSelected: selectedAccount != nil,
                color: selectedAccount.map { Color(hex: $0.colorHex) },
                action: onOpenSelector
            )

            ForEach(members, id: \.persistentModelID) { member in
                let isChosen = member.persistentModelID == selectedAccount?.persistentModelID
                SelectionChip(
                    icon: "banknote",
                    text: member.currencyCode,
                    isSelected: isChosen,
                    color: isChosen ? Color(hex: member.colorHex) : nil
                ) {
                    selectedAccount = member
                }
                .accessibilityLabel(L10n.Account.Lines.cardCurrencyChip(member.currencyCode))
                .accessibilityIdentifier("card_currency_chip_\(member.currencyCode)")
            }
        }
        .task(id: selectedAccount?.persistentModelID) { loadMembers() }
    }

    private func loadMembers() {
        guard let account = selectedAccount else {
            members = []
            return
        }
        do {
            let all = try modelContext.fetch(FetchDescriptor<Account>())
            let nodes = all.map { AccountLineNode($0) }
            let card = AccountCardLogic.liveMembers(of: account.shortcutID, nodes: nodes)
            members = card.count > 1
                ? card.compactMap { node in all.first { $0.shortcutID == node.id } }
                : []
        } catch {
            #if DEBUG
            print("AccountCardChips: Error: fetch de cuentas de la tarjeta: \(error)")
            #endif
            members = []
        }
    }
}

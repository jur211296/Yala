//
//  AccountSelectorViewModel.swift
//  Yala
//
//  ViewModel for AccountSelectorSheet - handles account list loading.
//  Fase D: Arquitectura - @Query → ViewModels
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class AccountSelectorViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Data

    private(set) var accounts: [Account] = []

    // MARK: - Computed Properties

    /// A0-Bridge: excluye cuentas sistema (`isSystemAccount`) de pickers manuales —
    /// solo el bridge puede asignarlas, nunca el usuario.
    var activeAccounts: [Account] {
        accounts.filter { !$0.isArchived && !$0.isSystemAccount }
    }

    /// Tarjeta con varias divisas (entrega 3): las cuentas como se eligen, cada tarjeta una vez con sus líneas debajo. El
    /// rol de cada cuenta se resuelve sobre TODAS (archivadas incluidas), como en el Panel.
    func cards(of shown: [Account]) -> [AccountCard<Account>] {
        let roles = AccountLineLogic.resolve(accounts.map { AccountLineNode($0) })
        return AccountCardLogic.cards(shown, roles: roles, id: \.shortcutID, currencyCode: \.currencyCode)
    }

    /// Lo que guarda el llamador al tocar `account` (decisión D3 del encargo): con `routingCurrency`, la cuenta de su tarjeta en
    /// esa divisa (`AccountCardLogic.route`); sin ella, o si no se encuentra, la cuenta tocada.
    func resolvedSelection(for account: Account, routingCurrency: String?) -> Account {
        guard let routingCurrency else { return account }
        let nodes = accounts.map { AccountLineNode($0) }
        guard let route = AccountCardLogic.route(chosenID: account.shortcutID, currencyCode: routingCurrency, nodes: nodes),
              let target = activeAccounts.first(where: { $0.shortcutID == route.accountID }) else { return account }
        return target
    }

    // MARK: - Context Injection

    func setContext(_ context: ModelContext) {
        self.modelContext = context
        loadAccounts()
    }

    // MARK: - Data Loading

    func loadAccounts() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<Account>(sortBy: [SortDescriptor(\Account.name)])
        do {
            accounts = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("AccountSelectorViewModel: Error loading accounts: \(error)")
            #endif
            accounts = []
        }
    }
}

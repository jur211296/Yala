//
//  BulkEditViewModel.swift
//  Yala
//
//  ViewModel for BulkEditSheet - handles tag loading, what the selection has today and the pending changes.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class BulkEditViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Data

    private(set) var allTags: [Tag] = []

    // MARK: - Lo que tienen hoy los elegidos (L8-13)

    private(set) var selectionCount = 0
    private(set) var currentAccount: BulkEditLogic.Current = .distinct(0)
    private(set) var currentSubcategory: BulkEditLogic.Current = .distinct(0)
    private(set) var currentNote: BulkEditLogic.Current = .distinct(0)
    /// El monto que comparten todos (en valor absoluto y con su moneda), o `nil` si difieren.
    private(set) var sharedAmount: Double?
    private(set) var selectedCurrencies: [String] = []

    // MARK: - Lo pendiente (L8-13)

    /// Lo elegido y todavía sin aplicar. Se aplica todo junto con «Aplicar a N registros».
    var changes = BulkEditChanges()
    /// Por qué no se puede aplicar lo pendiente; lo mide la hoja cada vez que cambia.
    var blocker: String?

    // MARK: - Computed Properties

    var activeTags: [Tag] {
        allTags.filter { $0.isActive }
    }

    /// La moneda en que se escribe el monto, o `nil` si no se ofrece (monedas distintas y sin cuenta nueva).
    var amountCurrency: String? {
        BulkEditLogic.amountCurrency(
            selectedCurrencies: selectedCurrencies, pendingAccountCurrency: changes.account?.currencyCode)
    }

    /// El aviso de moneda: la cuenta nueva cambia la moneda de alguno de los elegidos.
    var pendingAccountChangesCurrency: Bool {
        guard let account = changes.account else { return false }
        return BulkEditLogic.changesCurrency(selectedCurrencies: selectedCurrencies, destination: account.currencyCode)
    }

    // MARK: - Context Injection

    func setContext(_ context: ModelContext) {
        self.modelContext = context
        loadData()
    }

    // MARK: - Data Loading

    func loadData() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\Tag.name)])
        do {
            allTags = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("BulkEditViewModel: Error loading tags: \(error)")
            #endif
            allTags = []
        }
    }

    /// Lee qué tienen hoy los elegidos. Una vez al abrir la hoja: con «Seleccionar todo» son muchos.
    func loadSelection(_ transactions: [TransactionItem]) {
        selectionCount = transactions.count
        currentAccount = BulkEditLogic.current(transactions.map { $0.account?.name })
        currentSubcategory = BulkEditLogic.current(transactions.map { $0.subcategory?.name })
        currentNote = BulkEditLogic.current(transactions.map(\.note))
        selectedCurrencies = transactions.map(\.currencyCode)
        let amounts = Set(transactions.map { (abs($0.amount) * 100).rounded() / 100 })
        sharedAmount = amounts.count == 1 && Set(selectedCurrencies.map(normalizeCurrencyCode)).count == 1
            ? amounts.first : nil
    }

    /// Si la moneda del monto deja de estar clara (se quitó la cuenta nueva), el monto pendiente ya no significa lo
    /// mismo en cada registro y se descarta.
    func dropAmountIfCurrencyIsUnclear() {
        if changes.amount != nil && amountCurrency == nil {
            changes.amount = nil
        }
    }
}

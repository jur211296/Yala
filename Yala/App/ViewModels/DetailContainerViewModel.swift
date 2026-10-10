//
//  DetailContainerViewModel.swift
//  Yala
//
//  ViewModel para DetailContainerView - maneja carga de datos para Statistics tabs.
//  Refactor D.8: @Query → ViewModel
//

import Foundation
import SwiftData

@MainActor
@Observable
final class DetailContainerViewModel {

    // MARK: - Dependencies

    private var modelContext: ModelContext?

    // MARK: - Data

    private(set) var allTransactions: [TransactionItem] = []
    private(set) var accounts: [Account] = []
    private(set) var categories: [Category] = []
    private(set) var allSubcategories: [Subcategory] = []
    private(set) var tags: [Tag] = []
    private(set) var budgets: [Budget] = []
    private(set) var scheduledPayments: [ScheduledPayment] = []

    /// Avanza cuando una recarga del store trae algo nuevo. Es la señal de «los datos cambiaron» para quien precalcula a
    /// partir de estos arrays (hoy, Distribución).
    ///
    /// Los arrays solos no sirven de señal: editar el importe de un movimiento deja las MISMAS filas,
    /// `fetched != allTransactions` da `false` y nada aguas abajo se entera. Por eso cuenta también `dataVersion`, que
    /// todo mutador sube (alta, edición, borrado, ediciones masivas, sync). Observar `dataVersion` directamente tampoco
    /// vale: salta 150 ms antes de esta recarga (el debounce del contenedor) y quien lo mirara leería los arrays viejos.
    ///
    /// **No avanza en una recarga que no trae nada.** El contenedor recarga dos veces por alta —al guardar, por
    /// `dataVersion`, y al cerrar la pantalla de éxito, por el `onDisappear` del sheet— y también al cerrar un sheet sin
    /// guardar o al volver de segundo plano. Avanzar en cada una recalcularía Distribución más veces por gesto que el
    /// `.count` al que sustituye (medido: el Sankey pasaba de 1 a 2 por alta).
    private(set) var dataGeneration = 0

    /// `dataVersion` de la última recarga: lo que permite saber si la siguiente trae una mutación nueva.
    private var lastLoadedDataVersion: Int?

    // MARK: - Setup

    func setContext(_ context: ModelContext) {
        let isNewContext = self.modelContext !== context
        self.modelContext = context
        if isNewContext { loadData() }
    }

    /// - Parameter dataVersion: el `SessionState.dataVersion` en el momento de recargar; `nil` lo lee del singleton.
    ///   Inyectable para que los tests no dependan de él.
    func loadData(dataVersion: Int? = nil) {
        guard let context = modelContext else { return }
        let dataVersion = dataVersion ?? SessionState.shared.dataVersion
        var changed = false

        // Load transactions
        let transactionsDescriptor = FetchDescriptor<TransactionItem>(
            sortBy: [
                SortDescriptor(\.date, order: .reverse),
                SortDescriptor(\.createdAt, order: .reverse)
            ]
        )
        do {
            let fetched = try context.fetch(transactionsDescriptor)
            if fetched != allTransactions { allTransactions = fetched; changed = true }
        } catch {
            #if DEBUG
            print("DetailContainerViewModel: Error loading transactions: \(error)")
            #endif
        }

        // Load accounts
        let accountsDescriptor = FetchDescriptor<Account>(
            sortBy: [SortDescriptor(\.name)]
        )
        do {
            let fetched = try context.fetch(accountsDescriptor)
            if fetched != accounts { accounts = fetched; changed = true }
        } catch {
            #if DEBUG
            print("DetailContainerViewModel: Error loading accounts: \(error)")
            #endif
        }

        // Load categories
        let categoriesDescriptor = FetchDescriptor<Category>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        do {
            let fetched = try context.fetch(categoriesDescriptor)
            if fetched != categories { categories = fetched; changed = true }
        } catch {
            #if DEBUG
            print("DetailContainerViewModel: Error loading categories: \(error)")
            #endif
        }

        // Load subcategories
        let subcategoriesDescriptor = FetchDescriptor<Subcategory>(
            sortBy: [SortDescriptor(\.name)]
        )
        do {
            let fetched = try context.fetch(subcategoriesDescriptor)
            if fetched != allSubcategories { allSubcategories = fetched; changed = true }
        } catch {
            #if DEBUG
            print("DetailContainerViewModel: Error loading subcategories: \(error)")
            #endif
        }

        // Load tags
        let tagsDescriptor = FetchDescriptor<Tag>(
            sortBy: [SortDescriptor(\.name)]
        )
        do {
            let fetched = try context.fetch(tagsDescriptor)
            if fetched != tags { tags = fetched; changed = true }
        } catch {
            #if DEBUG
            print("DetailContainerViewModel: Error loading tags: \(error)")
            #endif
        }

        // Load budgets (for Insights commitments section)
        let budgetsDescriptor = FetchDescriptor<Budget>(
            sortBy: [SortDescriptor(\.name)]
        )
        do {
            let fetched = try context.fetch(budgetsDescriptor)
            if fetched != budgets { budgets = fetched; changed = true }
        } catch {
            #if DEBUG
            print("DetailContainerViewModel: Error loading budgets: \(error)")
            #endif
        }

        // Load scheduled payments (for Insights commitments section)
        let paymentsDescriptor = FetchDescriptor<ScheduledPayment>(
            sortBy: [SortDescriptor(\.nextDueDate)]
        )
        do {
            let fetched = try context.fetch(paymentsDescriptor)
            if fetched != scheduledPayments { scheduledPayments = fetched; changed = true }
        } catch {
            #if DEBUG
            print("DetailContainerViewModel: Error loading scheduled payments: \(error)")
            #endif
        }

        if dataVersion != lastLoadedDataVersion {
            lastLoadedDataVersion = dataVersion
            changed = true
        }
        if changed { dataGeneration &+= 1 }
    }

    // MARK: - Computed Properties

    /// Check if voice input can be used (requires accounts and subcategories)
    var canUseVoiceInput: Bool {
        let hasActiveAccounts = accounts.contains { !$0.isArchived }
        let hasVisibleSubcategories = allSubcategories.contains { $0.isVisible }
        return hasActiveAccounts && hasVisibleSubcategories
    }

    /// Compute date range of all transactions (for custom period picker limits)
    func computeTransactionDateRange() -> (start: Date, end: Date) {
        let sortedDates = allTransactions.map(\.date).sorted()
        let start = sortedDates.first ?? Date.now
        let end = sortedDates.last ?? Date.now
        return (start, end)
    }
}

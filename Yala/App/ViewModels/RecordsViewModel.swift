//
//  RecordsViewModel.swift
//  Yala
//
//  Created by Yala - Records Feature.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Records ViewModel

/// ViewModel for the Records list view
/// Manages filter state, selection, and computed data
@MainActor
@Observable
final class RecordsViewModel: Filterable {

    // MARK: - Filter State (SSOT: Read/Write from SessionState.shared)

    /// Selected accounts for filtering
    var selectedAccounts: Set<PersistentIdentifier> {
        get { SessionState.shared.selectedAccountIDs }
        set { SessionState.shared.selectedAccountIDs = newValue }
    }

    /// Selected categories for filtering
    var selectedCategories: Set<PersistentIdentifier> {
        get { SessionState.shared.selectedCategoryIDs }
        set { SessionState.shared.selectedCategoryIDs = newValue }
    }

    /// Selected subcategories for filtering
    var selectedSubcategories: Set<PersistentIdentifier> {
        get { SessionState.shared.selectedSubcategoryIDs }
        set { SessionState.shared.selectedSubcategoryIDs = newValue }
    }

    /// Selected needs for filtering
    var selectedNeeds: Set<SubcategoryNeed> {
        get { SessionState.shared.selectedNeeds }
        set { SessionState.shared.selectedNeeds = newValue }
    }

    /// Selected transaction natures for filtering (empty = all)
    /// Used for income/expense filter chips
    var selectedTransactionNatures: Set<TransactionNature> {
        get { SessionState.shared.selectedTransactionNatures }
        set { SessionState.shared.selectedTransactionNatures = newValue }
    }

    /// Selected tags for filtering
    var selectedTags: Set<PersistentIdentifier> {
        get { SessionState.shared.selectedTags }
        set { SessionState.shared.selectedTags = newValue }
    }

    /// Transaction type filter (local - not shared between views)
    var transactionTypeFilter: TransactionTypeFilter = .all

    /// Amount filter condition
    var amountCondition: AmountFilterCondition {
        get { SessionState.shared.amountCondition }
        set { SessionState.shared.amountCondition = newValue }
    }

    /// Period filter (unified with Trends)
    var period: DetailPeriod {
        get { SessionState.shared.selectedPeriod }
        set { SessionState.shared.selectedPeriod = newValue }
    }

    /// Custom date range (synced from SessionState)
    var customDateRange: DateInterval? {
        get { SessionState.shared.customDateRange }
        set { SessionState.shared.customDateRange = newValue }
    }

    /// Selected currencies for filtering
    var selectedCurrencies: Set<CurrencyCode> {
        get { SessionState.shared.selectedCurrencies }
        set { SessionState.shared.selectedCurrencies = newValue }
    }

    /// Search text for note filtering
    var searchText: String {
        get { SessionState.shared.searchText }
        set { SessionState.shared.searchText = newValue }
    }

    /// Exclude mode for entity filters
    var isExcludeMode: Bool {
        get { SessionState.shared.isExcludeMode }
        set { SessionState.shared.isExcludeMode = newValue }
    }

    var sharedExpenseFilter: SharedExpenseFilter = .all

    // MARK: - UI State

    /// Whether search bar is expanded
    var isSearchExpanded: Bool = false

    /// Whether selection mode is active
    var isSelectionMode: Bool = false

    /// Selected record IDs for bulk actions
    var selectedRecordIDs: Set<PersistentIdentifier> = []

    /// Sheet states
    var showFiltersSheet: Bool = false
    var showNewTransaction: Bool = false
    var showEditTransaction: Bool = false
    var showTransactionDetail: Bool = false
    var editingTransaction: TransactionItem?

    /// Mensaje de error surfaceado por `BulkEditSheet` cuando una operación bulk rechaza
    /// la mutación (e.g., subcategoría sobre transferencias).
    var bulkUpdateError: String?

    // MARK: - Computed Data

    /// Grouped records by date (pre-computed for performance)
    var groupedRecords: [(date: Date, records: [TransactionItem])] = []

    /// Cached summary (balance, income, expense) - updated when groupedRecords changes
    var recordsSummary: (balance: Double, income: Double, expense: Double) = (0, 0, 0)

    /// Total count of filtered records
    var filteredCount: Int {
        groupedRecords.reduce(0) { $0 + $1.records.count }
    }

    // MARK: - Computed Properties

    /// Build FilterCriteria including transactionTypeFilter (Records-specific, not in Filterable)
    private var currentCriteria: FilterCriteria {
        var c = filterCriteria
        c.transactionTypeFilter = transactionTypeFilter
        return c
    }

    /// Whether any filter is active (for UI indicator)
    var hasActiveFilters: Bool { currentCriteria.hasActiveFilters }

    /// Whether transaction nature filter shows a chip (exactly 1 selected)
    var hasTransactionNatureFilter: Bool {
        selectedTransactionNatures.count == 1
    }

    /// Number of active filter types (for badge)
    var activeFilterCount: Int { currentCriteria.activeFilterCount }

    // MARK: - Initialization

    init() {}

    /// Initialize with context from Panel
    init(context: RecordsFilterContext) {
        if let accountID = context.accountID {
            selectedAccounts = [accountID]
        }
        if let categoryID = context.categoryID {
            selectedCategories = [categoryID]
        }
        if let need = context.need {
            selectedNeeds = [need]
        }
        // Note: period is NOT set here because it's a computed property that writes to SessionState.
        // Setting it would overwrite the user's period selection. The period comes from SessionState directly.
        if let type = context.transactionType {
            self.transactionTypeFilter = type
        }
        if let search = context.searchText, !search.isEmpty {
            self.searchText = search
        }
    }

    // MARK: - Filter Application

    /// Apply all filters and group results by date
    func applyFilters(
        transactions: [TransactionItem],
        accounts: [Account],
        categories: [Category],
        tags: [Tag]
    ) {
        // In expenses-only mode, force expense transaction nature filter
        let effectiveTransactionNatures: Set<TransactionNature> =
            SessionState.shared.isExpensesOnlyMode ? [.expense] : selectedTransactionNatures

        // Build FilterCriteria from current state
        var criteria = FilterCriteria(
            selectedAccounts: selectedAccounts,
            selectedCategories: selectedCategories,
            selectedSubcategories: selectedSubcategories,
            selectedTags: selectedTags,
            selectedNeeds: selectedNeeds,
            selectedTransactionNatures: effectiveTransactionNatures,
            selectedCurrencies: selectedCurrencies,
            isExcludeMode: isExcludeMode,
            transactionTypeFilter: transactionTypeFilter,
            amountCondition: amountCondition,
            searchText: searchText,
            dateInterval: effectiveDateInterval()
        )
        criteria.populateTagUUIDs(
            from: tags.filter { selectedTags.contains($0.persistentModelID) }
        )

        // A0-Bridge: respeta toggle global "incluir transacciones de grupos en feed".
        // Si OFF, oculta TX bridgeadas (splitExpenseID/splitSettlementID != nil).
        // Default true; user lo desactiva en RecordsFiltersView (F10).
        let includeGroupTxs = UserDefaults.standard.object(
            forKey: AppPreferences.Keys.includeGroupTransactionsInFeed
        ) as? Bool ?? true

        // Pre-filter: hide transactions from accounts excluded from statistics
        let eligibleTransactions = transactions.filter { tx in
            guard let account = tx.account else { return true }
            if account.excludeFromStatistics { return false }
            if !includeGroupTxs && (tx.splitExpenseID != nil || tx.splitSettlementID != nil) {
                return false
            }
            return true
        }

        // Use FilterService for filtering and grouping
        groupedRecords = FilterService.filterAndGroup(
            transactions: eligibleTransactions,
            criteria: criteria
        )

        // Update cached summary (calculated once per filter change, not per render)
        calculateSummary()
    }

    /// Calculate summary from grouped records (called once when data changes)
    /// Balance = Income - Expense (excludes adjustments and transfers for consistency)
    private func calculateSummary() {
        var income: Double = 0
        var expense: Double = 0

        for group in groupedRecords {
            for record in group.records {
                guard let account = record.account else { continue }
                if account.excludeFromStatistics { continue }

                // Exclude balance adjustments and transfers from summary
                let isBalanceAdjustment = record.balanceAdjustmentType != nil
                if !isBalanceAdjustment {
                    let amount = record.amountInPreferredCurrency
                    if amount > 0 {
                        income += amount
                    } else {
                        expense += abs(amount)
                    }
                }
            }
        }

        // Balance is simply the difference (cash flow)
        let newSummary = (income - expense, income, expense)
        if newSummary != recordsSummary { recordsSummary = newSummary }
    }

    /// Get effective date interval from current period
    private func effectiveDateInterval() -> DateInterval? {
        // DetailPeriod always has a valid dateInterval
        return period.dateInterval(customRange: customDateRange)
    }

    // MARK: - Selection Actions

    /// Toggle selection for a record
    func toggleSelection(_ id: PersistentIdentifier) {
        if selectedRecordIDs.contains(id) {
            selectedRecordIDs.remove(id)
        } else {
            selectedRecordIDs.insert(id)
        }
    }

    /// Select all visible records
    func selectAll() {
        for group in groupedRecords {
            for record in group.records {
                selectedRecordIDs.insert(record.persistentModelID)
            }
        }
    }

    /// Deselect all records
    func deselectAll() {
        selectedRecordIDs.removeAll()
    }

    /// Enter selection mode
    func enterSelectionMode() {
        isSelectionMode = true
        selectedRecordIDs.removeAll()
    }

    /// Exit selection mode
    func exitSelectionMode() {
        isSelectionMode = false
        selectedRecordIDs.removeAll()
    }

    /// Delete selected records (including transfer pairs)
    func deleteSelected(context: ModelContext) {
        // Collect transfer pair IDs from selected records
        var transferPairIDs: Set<String> = []
        var recordsToDelete: [TransactionItem] = []

        for id in selectedRecordIDs {
            guard let record = context.model(for: id) as? TransactionItem else { continue }
            recordsToDelete.append(record)
            if record.balanceAdjustmentType == TransactionItem.adjustmentTypeTransfer, let pairID = record.transferPairID {
                transferPairIDs.insert(pairID)
            }
        }

        // Delete transfer pairs that weren't already selected
        if !transferPairIDs.isEmpty {
            for pairID in transferPairIDs {
                let fetchPairID = pairID
                let descriptor = FetchDescriptor<TransactionItem>(
                    predicate: #Predicate { $0.transferPairID == fetchPairID }
                )
                do {
                    let pairs = try context.fetch(descriptor)
                    for pair in pairs where !selectedRecordIDs.contains(pair.persistentModelID) {
                        context.delete(pair)
                    }
                } catch {
                    #if DEBUG
                    print("RecordsViewModel: Error fetching transfer pairs: \(error)")
                    #endif
                }
            }
        }

        // Delete selected records
        for record in recordsToDelete {
            context.delete(record)
        }

        do {
            try context.save()
            context.processPendingChanges()
            WidgetDataCache.updateCache(context: context)
            SessionState.shared.incrementDataVersion()
        } catch {
            #if DEBUG
            print("Error deleting records: \(error)")
            #endif
        }

        exitSelectionMode()
    }

    // MARK: - Filter Actions

    /// Clear all filters
    func clearFilters() {
        selectedAccounts.removeAll()
        selectedCategories.removeAll()
        selectedSubcategories.removeAll()
        selectedNeeds.removeAll()
        // In expenses-only mode, keep expense filter forced
        if SessionState.shared.isExpensesOnlyMode {
            selectedTransactionNatures = [.expense]
        } else {
            selectedTransactionNatures.removeAll()
        }
        selectedTags.removeAll()
        transactionTypeFilter = .all
        isExcludeMode = false
        amountCondition = .any
        // period = .thisMonth // Do not reset period
        selectedCurrencies = []
        searchText = ""
    }

    /// Clear search
    func clearSearch() {
        searchText = ""
        isSearchExpanded = false
    }

    // MARK: - Edit Actions

    /// Tap de una row: abre el detalle read-only (TransactionDetailSheet);
    /// la edición se alcanza desde ahí (botón Editar o drag a large).
    func showRecordDetail(_ record: TransactionItem) {
        editingTransaction = record
        showTransactionDetail = true
    }

    /// Handle edit action for selected records
    func editSelectedRecords(transactions: [TransactionItem]) -> EditAction {
        guard !selectedRecordIDs.isEmpty else { return .none }

        if selectedRecordIDs.count == 1,
            let id = selectedRecordIDs.first,
            let record = transactions.first(where: { $0.persistentModelID == id })
        {
            return .single(record)
        } else {
            return .multiple(selectedRecordIDs.count)
        }
    }

    enum EditAction {
        case none
        case single(TransactionItem)
        case multiple(Int)
    }

    // MARK: - Bulk Edit Operations

    /// Update account for all selected transactions.
    /// Bloqueado si la selección contiene transferencias — una transferencia tiene dos cuentas
    /// inherentes (origen y destino) ligadas por `transferPairID`; colapsarlas a una sola cuenta
    /// partiría el par entre cuentas no relacionadas y descuadraría ambos balances (y el exchange
    /// rate en cross-currency). Editar la cuenta de un transfer debe hacerse desde su editor dedicado.
    func bulkUpdateAccount(_ account: Account, context: ModelContext) {
        let transactions = getSelectedTransactions(context: context)
        if transactions.contains(where: { $0.balanceAdjustmentType == TransactionItem.adjustmentTypeTransfer }) {
            bulkUpdateError = L10n.BulkEdit.cannotEditTransferAccount
            return
        }
        for transaction in transactions {
            transaction.account = account
            transaction.currencyCode = account.currencyCode
            transaction.recalculatePreferredCurrency(context: context)
        }
        do {
            try context.save()
            SessionState.shared.incrementDataVersion()
        } catch {
            #if DEBUG
            print("RecordsViewModel: Error saving bulk account update: \(error)")
            #endif
        }
    }

    /// Update subcategory for all selected transactions.
    /// Bloqueado si la selección contiene transferencias — usan subcat sistema obligatoria.
    func bulkUpdateSubcategory(_ subcategory: Subcategory, context: ModelContext) {
        let transactions = getSelectedTransactions(context: context)
        if transactions.contains(where: { $0.balanceAdjustmentType == TransactionItem.adjustmentTypeTransfer }) {
            bulkUpdateError = L10n.BulkEdit.cannotEditTransferSubcategory
            return
        }
        for transaction in transactions {
            transaction.subcategory = subcategory
            transaction.category = subcategory.safeCategory
        }
        do {
            try context.save()
            SessionState.shared.incrementDataVersion()
        } catch {
            #if DEBUG
            print("RecordsViewModel: Error saving bulk subcategory update: \(error)")
            #endif
        }
    }

    /// Add tags to all selected transactions.
    /// Propaga al partner para transferencias — MERGE con tags propios del partner (no clobber).
    /// Usa `partnerSkipIfAmbiguous` para no propagar en collisions 3+ (evita widening desync).
    /// CSV-first read (resolvedTagIDs) — fixes lazy nil → tag loss bug.
    func bulkAddTags(_ tags: [Tag], context: ModelContext) {
        let transactions = getSelectedTransactions(context: context)
        let toAddIDs = Set(tags.map(\.id))
        var processedPairIDs: Set<String> = []

        // Si el fetch lanza, abortamos toda la operación (no clobber con `setTags(from: [])`).
        // El old code asignaba un currentTags-derived array sin fetch — no perdía tags ante errors.
        func applyAdd(to tx: TransactionItem) throws {
            let currentIDs = tx.resolvedTagIDs(scheduleBackfill: true) ?? []
            let newIDs = currentIDs.union(toAddIDs)
            guard newIDs != currentIDs else { return }   // idempotent
            let resolved = try TagResolver.fetch(ids: newIDs, in: context)
            tx.setTags(from: resolved)
        }

        do {
            for transaction in transactions {
                try applyAdd(to: transaction)
                if let pairID = transaction.transferPairID, !processedPairIDs.contains(pairID),
                   let partner = TransferPartnerLookup.partnerSkipIfAmbiguous(of: transaction, in: context) {
                    processedPairIDs.insert(pairID)
                    try applyAdd(to: partner)
                }
            }
            try context.save()
            SessionState.shared.incrementDataVersion()
        } catch {
            #if DEBUG
            print("RecordsViewModel: Error saving bulk tags update: \(error)")
            #endif
        }
    }

    /// Remove tags from all selected transactions.
    /// Propaga al partner para transferencias. Skip si collision (3+).
    /// CSV-first read (resolvedTagIDs).
    func bulkRemoveTags(_ tags: [Tag], context: ModelContext) {
        let transactions = getSelectedTransactions(context: context)
        let toRemoveIDs = Set(tags.map(\.id))
        var processedPairIDs: Set<String> = []

        func applyRemove(from tx: TransactionItem) throws {
            let currentIDs = tx.resolvedTagIDs(scheduleBackfill: true) ?? []
            let newIDs = currentIDs.subtracting(toRemoveIDs)
            guard newIDs != currentIDs else { return }   // idempotent
            let resolved = try TagResolver.fetch(ids: newIDs, in: context)
            tx.setTags(from: resolved)
        }

        do {
            for transaction in transactions {
                try applyRemove(from: transaction)
                if let pairID = transaction.transferPairID, !processedPairIDs.contains(pairID),
                   let partner = TransferPartnerLookup.partnerSkipIfAmbiguous(of: transaction, in: context) {
                    processedPairIDs.insert(pairID)
                    try applyRemove(from: partner)
                }
            }
        } catch {
            #if DEBUG
            print("RecordsViewModel: Error applying bulk remove: \(error)")
            #endif
            return  // abort early — no save (preserva tags previos)
        }
        do {
            try context.save()
            SessionState.shared.incrementDataVersion()
        } catch {
            #if DEBUG
            print("RecordsViewModel: Error saving bulk tags removal: \(error)")
            #endif
        }
    }

    /// Update note for all selected transactions.
    /// Propaga al partner SOLO si su nota actual ya coincide con la de tx (sincronizadas).
    /// Si las notas divergían intencionalmente, preserva la divergencia. Empty→nil para evitar
    /// schema noise en CloudKit.
    func bulkUpdateNote(_ note: String, context: ModelContext) {
        let transactions = getSelectedTransactions(context: context)
        let finalNote = note.isEmpty ? nil : note
        var processedPairIDs: Set<String> = []
        for transaction in transactions {
            let originalNote = transaction.note
            transaction.note = finalNote

            if let pairID = transaction.transferPairID, !processedPairIDs.contains(pairID),
               let partner = TransferPartnerLookup.partnerSkipIfAmbiguous(of: transaction, in: context) {
                processedPairIDs.insert(pairID)
                // Solo propagar si las notas estaban sincronizadas — preserva divergencia legacy.
                if (originalNote ?? "") == (partner.note ?? "") {
                    partner.note = finalNote
                }
            }
        }
        do {
            try context.save()
            SessionState.shared.incrementDataVersion()
        } catch {
            #if DEBUG
            print("RecordsViewModel: Error saving bulk note update: \(error)")
            #endif
        }
    }

    /// Update amount for all selected transactions.
    /// Propaga al partner con signo opuesto preservado para mantener balance del transfer.
    /// Bloquea si la selección contiene transferencias cross-currency (cambiar el amount destruiría
    /// el exchange rate). Skip si collision (3+).
    func bulkUpdateAmount(_ amount: Double, context: ModelContext) {
        let transactions = getSelectedTransactions(context: context)
        // Preserve exchange rate: bloquear bulk-edit en transfers cross-currency.
        for tx in transactions {
            if let partner = TransferPartnerLookup.partnerSkipIfAmbiguous(of: tx, in: context),
               tx.currencyCode != partner.currencyCode {
                bulkUpdateError = L10n.BulkEdit.cannotEditTransferAmountCrossCurrency
                return
            }
        }
        var processedPairIDs: Set<String> = []
        for transaction in transactions {
            // Preserve sign: expenses are negative, income positive
            transaction.amount = transaction.amount < 0 ? -abs(amount) : abs(amount)
            transaction.recalculatePreferredCurrency(context: context)

            if let pairID = transaction.transferPairID, !processedPairIDs.contains(pairID),
               let partner = TransferPartnerLookup.partnerSkipIfAmbiguous(of: transaction, in: context) {
                processedPairIDs.insert(pairID)
                partner.amount = partner.amount < 0 ? -abs(amount) : abs(amount)
                partner.recalculatePreferredCurrency(context: context)
            }
        }
        do {
            try context.save()
            SessionState.shared.incrementDataVersion()
        } catch {
            #if DEBUG
            print("RecordsViewModel: Error saving bulk amount update: \(error)")
            #endif
        }
    }

    /// Get tags for all selected transactions (for bulk tag editing UI).
    /// CSV-mirror SSOT: lee UUIDs vía `resolvedTagIDs(scheduleBackfill: true)` y los
    /// resuelve a Tag objects via `TagResolver.fetch(ids:in:)`. Sobrevive lazy
    /// hydration de la M2M `tx.tags`.
    func getSelectedTransactionTags(context: ModelContext) -> [[Tag]] {
        let flatTransactions = groupedRecords.flatMap { $0.records }
        return selectedRecordIDs.compactMap { id -> [Tag]? in
            guard let tx = flatTransactions.first(where: { $0.persistentModelID == id }) else {
                return nil
            }
            let ids = tx.resolvedTagIDs(scheduleBackfill: true) ?? []
            do {
                return try TagResolver.fetch(ids: ids, in: context)
            } catch {
                #if DEBUG
                print("RecordsViewModel: getSelectedTransactionTags fetch error: \(error)")
                #endif
                return []
            }
        }
    }

    /// Detect the transaction type of selected records for bulk edit filtering
    /// Returns .income if all non-transfer selections are income,
    /// .expense if all are expense, nil if mixed or only transfers
    func getSelectedTransactionType() -> TransactionType? {
        let flatTransactions = groupedRecords.flatMap { $0.records }
        let selected = flatTransactions.filter { selectedRecordIDs.contains($0.persistentModelID) }

        var hasIncome = false
        var hasExpense = false

        for transaction in selected {
            // Skip transactions without subcategory and transfers (system subcategory)
            guard let subcategory = transaction.subcategory else { continue }
            if subcategory.isAnySystem { continue }

            if subcategory.safeCategory.isIncome {
                hasIncome = true
            } else {
                hasExpense = true
            }
            // Early exit if mixed
            if hasIncome && hasExpense { return nil }
        }

        if hasIncome && !hasExpense { return .income }
        if hasExpense && !hasIncome { return .expense }
        return nil  // Mixed or only transfers
    }

    /// Helper to fetch selected transactions from context
    private func getSelectedTransactions(context: ModelContext) -> [TransactionItem] {
        var transactions: [TransactionItem] = []
        for id in selectedRecordIDs {
            if let transaction = context.model(for: id) as? TransactionItem {
                transactions.append(transaction)
            }
        }
        return transactions
    }
}

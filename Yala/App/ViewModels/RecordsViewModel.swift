//
//  RecordsViewModel.swift
//  Yala
//
//  Created by Yala - Records Feature.
//

import Foundation
import OSLog
import SwiftData
import SwiftUI

// MARK: - Records ViewModel

/// ViewModel for the Records list view
/// Manages filter state, selection, and computed data
@MainActor
@Observable
final class RecordsViewModel: Filterable {

    // DIAG (caso "registro de grupo desaparece al clasificar"). Quitar tras QA.
    private static let diagLogger = Logger(subsystem: "com.yala", category: "GroupBridge")

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

    /// Whether "identify duplicates" mode is active (ephemeral, per-view — resets on view/tab change)
    var duplicateModeActive: Bool = false

    /// Which fields must match for two records to count as duplicates (default: all 4)
    var duplicateCriteria = RecordsDuplicateLogic.Criteria(
        amount: true, note: true, subcategory: true, date: true
    )

    /// Modo duplicados (L8-11): los grupos que casan entre sí, cada uno con el que se queda delante. Vacío fuera del
    /// modo. Los calcula `applyFilters` sobre lo ya filtrado.
    private(set) var duplicateGroups: [[TransactionItem]] = []
    /// «2 posibles duplicados en 1 grupo».
    private(set) var duplicateTally = RecordsDuplicateLogic.Tally(duplicates: 0, groups: 0)
    private var duplicateCandidateGroups: [[RecordsDuplicateLogic.Candidate<PersistentIdentifier>]] = []

    /// «Quitar repetidos»: lo que va a borrar, medido al tocar el botón (la confirmación lo cuenta).
    private(set) var duplicateRemovalPlan = RecordsDuplicateLogic.RemovalPlan<PersistentIdentifier>(
        toDelete: [], keptGroupRecords: 0
    )
    var isConfirmingDuplicateRemoval = false

    /// Sheet states
    var showFiltersSheet: Bool = false
    var showNewTransaction: Bool = false
    var showEditTransaction: Bool = false
    var showTransactionDetail: Bool = false
    var editingTransaction: TransactionItem?

    /// Difiere la limpieza de `editingTransaction` cuando el detalle cede el paso
    /// al editor (botón Editar): el detalle se cierra y el padre, en su `onDismiss`,
    /// consume este flag para presentar NewTransactionView con la misma TX.
    private var pendingEditAfterDetail = false

    /// Registro abierto en la columna de detalle (ventana ancha). Vive aquí, fuera del
    /// `NavigationSplitView`, para que sobreviva a un redimensionado: si la ventana se estrecha,
    /// el split se pliega y lo enseña empujado.
    var openRecordID: PersistentIdentifier?

    /// `true` cuando la vista que monta este VM tiene columna de detalle y la ventana es ancha.
    /// Lo escriben, con el size class de la ventana, `RecordsStandaloneView` (columna del split) y
    /// `DetailContainerView` (panel de Estadísticas › Registros). En compacta, la hoja de siempre.
    var opensDetailInColumn = false

    /// Menú contextual y teclado (iPad, fase 3): el editor se abre ya en modo «duplicar». Lo limpian los hosts al
    /// cerrarse el editor, junto con `editingTransaction`.
    var editorStartsAsDuplicate = false

    /// Menú contextual y ⌫: el registro que espera la confirmación de borrado.
    var pendingDeleteRecordID: PersistentIdentifier?
    var isConfirmingSingleDelete = false

    /// Menú contextual: el registro al que se le elige otra categoría.
    var categoryChangeRecord: TransactionItem?

    /// ↑↓: el día que enseña la vista calendario, si hay uno elegido. Lo escribe `RecordsTabView`, que es quien filtra
    /// la lista por él (`displayedGroups`); sin él, las flechas abrirían registros que no se ven.
    var keyboardDayFilter: Date?

    /// Mensaje de error surfaceado por `BulkEditSheet` cuando una operación bulk rechaza
    /// la mutación (e.g., subcategoría sobre transferencias).
    var bulkUpdateError: String?

    // MARK: - Computed Data

    /// Grouped records by date (pre-computed for performance)
    var groupedRecords: [(date: Date, records: [TransactionItem])] = []

    /// Proyección "mi parte" (neto) de los gastos de grupo bridgeados, construida en `applyFilters`
    /// desde el set AMPLIO. La consumen el chip de resumen y el calendario (DailySpendingCalculator).
    private(set) var statsAdjustment: GroupBridgeStatsAdjustment = .none

    /// Los tres números del resumen de Registros más la marca «≈» de cada uno.
    ///
    /// Era una tupla de tres `Double`. Pasa a struct al ganar las señales: seis elementos sin
    /// nombre en el punto de asignación es donde se cruzan dos campos del mismo tipo sin que
    /// nada se ponga rojo.
    struct RecordsSummary: Equatable {
        var balance: Double = 0
        var income: Double = 0
        var expense: Double = 0

        /// Las tres van **por lado**, igual que en `CashFlowSummary` y por el mismo motivo: la
        /// pantalla pinta los tres números por separado, y una señal única le pondría «≈» al
        /// total de ingresos por culpa de un gasto mal convertido.
        var incomeIsApproximate: Bool = false
        var expenseIsApproximate: Bool = false
        var balanceIsApproximate: Bool = false
    }

    /// Cached summary - updated when groupedRecords changes
    var recordsSummary = RecordsSummary()

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
        tags: [Tag],
        context: ModelContext,
        currencyCode: String,
        converter: CurrencyConverting = CurrencyConverter.shared
    ) {
        // Proyección "mi parte" desde el set AMPLIO (con AMBAS hermanas del bridge, antes de
        // cualquier filtro por cuenta/tag) — cierra el edge account-filter.
        statsAdjustment = GroupBridgeStatsAdjustment.build(from: transactions, context: context)
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

        // DIAG (caso "registro de grupo desaparece al clasificar"): cuántas TX bridgeadas
        // quedan visibles en el feed tras este refresh. Sin PII. Quitar tras QA.
        let bridgedVisible = groupedRecords.flatMap(\.records).filter {
            $0.splitExpenseID != nil || $0.splitSettlementID != nil
        }.count
        Self.diagLogger.info("recordsRefresh visibleBridged=\(bridgedVisible, privacy: .public) totalEligible=\(eligibleTransactions.count, privacy: .public) includeGroupTxs=\(includeGroupTxs, privacy: .public)")

        // "Identify duplicates" mode: post-filter the result to keep only records with
        // at least one potential duplicate (exact match over selected criteria). Runs on
        // the already-filtered set ("duplicates within what you're filtering"). Excludes
        // transfers/adjustments — their pair is legitimate, not a duplicate to delete.
        if duplicateModeActive && !duplicateCriteria.isEmpty {
            var recordsByID: [PersistentIdentifier: TransactionItem] = [:]
            let candidates = groupedRecords.flatMap(\.records).compactMap {
                tx -> RecordsDuplicateLogic.Candidate<PersistentIdentifier>? in
                guard tx.balanceAdjustmentType == nil else { return nil }
                recordsByID[tx.persistentModelID] = tx
                return .init(
                    id: tx.persistentModelID,
                    amount: tx.amount,
                    currencyCode: tx.currencyCode,
                    note: tx.note,
                    subcategoryID: tx.subcategory?.shortcutID.uuidString,
                    date: tx.date,
                    createdAt: tx.createdAt,
                    isDeletable: RecordBulkActionLogic.allows(.delete, .init(record: tx)),
                    tiebreak: tx.syncID?.uuidString ?? "",
                    accountID: tx.account?.shortcutID.uuidString
                )
            }
            // L8-11: los grupos de duplicados, cada uno junto y con el que se queda delante.
            let candidateGroups = RecordsDuplicateLogic.duplicateGroups(in: candidates, criteria: duplicateCriteria)
            duplicateCandidateGroups = candidateGroups
            duplicateGroups = candidateGroups.map { group in group.compactMap { recordsByID[$0.id] } }
            duplicateTally = RecordsDuplicateLogic.tally(candidateGroups)
            let dupIDs = Set(candidateGroups.flatMap { $0.map(\.id) })
            groupedRecords = groupedRecords.compactMap { group in
                let kept = group.records.filter { dupIDs.contains($0.persistentModelID) }
                return kept.isEmpty ? nil : (group.date, kept)
            }
        } else {
            duplicateCandidateGroups = []
            duplicateGroups = []
            duplicateTally = RecordsDuplicateLogic.Tally(duplicates: 0, groups: 0)
        }

        // Update cached summary (calculated once per filter change, not per render)
        calculateSummary(currencyCode: currencyCode, converter: converter)
    }

    /// Calculate summary from grouped records (called once when data changes)
    /// Balance = Income - Expense (excludes adjustments and transfers for consistency)
    ///
    /// `currencyCode` es la divisa principal en la que la pantalla pinta los tres números: cada
    /// importe se lleva a ella antes de sumar, con la misma regla que el Panel
    /// (`CashFlowCalculator.resolvedAmount`).
    private func calculateSummary(currencyCode: String, converter: CurrencyConverting) {
        var income: Double = 0
        var expense: Double = 0
        // Magnitudes sumadas (nunca netos) para el cociente de `ApproximateMarkThreshold`: los
        // errores de dos conversiones distintas no se cancelan entre sí. Mismo razonamiento que
        // el `exposedBase` de `FXPnLLogic` y que `CashFlowCalculator`.
        var incomeApproximateMagnitude: Double = 0
        var incomeTotalMagnitude: Double = 0
        var expenseApproximateMagnitude: Double = 0
        var expenseTotalMagnitude: Double = 0

        for group in groupedRecords {
            for record in group.records {
                guard let account = record.account else { continue }
                if account.excludeFromStatistics { continue }
                // Excluir patas de préstamo derivadas del bridge (préstamo a grupos).
                if statsAdjustment.isSuppressed(record) { continue }

                // Exclude balance adjustments and transfers from summary
                let isBalanceAdjustment = record.balanceAdjustmentType != nil
                if !isBalanceAdjustment {
                    // La categoría decide el bucket; acumulación signed (paridad
                    // con CashFlowCalculator): un monto de signo contrario a su
                    // categoría reduce el bucket (reembolso), no suma magnitud.
                    // `statsAdjustment` proyecta un gasto de grupo Caso A a "mi parte" (neto).
                    // Paridad con el Panel: el monto guardado solo vale si se guardó en ESTA divisa
                    // principal; si se guardó en otra (el usuario cambió de divisa y la fila aún no
                    // se recalculó), se reconvierte desde el nativo. La marca sale de la rama que
                    // decidió: el flag (vía `statsAdjustment`) o la calidad de la conversión.
                    let resolved = CashFlowCalculator.resolvedAmount(
                        record, currencyCode: currencyCode,
                        adjustment: statsAdjustment, converter: converter
                    )
                    let amount = resolved.value
                    let magnitude = abs(amount)
                    let approximate = resolved.approximateMagnitude
                    if TransactionClassificationLogic.isIncome(record) {
                        income += amount
                        incomeTotalMagnitude += magnitude
                        incomeApproximateMagnitude += approximate
                    } else {
                        expense -= amount
                        expenseTotalMagnitude += magnitude
                        expenseApproximateMagnitude += approximate
                    }
                }
            }
        }

        // Balance is simply the difference (cash flow)
        let newSummary = RecordsSummary(
            balance: income - expense,
            income: income,
            expense: expense,
            incomeIsApproximate: ApproximateMarkThreshold.marks(
                approximate: incomeApproximateMagnitude, total: incomeTotalMagnitude
            ),
            expenseIsApproximate: ApproximateMarkThreshold.marks(
                approximate: expenseApproximateMagnitude, total: expenseTotalMagnitude
            ),
            // El neto necesita su propio cociente y NO el OR de los dos lados: con umbrales por
            // lado, un ingreso grande con un 4,9 % dudoso y un gasto grande exacto pueden dejar
            // un neto pequeño con una incertidumbre mayor que él mismo, y saldría sin marca.
            balanceIsApproximate: ApproximateMarkThreshold.marks(
                approximate: incomeApproximateMagnitude + expenseApproximateMagnitude,
                total: income - expense
            )
        )
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

    /// Exit "identify duplicates" mode (ephemeral — also called on view/tab change)
    func exitDuplicateMode() {
        duplicateModeActive = false
    }

    /// «Quitar repetidos»: mide qué se borraría y pide la confirmación. Con un día elegido en el calendario, solo los
    /// grupos que se ven (los que tocan ese día): borrar repetidos de días que no están delante sorprende.
    func requestDuplicateRemoval(limitedToDay day: Date? = nil) {
        let groups = day.map { day in
            duplicateCandidateGroups.filter { group in group.contains { Calendar.current.isDate($0.date, inSameDayAs: day) } }
        } ?? duplicateCandidateGroups
        duplicateRemovalPlan = RecordsDuplicateLogic.removalPlan(groups)
        duplicateRemovalGroupIDs = Set(groups.flatMap { $0.map(\.id) })
        isConfirmingDuplicateRemoval = true
    }

    /// Los registros (todos, también los que se quedan) de los grupos medidos al pedir «Quitar repetidos».
    private var duplicateRemovalGroupIDs: Set<PersistentIdentifier> = []

    /// Al confirmar se vuelve a medir con lo que hay AHORA en el store: con la alerta abierta, otro dispositivo pudo
    /// borrar el que se queda o cambiarle la nota. Solo se borra lo que sigue repetido y con su registro de referencia
    /// vivo (revisión adversarial del lote 8).
    private func currentRemovalIDs(context: ModelContext) -> Set<PersistentIdentifier> {
        let planned = Set(duplicateRemovalPlan.toDelete)
        guard !planned.isEmpty, !duplicateCriteria.isEmpty else { return [] }
        let fresh = fetchTransactions(ids: duplicateRemovalGroupIDs, context: context).filter {
            !$0.isDeleted && $0.balanceAdjustmentType == nil
        }
        let candidates = fresh.map { tx in
            RecordsDuplicateLogic.Candidate(
                id: tx.persistentModelID,
                amount: tx.amount,
                currencyCode: tx.currencyCode,
                note: tx.note,
                subcategoryID: tx.subcategory?.shortcutID.uuidString,
                date: tx.date,
                createdAt: tx.createdAt,
                isDeletable: RecordBulkActionLogic.allows(.delete, .init(record: tx)),
                tiebreak: tx.syncID?.uuidString ?? "",
                accountID: tx.account?.shortcutID.uuidString
            )
        }
        let regrouped = RecordsDuplicateLogic.duplicateGroups(in: candidates, criteria: duplicateCriteria)
        return Set(RecordsDuplicateLogic.removalPlan(regrouped).toDelete).intersection(planned)
    }

    /// Borra los repetidos medidos al pedirlo, con el borrado de siempre (`deleteRecords`), que vuelve a dejar fuera lo
    /// de grupo y borra la pareja de una transferencia (los candidatos ya no llevan transferencias ni ajustes).
    func confirmDuplicateRemoval(context: ModelContext) {
        let ids = currentRemovalIDs(context: context)
        duplicateRemovalPlan = RecordsDuplicateLogic.RemovalPlan(toDelete: [], keptGroupRecords: 0)
        duplicateRemovalGroupIDs = []
        guard !ids.isEmpty else { return }
        deleteRecords(ids: ids, context: context)
        // La recarga llega por `dataVersion` (el host la difiere 150 ms). Mientras, la lista no puede seguir pintando
        // los registros borrados: se quitan ya de lo que se enseña.
        groupedRecords = groupedRecords.compactMap { group in
            let kept = group.records.filter { !ids.contains($0.persistentModelID) }
            return kept.isEmpty ? nil : (group.date, kept)
        }
        duplicateCandidateGroups = duplicateCandidateGroups
            .map { group in group.filter { !ids.contains($0.id) } }
            .filter { $0.count >= 2 }
        duplicateGroups = duplicateGroups
            .map { group in group.filter { !ids.contains($0.persistentModelID) } }
            .filter { $0.count >= 2 }
        duplicateTally = RecordsDuplicateLogic.tally(duplicateCandidateGroups)
    }

    /// Delete selected records (including transfer pairs)
    func deleteSelected(context: ModelContext) {
        deleteRecords(ids: selectedRecordIDs, context: context)
        exitSelectionMode()
    }

    /// Borra estos registros y, de las transferencias, también su pareja. Es el borrado del modo selección; el menú
    /// contextual y ⌫ lo usan con un solo id.
    func deleteRecords(ids: Set<PersistentIdentifier>, context: ModelContext) {
        // Collect transfer pair IDs from selected records
        var transferPairIDs: Set<String> = []
        var recordsToDelete: [TransactionItem] = []

        for id in ids {
            guard let record = context.model(for: id) as? TransactionItem else { continue }
            // Lo que viene de un grupo se borra desde el grupo (`RecordBulkActionLogic`). El guard va aquí, dentro del
            // único borrado de Registros, para que ningún camino —selección, menú, ⌫— pueda saltárselo.
            guard RecordBulkActionLogic.allows(.delete, .init(record: record)) else {
                #if DEBUG
                print("RecordsViewModel: registro de grupo fuera del borrado en lote")
                #endif
                continue
            }
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
                    for pair in pairs where !ids.contains(pair.persistentModelID) {
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
    }

    // MARK: - Menú contextual y teclado (iPad, fase 3)

    /// Duplicar desde el menú: el editor de siempre, que arranca ya convertido en un registro nuevo con los mismos
    /// datos y la fecha de hoy (`NewTransactionView(startsAsDuplicate:)`).
    func duplicateRecord(_ record: TransactionItem) {
        editorStartsAsDuplicate = true
        editingTransaction = record
        showEditTransaction = true
    }

    /// Eliminar desde el menú o con ⌫: primero la confirmación.
    func requestDelete(_ record: TransactionItem) {
        pendingDeleteRecordID = record.persistentModelID
        isConfirmingSingleDelete = true
    }

    func confirmPendingDelete(context: ModelContext) {
        guard let id = pendingDeleteRecordID else { return }
        pendingDeleteRecordID = nil
        deleteRecords(ids: [id], context: context)
    }

    /// ↑↓: abre en la columna el registro vecino del abierto, en el orden de la lista.
    func openNeighbor(_ direction: KeyboardCommandLogic.Direction) {
        let groups = keyboardDayFilter.map { day in
            groupedRecords.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
        } ?? groupedRecords
        let ids = groups.flatMap(\.records).map(\.persistentModelID)
        guard let next = KeyboardCommandLogic.neighbor(of: openRecordID, in: ids, direction: direction) else { return }
        openRecordID = next
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
    /// la edición se alcanza desde ahí con el botón Editar.
    func showRecordDetail(_ record: TransactionItem) {
        if opensDetailInColumn {
            openRecordID = record.persistentModelID
            return
        }
        editingTransaction = record
        showTransactionDetail = true
    }

    /// Editar desde la columna de detalle: el registro sigue abierto en su columna y el editor se
    /// presenta directo, sin el encadenado de la hoja (no hay hoja que cerrar antes).
    func editOpenRecord(_ record: TransactionItem) {
        editorStartsAsDuplicate = false
        editingTransaction = record
        showEditTransaction = true
    }

    /// Botón Editar del detalle: cierra el detalle (slide-down) sin perder la TX.
    /// El padre presenta NewTransactionView al recibir el `onDismiss` del detalle.
    func requestEditFromDetail() {
        pendingEditAfterDetail = true
        showTransactionDetail = false
    }

    /// Consume el flag en el `onDismiss` del detalle. `true` → presentar el editor
    /// (conservar la TX, sin recalcular); `false` → cierre normal del detalle.
    func consumePendingEditAfterDetail() -> Bool {
        defer { pendingEditAfterDetail = false }
        return pendingEditAfterDetail
    }

    // MARK: - Duplicar y Eliminar desde el detalle (auditoría UX 2.2, L8-4)

    /// Detalle › Eliminar, ya confirmado en el propio detalle. La hoja se cierra primero y el borrado corre en su
    /// `onDismiss` (`consumePendingDeleteAfterDetail`): así la hoja no repinta un registro que ya no existe.
    private var pendingDeleteAfterDetail: PersistentIdentifier?

    /// Detalle › Duplicar (hoja): se cierra el detalle y el editor sube ya como copia, por el mismo encadenado que
    /// Editar.
    func requestDuplicateFromDetail() {
        editorStartsAsDuplicate = true
        requestEditFromDetail()
    }

    func requestDeleteFromDetail(_ record: TransactionItem) {
        pendingDeleteAfterDetail = record.persistentModelID
        showTransactionDetail = false
    }

    /// En el `onDismiss` del detalle: borra lo que se pidió borrar desde él. `true` si había algo.
    func consumePendingDeleteAfterDetail(context: ModelContext) -> Bool {
        guard let id = pendingDeleteAfterDetail else { return false }
        pendingDeleteAfterDetail = nil
        deleteRecords(ids: [id], context: context)
        return true
    }

    /// Eliminar desde la columna o el panel de una ventana ancha: se cierra lo abierto y se borra.
    func deleteOpenRecord(_ record: TransactionItem, context: ModelContext) {
        let id = record.persistentModelID
        if openRecordID == id { openRecordID = nil }
        deleteRecords(ids: [id], context: context)
    }

    /// «Deshacer» del aviso tras cambiar la subcategoría desde el menú (L8-9): deja la subcategoría y la categoría que
    /// tenía. Directo y no por `updateSubcategory`, que no admite volver a «sin subcategoría».
    func restoreSubcategory(
        _ subcategory: Subcategory?,
        category: Category?,
        id: PersistentIdentifier,
        ifStillIs applied: Subcategory,
        context: ModelContext
    ) {
        do {
            // Un fetch y no `model(for:)`, que fabrica un objeto aunque el registro ya se haya borrado.
            var descriptor = FetchDescriptor<TransactionItem>(predicate: #Predicate { $0.persistentModelID == id })
            descriptor.fetchLimit = 1
            guard let transaction = try context.fetch(descriptor).first else { return }
            // Si en los segundos del aviso la subcategoría cambió por otro camino, Deshacer no pisa ese cambio.
            guard transaction.subcategory?.persistentModelID == applied.persistentModelID else { return }
            transaction.subcategory = subcategory
            transaction.category = category
            try context.save()
            SessionState.shared.incrementDataVersion()
        } catch {
            #if DEBUG
            print("RecordsViewModel: Error restoring subcategory: \(error)")
            #endif
        }
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
        if let blocker = accountBlocker(account, in: transactions) {
            bulkUpdateError = blocker
            return
        }
        for transaction in transactions {
            transaction.account = account
            transaction.currencyCode = account.currencyCode
            transaction.recalculatePreferredCurrency(context: context)
        }
        do {
            try commitBulkStep(context)
        } catch {
            bulkBatchFailed = true
            #if DEBUG
            print("RecordsViewModel: Error saving bulk account update: \(error)")
            #endif
        }
    }

    /// Update subcategory for all selected transactions.
    /// Bloqueado si la selección contiene transferencias — usan subcat sistema obligatoria.
    func bulkUpdateSubcategory(_ subcategory: Subcategory, context: ModelContext) {
        updateSubcategory(subcategory, ids: selectedRecordIDs, context: context)
    }

    /// El cambio de subcategoría del modo selección, para estos registros. El menú contextual lo usa con uno solo.
    func updateSubcategory(_ subcategory: Subcategory, ids: Set<PersistentIdentifier>, context: ModelContext) {
        let transactions = fetchTransactions(ids: ids, context: context)
        if let blocker = subcategoryBlocker(in: transactions) {
            bulkUpdateError = blocker
            return
        }
        for transaction in transactions {
            transaction.subcategory = subcategory
            transaction.category = subcategory.safeCategory
        }
        do {
            try commitBulkStep(context)
        } catch {
            bulkBatchFailed = true
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
        if let blocker = groupBlocker(.tags, in: transactions) {
            bulkUpdateError = blocker
            return
        }
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
            try commitBulkStep(context)
        } catch {
            bulkBatchFailed = true
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
        if let blocker = groupBlocker(.tags, in: transactions) {
            bulkUpdateError = blocker
            return
        }
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
            bulkBatchFailed = true
            #if DEBUG
            print("RecordsViewModel: Error applying bulk remove: \(error)")
            #endif
            return  // abort early — no save (preserva tags previos)
        }
        do {
            try commitBulkStep(context)
        } catch {
            bulkBatchFailed = true
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
        if let blocker = groupBlocker(.note, in: transactions) {
            bulkUpdateError = blocker
            return
        }
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
            try commitBulkStep(context)
        } catch {
            bulkBatchFailed = true
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
        if let blocker = amountBlocker(in: transactions, context: context) {
            bulkUpdateError = blocker
            return
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
            try commitBulkStep(context)
        } catch {
            bulkBatchFailed = true
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

    /// Si algún registro viene de un grupo y en esta operación manda el grupo, avisa y no se toca ninguno: el mismo
    /// molde que el bloqueo de las transferencias (todo o nada, nunca a medias).
    private func groupBlocker(_ operation: RecordBulkActionLogic.Operation, in transactions: [TransactionItem]) -> String? {
        guard transactions.contains(where: { !RecordBulkActionLogic.allows(operation, .init(record: $0)) }) else {
            return nil
        }
        return L10n.BulkEdit.cannotEditGroupRecords
    }

    // MARK: - Bloqueos de «Editar varios» (uno por operación)
    //
    // Cada operación en lote y la comprobación previa de `bulkEditBlocker` leen la MISMA regla: si se copiaran, la
    // hoja podría ofrecer «Aplicar» para algo que la operación luego rechaza a medias.

    private func accountBlocker(_ account: Account, in transactions: [TransactionItem]) -> String? {
        if transactions.contains(where: { $0.balanceAdjustmentType == TransactionItem.adjustmentTypeTransfer }) {
            return L10n.BulkEdit.cannotEditTransferAccount
        }
        if let blocker = groupBlocker(.account, in: transactions) { return blocker }
        // Y aunque el caso A deje cambiar la cuenta, no a una de OTRA divisa: el editor tampoco lo ofrece
        // (`currencyFilter`), porque el puente de grupos exige la divisa del gasto y, si no casa, borra el registro y
        // lo devuelve como borrador al siguiente re-puente (`GroupTransactionBridge`, `.currencyChanged`).
        let destination = normalizeCurrencyCode(account.currencyCode)
        if transactions.contains(where: {
            ($0.splitExpenseID != nil || $0.splitSettlementID != nil) && normalizeCurrencyCode($0.currencyCode) != destination
        }) {
            return L10n.BulkEdit.cannotEditGroupRecords
        }
        return nil
    }

    private func subcategoryBlocker(in transactions: [TransactionItem]) -> String? {
        if transactions.contains(where: { $0.balanceAdjustmentType == TransactionItem.adjustmentTypeTransfer }) {
            return L10n.BulkEdit.cannotEditTransferSubcategory
        }
        return groupBlocker(.subcategory, in: transactions)
    }

    /// Preserve exchange rate: bloquear bulk-edit en transfers cross-currency.
    private func amountBlocker(in transactions: [TransactionItem], context: ModelContext) -> String? {
        for tx in transactions {
            if let partner = TransferPartnerLookup.partnerSkipIfAmbiguous(of: tx, in: context),
               tx.currencyCode != partner.currencyCode {
                return L10n.BulkEdit.cannotEditTransferAmountCrossCurrency
            }
        }
        return groupBlocker(.amount, in: transactions)
    }

    // MARK: - «Editar varios»: elegir primero, aplicar después (UX 2.2 · L8-13)

    /// Los registros elegidos, para que la hoja enseñe qué tienen hoy.
    func selectedTransactions(context: ModelContext) -> [TransactionItem] {
        getSelectedTransactions(context: context)
    }

    /// Por qué no se puede aplicar lo pendiente, o `nil`. Mira todas las operaciones antes de tocar nada: así
    /// «Aplicar» es todo o nada, como cada operación por separado (el molde del bloqueo de transferencias).
    func bulkEditBlocker(_ changes: BulkEditChanges, context: ModelContext) -> String? {
        let transactions = getSelectedTransactions(context: context)
        if changes.subcategory != nil, let blocker = subcategoryBlocker(in: transactions) { return blocker }
        if let account = changes.account, let blocker = accountBlocker(account, in: transactions) { return blocker }
        if !changes.tagsToAdd.isEmpty || !changes.tagsToRemove.isEmpty,
           let blocker = groupBlocker(.tags, in: transactions) {
            return blocker
        }
        if changes.note != nil, let blocker = groupBlocker(.note, in: transactions) { return blocker }
        if changes.amount != nil, let blocker = amountBlocker(in: transactions, context: context) { return blocker }
        return nil
    }

    /// Aplica todo lo pendiente de una vez. Si algo está bloqueado no aplica nada, deja el motivo en
    /// `bulkUpdateError` y devuelve `false`.
    ///
    /// Orden: categoría, cuenta, etiquetas, nota y, al final, el monto, que recalcula la divisa principal con la
    /// cuenta ya cambiada.
    @discardableResult
    func applyBulkEdit(_ changes: BulkEditChanges, context: ModelContext) -> Bool {
        if let blocker = bulkEditBlocker(changes, context: context) {
            bulkUpdateError = blocker
            return false
        }
        bulkUpdateError = nil
        // Todo o nada también ante un fallo del store (revisión adversarial del lote 8): los pasos no guardan cada uno
        // por su cuenta; se guarda una vez al final, y si un paso falla o se bloquea, se deshace lo que ya se tocó.
        isBatchingBulkEdit = true
        bulkBatchFailed = false
        defer { isBatchingBulkEdit = false }
        if let subcategory = changes.subcategory { bulkUpdateSubcategory(subcategory, context: context) }
        if let account = changes.account { bulkUpdateAccount(account, context: context) }
        if !changes.tagsToAdd.isEmpty { bulkAddTags(changes.tagsToAdd, context: context) }
        if !changes.tagsToRemove.isEmpty { bulkRemoveTags(changes.tagsToRemove, context: context) }
        if let note = changes.note { bulkUpdateNote(note, context: context) }
        if let amount = changes.amount { bulkUpdateAmount(amount, context: context) }
        guard bulkUpdateError == nil, !bulkBatchFailed else {
            context.rollback()
            if bulkUpdateError == nil { bulkUpdateError = L10n.UXL8.bulkSaveFailed }
            return false
        }
        do {
            try context.save()
            SessionState.shared.incrementDataVersion()
        } catch {
            #if DEBUG
            print("RecordsViewModel: Error saving bulk edit: \(error)")
            #endif
            context.rollback()
            bulkUpdateError = L10n.UXL8.bulkSaveFailed
            return false
        }
        return true
    }

    /// `applyBulkEdit` en curso: los pasos no guardan (lo hace él al final, una vez).
    private var isBatchingBulkEdit = false
    /// Algún paso de `applyBulkEdit` falló contra el store (lectura o guardado).
    private var bulkBatchFailed = false

    /// El guardado de un paso de edición en lote: suelto, guarda y avisa; dentro de `applyBulkEdit`, espera al final.
    private func commitBulkStep(_ context: ModelContext) throws {
        guard !isBatchingBulkEdit else { return }
        try context.save()
        SessionState.shared.incrementDataVersion()
    }

    /// Lo que dice la confirmación del borrado en lote. Se mide al tocar la papelera (`prepareBulkDelete`), no en cada
    /// repintado del diálogo: con «Seleccionar todo» serían miles de búsquedas por pasada.
    var bulkDeleteDialog = RecordBulkActionLogic.deleteDialog(deletable: 0, groupRecords: 0)

    func prepareBulkDelete(context: ModelContext) {
        bulkDeleteDialog = selectionDeleteDialog(context: context)
    }

    /// La confirmación del borrado en lote: cuántos de los elegidos se borran y cuántos se quedan por venir de un grupo.
    func selectionDeleteDialog(context: ModelContext) -> RecordBulkActionLogic.DeleteDialog {
        let selected = getSelectedTransactions(context: context)
        let groupRecords = selected.filter { !RecordBulkActionLogic.allows(.delete, .init(record: $0)) }.count
        return RecordBulkActionLogic.deleteDialog(deletable: selected.count - groupRecords, groupRecords: groupRecords)
    }

    /// Helper to fetch selected transactions from context
    private func getSelectedTransactions(context: ModelContext) -> [TransactionItem] {
        fetchTransactions(ids: selectedRecordIDs, context: context)
    }

    private func fetchTransactions(ids: Set<PersistentIdentifier>, context: ModelContext) -> [TransactionItem] {
        var transactions: [TransactionItem] = []
        for id in ids {
            if let transaction = context.model(for: id) as? TransactionItem {
                transactions.append(transaction)
            }
        }
        return transactions
    }
}

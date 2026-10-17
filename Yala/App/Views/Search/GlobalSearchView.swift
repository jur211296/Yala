//
//  GlobalSearchView.swift
//  Yala
//
//  Extracted from ContentView.swift — search tab functionality.
//

import SwiftData
import SwiftUI

// MARK: - Global Search View

struct GlobalSearchView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(SessionState.self) private var sessionState
    @Environment(SceneNavigation.self) private var navigation

    @State private var searchText: String = ""
    @State private var isSearchActive: Bool = false
    @State private var isDataReady: Bool = false

    // Load data here to avoid glitch during search activation
    @Query(sort: \TransactionItem.date, order: .reverse) private var allTransactions:
        [TransactionItem]

    var body: some View {
        NavigationStack {
            ZStack {
                if isDataReady {
                    SearchContentView(searchText: $searchText, transactions: allTransactions)
                } else {
                    // Loading state - subtle animation
                    VStack(spacing: DS.Spacing.lg) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text(L10n.Common.loading)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .yalaScreenBackground()
            .navigationTitle(L10n.Common.search)
            .navigationBarTitleDisplayMode(.large)
        }
        .searchable(
            text: $searchText,
            isPresented: $isSearchActive,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: L10n.Common.search
        )
        .task {
            // Delay to let Query load, then reveal content smoothly
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                // Task cancelled - continue with animation anyway
            }
            await MainActor.run {
                dsWithAnimation(reduceMotion, .easeIn(duration: 0.2)) {
                    isDataReady = true
                }
                isSearchActive = true
            }
        }
        // ⌘F (iPad con teclado): enfoca el campo aunque Buscar ya estuviera delante.
        .onChange(of: navigation.keyboardSearchRequest) { _, _ in isSearchActive = true }
    }
}

// MARK: - Search Content View

struct SearchContentView: View {
    @Environment(\.yalaTheme) private var theme
    @Environment(SessionState.self) private var sessionState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.tagCatalog) private var tagCatalog
    @Environment(\.modelContext) private var modelContext
    @Binding var searchText: String
    let transactions: [TransactionItem]  // Passed from parent

    @State private var selectedFilter: SearchFilter = .all
    /// Un resultado abre su detalle, como en Registros (UX 2.2 · L8-14); antes abría el editor directo.
    @State private var detailTransaction: TransactionItem?
    /// El registro del detalle mientras Editar o Duplicar esperan a que la hoja termine de cerrarse.
    @State private var recordAwaitingEditor: TransactionItem?
    /// «Editar» en el detalle: el detalle baja y, en su `onDismiss`, sube el editor con el mismo registro. Es el
    /// encadenado de Registros (`RecordsViewModel.requestEditFromDetail`), con estado propio de Buscar: nunca dos
    /// presentaciones a la vez desde el mismo anchor.
    @State private var editingTransaction: TransactionItem?
    /// Duplicar y Eliminar al pie del detalle, como en Registros (L8-4): por el mismo encadenado que Editar.
    @State private var editorStartsAsDuplicate = false
    @State private var pendingDeleteAfterDetail: TransactionItem?
    /// «Ver todos» despliega aquí mismo todo lo que contó el encabezado. Antes llevaba a Estadísticas › Registros con
    /// el texto como filtro de nota, que solo mira la nota: «Restaurantes» contaba 204 resultados (por categoría) y
    /// allí no salía ninguno; además dejaba el período de toda la app en «Todo» (auditoría UX 2.2, lote 8).
    @State private var showsAllResults = false

    // MARK: - Filtered Results

    private func matchesSearch(_ transaction: TransactionItem, lowercasedSearch: String, filter: SearchFilter) -> Bool {
        switch filter {
        case .all:
            let noteMatch = transaction.note?.lowercased().contains(lowercasedSearch) ?? false
            let categoryMatch = transaction.category?.name.lowercased().contains(lowercasedSearch) ?? false
            let subcategoryMatch = transaction.subcategory?.name.lowercased().contains(lowercasedSearch) ?? false
            let accountMatch = transaction.account?.name.lowercased().contains(lowercasedSearch) ?? false
            let tagMatch = matchesTagName(transaction: transaction, lowercasedSearch: lowercasedSearch)
            return noteMatch || categoryMatch || subcategoryMatch || accountMatch || tagMatch
        case .note:
            return transaction.note?.lowercased().contains(lowercasedSearch) ?? false
        case .category:
            return transaction.category?.name.lowercased().contains(lowercasedSearch) ?? false
        case .subcategory:
            return transaction.subcategory?.name.lowercased().contains(lowercasedSearch) ?? false
        case .account:
            return transaction.account?.name.lowercased().contains(lowercasedSearch) ?? false
        case .need:
            return transaction.subcategory?.need.displayName.lowercased().contains(lowercasedSearch) ?? false
        case .tag:
            return matchesTagName(transaction: transaction, lowercasedSearch: lowercasedSearch)
        }
    }

    /// CSV-mirror SSOT: resuelve UUIDs vía catalog → Tag.name lowercased contains query.
    /// Sobrevive lazy hydration de la M2M `tx.tags` durante cold launch.
    private func matchesTagName(transaction: TransactionItem, lowercasedSearch: String) -> Bool {
        let txTagIDs = transaction.resolvedTagIDs(scheduleBackfill: true) ?? []
        return txTagIDs.contains { uuid in
            tagCatalog[uuid]?.name.lowercased().contains(lowercasedSearch) ?? false
        }
    }

    private var baseTransactions: [TransactionItem] {
        sessionState.isExpensesOnlyMode
            ? transactions.filter { $0.category?.isIncome != true }
            : transactions
    }

    private var matchingTransactions: [TransactionItem] {
        guard !searchText.isEmpty else { return baseTransactions }
        let lowercased = searchText.lowercased()
        return baseTransactions.filter { matchesSearch($0, lowercasedSearch: lowercased, filter: selectedFilter) }
    }

    private var filteredResults: [TransactionItem] {
        SearchResultsLogic.visible(matchingTransactions, showsAll: showsAllResults)
    }

    // Total count for "Ver todo" (without limit)
    private var totalMatchingCount: Int {
        matchingTransactions.count
    }

    // MARK: - Grouped Results by Date

    private var groupedResults: [(date: Date, records: [TransactionItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredResults) { record in
            calendar.startOfDay(for: record.date)
        }
        return grouped.sorted { $0.key > $1.key }
            .map { (date: $0.key, records: $0.value.sorted { $0.createdAt > $1.createdAt }) }
    }

    var body: some View {
        VStack(spacing: DS.Spacing.none) {
            // Filter chips (only show when searching)
            if !searchText.isEmpty {
                filterChipsBar
                    .padding(.top, DS.Spacing.sm)
            }

            // Always show results (all or filtered)
            searchResultsView
        }
        .onChange(of: searchText) { showsAllResults = false }
        .onChange(of: selectedFilter) { showsAllResults = false }
        // `item:` y no `isPresented:` + un `@State` aparte: el `body` no lee ese estado fuera del cierre de la hoja, así
        // que el cierre se quedaba con el valor viejo (nil) y la hoja salía vacía (medido en el simulador el 17-oct).
        .sheet(item: $detailTransaction, onDismiss: handleDetailDismiss) { transaction in
            TransactionDetailSheet(
                transaction: transaction,
                onEdit: { requestEditFromDetail(transaction) },
                onDuplicate: {
                    editorStartsAsDuplicate = true
                    requestEditFromDetail(transaction)
                },
                onDelete: {
                    pendingDeleteAfterDetail = transaction
                    detailTransaction = nil
                }
            )
        }
        .sheet(item: $editingTransaction, onDismiss: { editorStartsAsDuplicate = false }) { transaction in
            NewTransactionView(transactionToEdit: transaction, startsAsDuplicate: editorStartsAsDuplicate)
                .presentationDetents([.large])
        }
    }

    // MARK: - Detalle → Editar (UX 2.2 · L8-14)

    private func openDetail(_ record: TransactionItem) {
        detailTransaction = record
    }

    /// Botón Editar (o Duplicar) del detalle: lo cierra sin perder el registro; el editor sube en `handleDetailDismiss`.
    private func requestEditFromDetail(_ record: TransactionItem) {
        recordAwaitingEditor = record
        detailTransaction = nil
    }

    private func handleDetailDismiss() {
        if let record = recordAwaitingEditor {
            recordAwaitingEditor = nil
            editingTransaction = record
        }
        // Eliminar desde el detalle, ya confirmado en él: con la hoja cerrada, por el mismo borrado que Registros
        // (respeta lo de grupo y borra la pareja de una transferencia).
        if let record = pendingDeleteAfterDetail {
            pendingDeleteAfterDetail = nil
            RecordsViewModel().deleteRecords(ids: [record.persistentModelID], context: modelContext)
        }
    }

    // MARK: - Filter Chips Bar

    private var filterChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(SearchFilter.allCases) { filter in
                    filterChip(for: filter)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
        }
    }

    private func filterChip(for filter: SearchFilter) -> some View {
        let isSelected = selectedFilter == filter

        return Button {
            dsWithAnimation(reduceMotion, .easeInOut(duration: 0.2)) {
                selectedFilter = filter
            }
        } label: {
            Text(filter.displayName)
                .font(DS.Typography.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(
                    Group {
                        if isSelected {
                            Capsule().fill(theme.accent)
                        } else {
                            Capsule().fill(.clear).glassEffect(.regular.interactive(), in: .capsule)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(filter.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Search Results

    private var searchResultsView: some View {
        ScrollView {
            // Sin cabeceras fijas: fijadas, la fecha se montaba sobre la primera fila sin fondo, y un fondo propio no
            // casa con el degradado de la pantalla (L8-14). La fecha se va con su día al desplazarse.
            LazyVStack(spacing: DS.Spacing.none) {
                // Encabezado: sin texto, «Recientes»; con texto, el número de resultados y «Ver todos».
                if !filteredResults.isEmpty {
                    HStack {
                        Text(SearchResultsLogic.headerLabel(searchText: searchText, total: totalMatchingCount))
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityIdentifier("search_results_header")

                        Spacer()

                        if !searchText.isEmpty,
                           SearchResultsLogic.offersShowAll(total: totalMatchingCount, showsAll: showsAllResults) {
                            Button {
                                dsWithAnimation(reduceMotion, .easeInOut(duration: 0.2)) {
                                    showsAllResults = true
                                }
                            } label: {
                                HStack(spacing: DS.Spacing.xs) {
                                    Text(L10n.Action.viewAll)
                                    Image(systemName: "chevron.down")
                                }
                                .font(DS.Typography.label)
                                .foregroundStyle(theme.accent)
                            }
                            .accessibilityIdentifier("search_view_all")
                        }
                    }
                    // Al borde de las tarjetas, como la fecha de cada día (en Registros la fecha va a ese borde).
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.sm)
                    .padding(.bottom, DS.Spacing.md)
                }

                // Grouped results by date — la misma fila y la misma fecha que Registros (L8-14).
                ForEach(groupedResults, id: \.date) { group in
                    Section {
                        ForEach(group.records, id: \.persistentModelID) { record in
                            RecordRowView(
                                record: record,
                                currencyCode: appPreferences.defaultCurrencyCode.rawValue,
                                isSelectionMode: false,
                                isSelected: false,
                                onTap: { openDetail(record) },
                                onToggleSelection: {}
                            )
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.vertical, DS.Spacing.xs)
                        }
                    } header: {
                        RecordDateSectionView(
                            date: group.date,
                            includesYear: SearchResultsLogic.headerIncludesYear(group.date)
                        )
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.top, DS.Spacing.sm)
                    }
                }

                // No results message
                if filteredResults.isEmpty && !searchText.isEmpty {
                    YalaEmptyState.noResults()
                        .padding(.top, DS.Spacing.xxxl)
                } else if filteredResults.isEmpty && searchText.isEmpty {
                    YalaEmptyState.noTransactions()
                        .padding(.top, DS.Spacing.xxxl)
                }
            }
            .padding(.bottom, DS.Spacing.xl)
        }
        .scrollDismissesKeyboard(.immediately)
    }
}

// MARK: - Search Filter Enum

enum SearchFilter: String, CaseIterable, Identifiable {
    case all
    case note
    case category
    case subcategory
    case account
    case need
    case tag

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return L10n.Search.Filter.all
        case .note: return L10n.Search.Filter.note
        case .category: return L10n.Search.Filter.category
        case .subcategory: return L10n.Search.Filter.subcategory
        case .account: return L10n.Search.Filter.account
        case .need: return L10n.Search.Filter.need
        case .tag: return L10n.Search.Filter.tag
        }
    }
}

#Preview {
    GlobalSearchView()
        .environment(SceneNavigation())
        .modelContainer(
            for: [
                TransactionItem.self,
                Category.self,
                Subcategory.self,
                Tag.self,
            ], inMemory: true)
        .previewAppPreferences()
}

// MARK: - Search Results Logic

/// Cuántos resultados enseña Buscar. Sin «Ver todos», los 20 más recientes; con él, todos los que cuenta el
/// encabezado, para que la cifra y la lista digan lo mismo.
enum SearchResultsLogic {
    static let previewLimit = 20

    static func visible<T>(_ matches: [T], showsAll: Bool) -> [T] {
        showsAll ? matches : Array(matches.prefix(previewLimit))
    }

    /// «Ver todos» solo cuando hay más de los que se ven.
    static func offersShowAll(total: Int, showsAll: Bool) -> Bool {
        !showsAll && total > previewLimit
    }

    /// Sin texto, Buscar enseña los últimos registros: el encabezado lo dice («Recientes») en vez de dejarlos sin
    /// nombre. Con texto, cuántos resultados hay (UX 2.2 · L8-14).
    static func headerLabel(searchText: String, total: Int) -> String {
        searchText.isEmpty ? L10n.UXL8C.searchRecent : L10n.Search.resultsCount(total)
    }

    /// La fecha de cada día es la de Registros («14 de octubre»); como Buscar recorre todos los años, un día de otro
    /// año lleva el año.
    static func headerIncludesYear(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
        !calendar.isDate(date, equalTo: now, toGranularity: .year)
    }
}

//
//  DetailContainerView.swift
//  Neto
//
//  Unified container for Trends, Categories, and Records with shared navigation.
//  Located in Statistics as it's the primary drill-down view from the Statistics tab.
//

import SwiftData
import SwiftUI

// MARK: - Detail Container View

/// Unified container view providing chip-based navigation between Trends, Categories, and Records.
/// Uses extracted TrendsTabView and CategoriesTabView components for their respective content.
struct DetailContainerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(SessionState.self) private var sessionState

    // MARK: - Data Queries

    @Query(sort: \TransactionItem.date, order: .reverse)
    private var allTransactions: [TransactionItem]

    @Query(sort: \Account.name) private var accounts: [Account]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Tag.name) private var tags: [Tag]

    // MARK: - ViewModels

    @State private var recordsViewModel: RecordsViewModel
    @State private var trendsViewModel: StatisticsViewModel

    // MARK: - Navigation State

    @State private var selectedTab: DetailViewTab = .records

    // MARK: - UI State

    @State private var showDeleteConfirmation = false
    @State private var showMultiEditPlaceholder = false
    @State private var isPresentingSettings = false

    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = CurrencyCode.pen
        .rawValue

    // MARK: - Initialization

    init(context: RecordsFilterContext = .empty, initialTab: DetailViewTab = .records) {
        var cleanContext = context
        cleanContext.period = .thisMonth
        cleanContext.accountID = nil
        cleanContext.categoryID = nil
        cleanContext.nature = nil
        _recordsViewModel = State(initialValue: RecordsViewModel(context: cleanContext))

        let trendsContext = StatisticsContext(
            initialMetric: .balance,
            period: .thisMonth,
            accountID: nil,
            categoryID: nil,
            subcategoryName: nil,
            nature: nil,
            dateInterval: nil
        )
        _trendsViewModel = State(initialValue: StatisticsViewModel(context: trendsContext))
        _selectedTab = State(initialValue: initialTab)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            PanelBackgroundView()

            VStack(spacing: 0) {
                // Navigation Chips (always visible)
                navigationChipsBar
                    .padding(.vertical, 8)

                // Content based on selected tab - using extracted components
                Group {
                    switch selectedTab {
                    case .trends:
                        TrendsTabView(
                            trendsViewModel: trendsViewModel,
                            defaultCurrencyCode: defaultCurrencyCode,
                            onNavigateToRecords: { selectedTab = .records }
                        )
                    case .categories:
                        CategoriesTabView()
                    case .records:
                        recordsContentView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Floating Action Button for new record (only for Records)
            if selectedTab == .records && !recordsViewModel.isSelectionMode {
                newRecordFAB
            }

            // Selection action bar
            if recordsViewModel.isSelectionMode && !recordsViewModel.selectedRecordIDs.isEmpty {
                selectionActionBar
            }
        }
        .toolbar {
            if recordsViewModel.isSelectionMode {
                selectionModeToolbar
            } else {
                normalModeToolbar
            }
        }
        .navigationBarBackButtonHidden(recordsViewModel.isSelectionMode)
        .tint(.primary)
        .sheet(isPresented: $recordsViewModel.showFiltersSheet) {
            RecordsFiltersView(viewModel: recordsViewModel)
                .onDisappear {
                    refreshRecordsData()
                }
        }
        .sheet(isPresented: $recordsViewModel.showNewTransaction) {
            NewTransactionView()
                .onDisappear {
                    refreshRecordsData()
                }
        }
        .sheet(isPresented: $recordsViewModel.showEditTransaction) {
            if let transaction = recordsViewModel.editingTransaction {
                NewTransactionView(transactionToEdit: transaction)
                    .onDisappear {
                        recordsViewModel.editingTransaction = nil
                        refreshRecordsData()
                    }
            }
        }
        .sheet(isPresented: $trendsViewModel.showFiltersSheet) {
            // Use RecordsFiltersView since filters are synchronized between tabs
            RecordsFiltersView(viewModel: recordsViewModel)
                .onDisappear {
                    syncFiltersToTrends()
                    calculateTrendsData()
                }
        }
        .confirmationDialog(
            "¿Eliminar \(recordsViewModel.selectedRecordIDs.count) registro(s)?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                recordsViewModel.deleteSelected(context: modelContext)
                refreshRecordsData()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
        .alert("Edición múltiple", isPresented: $showMultiEditPlaceholder) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text("La edición múltiple estará disponible próximamente.")
        }
        .sheet(isPresented: $isPresentingSettings) {
            ProfileView()
        }
        .onRecordsFilterChange(viewModel: recordsViewModel) {
            refreshRecordsData()
            syncFiltersToTrends()
            syncToSessionState()
        }
        .onTrendsFilterChange(viewModel: trendsViewModel) {
            calculateTrendsData()
            syncFiltersToRecords()
            syncToSessionState()
        }
        .onAppear {
            syncFromSessionState()
            refreshRecordsData()
            calculateTrendsData()
        }
        .onChange(of: sessionState.selectedPeriod) {
            syncFromSessionState()
        }
        .onChange(of: sessionState.selectedAccountIDs) {
            syncFromSessionState()
            calculateTrendsData()
            refreshRecordsData()
        }
        .onChange(of: sessionState.selectedCategoryIDs) {
            syncFromSessionState()
            calculateTrendsData()
            refreshRecordsData()
        }
        .onChange(of: sessionState.selectedNatures) {
            syncFromSessionState()
            calculateTrendsData()
            refreshRecordsData()
        }
        .onChange(of: trendsViewModel.selectedMetric) { _, _ in
            calculateTrendsData()
        }
        .onChange(of: trendsViewModel.isAggregatedView) { _, _ in
            calculateTrendsData()
        }
        .onChange(of: trendsViewModel.detailPeriod) { _, _ in
            calculateTrendsData()
        }
        .onChange(of: recordsViewModel.searchText) {
            refreshRecordsData()
        }
    }

    // MARK: - Navigation Chips Bar

    private var navigationChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DetailViewTab.allCases) { tab in
                    navigationChipButton(for: tab)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func navigationChipButton(for tab: DetailViewTab) -> some View {
        let isSelected = selectedTab == tab

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.subheadline)
                Text(tab.rawValue)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(
                Capsule()
                    .fill(isSelected ? Color.electricIndigo : Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(Color.netoSecondaryText.opacity(0.2), lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Normal Mode Toolbar

    @ToolbarContentBuilder
    private var normalModeToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 16) {
                // Selection button (only for Records)
                if selectedTab == .records {
                    Button {
                        recordsViewModel.enterSelectionMode()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.electricIndigo)
                    }
                }

                // Filters button
                Button {
                    if selectedTab == .records {
                        recordsViewModel.showFiltersSheet = true
                    } else {
                        trendsViewModel.showFiltersSheet = true
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.electricIndigo)
                }
                .overlay(alignment: .topTrailing) {
                    if selectedTab == .records && recordsViewModel.activeFilterCount > 0 {
                        Circle()
                            .fill(Color.hotPink)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                    }
                }

                // Profile button
                Button {
                    isPresentingSettings = true
                } label: {
                    Image(systemName: "person.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.electricIndigo)
                }
            }
        }
    }

    // MARK: - Selection Mode Toolbar

    @ToolbarContentBuilder
    private var selectionModeToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancelar") {
                recordsViewModel.exitSelectionMode()
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button("Seleccionar todo") {
                recordsViewModel.selectAll()
            }
        }
    }

    // MARK: - Records Content

    private var recordsContentView: some View {
        VStack(spacing: 0) {
            recordsControlBar
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

            if recordsViewModel.groupedRecords.isEmpty {
                emptyRecordsState
            } else {
                recordsList
            }
        }
    }

    private var recordsControlBar: some View {
        HStack(spacing: 12) {
            recordsPeriodSelector

            if recordsViewModel.hasActiveFilters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if let chipText = accountsChipText(for: recordsViewModel.selectedAccounts) {
                            FilterChipView(text: chipText) {
                                recordsViewModel.selectedAccounts.removeAll()
                                refreshRecordsData()
                            }
                        }

                        if let chipText = categoriesChipText(
                            categories: recordsViewModel.selectedCategories,
                            subcategories: recordsViewModel.selectedSubcategories
                        ) {
                            FilterChipView(text: chipText) {
                                recordsViewModel.selectedCategories.removeAll()
                                recordsViewModel.selectedSubcategories.removeAll()
                                refreshRecordsData()
                            }
                        }

                        if let chipText = tagsChipText(for: recordsViewModel.selectedTags) {
                            FilterChipView(text: chipText) {
                                recordsViewModel.selectedTags.removeAll()
                                refreshRecordsData()
                            }
                        }

                        if let chipText = naturesChipText(for: recordsViewModel.selectedNatures) {
                            FilterChipView(text: chipText) {
                                recordsViewModel.selectedNatures.removeAll()
                                refreshRecordsData()
                            }
                        }

                        if recordsViewModel.transactionTypeFilter != .all {
                            FilterChipView(text: recordsViewModel.transactionTypeFilter.displayName)
                            {
                                recordsViewModel.transactionTypeFilter = .all
                                refreshRecordsData()
                            }
                        }

                        if recordsViewModel.activeFilterCount > 1 {
                            Button {
                                withAnimation {
                                    recordsViewModel.clearFilters()
                                    refreshRecordsData()
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Spacer()
        }
        .animation(nil, value: recordsViewModel.period)
    }

    private var recordsPeriodSelector: some View {
        TrendsPeriodMenu(
            selectedPeriod: recordsViewModel.period,
            onSelect: { period in
                withTransaction(Transaction(animation: nil)) {
                    recordsViewModel.period = period
                }
            }
        )
        .equatable()
    }

    private var recordsList: some View {
        ScrollView {
            LazyVStack(spacing: 8, pinnedViews: [.sectionHeaders]) {
                ForEach(recordsViewModel.groupedRecords, id: \.date) { group in
                    Section {
                        ForEach(group.records, id: \.persistentModelID) { record in
                            RecordRowView(
                                record: record,
                                currencyCode: defaultCurrencyCode,
                                isSelectionMode: recordsViewModel.isSelectionMode,
                                isSelected: recordsViewModel.selectedRecordIDs.contains(
                                    record.persistentModelID),
                                onTap: {
                                    recordsViewModel.editRecord(record)
                                },
                                onToggleSelection: {
                                    recordsViewModel.toggleSelection(record.persistentModelID)
                                }
                            )
                            .padding(.horizontal, 16)
                        }
                    } header: {
                        RecordDateSectionView(date: group.date)
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, recordsViewModel.isSelectionMode ? 80 : 100)
        }
    }

    private var emptyRecordsState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "list.bullet.rectangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary.opacity(0.5))

            Text("No hay registros")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Text(
                recordsViewModel.hasActiveFilters
                    ? "No se encontraron registros con los filtros aplicados."
                    : "Cuando registres movimientos, aparecerán aquí."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)

            if recordsViewModel.hasActiveFilters {
                Button {
                    recordsViewModel.clearFilters()
                    refreshRecordsData()
                } label: {
                    Text("Limpiar filtros")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.electricIndigo)
                }
                .padding(.top, 8)
            }

            Spacer()
        }
    }

    // MARK: - Chip Text Helpers

    private func accountsChipText(for selectedIDs: Set<PersistentIdentifier>) -> String? {
        guard !selectedIDs.isEmpty else { return nil }
        let selectedNames = accounts.filter { selectedIDs.contains($0.persistentModelID) }.map {
            $0.name
        }
        guard !selectedNames.isEmpty else { return nil }
        if selectedNames.count == 1 {
            return selectedNames.first
        }
        return "\(selectedNames.first ?? "") +\(selectedNames.count - 1)"
    }

    private func categoriesChipText(
        categories: Set<PersistentIdentifier>,
        subcategories: Set<PersistentIdentifier>
    ) -> String? {
        var names: [String] = []
        for cat in self.categories where categories.contains(cat.persistentModelID) {
            names.append(cat.name)
        }
        guard !names.isEmpty || !subcategories.isEmpty else { return nil }

        let totalCount = categories.count + subcategories.count
        if totalCount == 1 {
            return names.first ?? "Categoría"
        }
        return "\(names.first ?? "Categorías") +\(totalCount - 1)"
    }

    private func tagsChipText(for selectedIDs: Set<PersistentIdentifier>) -> String? {
        guard !selectedIDs.isEmpty else { return nil }
        let selectedNames = tags.filter { selectedIDs.contains($0.persistentModelID) }.map {
            $0.name
        }
        guard !selectedNames.isEmpty else { return nil }
        if selectedNames.count == 1 {
            return selectedNames.first
        }
        return "\(selectedNames.first ?? "") +\(selectedNames.count - 1)"
    }

    private func naturesChipText(for selectedNatures: Set<SubcategoryNature>) -> String? {
        guard !selectedNatures.isEmpty else { return nil }
        let names = selectedNatures.map { $0.displayName }
        if names.count == 1 {
            return names.first
        }
        return "\(names.first ?? "") +\(names.count - 1)"
    }

    // MARK: - New Record FAB

    private var newRecordFAB: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                Button {
                    recordsViewModel.showNewTransaction = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.netoPrimaryText, in: Circle())
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                }
            }
            .padding(.trailing, 20)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Selection Action Bar

    private var selectionActionBar: some View {
        VStack {
            Spacer()

            HStack {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("Eliminar")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                }

                Text("\(recordsViewModel.selectedRecordIDs.count) seleccionado(s)")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)

                Button {
                    handleEditAction()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text("Editar")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Actions

    private func refreshRecordsData() {
        DispatchQueue.main.async {
            recordsViewModel.applyFilters(
                transactions: allTransactions,
                accounts: accounts,
                categories: categories,
                tags: tags
            )
        }
    }

    private func calculateTrendsData() {
        DispatchQueue.main.async {
            trendsViewModel.calculateTrendData(
                accounts: accounts,
                transactions: allTransactions,
                defaultCurrencyCode: defaultCurrencyCode,
                context: modelContext
            )
        }
    }

    private func handleEditAction() {
        let flatTransactions = recordsViewModel.groupedRecords.flatMap { $0.records }
        let action = recordsViewModel.editSelectedRecords(transactions: flatTransactions)

        switch action {
        case .none:
            break
        case .single(let record):
            recordsViewModel.editingTransaction = record
            recordsViewModel.showEditTransaction = true
            recordsViewModel.exitSelectionMode()
        case .multiple:
            showMultiEditPlaceholder = true
        }
    }

    // MARK: - Synchronization

    private func syncFiltersToTrends() {
        if trendsViewModel.detailPeriod != recordsViewModel.period {
            trendsViewModel.detailPeriod = recordsViewModel.period
        }
        if trendsViewModel.selectedAccounts != recordsViewModel.selectedAccounts {
            trendsViewModel.selectedAccounts = recordsViewModel.selectedAccounts
        }
        if trendsViewModel.selectedCategories != recordsViewModel.selectedCategories {
            trendsViewModel.selectedCategories = recordsViewModel.selectedCategories
        }
        if trendsViewModel.selectedSubcategories != recordsViewModel.selectedSubcategories {
            trendsViewModel.selectedSubcategories = recordsViewModel.selectedSubcategories
        }
        if trendsViewModel.selectedTags != recordsViewModel.selectedTags {
            trendsViewModel.selectedTags = recordsViewModel.selectedTags
        }
        if trendsViewModel.selectedNatures != recordsViewModel.selectedNatures {
            trendsViewModel.selectedNatures = recordsViewModel.selectedNatures
        }
        if trendsViewModel.selectedCurrencies != recordsViewModel.selectedCurrencies {
            trendsViewModel.selectedCurrencies = recordsViewModel.selectedCurrencies
        }
        if trendsViewModel.amountCondition != recordsViewModel.amountCondition {
            trendsViewModel.amountCondition = recordsViewModel.amountCondition
        }
        if trendsViewModel.searchText != recordsViewModel.searchText {
            trendsViewModel.searchText = recordsViewModel.searchText
        }
    }

    private func syncFiltersToRecords() {
        if recordsViewModel.period != trendsViewModel.detailPeriod {
            recordsViewModel.period = trendsViewModel.detailPeriod
        }
        if recordsViewModel.selectedAccounts != trendsViewModel.selectedAccounts {
            recordsViewModel.selectedAccounts = trendsViewModel.selectedAccounts
        }
        if recordsViewModel.selectedCategories != trendsViewModel.selectedCategories {
            recordsViewModel.selectedCategories = trendsViewModel.selectedCategories
        }
        if recordsViewModel.selectedSubcategories != trendsViewModel.selectedSubcategories {
            recordsViewModel.selectedSubcategories = trendsViewModel.selectedSubcategories
        }
        if recordsViewModel.selectedTags != trendsViewModel.selectedTags {
            recordsViewModel.selectedTags = trendsViewModel.selectedTags
        }
        if recordsViewModel.selectedNatures != trendsViewModel.selectedNatures {
            recordsViewModel.selectedNatures = trendsViewModel.selectedNatures
        }
        if recordsViewModel.selectedCurrencies != trendsViewModel.selectedCurrencies {
            recordsViewModel.selectedCurrencies = trendsViewModel.selectedCurrencies
        }
        if recordsViewModel.amountCondition != trendsViewModel.amountCondition {
            recordsViewModel.amountCondition = trendsViewModel.amountCondition
        }
        if recordsViewModel.searchText != trendsViewModel.searchText {
            recordsViewModel.searchText = trendsViewModel.searchText
        }
    }

    private func syncFromSessionState() {
        trendsViewModel.detailPeriod = sessionState.selectedPeriod
        recordsViewModel.period = sessionState.selectedPeriod

        trendsViewModel.selectedAccounts = sessionState.selectedAccountIDs
        recordsViewModel.selectedAccounts = sessionState.selectedAccountIDs

        trendsViewModel.selectedCategories = sessionState.selectedCategoryIDs
        recordsViewModel.selectedCategories = sessionState.selectedCategoryIDs

        if sessionState.selectedSubcategoryNames.isEmpty {
            trendsViewModel.selectedSubcategories.removeAll()
            recordsViewModel.selectedSubcategories.removeAll()
        }

        trendsViewModel.selectedNatures = sessionState.selectedNatures
        recordsViewModel.selectedNatures = sessionState.selectedNatures
    }

    private func syncToSessionState() {
        sessionState.selectedPeriod = trendsViewModel.detailPeriod
        sessionState.selectedAccountIDs = trendsViewModel.selectedAccounts
        sessionState.selectedCategoryIDs = trendsViewModel.selectedCategories
        sessionState.selectedNatures = trendsViewModel.selectedNatures
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DetailContainerView()
    }
}

// MARK: - View Helpers

extension View {
    fileprivate func onRecordsFilterChange(
        viewModel: RecordsViewModel, action: @escaping () -> Void
    ) -> some View {
        self
            .onChange(of: viewModel.period) { _, _ in action() }
            .onChange(of: viewModel.selectedAccounts) { _, _ in action() }
            .onChange(of: viewModel.selectedCategories) { _, _ in action() }
            .onChange(of: viewModel.selectedSubcategories) { _, _ in action() }
            .onChange(of: viewModel.selectedTags) { _, _ in action() }
            .onChange(of: viewModel.selectedNatures) { _, _ in action() }
            .onChange(of: viewModel.selectedCurrencies) { _, _ in action() }
            .onChange(of: viewModel.amountCondition) { _, _ in action() }
            .onChange(of: viewModel.searchText) { _, _ in action() }
    }

    func onTrendsFilterChange(viewModel: StatisticsViewModel, action: @escaping () -> Void)
        -> some View
    {
        self
            .onChange(of: viewModel.detailPeriod) { _, _ in action() }
            .onChange(of: viewModel.selectedMetric) { _, _ in action() }
            .onChange(of: viewModel.isAggregatedView) { _, _ in action() }
            .onChange(of: viewModel.selectedAccounts) { _, _ in action() }
            .onChange(of: viewModel.selectedCategories) { _, _ in action() }
            .onChange(of: viewModel.selectedSubcategories) { _, _ in action() }
            .onChange(of: viewModel.selectedTags) { _, _ in action() }
            .onChange(of: viewModel.selectedNatures) { _, _ in action() }
            .onChange(of: viewModel.selectedCurrencies) { _, _ in action() }
            .onChange(of: viewModel.amountCondition) { _, _ in action() }
            .onChange(of: viewModel.searchText) { _, _ in action() }
    }
}

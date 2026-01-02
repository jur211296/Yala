//
//  RecordsListView.swift
//  Neto
//
//  Created by Neto - Records Feature.
//

import SwiftData
import SwiftUI

// MARK: - Records List View

/// Main container view for the Records screen
struct RecordsListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // MARK: - Data Queries

    @Query(sort: \TransactionItem.date, order: .reverse)
    private var allTransactions: [TransactionItem]

    @Query(sort: \Account.name) private var accounts: [Account]
    @Query(sort: \Category.sortOrder) private var categories: [Category]
    @Query(sort: \Tag.name) private var tags: [Tag]

    // MARK: - ViewModel

    @State private var viewModel: RecordsViewModel

    // MARK: - State

    @State private var showDeleteConfirmation = false
    @State private var showMultiEditPlaceholder = false

    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = CurrencyCode.pen
        .rawValue

    // MARK: - Initialization

    private let isEmbedded: Bool

    init(context: RecordsFilterContext = .empty, isEmbedded: Bool = false) {
        self.isEmbedded = isEmbedded
        _viewModel = State(initialValue: RecordsViewModel(context: context))
    }

    // MARK: - Body

    var body: some View {
        ZStack {

            if !isEmbedded {
                PanelBackgroundView()
            }

            VStack(spacing: 0) {
                // Active filter chips
                if viewModel.hasActiveFilters {
                    filterChipsSection
                }

                // Main content
                if viewModel.groupedRecords.isEmpty {
                    emptyState
                } else {
                    recordsList
                }
            }

            // Floating search button
            floatingSearchButton

            // Selection action bar
            if viewModel.isSelectionMode && !viewModel.selectedRecordIDs.isEmpty {
                selectionActionBar
            }
        }
        .navigationTitle(isEmbedded ? "" : (viewModel.isSelectionMode ? "" : "Registros"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isEmbedded || viewModel.isSelectionMode {
                if viewModel.isSelectionMode {
                    selectionModeToolbar
                } else {
                    normalModeToolbar
                }
            }
        }
        .navigationBarBackButtonHidden(viewModel.isSelectionMode)
        .tint(.primary)
        .sheet(isPresented: $viewModel.showFiltersSheet) {
            RecordsFiltersView(viewModel: viewModel)
                .onDisappear {
                    refreshData()
                }
        }
        .sheet(isPresented: $viewModel.showNewTransaction) {
            NewTransactionView()
                .onDisappear {
                    refreshData()
                }
        }
        .sheet(isPresented: $viewModel.showEditTransaction) {
            if let transaction = viewModel.editingTransaction {
                NewTransactionView(transactionToEdit: transaction)
                    .onDisappear {
                        viewModel.editingTransaction = nil
                        refreshData()
                    }
            }
        }
        .confirmationDialog(
            "¿Eliminar \(viewModel.selectedRecordIDs.count) registro(s)?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                viewModel.deleteSelected(context: modelContext)
                refreshData()
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
        .onAppear {
            refreshData()
        }
        .onChange(of: viewModel.searchText) {
            refreshData()
        }
    }

    // MARK: - Normal Mode Toolbar

    @ToolbarContentBuilder
    private var normalModeToolbar: some ToolbarContent {
        // No custom back button - using native navigation back button

        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 16) {
                // Filters button
                Button {
                    viewModel.showFiltersSheet = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .overlay(alignment: .topTrailing) {
                    if viewModel.activeFilterCount > 0 {
                        Circle()
                            .fill(Color.hotPink)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                    }
                }

                // Select button (icon)
                Button {
                    viewModel.enterSelectionMode()
                } label: {
                    Image(systemName: "checkmark.circle")
                }

                // New record button
                Button {
                    viewModel.showNewTransaction = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    // MARK: - Selection Mode Toolbar

    @ToolbarContentBuilder
    private var selectionModeToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancelar") {
                viewModel.exitSelectionMode()
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button("Seleccionar todo") {
                viewModel.selectAll()
            }
        }
    }

    // MARK: - Filter Chips Section

    private var filterChipsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Period chip
                if viewModel.period != .thisMonth {
                    filterChip(
                        text: viewModel.period.displayName,
                        onClear: { viewModel.period = .thisMonth }
                    )
                }

                // Account chips
                if !viewModel.selectedAccounts.isEmpty {
                    filterChip(
                        text: "\(viewModel.selectedAccounts.count) cuenta(s)",
                        onClear: { viewModel.selectedAccounts.removeAll() }
                    )
                }

                // Category chips
                if !viewModel.selectedCategories.isEmpty || !viewModel.selectedSubcategories.isEmpty
                {
                    filterChip(
                        text: "Categorías filtradas",
                        onClear: {
                            viewModel.selectedCategories.removeAll()
                            viewModel.selectedSubcategories.removeAll()
                        }
                    )
                }

                // Nature chips
                ForEach(Array(viewModel.selectedNatures), id: \.self) { nature in
                    filterChip(
                        text: nature.displayName,
                        color: nature.color,
                        onClear: { viewModel.selectedNatures.remove(nature) }
                    )
                }

                // Transaction type chip
                if viewModel.transactionTypeFilter != .all {
                    filterChip(
                        text: viewModel.transactionTypeFilter.displayName,
                        onClear: { viewModel.transactionTypeFilter = .all }
                    )
                }

                // Search chip
                if !viewModel.searchText.isEmpty {
                    filterChip(
                        text: "Buscar: \(viewModel.searchText)",
                        onClear: { viewModel.clearSearch() }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color.netoBackground.opacity(0.9))
    }

    private func filterChip(
        text: String, color: Color = .electricIndigo, onClear: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.caption)
                .foregroundStyle(.primary)

            Button {
                withAnimation {
                    onClear()
                    refreshData()
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Records List

    private var recordsList: some View {
        ScrollView {
            LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
                ForEach(viewModel.groupedRecords, id: \.date) { group in
                    Section {
                        ForEach(group.records, id: \.persistentModelID) { record in
                            RecordRowView(
                                record: record,
                                currencyCode: defaultCurrencyCode,
                                isSelectionMode: viewModel.isSelectionMode,
                                isSelected: viewModel.selectedRecordIDs.contains(
                                    record.persistentModelID),
                                onTap: {
                                    viewModel.editRecord(record)
                                },
                                onToggleSelection: {
                                    viewModel.toggleSelection(record.persistentModelID)
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
            .padding(.bottom, viewModel.isSelectionMode ? 80 : 100)  // Space for action bar or search button
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "list.bullet.rectangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary.opacity(0.5))

            Text("No hay registros")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Text(
                viewModel.hasActiveFilters
                    ? "No se encontraron registros con los filtros aplicados."
                    : "Cuando registres movimientos, aparecerán aquí."
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)

            if viewModel.hasActiveFilters {
                Button {
                    viewModel.clearFilters()
                    refreshData()
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

    // MARK: - Floating Search Button

    private var floatingSearchButton: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                if viewModel.isSearchExpanded {
                    expandedSearchBar
                } else {
                    collapsedSearchButton
                }
            }
            .padding(.trailing, 20)
            .padding(.bottom, viewModel.isSelectionMode ? 80 : 24)
        }
    }

    private var collapsedSearchButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.isSearchExpanded = true
            }
        } label: {
            Image(systemName: "magnifyingglass")
                .font(.title3.weight(.medium))
                .frame(width: 56, height: 56)
                .background(.ultraThinMaterial, in: Circle())
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
        }
    }

    private var expandedSearchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Buscar por nota...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .submitLabel(.search)

            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            Button("Cancelar") {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.clearSearch()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
        .transition(
            .asymmetric(
                insertion: .scale(scale: 0.8, anchor: .bottomTrailing).combined(with: .opacity),
                removal: .scale(scale: 0.8, anchor: .bottomTrailing).combined(with: .opacity)
            ))
    }

    // MARK: - Selection Action Bar

    private var selectionActionBar: some View {
        VStack {
            Spacer()

            HStack {
                // Delete button
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

                // Selected count
                Text("\(viewModel.selectedRecordIDs.count) seleccionado(s)")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)

                // Edit button
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

    private func refreshData() {
        viewModel.applyFilters(
            transactions: allTransactions,
            accounts: accounts,
            categories: categories,
            tags: tags
        )
    }

    private func handleEditAction() {
        let flatTransactions = viewModel.groupedRecords.flatMap { $0.records }
        let action = viewModel.editSelectedRecords(transactions: flatTransactions)

        switch action {
        case .none:
            break
        case .single(let record):
            viewModel.editingTransaction = record
            viewModel.showEditTransaction = true
            viewModel.exitSelectionMode()
        case .multiple:
            showMultiEditPlaceholder = true
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        RecordsListView()
    }
}

//
//  ContentView.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftData
import SwiftUI

// MARK: - ContentView (Punto de entrada principal)

struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

// MARK: - TabView Principal con Search Role (iOS 18+)

struct MainTabView: View {
    @Bindable private var sessionState: SessionState
    @State private var searchText: String = ""

    init() {
        // Get SessionState from the environment wrapper
        // This is initialized here to work with @Bindable
        _sessionState = Bindable(wrappedValue: SessionState.shared)
    }

    var body: some View {
        // IMPORTANT: When wiping data, completely unmount the TabView to deactivate all @Query observers
        // This prevents crashes from SwiftUI trying to access invalidated model instances
        if sessionState.isWipingData {
            wipingDataView
        } else {
            TabView(selection: $sessionState.selectedMainTab) {
                Tab(L10n.Tab.panel, systemImage: "rectangle.grid.2x2.fill", value: .panel) {
                    PanelView()
                }

                Tab(L10n.Tab.statistics, systemImage: "chart.bar.fill", value: .statistics) {
                    StatisticsView()
                }

                Tab(L10n.Tab.planning, systemImage: "calendar", value: .planning) {
                    PlanningView()
                }

                Tab(L10n.Tab.more, systemImage: "ellipsis", value: .more) {
                    MorePlaceholderView()
                }

                // Search tab with .search role - pinned to trailing edge
                Tab(value: .search, role: .search) {
                    GlobalSearchView()
                }
            }
            .tint(Color.electricIndigo)
        }
    }

    private var wipingDataView: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)

                Text(L10n.Settings.deletingData)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - App Tab Enum

enum AppTab: Hashable {
    case panel
    case statistics
    case planning
    case more
    case search
}

// MARK: - More Placeholder View

struct MorePlaceholderView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                VStack(spacing: 16) {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.tertiary)

                    Text(L10n.Common.moreOptions)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)

                    Text(L10n.Common.comingSoon)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(L10n.Tab.more)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Global Search View

struct GlobalSearchView: View {
    @State private var searchText: String = ""
    @State private var isSearchActive: Bool = false
    @State private var isDataReady: Bool = false

    // Load data here to avoid glitch during search activation
    @Query(sort: \TransactionItem.date, order: .reverse) private var allTransactions:
        [TransactionItem]

    var body: some View {
        NavigationStack {
            ZStack {
                // Background for both states
                PanelBackgroundView()

                if isDataReady {
                    SearchContentView(searchText: $searchText, transactions: allTransactions)
                } else {
                    // Loading state - subtle animation
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text(L10n.Common.loading)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
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
            try? await Task.sleep(for: .milliseconds(300))
            await MainActor.run {
                withAnimation(.easeIn(duration: 0.2)) {
                    isDataReady = true
                }
                isSearchActive = true
            }
        }
    }
}

// MARK: - Search Content View

struct SearchContentView: View {
    @Binding var searchText: String
    let transactions: [TransactionItem]  // Passed from parent

    @State private var selectedFilter: SearchFilter = .all
    @State private var editingTransaction: TransactionItem?
    @State private var navigateToRecords: Bool = false

    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = "PEN"

    // MARK: - Filtered Results

    private var filteredResults: [TransactionItem] {
        // If no search text, show all (limited to 20)
        guard !searchText.isEmpty else {
            return Array(transactions.prefix(20))
        }

        let lowercasedSearch = searchText.lowercased()

        return transactions.filter { transaction in
            switch selectedFilter {
            case .all:
                // Search in all fields
                let noteMatch = transaction.note?.lowercased().contains(lowercasedSearch) ?? false
                let categoryMatch =
                    transaction.category?.name.lowercased().contains(lowercasedSearch) ?? false
                let subcategoryMatch =
                    transaction.subcategory?.name.lowercased().contains(lowercasedSearch) ?? false
                let accountMatch =
                    transaction.account?.name.lowercased().contains(lowercasedSearch) ?? false
                let tagMatch = transaction.tags.contains {
                    $0.name.lowercased().contains(lowercasedSearch)
                }
                return noteMatch || categoryMatch || subcategoryMatch || accountMatch || tagMatch
            case .note:
                return transaction.note?.lowercased().contains(lowercasedSearch) ?? false
            case .category:
                return transaction.category?.name.lowercased().contains(lowercasedSearch) ?? false
            case .subcategory:
                return transaction.subcategory?.name.lowercased().contains(lowercasedSearch)
                    ?? false
            case .account:
                return transaction.account?.name.lowercased().contains(lowercasedSearch) ?? false
            case .nature:
                return transaction.subcategory?.nature.displayName.lowercased()
                    .contains(lowercasedSearch) ?? false
            case .tag:
                return transaction.tags.contains { $0.name.lowercased().contains(lowercasedSearch) }
            }
        }
        .prefix(20)
        .map { $0 }
    }

    // Total count for "Ver todo" (without limit)
    private var totalMatchingCount: Int {
        guard !searchText.isEmpty else { return transactions.count }

        let lowercasedSearch = searchText.lowercased()

        return transactions.filter { transaction in
            switch selectedFilter {
            case .all:
                let noteMatch = transaction.note?.lowercased().contains(lowercasedSearch) ?? false
                let categoryMatch =
                    transaction.category?.name.lowercased().contains(lowercasedSearch) ?? false
                let subcategoryMatch =
                    transaction.subcategory?.name.lowercased().contains(lowercasedSearch) ?? false
                let accountMatch =
                    transaction.account?.name.lowercased().contains(lowercasedSearch) ?? false
                let tagMatch = transaction.tags.contains {
                    $0.name.lowercased().contains(lowercasedSearch)
                }
                return noteMatch || categoryMatch || subcategoryMatch || accountMatch || tagMatch
            case .note:
                return transaction.note?.lowercased().contains(lowercasedSearch) ?? false
            case .category:
                return transaction.category?.name.lowercased().contains(lowercasedSearch) ?? false
            case .subcategory:
                return transaction.subcategory?.name.lowercased().contains(lowercasedSearch)
                    ?? false
            case .account:
                return transaction.account?.name.lowercased().contains(lowercasedSearch) ?? false
            case .nature:
                return transaction.subcategory?.nature.displayName.lowercased().contains(
                    lowercasedSearch) ?? false
            case .tag:
                return transaction.tags.contains { $0.name.lowercased().contains(lowercasedSearch) }
            }
        }.count
    }

    // MARK: - Grouped Results by Date

    private var groupedResults: [(date: Date, records: [TransactionItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredResults) { record in
            calendar.startOfDay(for: record.date)
        }
        return grouped.sorted { $0.key > $1.key }
            .map { (date: $0.key, records: $0.value) }
    }

    var body: some View {
        ZStack {
            PanelBackgroundView()

            VStack(spacing: 0) {
                // Filter chips (only show when searching)
                if !searchText.isEmpty {
                    filterChipsBar
                        .padding(.top, 8)
                }

                // Always show results (all or filtered)
                searchResultsView
            }
        }
        .sheet(item: $editingTransaction) { transaction in
            NewTransactionView(transactionToEdit: transaction)
        }
        .navigationDestination(isPresented: $navigateToRecords) {
            DetailContainerView(
                context: RecordsFilterContext(
                    period: .allTime,
                    searchText: searchText,
                    isFromSearch: true
                ),
                initialTab: .records
            )
        }
    }

    // MARK: - Filter Chips Bar

    private var filterChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchFilter.allCases) { filter in
                    filterChip(for: filter)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private func filterChip(for filter: SearchFilter) -> some View {
        let isSelected = selectedFilter == filter

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedFilter = filter
            }
        } label: {
            Text(filter.rawValue)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.electricIndigo : Color.clear)
                )
                .overlay(
                    Capsule()
                        .stroke(Color.secondary.opacity(0.3), lineWidth: isSelected ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search Results

    private var searchResultsView: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                // Header with count and Ver todo
                if !filteredResults.isEmpty && !searchText.isEmpty {
                    HStack {
                        Text("\(totalMatchingCount) resultados")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            navigateToRecords = true
                        } label: {
                            HStack(spacing: 4) {
                                Text(L10n.Action.viewAll)
                                Image(systemName: "arrow.right")
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.electricIndigo)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }

                // Grouped results by date
                ForEach(groupedResults, id: \.date) { group in
                    Section {
                        ForEach(group.records, id: \.persistentModelID) { record in
                            SearchResultRow(record: record, currencyCode: defaultCurrencyCode) {
                                editingTransaction = record
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                        }
                    } header: {
                        SearchDateSectionHeader(date: group.date)
                    }
                }

                // No results message
                if filteredResults.isEmpty && !searchText.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(.tertiary)

                        Text(L10n.Search.noResults)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(L10n.Search.tryAnotherTerm)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                }
            }
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.immediately)
    }
}

// MARK: - Search Date Section Header

struct SearchDateSectionHeader: View {
    let date: Date

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = AppLocale.current

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return L10n.Date.today
        } else if calendar.isDateInYesterday(date) {
            return L10n.Date.yesterday
        } else {
            formatter.dateFormat = "d MMM yyyy"
            return formatter.string(from: date).replacingOccurrences(of: ".", with: "")
        }
    }

    var body: some View {
        HStack {
            Text(formattedDate)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

// MARK: - Search Filter Enum

enum SearchFilter: String, CaseIterable, Identifiable {
    case all = "Todo"
    case note = "Nota"
    case category = "Categoría"
    case subcategory = "Subcategoría"
    case account = "Cuenta"
    case nature = "Naturaleza"
    case tag = "Etiqueta"

    var id: String { rawValue }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let record: TransactionItem
    let currencyCode: String
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                // Icon
                subcategoryIcon

                // Content
                VStack(alignment: .leading, spacing: 3) {
                    Text(
                        record.note ?? record.subcategory?.name ?? record.category?.name
                            ?? L10n.Common.uncategorized
                    )
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                    let categoryName = record.subcategory?.name ?? record.category?.name ?? ""
                    let accountName = record.account?.name ?? ""

                    if !categoryName.isEmpty || !accountName.isEmpty {
                        Text("\(categoryName) • \(accountName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Amount
                Text(formattedAmount)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(amountColor)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var subcategoryIcon: some View {
        let colorHex = record.category?.colorHex ?? "#6366F1"
        let iconName = record.subcategory?.iconName ?? record.category?.iconName ?? "tag.fill"

        return ZStack {
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: 40, height: 40)

            Image(systemName: iconName)
                .font(.callout.weight(.medium))
                .foregroundStyle(.white)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.netoCard)
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.06),
                radius: 6,
                x: 0,
                y: 3
            )
    }

    private var formattedAmount: String {
        NetoFormatter.currency(value: record.amount, currencyCode: record.currencyCode)
    }

    private var amountColor: Color {
        let isIncome = record.category?.isIncome ?? (record.amount >= 0)
        return isIncome ? Color.electricIndigo : Color.hotPink
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [
                Account.self,
                TransactionItem.self,
                Category.self,
                Subcategory.self,
                Tag.self,
                Budget.self,
                ExchangeRate.self,
            ], inMemory: true)
}

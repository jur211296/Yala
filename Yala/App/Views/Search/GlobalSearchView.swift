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
                    VStack(spacing: DS.Spacing.lg) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text(L10n.Common.loading)
                            .font(DS.Typography.subheadline)
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
    }
}

// MARK: - Search Content View

struct SearchContentView: View {
    @Environment(\.yalaTheme) private var theme
    @Environment(SessionState.self) private var sessionState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.tagCatalog) private var tagCatalog
    @Binding var searchText: String
    let transactions: [TransactionItem]  // Passed from parent

    @State private var selectedFilter: SearchFilter = .all
    @State private var editingTransaction: TransactionItem?

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
        Array(matchingTransactions.prefix(20))
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
        ZStack {
            PanelBackgroundView()

            VStack(spacing: DS.Spacing.none) {
                // Filter chips (only show when searching)
                if !searchText.isEmpty {
                    filterChipsBar
                        .padding(.top, DS.Spacing.sm)
                }

                // Always show results (all or filtered)
                searchResultsView
            }
        }
        .sheet(item: $editingTransaction) { transaction in
            NewTransactionView(transactionToEdit: transaction)
                .presentationDetents([.large])
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
            LazyVStack(spacing: DS.Spacing.none, pinnedViews: [.sectionHeaders]) {
                // Header with count and Ver todo
                if !filteredResults.isEmpty && !searchText.isEmpty {
                    HStack {
                        Text(L10n.Search.resultsCount(totalMatchingCount))
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            // Navigate to Statistics > Records with search filter applied
                            sessionState.searchText = searchText
                            sessionState.selectedPeriod = .allTime
                            sessionState.navigateToDetail(.records)
                            // Clear local state - SessionState is now the source of truth
                            searchText = ""
                        } label: {
                            HStack(spacing: DS.Spacing.xs) {
                                Text(L10n.Action.viewAll)
                                Image(systemName: "arrow.right")
                            }
                            .font(DS.Typography.label)
                            .foregroundStyle(theme.accent)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.top, DS.Spacing.sm)
                    .padding(.bottom, DS.Spacing.md)
                }

                // Grouped results by date
                ForEach(groupedResults, id: \.date) { group in
                    Section {
                        ForEach(group.records, id: \.persistentModelID) { record in
                            SearchResultRow(record: record, currencyCode: appPreferences.defaultCurrencyCode.rawValue) {
                                editingTransaction = record
                            }
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.vertical, DS.Spacing.xs)
                        }
                    } header: {
                        SearchDateSectionHeader(date: group.date)
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

// MARK: - Search Date Section Header

struct SearchDateSectionHeader: View {
    let date: Date

    private static let sectionDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppLocale.current
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    private var formattedDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return L10n.Date.today
        } else if calendar.isDateInYesterday(date) {
            return L10n.Date.yesterday
        } else {
            return Self.sectionDateFormatter.string(from: date).replacing(".", with: "")
        }
    }

    var body: some View {
        HStack {
            Text(formattedDate)
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Spacer()
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.sm)
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

// MARK: - Search Result Row

struct SearchResultRow: View {
    let record: TransactionItem
    let currencyCode: String
    let onTap: () -> Void

    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: DS.Spacing.md) {
                // Icon
                subcategoryIcon

                // Content
                VStack(alignment: .leading, spacing: 3) { // DS: intentional non-token value
                    Text(
                        record.note ?? record.subcategory?.name ?? record.category?.name
                            ?? L10n.Common.uncategorized
                    )
                    .font(DS.Typography.label)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                    let categoryName = record.subcategory?.name ?? record.category?.name ?? ""
                    let accountName = record.account?.name ?? ""

                    if !categoryName.isEmpty || !accountName.isEmpty {
                        Text("\(categoryName) • \(accountName)")
                            .font(DS.Typography.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Amount
                Text(formattedAmount)
                    .font(DS.Typography.amount)
                    .foregroundStyle(amountColor)
            }
            .padding(.vertical, DS.Spacing.md)
            .padding(.horizontal, DS.Spacing.md)
            .contentShape(Rectangle())
            .solidCard(radius: DS.Radius.card)
        }
        .buttonStyle(.plain)
    }

    private var subcategoryIcon: some View {
        let colorHex = record.category?.colorHex ?? AppConstants.defaultColorHex
        let iconName = record.subcategory?.iconName ?? record.category?.iconName ?? "tag.fill"

        return ZStack {
            Circle()
                .fill(Color(hex: colorHex))
                .frame(width: DS.ListRow.iconSize, height: DS.ListRow.iconSize)

            Image(systemName: iconName)
                .font(DS.Typography.label)
                .foregroundStyle(.white)
        }
    }

    private var formattedAmount: String {
        appPreferences.currency(record.amount, currencyCode: record.currencyCode, forceFullPrecision: true)
    }

    private var amountColor: Color {
        let isIncome = record.category?.isIncome ?? (record.amount >= 0)
        return isIncome ? Color.electricIndigo : Color.hotPink
    }
}

#Preview {
    GlobalSearchView()
        .modelContainer(
            for: [
                TransactionItem.self,
                Category.self,
                Subcategory.self,
                Tag.self,
            ], inMemory: true)
        .previewAppPreferences()
}

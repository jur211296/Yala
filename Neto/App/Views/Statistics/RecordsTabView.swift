//
//  RecordsTabView.swift
//  Neto
//
//  Records tab content extracted from DetailContainerView.
//  Provides the records list, control bar, filter chips, and empty state.
//

import SwiftData
import SwiftUI

// MARK: - Records Tab View

/// Records tab content with control bar, filter chips, and record list.
/// Extracted from DetailContainerView to reduce complexity.
struct RecordsTabView: View {
    @Environment(SessionState.self) private var sessionState

    /// All transactions (unfiltered) for date range limits
    @Query(sort: \TransactionItem.date, order: .reverse)
    private var allTransactions: [TransactionItem]

    /// All subcategories for chip display (independent of spending data)
    @Query(sort: \Subcategory.name, order: .forward)
    private var allSubcategories: [Subcategory]

    @Bindable var viewModel: RecordsViewModel
    let accounts: [Account]
    let categories: [Category]
    let tags: [Tag]
    let defaultCurrencyCode: String
    var onFilterChange: () -> Void

    // Custom period picker state
    @State private var showCustomPeriodPicker: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                controlBar
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.sm)

                if viewModel.groupedRecords.isEmpty {
                    emptyStateContent
                } else {
                    summaryRow

                    recordsListContent
                }
            }
        }
        .sheet(isPresented: $showCustomPeriodPicker) {
            CustomPeriodPickerSheet(
                minDate: transactionDateRange.start,
                maxDate: transactionDateRange.end,
                currentRange: sessionState.customDateRange
            )
        }
        .onChange(of: sessionState.customDateRange) {
            // Sync custom date range and period, then recalculate
            viewModel.syncCustomRangeFromSessionState(sessionState)
            onFilterChange()
        }
    }

    /// Date range of all transactions (unfiltered, for custom period picker limits)
    private var transactionDateRange: (start: Date, end: Date) {
        let sortedDates = allTransactions.map(\.date).sorted()
        let start = sortedDates.first ?? Date()
        let end = sortedDates.last ?? Date()
        return (start, end)
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: DS.Spacing.md) {
            periodSelector

            if viewModel.hasActiveFilters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.sm) {
                        // Account chips (with icon)
                        ForEach(selectedAccountChips, id: \.id) { chip in
                            FilterChipView(
                                accountName: chip.name,
                                count: chip.count,
                                onClear: {
                                    viewModel.selectedAccounts.removeAll()
                                    onFilterChange()
                                }
                            )
                        }

                        // Category chip (aggregated - one chip max)
                        if let catChip = aggregatedCategoryChip(
                            selectedSubcategories: viewModel.selectedSubcategories,
                            allSubcategories: allSubcategories
                        ) {
                            FilterChipView(
                                categoryName: catChip.name,
                                iconName: catChip.iconName,
                                colorHex: catChip.colorHex,
                                count: catChip.count,
                                onClear: {
                                    viewModel.selectedCategories.removeAll()
                                    viewModel.selectedSubcategories.removeAll()
                                    onFilterChange()
                                }
                            )
                        }

                        // Subcategory chip (aggregated - one chip max)
                        if let subChip = aggregatedSubcategoryChip(
                            selectedSubcategories: viewModel.selectedSubcategories,
                            allSubcategories: allSubcategories
                        ) {
                            FilterChipView(
                                subcategoryName: subChip.name,
                                iconName: subChip.iconName,
                                colorHex: subChip.colorHex,
                                count: subChip.count,
                                onClear: {
                                    viewModel.selectedSubcategories.removeAll()
                                    onFilterChange()
                                }
                            )
                        }

                        // Tag chips (individual with icon and color)
                        ForEach(selectedTagChips, id: \.id) { chip in
                            FilterChipView(
                                tagName: chip.name,
                                iconName: chip.iconName,
                                colorHex: chip.colorHex,
                                onClear: {
                                    viewModel.selectedTags.remove(chip.tagID)
                                    onFilterChange()
                                }
                            )
                        }

                        // Nature chips (with color dots)
                        ForEach(natureChips, id: \.nature.rawValue) { chipData in
                            FilterChipView(
                                nature: chipData.nature,
                                onClear: {
                                    viewModel.selectedNatures.remove(chipData.nature)
                                    onFilterChange()
                                }
                            )
                        }

                        // Transaction nature chip (income/expense with color dot)
                        // Only show when exactly 1 selected
                        if viewModel.selectedTransactionNatures.count == 1,
                            let nature = viewModel.selectedTransactionNatures.first
                        {
                            FilterChipView(
                                transactionNature: nature,
                                onClear: {
                                    viewModel.selectedTransactionNatures.removeAll()
                                    sessionState.selectedTransactionNatures.removeAll()
                                    onFilterChange()
                                }
                            )
                        }

                        // Transaction type chip
                        if viewModel.transactionTypeFilter != .all {
                            FilterChipView(text: viewModel.transactionTypeFilter.displayName) {
                                viewModel.transactionTypeFilter = .all
                                onFilterChange()
                            }
                        }

                        // Currency chips
                        ForEach(Array(viewModel.selectedCurrencies), id: \.self) { currency in
                            FilterChipView(
                                currencyCode: currency.rawValue,
                                onClear: {
                                    viewModel.selectedCurrencies.remove(currency)
                                    sessionState.selectedCurrencies.remove(currency)
                                    onFilterChange()
                                }
                            )
                        }

                        // Amount chip
                        if viewModel.amountCondition.isActive {
                            FilterChipView(
                                amountText: viewModel.amountCondition.displayText,
                                onClear: {
                                    viewModel.amountCondition = .any
                                    sessionState.amountCondition = .any
                                    onFilterChange()
                                }
                            )
                        }

                        // Search/Note chip
                        if !viewModel.searchText.isEmpty {
                            FilterChipView(
                                noteText: viewModel.searchText,
                                onClear: {
                                    viewModel.searchText = ""
                                    sessionState.searchText = ""
                                    onFilterChange()
                                }
                            )
                        }

                        // Clear all button
                        if viewModel.activeFilterCount > 1 {
                            Button {
                                withAnimation {
                                    viewModel.clearFilters()
                                    onFilterChange()
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
        .animation(nil, value: viewModel.period)
    }

    // MARK: - Period Selector

    private var periodSelector: some View {
        TrendsPeriodMenu(
            selectedPeriod: viewModel.period,
            customDateRange: sessionState.customDateRange,
            onSelect: { period in
                withTransaction(Transaction(animation: nil)) {
                    viewModel.period = period
                    sessionState.selectedPeriod = period
                }
            },
            onCustomTapped: {
                showCustomPeriodPicker = true
            }
        )
        .equatable()
    }

    // MARK: - Summary Row

    private var summaryRow: some View {
        let isIncomeFiltered = viewModel.selectedTransactionNatures == [.income]
        let isExpenseFiltered = viewModel.selectedTransactionNatures == [.expense]
        let hasNatureFilter = isIncomeFiltered || isExpenseFiltered

        return VStack(alignment: .center, spacing: DS.Spacing.xs) {
            // Balance (Saldo) - Large and centered
            Text(
                NetoFormatter.currency(
                    value: recordsSummary.balance, currencyCode: defaultCurrencyCode)
            )
            .font(.title.weight(.bold))
            .foregroundStyle(.primary)

            // Income and Expense indicators below (tappable to filter)
            HStack(spacing: DS.Spacing.md) {
                // Income button
                Button {
                    withAnimation {
                        if isIncomeFiltered {
                            viewModel.selectedTransactionNatures.removeAll()
                            sessionState.selectedTransactionNatures.removeAll()
                        } else {
                            viewModel.selectedTransactionNatures = [.income]
                            sessionState.selectedTransactionNatures = [.income]
                        }
                        onFilterChange()
                    }
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.incomeGraph)
                        Text(
                            NetoFormatter.currency(
                                value: recordsSummary.income, currencyCode: defaultCurrencyCode)
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .opacity(hasNatureFilter && !isIncomeFiltered ? 0.3 : 1.0)
                }
                .buttonStyle(.plain)

                // Expense button
                Button {
                    withAnimation {
                        if isExpenseFiltered {
                            viewModel.selectedTransactionNatures.removeAll()
                            sessionState.selectedTransactionNatures.removeAll()
                        } else {
                            viewModel.selectedTransactionNatures = [.expense]
                            sessionState.selectedTransactionNatures = [.expense]
                        }
                        onFilterChange()
                    }
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "arrow.down.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.expenseGraph)
                        Text(
                            NetoFormatter.currency(
                                value: recordsSummary.expense, currencyCode: defaultCurrencyCode)
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .opacity(hasNatureFilter && !isExpenseFiltered ? 0.3 : 1.0)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }

    private var recordsSummary: (balance: Double, income: Double, expense: Double) {
        var income: Double = 0
        var expense: Double = 0
        var balance: Double = 0

        for group in viewModel.groupedRecords {
            for record in group.records {
                // Skip transactions without account or from archived/excluded accounts (matches Panel/Trends)
                guard let account = record.account else { continue }
                if account.isArchived || account.excludeFromStatistics {
                    continue
                }

                // Always use amountInPreferredCurrency (matches TrendDataProcessor calculation)
                let amount = record.amountInPreferredCurrency

                // Balance includes ALL transactions (initial balance, adjustments, income, expense)
                balance += amount

                // Income/Expense exclude balance adjustments (initial_balance and adjustment)
                let isBalanceAdjustment = record.balanceAdjustmentType != nil

                if !isBalanceAdjustment {
                    if amount > 0 {
                        income += amount
                    } else {
                        expense += abs(amount)
                    }
                }
            }
        }

        return (balance, income, expense)
    }

    // MARK: - Records List Content

    private var recordsListContent: some View {
        LazyVStack(spacing: DS.Spacing.sm, pinnedViews: [.sectionHeaders]) {
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
                        .padding(.horizontal, DS.Spacing.lg)
                    }
                } header: {
                    RecordDateSectionView(date: group.date)
                }
            }
        }
        .padding(.top, DS.Spacing.sm)
        .netoSafeBottomPadding()
    }

    // MARK: - Empty State Content

    private var emptyStateContent: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "list.bullet.rectangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary.opacity(0.5))

            Text(L10n.Records.noRecords)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Text(
                viewModel.hasActiveFilters
                    ? L10n.Statistics.noRecordsFiltered
                    : L10n.Statistics.noRecordsDescription
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, DS.Spacing.xxxl + DS.Spacing.sm)

            if viewModel.hasActiveFilters {
                Button {
                    viewModel.clearFilters()
                    onFilterChange()
                } label: {
                    Text(L10n.Filters.clearFilters)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.electricIndigo)
                }
                .padding(.top, DS.Spacing.sm)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.xxxl * 2)
    }

    // MARK: - Chip Data Structures

    private struct AccountChip: Identifiable {
        let id = UUID()
        let name: String
        let count: Int
    }

    private struct CategoryChip: Identifiable {
        let id = UUID()
        let categoryID: PersistentIdentifier
    }

    private struct SubcategoryChip: Identifiable {
        let id = UUID()
        let name: String
        let iconName: String?
        let colorHex: String?
        let subcategoryID: PersistentIdentifier?
    }

    private struct TagChip: Identifiable {
        let id: PersistentIdentifier
        let tagID: PersistentIdentifier
        let name: String
        let iconName: String
        let colorHex: String?
    }

    private struct NatureChipData: Identifiable {
        let id = UUID()
        let nature: SubcategoryNature
    }

    // MARK: - Chip Computation

    private var categoryChips: [CategoryChip] {
        viewModel.selectedCategories.map { CategoryChip(categoryID: $0) }
    }

    private var subcategoryChips: [SubcategoryChip] {
        var chips: [SubcategoryChip] = []
        for subcategoryID in viewModel.selectedSubcategories {
            // Use allSubcategories Query for chip display
            if let subcategory = allSubcategories.first(where: {
                $0.persistentModelID == subcategoryID
            }) {
                let categoryColor = subcategory.category.colorHex
                chips.append(
                    SubcategoryChip(
                        name: subcategory.name,
                        iconName: subcategory.iconName,
                        colorHex: (subcategory.colorHex?.isEmpty == false
                            ? subcategory.colorHex : nil) ?? categoryColor,
                        subcategoryID: subcategoryID
                    ))
            }
        }
        return chips
    }

    private var natureChips: [NatureChipData] {
        viewModel.selectedNatures.map { NatureChipData(nature: $0) }
    }

    private var selectedAccountChips: [AccountChip] {
        guard !viewModel.selectedAccounts.isEmpty else { return [] }
        let selectedAccountsList =
            accounts
            .filter { viewModel.selectedAccounts.contains($0.persistentModelID) }
        guard !selectedAccountsList.isEmpty else { return [] }

        // Return a single chip with the first account name and total count
        if let firstName = selectedAccountsList.first?.name {
            return [AccountChip(name: firstName, count: selectedAccountsList.count)]
        }
        return []
    }

    private var selectedTagChips: [TagChip] {
        tags.filter { viewModel.selectedTags.contains($0.persistentModelID) }
            .map {
                TagChip(
                    id: $0.persistentModelID,
                    tagID: $0.persistentModelID,
                    name: $0.name,
                    iconName: $0.iconName,
                    colorHex: $0.colorHex
                )
            }
    }
}

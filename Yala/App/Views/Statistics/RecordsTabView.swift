//
//  RecordsTabView.swift
//  Yala
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
    @Environment(\.yalaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Bindable var viewModel: RecordsViewModel
    let accounts: [Account]
    let categories: [Category]
    let tags: [Tag]
    let subcategories: [Subcategory]
    let transactionDateRange: (start: Date, end: Date)
    let defaultCurrencyCode: String
    var onFilterChange: () -> Void

    // Custom period picker state
    @State private var showCustomPeriodPicker: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.none) {
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
            onFilterChange()
        }
    }


    // MARK: - Control Bar

    private var controlBar: some View {
        FilterControlBar(
            periodSelector: periodSelector,
            viewModel: viewModel,
            accounts: accounts,
            categories: categories,
            allSubcategories: subcategories,
            tags: tags,
            animationValue: viewModel.period,
            transactionTypeFilter: viewModel.transactionTypeFilter,
            onClearTransactionType: { viewModel.transactionTypeFilter = .all },
            onFilterChange: onFilterChange
        )
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
        let hasNeedFilter = isIncomeFiltered || isExpenseFiltered

        return VStack(alignment: .center, spacing: DS.Spacing.xs) {
            // Balance (Saldo) - Large and centered (hidden in expenses-only mode)
            if !sessionState.isExpensesOnlyMode {
                Text(
                    YalaFormatter.currency(
                        value: recordsSummary.balance, currencyCode: defaultCurrencyCode)
                )
                .font(DS.Typography.largeTitle)
                .foregroundStyle(.primary)
            }

            // Income and Expense indicators below (tappable to filter)
            HStack(spacing: DS.Spacing.md) {
                // Income button (hidden in expenses-only mode)
                if !sessionState.isExpensesOnlyMode {
                    Button {
                        dsWithAnimation(reduceMotion) {
                            // SSOT: viewModel.selectedTransactionNatures writes to SessionState.shared
                            if isIncomeFiltered {
                                viewModel.selectedTransactionNatures.removeAll()
                            } else {
                                viewModel.selectedTransactionNatures = [.income]
                            }
                            onFilterChange()
                        }
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "arrow.up.right")
                                .font(DS.Typography.labelSmall)
                                .foregroundStyle(Color.incomeGraph)
                            Text(
                                YalaFormatter.currency(
                                    value: recordsSummary.income, currencyCode: defaultCurrencyCode)
                            )
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                        }
                        .opacity(hasNeedFilter && !isIncomeFiltered ? 0.3 : 1.0)
                    }
                    .buttonStyle(.plain)
                }

                // Expense button
                Button {
                    dsWithAnimation(reduceMotion) {
                        // SSOT: viewModel.selectedTransactionNatures writes to SessionState.shared
                        if isExpenseFiltered {
                            // In expenses-only mode, don't allow clearing the expense filter
                            if !sessionState.isExpensesOnlyMode {
                                viewModel.selectedTransactionNatures.removeAll()
                            }
                        } else {
                            viewModel.selectedTransactionNatures = [.expense]
                        }
                        onFilterChange()
                    }
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "arrow.down.right")
                            .font(DS.Typography.labelSmall)
                            .foregroundStyle(Color.expenseGraph)
                        Text(
                            YalaFormatter.currency(
                                value: recordsSummary.expense, currencyCode: defaultCurrencyCode)
                        )
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .opacity(hasNeedFilter && !isExpenseFiltered ? 0.3 : 1.0)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }

    /// Summary from ViewModel (cached, calculated once per filter change instead of per render)
    private var recordsSummary: (balance: Double, income: Double, expense: Double) {
        viewModel.recordsSummary
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
        .yalaSafeBottomPadding()
    }

    // MARK: - Empty State Content

    private var emptyStateContent: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "list.bullet.rectangle")
                .font(DS.Typography.largeTitle)
                .foregroundStyle(.secondary.opacity(0.5))

            Text(L10n.Records.noRecords)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Text(
                viewModel.hasActiveFilters
                    ? L10n.Statistics.noRecordsFiltered
                    : L10n.Statistics.noRecordsDescription
            )
            .font(DS.Typography.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, DS.Spacing.xxxl + DS.Spacing.sm)

            if viewModel.hasActiveFilters {
                Button {
                    viewModel.clearFilters()
                    onFilterChange()
                } label: {
                    Text(L10n.Filters.clearFilters)
                        .font(DS.Typography.label)
                        .foregroundStyle(.thAccent)
                }
                .padding(.top, DS.Spacing.sm)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.xxxl * 2)
    }

}

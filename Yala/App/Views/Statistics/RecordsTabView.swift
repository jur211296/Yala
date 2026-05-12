//
//  RecordsTabView.swift
//  Yala
//
//  Records tab content extracted from DetailContainerView.
//  Provides the records list, hero edge-to-edge (panel-aligned), panel-style
//  filter bar, and empty state.
//

import SwiftData
import SwiftUI

// MARK: - Records Tab View

/// Records tab content with hero, filter chips, and record list.
/// Extracted from DetailContainerView to reduce complexity.
struct RecordsTabView: View {
    @Environment(SessionState.self) private var sessionState
    @Environment(\.yalaTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppPreferences.self) private var appPreferences

    @ScaledMetric(relativeTo: .largeTitle) private var summaryVerticalPadding: CGFloat = 12

    @Bindable var viewModel: RecordsViewModel
    let accounts: [Account]
    let categories: [Category]
    let tags: [Tag]
    let subcategories: [Subcategory]
    let transactionDateRange: (start: Date, end: Date)
    let defaultCurrencyCode: String
    var onFilterChange: () -> Void

    /// Cuando el host quiere title scroll-driven, pasa un binding aquí.
    /// `nil` desactiva el listener (la vista funciona idéntico sin reportar).
    var inlineTitleVisible: Binding<Bool>? = nil

    // Custom period picker state
    @State private var showCustomPeriodPicker: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                // Hero SIEMPRE visible (preserva acceso al period menu incluso en empty state)
                heroSection

                // FilterBar solo cuando hay filtros activos (panel style)
                filterBarPanel

                if viewModel.groupedRecords.isEmpty {
                    emptyStateContent
                } else {
                    recordsListContent
                }
            }
            .padding(.top, DS.Spacing.sm)
        }
        .scrollViewGlassEdges()
        .scrollDrivenVisibility(inlineTitleVisible)
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


    // MARK: - Filter Bar (panel style)

    private var filterBarPanel: some View {
        FilterControlBar(
            periodSelector: EmptyView(),                    // vive en heroTopRow
            viewModel: viewModel,
            accounts: accounts,
            categories: categories,
            allSubcategories: subcategories,
            tags: tags,
            animationValue: viewModel.period,
            transactionTypeFilter: viewModel.transactionTypeFilter,
            onClearTransactionType: { viewModel.transactionTypeFilter = .all },
            onFilterChange: onFilterChange,
            panelStyle: true,
            inlinePeriodSelector: false
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

    // MARK: - Hero Section (edge-to-edge, panel-aligned)

    private var heroSection: some View {
        VStack(spacing: DS.Spacing.md) {
            heroTopRow
            heroSummaryColumn
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, summaryVerticalPadding)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
    }

    private var heroTopRow: some View {
        HStack {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "list.bullet.rectangle")
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(L10n.Stats.Records.heroChip)
                    .font(DS.Typography.title)
                    .foregroundStyle(.primary)
            }
            Spacer()
            periodSelector
        }
    }

    @ViewBuilder
    private var heroSummaryColumn: some View {
        let hasRecords = viewModel.filteredCount > 0

        VStack(alignment: .center, spacing: DS.Spacing.xs) {
            // Balance label + amount — ocultos en empty state (no hay saldo)
            // y en isExpensesOnlyMode (idéntico a summaryRow original L110-116).
            if !sessionState.isExpensesOnlyMode && hasRecords {
                HStack(spacing: DS.Spacing.xxs) {
                    Text(L10n.Stats.Records.balanceLabel)
                    Text("·")
                    Text(viewModel.period.displayName)
                }
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

                Text(
                    appPreferences.currency(recordsSummary.balance, currencyCode: defaultCurrencyCode)
                )
                .font(DS.Typography.largeTitle)
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            }

            // Income / Expense chips (tappables para filtrar nature).
            // Visibles también en empty state — patrón actual de summaryRow.
            incomeExpenseChips

            // Subtítulo motivacional (helper retorna nil si count<=0)
            if let subtitle = RecordsMotivationalLogic.subtitle(forCount: viewModel.filteredCount) {
                Text(localizedMotivational(subtitle))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func localizedMotivational(_ subtitle: RecordsHeroSubtitle) -> String {
        switch subtitle {
        case .one: return L10n.Stats.Records.motivationalOne
        case .many(let n): return L10n.Stats.Records.motivationalMany(n)
        }
    }

    // MARK: - Income / Expense Chips (preserva interacción tap-to-filter del summaryRow original)

    private var incomeExpenseChips: some View {
        let isIncomeFiltered = viewModel.selectedTransactionNatures == [.income]
        let isExpenseFiltered = viewModel.selectedTransactionNatures == [.expense]
        let hasNeedFilter = isIncomeFiltered || isExpenseFiltered

        return HStack(spacing: DS.Spacing.md) {
            // Income button (hidden in expenses-only mode)
            if !sessionState.isExpensesOnlyMode {
                Button {
                    dsWithAnimation(reduceMotion) {
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
                            .accessibilityHidden(true)
                        Text(
                            appPreferences.currency(recordsSummary.income, currencyCode: defaultCurrencyCode)
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
                    if isExpenseFiltered {
                        // En expenses-only mode no permitir limpiar el expense filter
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
                        .accessibilityHidden(true)
                    Text(
                        appPreferences.currency(recordsSummary.expense, currencyCode: defaultCurrencyCode)
                    )
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                }
                .opacity(hasNeedFilter && !isExpenseFiltered ? 0.3 : 1.0)
            }
            .buttonStyle(.plain)
        }
    }

    /// Summary from ViewModel (cached, calculated once per filter change)
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
                .accessibilityHidden(true)

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

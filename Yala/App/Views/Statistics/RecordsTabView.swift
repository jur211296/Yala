//
//  RecordsTabView.swift
//  Yala
//
//  Records tab content — hero summary + panel-style filter bar + lista.
//
//  El title del módulo (`.navigationTitle` "Estadísticas" en `DetailContainerView` /
//  "Registros" en `RecordsStandaloneView`) vive en el host — esta view solo
//  renderiza el contenido scrolleable.
//

import SwiftData
import SwiftUI

// MARK: - Records Tab View

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

    @State private var showCustomPeriodPicker: Bool = false
    @State private var recordsViewMode: RecordsViewMode = .list
    @State private var selectedCalendarDay: Date?
    @State private var calendarMonth: Date = .now
    @Namespace private var viewModeNamespace

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.md) {
                heroSummary
                filterBarPanel

                if viewModel.groupedRecords.isEmpty {
                    emptyStateContent
                } else {
                    viewModeHeader

                    if recordsViewMode == .calendar {
                        RecordsCalendarView(
                            groups: viewModel.groupedRecords,
                            period: viewModel.period,
                            customDateRange: sessionState.customDateRange,
                            currencyCode: defaultCurrencyCode,
                            selectedDay: $selectedCalendarDay,
                            calendarMonth: $calendarMonth
                        )
                        .padding(.horizontal, DS.Spacing.lg)
                    }

                    recordsListContent
                }
            }
            .padding(.top, DS.Spacing.sm)
        }
        .scrollViewGlassEdges()
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
        .onChange(of: viewModel.period) {
            resetCalendarState()
        }
        .onChange(of: viewModel.filteredCount) {
            clampCalendarMonthIfNeeded()
        }
        .onAppear {
            syncCalendarMonth()
        }
    }

    // MARK: - Filter Bar (panel style)

    private var filterBarPanel: some View {
        FilterControlBar(
            periodSelector: EmptyView(),                    // period vive inline en heroSummary
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

    // MARK: - Period Selector (inline en la fila "Saldo · ...")

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

    // MARK: - Hero Summary

    private var heroSummary: some View {
        let hasRecords = viewModel.filteredCount > 0

        return VStack(alignment: .center, spacing: DS.Spacing.xs) {
            periodSelector

            if !sessionState.isExpensesOnlyMode && hasRecords {
                AmountText(
                    value: recordsSummary.balance,
                    currencyCode: defaultCurrencyCode,
                    font: DS.Typography.heroAmount, secondaryFont: DS.Typography.heroAmountSecondary
                )
            }

            incomeExpenseChips

            if let subtitle = RecordsMotivationalLogic.subtitle(forCount: viewModel.filteredCount) {
                Text(localizedMotivational(subtitle))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, summaryVerticalPadding)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
    }

    private func localizedMotivational(_ subtitle: RecordsHeroSubtitle) -> String {
        switch subtitle {
        case .one: return L10n.Stats.Records.motivationalOne
        case .many(let n): return L10n.Stats.Records.motivationalMany(n)
        }
    }

    // MARK: - Income / Expense Chips (tap-to-filter)

    private var incomeExpenseChips: some View {
        let isIncomeFiltered = viewModel.selectedTransactionNatures == [.income]
        let isExpenseFiltered = viewModel.selectedTransactionNatures == [.expense]
        let hasNeedFilter = isIncomeFiltered || isExpenseFiltered

        return HStack(spacing: DS.Spacing.md) {
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
                        AmountText(
                            value: recordsSummary.income,
                            currencyCode: defaultCurrencyCode,
                            font: DS.Typography.subheadline, secondaryFont: DS.Typography.captionSmall,
                            tint: .secondary
                        )
                    }
                    .opacity(hasNeedFilter && !isIncomeFiltered ? 0.3 : 1.0)
                }
                .buttonStyle(.plain)
            }

            Button {
                dsWithAnimation(reduceMotion) {
                    if isExpenseFiltered {
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
                    AmountText(
                        value: recordsSummary.expense,
                        currencyCode: defaultCurrencyCode,
                        font: DS.Typography.subheadline, secondaryFont: DS.Typography.captionSmall,
                        tint: .secondary
                    )
                }
                .opacity(hasNeedFilter && !isExpenseFiltered ? 0.3 : 1.0)
            }
            .buttonStyle(.plain)
        }
    }

    private var recordsSummary: (balance: Double, income: Double, expense: Double) {
        viewModel.recordsSummary
    }

    // MARK: - Records List Content

    /// Grupos a mostrar: todos, o solo el día seleccionado en modo calendario.
    private var displayedGroups: [(date: Date, records: [TransactionItem])] {
        guard recordsViewMode == .calendar, let day = selectedCalendarDay else {
            return viewModel.groupedRecords
        }
        return viewModel.groupedRecords.filter {
            Calendar.current.isDate($0.date, inSameDayAs: day)
        }
    }

    @ViewBuilder
    private var recordsListContent: some View {
        let groups = displayedGroups
        if groups.isEmpty {
            dayEmptyState
        } else {
            LazyVStack(spacing: DS.Spacing.sm, pinnedViews: [.sectionHeaders]) {
                ForEach(groups, id: \.date) { group in
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
    }

    /// Mini empty-state cuando el día seleccionado en el calendario no tiene registros.
    private var dayEmptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(DS.Typography.largeTitle)
                .foregroundStyle(.secondary.opacity(0.5))
                .accessibilityHidden(true)
            Text(L10n.Records.noRecordsThisDay)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.xxxl)
        .yalaSafeBottomPadding()
    }

    // MARK: - View Mode Header (toggle Lista / Calendario)

    private var viewModeHeader: some View {
        HStack {
            Text(L10n.Records.title)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
            Spacer()
            viewModeSelector
        }
        .padding(.horizontal, DS.Spacing.lg)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
    }

    private var viewModeSelector: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(RecordsViewMode.allCases) { mode in
                viewModeButton(for: mode)
            }
        }
    }

    private func viewModeButton(for mode: RecordsViewMode) -> some View {
        let isSelected = recordsViewMode == mode
        return Button {
            dsWithAnimation(reduceMotion) {
                recordsViewMode = mode
                if mode == .list {
                    selectedCalendarDay = nil
                } else {
                    clampCalendarMonthIfNeeded()
                }
            }
        } label: {
            Image(systemName: mode.iconName)
                .font(DS.Typography.labelSmall)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? .white : theme.secondaryText)
                .frame(width: 32, height: 32)
                .background {
                    if isSelected {
                        Circle()
                            .fill(theme.accent)
                            .matchedGeometryEffect(id: "recordsViewMode", in: viewModeNamespace)
                    } else {
                        Circle()
                            .fill(.thSecondaryText.opacity(0.08))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Calendar State

    /// Pone el mes visible (modo paginado) en el mes más reciente con datos.
    private func syncCalendarMonth() {
        guard let maxDate = viewModel.groupedRecords.map(\.date).max() else { return }
        calendarMonth = Calendar.current.startOfDay(for: maxDate)
    }

    /// Si tras cambiar filtros el mes visible quedó fuera del rango de datos, lo reencuadra.
    private func clampCalendarMonthIfNeeded() {
        let dates = viewModel.groupedRecords.map(\.date)
        guard let minDate = dates.min(), let maxDate = dates.max() else { return }
        let cal = Calendar.current
        if calendarMonth < cal.startOfDay(for: minDate) || calendarMonth > maxDate {
            calendarMonth = cal.startOfDay(for: maxDate)
        }
    }

    /// Al cambiar de periodo: limpia el día seleccionado y reencuadra el mes.
    private func resetCalendarState() {
        selectedCalendarDay = nil
        syncCalendarMonth()
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

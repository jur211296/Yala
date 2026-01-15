//
//  PanelView.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftData
import SwiftUI
import UIKit

// MARK: - Panel (pantalla de inicio)

struct PanelView: View {

    init() {
        // FIN-56: Eliminamos el fondo gris por defecto del TabView en modo página
        let pageViewBackground = UIView.appearance(
            whenContainedInInstancesOf: [UIPageViewController.self]
        )
        pageViewBackground.backgroundColor = .clear

        let scrollViewBackground = UIScrollView.appearance(
            whenContainedInInstancesOf: [UIPageViewController.self]
        )
        scrollViewBackground.backgroundColor = .clear
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(SessionState.self) private var sessionState
    @Query(sort: \Account.name, order: .forward) private var accounts: [Account]
    @Query(sort: \Tag.name, order: .forward) private var tags: [Tag]
    @Query(sort: \Subcategory.name, order: .forward) private var allSubcategories: [Subcategory]
    // FIN-46: Transacciones usadas para calcular saldos actuales por cuenta
    @Query(sort: \TransactionItem.date, order: .reverse)
    private var transactions: [TransactionItem]

    // Budgets for widget
    @Query(filter: #Predicate<Budget> { $0.isActive }, sort: \Budget.createdAt, order: .reverse)
    private var budgets: [Budget]

    @State private var viewModel = PanelViewModel()

    @State private var isPresentingSettings = false

    /// Sheet presentation state for account form
    @State private var accountFormSheet: AccountFormSheet?

    /// Trend Detail View State (To be removed/minimized as navigation is gone)
    @State private var trendDetailType: TrendType = .balance

    /// Widget Preferences Sheet
    @State private var showWidgetPreferences = false

    /// New Transaction Sheet
    @State private var showNewTransaction = false

    /// Budget Favorites Settings Sheet
    @State private var showBudgetFavoritesSettings = false

    /// Task for debouncing data recalculations
    @State private var calculationTask: Task<Void, Never>?

    /// Custom period picker sheet
    @State private var showCustomPeriodPicker = false

    @AppStorage("userName") private var userName: String = "Usuario"
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCodeRaw: String = CurrencyCode.pen
        .rawValue
    @AppStorage("accountsSortOrderNames") private var accountsSortOrderNamesRaw: String = ""

    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle(L10n.Panel.greeting(userName))
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            isPresentingSettings = true
                        } label: {
                            Image(systemName: "person.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Color.electricIndigo)
                        }
                    }
                }
                .sheet(item: $accountFormSheet) { sheet in
                    AccountFormView(
                        existingNames: existingAccountNames(editingAccount: sheet.account),
                        accountToEdit: sheet.account
                    )
                    .onDisappear {
                        // Force recalculation when account form closes
                        // (initial balance changes may not trigger @Query immediately)
                        recalculateData()
                    }
                }
                .sheet(isPresented: $isPresentingSettings) {
                    ProfileView()
                }
                .sheet(isPresented: $showWidgetPreferences) {
                    WidgetPreferencesView(viewModel: viewModel)
                        .presentationDragIndicator(.visible)
                }
                .sheet(isPresented: $showNewTransaction) {
                    // Convert selected subcategory ID back to name for prefill
                    let prefillSubcategoryName: String? = viewModel.selectedSubcategoryIDs.first.flatMap { subcategoryID in
                        allSubcategories.first(where: { $0.persistentModelID == subcategoryID })?.name
                    }
                    NewTransactionView(
                        prefillAccountID: viewModel.selectedAccountID,
                        prefillCategoryID: viewModel.selectedCategoryID,
                        prefillSubcategoryName: prefillSubcategoryName
                    )
                }
                .sheet(isPresented: $showCustomPeriodPicker) {
                    CustomPeriodPickerSheet(
                        minDate: transactionDateRange.start,
                        maxDate: transactionDateRange.end,
                        currentRange: sessionState.customDateRange
                    )
                }
                .sheet(isPresented: $showBudgetFavoritesSettings) {
                    NavigationStack {
                        BudgetsFavoritesSettingsView()
                    }
                }
        }
        .onAppear {
            seedCategoriesIfNeeded(in: modelContext)

            // Sync all filters from SessionState -> ViewModel
            viewModel.syncFromSessionState(sessionState)

            // Ensure consistency
            let newOrder = viewModel.ensureAccountsSortOrderConsistency(
                accounts: accounts,
                currentOrderRaw: accountsSortOrderNamesRaw
            )
            if newOrder != accountsSortOrderNamesRaw {
                accountsSortOrderNamesRaw = newOrder
            }

            // Initial Trend Calculation (async to avoid blocking UI)
            recalculateData()
        }
        .onChange(of: accounts) {
            let newOrder = viewModel.ensureAccountsSortOrderConsistency(
                accounts: accounts,
                currentOrderRaw: accountsSortOrderNamesRaw
            )
            if newOrder != accountsSortOrderNamesRaw {
                accountsSortOrderNamesRaw = newOrder
            }
        }
        .onChange(of: viewModel.selectedAccountID) {
            // Sync to SessionState and recalculate
            viewModel.syncToSessionState(sessionState)
            recalculateData()
        }
        .onChange(of: viewModel.selectedCategoryID) {
            // Sync to SessionState and recalculate
            viewModel.syncToSessionState(sessionState)
            recalculateData()
        }
        .onChange(of: viewModel.selectedSubcategoryIDs) {
            // Sync to SessionState and recalculate
            viewModel.syncToSessionState(sessionState)
            recalculateData()
        }
        .onChange(of: viewModel.selectedNature) {
            // Sync to SessionState and recalculate
            viewModel.syncToSessionState(sessionState)
            recalculateData()
        }
        .onChange(of: transactions) {
            // Recalculate when transactions change
            recalculateData()
        }
        .onChange(of: budgets) {
            // Recalculate when budgets change (favorites toggled, reordered, etc.)
            recalculateData()
        }
        .onChange(of: defaultCurrencyCodeRaw) {
            // Recalculate when preferred currency changes
            recalculateData()
        }
        .onChange(of: viewModel.trendType) {
            // Sync trend type to SessionState when it changes
            viewModel.syncToSessionState(sessionState)
            recalculateData()
        }
        .modifier(
            PanelSessionObservers(
                sessionState: sessionState,
                syncFromSessionState: { viewModel.syncFromSessionState(sessionState) },
                recalculateData: recalculateData
            )
        )
    }

    private var mainContent: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    accountsSection
                    totalBalanceSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }

            // Botón flotante de nuevo registro
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        showNewTransaction = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.electricIndigo)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive())
                    .shadow(color: Color.black.opacity(0.20), radius: 20, x: 0, y: 10)
                    .padding(.trailing, 20)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.Panel.accounts)
                .font(.title2.weight(.semibold))

            AccountsCarouselView(
                viewModel: viewModel,
                orderedAccounts: viewModel.orderedActiveAccounts(
                    from: accounts,
                    sortOrderNames: accountsSortOrderNamesRaw.split(separator: "|").map(String.init)
                ),
                transactions: transactions,
                onAddAccount: {
                    accountFormSheet = AccountFormSheet(account: nil)
                },
                onEditAccount: { account in
                    accountFormSheet = AccountFormSheet(account: account)
                }
            )
        }
    }

    private var totalBalanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Unified Period Selector & Filters Row
            HStack(alignment: .center, spacing: 12) {
                TrendsPeriodMenu(
                    selectedPeriod: sessionState.selectedPeriod,
                    customDateRange: sessionState.customDateRange,
                    onSelect: { period in
                        sessionState.selectedPeriod = period
                    },
                    onCustomTapped: {
                        showCustomPeriodPicker = true
                    }
                )

                // Filter chips (Scrollable to the right)
                let hasAccountFilter = viewModel.selectedAccountID != nil
                let hasDateFilter = viewModel.focusedDate != nil
                let hasCategoryFilter = viewModel.selectedCategoryID != nil
                let hasNatureFilter = viewModel.selectedNature != nil
                let hasSubcategoryFilter = !viewModel.selectedSubcategoryIDs.isEmpty
                let hasTagFilter = !viewModel.selectedTags.isEmpty
                let hasCurrencyFilter = !viewModel.selectedCurrencies.isEmpty
                let hasAmountFilter = viewModel.amountCondition.isActive
                let hasNoteFilter = !viewModel.searchText.isEmpty

                let activeFilterCount = [
                    hasAccountFilter, hasDateFilter, hasCategoryFilter,
                    hasNatureFilter, hasSubcategoryFilter, hasTagFilter,
                    hasCurrencyFilter, hasAmountFilter, hasNoteFilter,
                ].filter { $0 }.count

                if activeFilterCount > 0 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            // Account Chip
                            if let selectedID = viewModel.selectedAccountID,
                                let account = accounts.first(where: {
                                    $0.persistentModelID == selectedID
                                })
                            {
                                FilterChipView(
                                    accountName: account.name,
                                    onClear: { viewModel.selectedAccountID = nil }
                                )
                            }

                            // Date Chip
                            if let focusedDate = viewModel.focusedDate {
                                FilterChipView(
                                    text: "Fecha: \(formattedDate(focusedDate))",
                                    onClear: {
                                        withAnimation {
                                            viewModel.focusedDate = nil
                                        }
                                    }
                                )
                            }

                            // Category Chip (aggregated from selected subcategory IDs)
                            // Skip if all subcategories are selected (= no filter = "Todas")
                            let selectedSubsByID = allSubcategories.filter {
                                sessionState.selectedSubcategoryIDs.contains($0.persistentModelID)
                            }
                            let isAllSelected =
                                !selectedSubsByID.isEmpty
                                && selectedSubsByID.count == allSubcategories.count

                            if !isAllSelected && !selectedSubsByID.isEmpty {
                                let parentCategories = Set(
                                    selectedSubsByID.compactMap { $0.category })
                                if let firstCategory = parentCategories.first {
                                    FilterChipView(
                                        categoryName: firstCategory.name,
                                        iconName: firstCategory.iconName,
                                        colorHex: firstCategory.colorHex,
                                        count: parentCategories.count,
                                        onClear: {
                                            viewModel.selectedCategoryID = nil
                                            viewModel.selectedSubcategoryIDs.removeAll()
                                            sessionState.selectedCategoryIDs.removeAll()
                                            sessionState.selectedSubcategoryIDs.removeAll()
                                        }
                                    )
                                }

                                // Subcategory Chip (aggregated from selected subcategory IDs)
                                if let firstSub = selectedSubsByID.first {
                                    let color =
                                        (firstSub.colorHex?.isEmpty == false
                                            ? firstSub.colorHex : nil)
                                        ?? firstSub.category.colorHex
                                    FilterChipView(
                                        subcategoryName: firstSub.name,
                                        iconName: firstSub.iconName,
                                        colorHex: color,
                                        count: selectedSubsByID.count,
                                        onClear: {
                                            viewModel.selectedSubcategoryIDs.removeAll()
                                            sessionState.selectedSubcategoryIDs.removeAll()
                                        }
                                    )
                                }
                            }

                            // Nature Chip
                            if let nature = viewModel.selectedNature {
                                FilterChipView(
                                    nature: nature,
                                    onClear: {
                                        withAnimation { viewModel.selectedNature = nil }
                                    }
                                )
                            }

                            // Tag Chips
                            ForEach(Array(viewModel.selectedTags), id: \.self) { tagID in
                                if let tag = tags.first(where: { $0.persistentModelID == tagID }) {
                                    FilterChipView(
                                        tagName: tag.name,
                                        colorHex: tag.colorHex,
                                        onClear: {
                                            withAnimation {
                                                viewModel.selectedTags.remove(tagID)
                                                viewModel.syncToSessionState(sessionState)
                                            }
                                        }
                                    )
                                }
                            }

                            // Currency Chips
                            ForEach(Array(viewModel.selectedCurrencies), id: \.self) { currency in
                                FilterChipView(
                                    currencyCode: currency.rawValue,
                                    onClear: {
                                        withAnimation {
                                            viewModel.selectedCurrencies.remove(currency)
                                            viewModel.syncToSessionState(sessionState)
                                        }
                                    }
                                )
                            }

                            // Amount Chip
                            if viewModel.amountCondition.isActive {
                                FilterChipView(
                                    amountText: viewModel.amountCondition.displayText,
                                    onClear: {
                                        withAnimation {
                                            viewModel.amountCondition = .any
                                            viewModel.syncToSessionState(sessionState)
                                        }
                                    }
                                )
                            }

                            // Note/Search Chip
                            if !viewModel.searchText.isEmpty {
                                FilterChipView(
                                    noteText: viewModel.searchText,
                                    onClear: {
                                        withAnimation {
                                            viewModel.searchText = ""
                                            viewModel.syncToSessionState(sessionState)
                                        }
                                    }
                                )
                            }

                            // Clear All Button
                            if activeFilterCount > 1 {
                                Button {
                                    withAnimation {
                                        clearAllPanelFilters()
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } else {
                    Spacer()
                }
            }
            .padding(.bottom, 8)

            HStack {
                Text(L10n.Panel.widgets)
                    .font(.title2.weight(.semibold))

                Spacer()

                Button {
                    showWidgetPreferences = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.primary)
                }
            }
            .padding(.trailing, 4)

            // Custom Grid Layout (VStack of Rows)
            VStack(spacing: 16) {
                ForEach(viewModel.layoutRows) { row in
                    switch row.type {
                    case .fullWidth(let config):
                        widgetView(for: config)
                            .clipped()  // Prevent content overflow
                    case .halfWidthPair(let left, let right):
                        HStack(spacing: 16) {
                            widgetView(for: left)
                                .frame(maxWidth: .infinity)
                                .clipped()  // Prevent content overflow

                            if let right = right {
                                widgetView(for: right)
                                    .frame(maxWidth: .infinity)
                                    .clipped()  // Prevent content overflow
                            } else {
                                // Spacer for empty slot
                                Color.clear
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }

            EmptyView()
                .onChange(of: viewModel.selectedCategoryID) {
                    recalculateData()
                }
                .onChange(of: viewModel.focusedDate) {
                    recalculateData()
                }
                .onChange(of: viewModel.selectedNature) {
                    recalculateData()
                }
        }

    }

    private func formattedAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "0.00"
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocale.current
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    /// Recalculate trend data with smooth animation
    private func recalculateData() {
        // Direct synchronous call for instant response
        withAnimation(.easeOut(duration: 0.15)) {
            viewModel.calculateTrendData(
                accounts: accounts,
                transactions: transactions,
                defaultCurrencyCode: defaultCurrencyCodeRaw,
                context: modelContext,
                sessionState: sessionState
            )

            // Calculate budgets widget data
            viewModel.calculateBudgetsWidget(
                budgets: budgets,
                transactions: transactions,
                defaultCurrencyCode: defaultCurrencyCodeRaw
            )
        }
    }

    // MARK: - Widget Helpers

    @ViewBuilder
    private func widgetView(for config: WidgetConfig) -> some View {
        // Render actual widget directly - calculations are fast enough now
        actualWidgetView(for: config)
    }

    @ViewBuilder
    private func skeletonView(for config: WidgetConfig) -> some View {
        switch config.type {
        case .trend:
            TrendWidgetSkeleton()
        case .cashFlow:
            CashFlowSkeleton()
        case .latestRecords:
            LatestRecordsSkeleton()
        case .categoriesPie:
            CategoriesPieSkeleton()
        default:
            WidgetSkeleton(height: config.size == .large ? 300 : 200)
        }
    }

    @ViewBuilder
    private func actualWidgetView(for config: WidgetConfig) -> some View {
        let preferredCurrency = CurrencyCode(rawValue: defaultCurrencyCodeRaw) ?? .pen
        let balance = viewModel.displayedBalanceInDefaultCurrency(
            accounts: accounts,
            transactions: transactions,
            defaultCurrencyCode: defaultCurrencyCodeRaw,
            context: modelContext
        )

        // All widgets below have 'onShowMore' or 'onViewDetail' removed (or passed as nil) to remove chevrons

        if config.type == .trend {
            TrendWidget(
                viewModel: viewModel,
                sessionState: sessionState,
                currencyCode: preferredCurrency.rawValue,
                currentBalance: balance
            )
            .onChange(of: viewModel.subcategoriesWidgetFilter) { _, _ in
                recalculateData()
            }
            .onChange(of: viewModel.selectedSubcategoryIDs) { _, _ in
                recalculateData()
            }
            .onChange(of: viewModel.trendType) { _, _ in
                recalculateData()
            }
            .onChange(of: viewModel.subcategoriesWidgetFilter) { _, _ in
                recalculateData()
            }
            .onChange(of: viewModel.selectedSubcategoryIDs) { _, _ in
                recalculateData()
            }
            .onChange(of: viewModel.trendType) { _, _ in
                recalculateData()
            }
        } else if config.type == .topSpending {
            TopCategoriesWidget(
                categories: viewModel.topSpendingCategories,
                currencyCode: preferredCurrency.rawValue,
                selectedCategoryID: viewModel.selectedCategoryID,
                onSelectCategory: { id in
                    withAnimation {
                        viewModel.toggleCategoryFilter(id)
                    }
                },
                onShowMore: { sessionState.navigateToDetail(.categories) },
                size: mapWidgetSize(config.size)
            )
        } else if config.type == .topSubcategories {
            TopSubcategoriesWidget(
                subcategories: viewModel.topSubcategories,
                currencyCode: preferredCurrency.rawValue,
                globalCategoryFilterID: viewModel.selectedCategoryID,
                localCategoryFilterID: $viewModel.subcategoriesWidgetFilter,
                onSelectSubcategory: { subcategoryID in
                    withAnimation {
                        viewModel.toggleSubcategoryFilter(
                            subcategoryID,
                            transactions: transactions,
                            accounts: accounts,
                            defaultCurrencyCode: preferredCurrency.rawValue,
                            context: modelContext,
                            sessionState: sessionState
                        )
                    }
                },
                selectedSubcategoryIDs: viewModel.selectedSubcategoryIDs,
                onShowMore: { sessionState.navigateToDetail(.categories) },
                size: mapWidgetSize(config.size)
            )
        } else if config.type == .categoriesPie {
            CategoriesPieWidget(
                categories: viewModel.topSpendingCategories,
                currencyCode: preferredCurrency.rawValue,
                selectedCategoryID: viewModel.selectedCategoryID,
                onSelectCategory: { id in
                    withAnimation {
                        viewModel.toggleCategoryFilter(id)
                    }
                },
                onShowDetail: { sessionState.navigateToDetail(.categories) },
                size: config.size
            )
        } else if config.type == .subcategoriesPie {
            SubcategoriesPieWidget(
                subcategories: viewModel.topSubcategories,
                currencyCode: preferredCurrency.rawValue,
                selectedCategoryID: viewModel.selectedCategoryID,
                selectedSubcategoryIDs: viewModel.selectedSubcategoryIDs,
                onSelectSubcategory: { subcategoryID in
                    withAnimation {
                        viewModel.toggleSubcategoryFilter(
                            subcategoryID,
                            transactions: transactions,
                            accounts: accounts,
                            defaultCurrencyCode: preferredCurrency.rawValue,
                            context: modelContext,
                            sessionState: sessionState
                        )
                    }
                },
                onShowDetail: { sessionState.navigateToDetail(.categories) },
                size: config.size
            )
        } else if config.type == .cashFlow {
            if let summary = viewModel.cashFlowSummary {
                CashFlowWidget(
                    summary: summary,
                    size: config.size,
                    period: viewModel.selectedPeriod.rawValue,
                    grouping: viewModel.cashFlowGrouping,
                    interval: viewModel.currentInterval,
                    onShowDetail: { sessionState.navigateToDetail(.trends) },
                    displayMode: viewModel.trendType
                )
            } else {
                EmptyView()
            }
        } else if config.type == .latestRecords {
            RecentRecordsWidget(
                records: viewModel.latestRecords,
                currencyCode: preferredCurrency.rawValue,
                onShowMore: { sessionState.navigateToDetail(.records) }
            )
        } else if config.type == .expensesByNature {
            NatureTrendWidget(
                trendPoints: viewModel.natureTrendPoints,
                selectedNature: viewModel.selectedNature,
                currencyCode: preferredCurrency.rawValue,
                size: mapWidgetSize(config.size),
                grouping: viewModel.natureGrouping,
                interval: viewModel.currentInterval,
                onSelectNature: { nature in
                    withAnimation {
                        viewModel.toggleNatureFilter(nature)
                    }
                },
                onShowDetail: { sessionState.navigateToDetail(.categories) }
            )
        } else if config.type == .exchangeRate {
            ExchangeRateWidget(
                data: viewModel.exchangeRateWidgetData,
                preferredCurrency: preferredCurrency.rawValue,
                selectedCurrencies: $viewModel.selectedComparisonCurrencies,
                grouping: viewModel.exchangeRateGrouping,
                onShowDetail: nil  // REMOVED CHEVRON
            )
        } else if config.type == .budgets {
            BudgetsWidget(
                budgets: viewModel.topBudgetSummaries,
                currencyCode: preferredCurrency.rawValue,
                hasBudgetsButNoFavorites: viewModel.hasBudgetsButNoFavorites,
                selectedBudgetID: sessionState.selectedBudgetID,
                onSelectBudget: { budget in
                    sessionState.applyBudgetFilters(budget)
                },
                onShowMore: { sessionState.selectedMainTab = .planning },
                onEditFavorites: { showBudgetFavoritesSettings = true },
                size: mapBudgetsWidgetSize(config.size)
            )
        }
    }

    private func mapWidgetSize(_ size: WidgetSize) -> TopCategoriesWidget.CardSize {
        switch size {
        case .medium: return .medium
        case .large: return .large
        }
    }

    private func mapBudgetsWidgetSize(_ size: WidgetSize) -> BudgetsWidget.CardSize {
        switch size {
        case .medium: return .medium
        case .large: return .large
        }
    }

    // MARK: - Helpers

    private func existingAccountNames(editingAccount: Account?) -> [String] {
        guard let editingAccount = editingAccount else {
            return accounts.map { $0.name }
        }
        return
            accounts
            .filter { $0.persistentModelID != editingAccount.persistentModelID }
            .map { $0.name }
    }

    /// Date range of all transactions (for custom period picker limits)
    private var transactionDateRange: (start: Date, end: Date) {
        let sortedDates = transactions.map(\.date).sorted()
        let start = sortedDates.first ?? Date()
        let end = sortedDates.last ?? Date()
        return (start, end)
    }

    /// Clear all Panel filters and sync to SessionState
    private func clearAllPanelFilters() {
        viewModel.selectedAccountID = nil
        viewModel.focusedDate = nil
        viewModel.selectedCategoryID = nil
        viewModel.selectedSubcategoryIDs.removeAll()
        viewModel.selectedNature = nil
        viewModel.selectedTags.removeAll()
        viewModel.selectedCurrencies.removeAll()
        viewModel.amountCondition = .any
        viewModel.searchText = ""
        viewModel.syncToSessionState(sessionState)
    }
}

// MARK: - Sheet Wrapper

/// Wrapper to enable `.sheet(item:)` pattern for both new and edit account forms.
struct AccountFormSheet: Identifiable {
    let id = UUID()
    let account: Account?
}

// MARK: - Panel Observers

/// Encapsulates SessionState onChange observers to reduce body complexity and avoid type-checker limits
private struct PanelSessionObservers: ViewModifier {
    let sessionState: SessionState
    let syncFromSessionState: () -> Void
    let recalculateData: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: sessionState.selectedPeriod) {
                syncFromSessionState()
                recalculateData()
            }
            .onChange(of: sessionState.selectedAccountIDs) {
                syncFromSessionState()
                recalculateData()
            }
            .onChange(of: sessionState.selectedCategoryIDs) {
                syncFromSessionState()
                recalculateData()
            }
            .onChange(of: sessionState.selectedNatures) {
                syncFromSessionState()
                recalculateData()
            }
            .onChange(of: sessionState.selectedSubcategoryIDs) {
                syncFromSessionState()
                recalculateData()
            }
            .onChange(of: sessionState.selectedTags) {
                syncFromSessionState()
                recalculateData()
            }
            .onChange(of: sessionState.selectedCurrencies) {
                syncFromSessionState()
                recalculateData()
            }
            .onChange(of: sessionState.amountCondition) {
                syncFromSessionState()
                recalculateData()
            }
            .onChange(of: sessionState.searchText) {
                syncFromSessionState()
                recalculateData()
            }
            .onChange(of: sessionState.selectedTrendMetric) {
                syncFromSessionState()
                recalculateData()
            }
            .onChange(of: sessionState.customDateRange) {
                syncFromSessionState()
                recalculateData()
            }
    }
}

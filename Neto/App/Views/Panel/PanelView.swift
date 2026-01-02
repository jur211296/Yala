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
    // FIN-46: Transacciones usadas para calcular saldos actuales por cuenta
    @Query(sort: \TransactionItem.date, order: .reverse)
    private var transactions: [TransactionItem]

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

    /// Task for debouncing data recalculations
    @State private var calculationTask: Task<Void, Never>?

    @AppStorage("userName") private var userName: String = "Usuario"
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCodeRaw: String = CurrencyCode.pen
        .rawValue
    @AppStorage("accountsSortOrderNames") private var accountsSortOrderNamesRaw: String = ""

    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("Habla neto, \(userName)")
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
                }
                .sheet(isPresented: $isPresentingSettings) {
                    ProfileView()
                }
                .sheet(isPresented: $showWidgetPreferences) {
                    WidgetPreferencesView(viewModel: viewModel)
                        .presentationDragIndicator(.visible)
                }
                .sheet(isPresented: $showNewTransaction) {
                    NewTransactionView(
                        prefillAccountID: viewModel.selectedAccountID,
                        prefillCategoryID: viewModel.selectedCategoryID,
                        prefillSubcategoryName: viewModel.selectedSubcategoryID
                    )
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
        .onChange(of: viewModel.selectedSubcategoryID) {
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
        .onChange(of: defaultCurrencyCodeRaw) {
            // Recalculate when preferred currency changes
            recalculateData()
        }
        .onChange(of: sessionState.selectedPeriod) {
            // Sync Session -> ViewModel
            viewModel.syncFromSessionState(sessionState)
            recalculateData()
        }
        // Also sync when SessionState filters change (from Statistics tab)
        .onChange(of: sessionState.selectedAccountIDs) {
            viewModel.syncFromSessionState(sessionState)
            recalculateData()
        }
        .onChange(of: sessionState.selectedCategoryIDs) {
            viewModel.syncFromSessionState(sessionState)
            recalculateData()
        }
        .onChange(of: sessionState.selectedNatures) {
            viewModel.syncFromSessionState(sessionState)
            recalculateData()
        }
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
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 60)
                            .background(
                                Circle()
                                    .fill(Color.electricIndigo)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.35), lineWidth: 1.2)
                            )
                            .shadow(color: Color.black.opacity(0.20), radius: 20, x: 0, y: 10)
                    }
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
                    onSelect: { period in
                        sessionState.selectedPeriod = period
                    }
                )

                // Filter chips (Scrollable to the right)
                let hasAccountFilter = viewModel.selectedAccountID != nil
                let hasDateFilter = viewModel.focusedDate != nil
                let hasCategoryFilter = viewModel.selectedCategoryID != nil
                let hasNatureFilter = viewModel.selectedNature != nil
                let hasSubcategoryFilter = viewModel.selectedSubcategoryID != nil

                if hasAccountFilter || hasDateFilter || hasCategoryFilter || hasNatureFilter
                    || hasSubcategoryFilter
                {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            if let selectedID = viewModel.selectedAccountID,
                                let account = accounts.first(where: {
                                    $0.persistentModelID == selectedID
                                })
                            {
                                HStack(spacing: 6) {
                                    Text(account.name)
                                        .font(.caption)

                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial, in: Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                )
                                .foregroundStyle(.primary)
                                .onTapGesture {
                                    viewModel.selectedAccountID = nil
                                }
                            }

                            if let focusedDate = viewModel.focusedDate {
                                HStack(spacing: 6) {
                                    Text("Fecha: \(formattedDate(focusedDate))")
                                        .font(.caption)

                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial, in: Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                )
                                .foregroundStyle(.primary)
                                .onTapGesture {
                                    withAnimation {
                                        viewModel.focusedDate = nil
                                    }
                                }
                            }

                            // Category Chip
                            if let categoryID = viewModel.selectedCategoryID,
                                let category = viewModel.topSpendingCategories.first(where: {
                                    $0.category.persistentModelID == categoryID
                                })?.category
                            {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color(hex: category.colorHex))
                                        .frame(width: 8, height: 8)

                                    Text(category.name)
                                        .font(.caption)

                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial, in: Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                )
                                .foregroundStyle(.primary)
                                .onTapGesture {
                                    viewModel.selectedCategoryID = nil
                                }
                            }

                            // Subcategory Chip
                            if let subcategoryID = viewModel.selectedSubcategoryID {
                                HStack(spacing: 6) {
                                    Image(systemName: "list.bullet.indent")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)

                                    Text(subcategoryID)
                                        .font(.caption)

                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial, in: Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                )
                                .foregroundStyle(.primary)
                                .onTapGesture {
                                    // Clear ONLY subcategory filter
                                    withAnimation {
                                        viewModel.selectedSubcategoryID = nil
                                    }
                                }
                            }

                            // Nature Chip
                            if let nature = viewModel.selectedNature {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(nature.color)
                                        .frame(width: 8, height: 8)

                                    Text(nature.displayName)
                                        .font(.caption)

                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial, in: Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                )
                                .foregroundStyle(.primary)
                                .onTapGesture {
                                    withAnimation {
                                        viewModel.selectedNature = nil
                                    }
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
                Text("Widgets")
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
                    case .halfWidthPair(let left, let right):
                        HStack(spacing: 16) {
                            widgetView(for: left)
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)

                            if let right = right {
                                widgetView(for: right)
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fit)
                            } else {
                                // Spacer for empty slot
                                Color.clear
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fit)
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

    /// Recalculate trend data with debouncing and smooth animation
    private func recalculateData() {
        // Cancel any pending calculation
        calculationTask?.cancel()

        calculationTask = Task {
            // Show skeleton for initial load only (when data is empty)
            let showSkeleton = viewModel.chartTransactions.isEmpty
            if showSkeleton {
                await MainActor.run {
                    viewModel.isCalculating = true
                }
            }

            try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms

            guard !Task.isCancelled else { return }

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.calculateTrendData(
                        accounts: accounts,
                        transactions: transactions,
                        defaultCurrencyCode: defaultCurrencyCodeRaw,
                        context: modelContext
                    )
                    viewModel.isCalculating = false
                }
            }
        }
    }

    // MARK: - Widget Helpers

    @ViewBuilder
    private func widgetView(for config: WidgetConfig) -> some View {
        // Show skeleton during initial calculation
        if viewModel.isCalculating {
            skeletonView(for: config)
        } else {
            actualWidgetView(for: config)
        }
    }

    @ViewBuilder
    private func skeletonView(for config: WidgetConfig) -> some View {
        switch config.type {
        case .trend:
            TrendCardSkeleton()
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
            TrendCardView(
                viewModel: viewModel,
                size: config.size,
                currencyCode: preferredCurrency.rawValue,
                currentBalance: balance
            )
            .onChange(of: viewModel.subcategoriesWidgetFilter) { _, _ in
                recalculateData()
            }
            .onChange(of: viewModel.selectedSubcategoryID) { _, _ in
                recalculateData()
            }
            .onChange(of: viewModel.trendType) { _, _ in
                recalculateData()
            }
            .onChange(of: viewModel.subcategoriesWidgetFilter) { _, _ in
                recalculateData()
            }
            .onChange(of: viewModel.selectedSubcategoryID) { _, _ in
                recalculateData()
            }
            .onChange(of: viewModel.trendType) { _, _ in
                recalculateData()
            }
        } else if config.type == .topSpending {
            TopSpendingCardView(
                categories: viewModel.topSpendingCategories,
                currencyCode: preferredCurrency.rawValue,
                selectedCategoryID: viewModel.selectedCategoryID,
                onSelectCategory: { id in
                    withAnimation {
                        viewModel.toggleCategoryFilter(id)
                    }
                },
                onShowMore: nil,  // REMOVED CHEVRON
                size: mapWidgetSize(config.size)
            )
        } else if config.type == .topSubcategories {
            TopSubcategoriesCardView(
                subcategories: viewModel.topSubcategories,
                currencyCode: preferredCurrency.rawValue,
                globalCategoryFilterID: viewModel.selectedCategoryID,
                localCategoryFilterID: $viewModel.subcategoriesWidgetFilter,
                onSelectSubcategory: { name in
                    withAnimation {
                        viewModel.toggleSubcategoryFilter(
                            name,
                            transactions: transactions,
                            accounts: accounts,
                            defaultCurrencyCode: preferredCurrency.rawValue,
                            context: modelContext
                        )
                    }
                },
                selectedSubcategoryID: viewModel.selectedSubcategoryID,
                onShowMore: nil,
                size: mapWidgetSize(config.size)
            )
        } else if config.type == .categoriesPie {
            CategoriesPieChartCardView(
                categories: viewModel.topSpendingCategories,
                currencyCode: preferredCurrency.rawValue,
                selectedCategoryID: viewModel.selectedCategoryID,
                onSelectCategory: { id in
                    withAnimation {
                        viewModel.toggleCategoryFilter(id)
                    }
                },
                onShowDetail: nil,
                size: config.size
            )
        } else if config.type == .subcategoriesPie {
            SubcategoriesPieChartCardView(
                subcategories: viewModel.topSubcategories,
                currencyCode: preferredCurrency.rawValue,
                selectedCategoryID: viewModel.selectedCategoryID,
                selectedSubcategoryID: viewModel.selectedSubcategoryID,
                onSelectSubcategory: { name in
                    withAnimation {
                        viewModel.toggleSubcategoryFilter(
                            name,
                            transactions: transactions,
                            accounts: accounts,
                            defaultCurrencyCode: preferredCurrency.rawValue,
                            context: modelContext
                        )
                    }
                },
                onShowDetail: nil,
                size: config.size
            )
        } else if config.type == .cashFlow {
            if let summary = viewModel.cashFlowSummary {
                CashFlowCardView(
                    summary: summary,
                    size: config.size,
                    period: viewModel.selectedPeriod.rawValue,
                    grouping: viewModel.cashFlowGrouping,
                    interval: viewModel.currentInterval,
                    onShowDetail: nil  // REMOVED CHEVRON
                )
            } else {
                EmptyView()
            }
        } else if config.type == .latestRecords {
            LatestRecordsCardView(
                records: viewModel.latestRecords,
                currencyCode: preferredCurrency.rawValue,
                onShowMore: nil  // REMOVED CHEVRON
            )
        } else if config.type == .expensesByNature {
            NatureSpendingCardView(
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
                onShowDetail: nil  // Explicitly remove chevron
            )
        } else if config.type == .exchangeRate {
            ExchangeRateCardView(
                data: viewModel.exchangeRateWidgetData,
                preferredCurrency: preferredCurrency.rawValue,
                selectedCurrencies: $viewModel.selectedComparisonCurrencies,
                grouping: viewModel.exchangeRateGrouping,
                onShowDetail: nil  // REMOVED CHEVRON
            )
        }
    }

    private func mapWidgetSize(_ size: WidgetSize) -> TopSpendingCardView.CardSize {
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
}

// MARK: - Sheet Wrapper

/// Wrapper to enable `.sheet(item:)` pattern for both new and edit account forms.
struct AccountFormSheet: Identifiable {
    let id = UUID()
    let account: Account?
}

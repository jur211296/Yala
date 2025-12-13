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
    @Query(sort: \Account.name, order: .forward) private var accounts: [Account]
    // FIN-46: Transacciones usadas para calcular saldos actuales por cuenta
    @Query(sort: \TransactionItem.date, order: .reverse)
    private var transactions: [TransactionItem]

    @State private var viewModel = PanelViewModel()

    @State private var isPresentingSettings = false

    /// Sheet presentation state for account form
    @State private var accountFormSheet: AccountFormSheet?

    /// Navigation to trend detail view
    @State private var showTrendDetail = false
    @State private var trendDetailType: TrendType = .balance

    /// Widget Preferences Sheet
    @State private var showWidgetPreferences = false

    @AppStorage("userName") private var userName: String = "Usuario"
    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCodeRaw: String = CurrencyCode.pen
        .rawValue
    @AppStorage("accountsSortOrderNames") private var accountsSortOrderNamesRaw: String = ""

    // FIN-57: Persistencia del filtro (Removed)
    // panelPeriodTypeRaw removed
    // panelPeriodCustomStartISO removed
    // panelPeriodCustomEndISO removed

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
            // .sheet(isPresented: $viewModel.isPresentingCustomPeriodSheet) (Removed)

        }
        .onAppear {
            seedCategoriesIfNeeded(in: modelContext)

            // Sync AppStorage -> ViewModel
            syncStateToViewModel()

            // Ensure consistency
            let newOrder = viewModel.ensureAccountsSortOrderConsistency(
                accounts: accounts,
                currentOrderRaw: accountsSortOrderNamesRaw
            )
            if newOrder != accountsSortOrderNamesRaw {
                accountsSortOrderNamesRaw = newOrder
            }

            // Initial Trend Calculation
            viewModel.calculateTrendData(
                accounts: accounts,
                transactions: transactions,
                defaultCurrencyCode: defaultCurrencyCodeRaw
            )
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
        // Sync ViewModel -> AppStorage
        // .onChange(of: viewModel.panelPeriodType)... Removed

        // .onChange(of: viewModel.customPeriodStart)... Removed

        // .onChange(of: viewModel.customPeriodEnd)... Removed
        // .onChange(of: viewModel.panelPeriodType)... Removed

        .onChange(of: viewModel.selectedAccountID) {
            // Recalculate when selected account changes
            viewModel.calculateTrendData(
                accounts: accounts,
                transactions: transactions,
                defaultCurrencyCode: defaultCurrencyCodeRaw
            )
        }
        .onChange(of: transactions) {
            // Recalculate when transactions change
            viewModel.calculateTrendData(
                accounts: accounts,
                transactions: transactions,
                defaultCurrencyCode: defaultCurrencyCodeRaw
            )
        }
    }

    private func syncStateToViewModel() {
        // No filter syncing needed anymore
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

            // FIN-XX: Botón flotante de nuevo registro, siempre visible
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        // TODO: Implement new record flow
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
            Text("Cuentas")
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

    // private var periodFilterSection... Removed

    private var totalBalanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Periodo", selection: $viewModel.selectedPeriod) {
                ForEach(PanelViewModel.TrendPeriod.allCases) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 8)
            .onChange(of: viewModel.selectedPeriod) {
                viewModel.calculateTrendData(
                    accounts: accounts,
                    transactions: transactions,
                    defaultCurrencyCode: defaultCurrencyCodeRaw
                )
            }

            // Filter chips (side by side)
            let hasAccountFilter = viewModel.selectedAccountID != nil
            let hasDateFilter = viewModel.focusedDate != nil
            // FIN-18: New Category Filter
            let hasCategoryFilter = viewModel.selectedCategoryID != nil

            if hasAccountFilter || hasDateFilter || hasCategoryFilter {
                HStack(spacing: 8) {
                    if let selectedID = viewModel.selectedAccountID,
                        let account = accounts.first(where: { $0.persistentModelID == selectedID })
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

                    Spacer()
                }
                .padding(.bottom, 4)
            }

            HStack {
                Text("Tendencias")
                    .font(.title2.weight(.semibold))

                Spacer()

                Button {
                    showWidgetPreferences = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.primary)  // Adapts to Light/Dark mode
                }
            }
            .padding(.trailing, 4)  // Align with card edges if needed, or remove if parent has padding

            // Custom Grid Layout (VStack of Rows)
            // LazyVGrid was failing to respect column spans, so we compute rows manually in ViewModel.
            VStack(spacing: 16) {
                ForEach(viewModel.layoutRows) { row in
                    switch row.type {
                    case .fullWidth(let config):
                        widgetView(for: config)
                    case .halfWidthPair(let left, let right):
                        HStack(spacing: 16) {
                            widgetView(for: left)
                                .frame(maxWidth: .infinity)
                                // Force Square aspect ratio for Small widgets
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

            // ... hidden navigation link
            EmptyView()
                .navigationDestination(isPresented: $showTrendDetail) {
                    TrendDetailView(trendType: trendDetailType)
                }
                .onChange(of: viewModel.selectedCategoryID) {
                    // Recalculate when selected category changes
                    viewModel.calculateTrendData(
                        accounts: accounts,
                        transactions: transactions,
                        defaultCurrencyCode: defaultCurrencyCodeRaw
                    )
                }
                .onChange(of: viewModel.focusedDate) {
                    // Recalculate when focused date (chart filter) changes
                    viewModel.calculateTrendData(
                        accounts: accounts,
                        transactions: transactions,
                        defaultCurrencyCode: defaultCurrencyCodeRaw
                    )
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
        formatter.locale = Locale(identifier: "es")  // Enforce Spanish
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    // MARK: - Widget Helpers

    @ViewBuilder
    private func widgetView(for config: WidgetConfig) -> some View {
        let preferredCurrency = CurrencyCode(rawValue: defaultCurrencyCodeRaw) ?? .pen
        let balance = viewModel.displayedBalanceInDefaultCurrency(
            accounts: accounts,
            transactions: transactions,
            defaultCurrencyCode: defaultCurrencyCodeRaw
        )

        if config.type == .trend {
            BalanceTrendCardView(
                currentBalance: balance,
                totalExpense: viewModel.totalExpenseInDefaultCurrency(
                    accounts: accounts,
                    transactions: transactions,
                    defaultCurrencyCode: defaultCurrencyCodeRaw
                ),
                currencyCode: preferredCurrency.rawValue,
                trendPoints: viewModel.processedTrendPoints,
                yDomain: viewModel.processedYDomain,
                balanceStatus: viewModel.balanceStatus,
                grouping: viewModel.trendGrouping,
                interval: viewModel.panelDateInterval,
                trendType: $viewModel.trendType,
                focusedDate: $viewModel.focusedDate,
                period: viewModel.selectedPeriod,
                isLocked: viewModel.isTrendLockedToExpense,
                size: config.size,
                onViewDetail: { selectedType in
                    trendDetailType = selectedType
                    showTrendDetail = true
                }
            )
            .onChange(of: viewModel.subcategoriesWidgetFilter) { _, _ in
                // Trigger recalculation when local widget filter changes
                viewModel.calculateTrendData(
                    accounts: accounts,
                    transactions: transactions,
                    defaultCurrencyCode: preferredCurrency.rawValue
                )
            }
            .onChange(of: viewModel.selectedSubcategoryID) { _, _ in
                // Trigger recalculation when submodule selection changes
                viewModel.calculateTrendData(
                    accounts: accounts,
                    transactions: transactions,
                    defaultCurrencyCode: preferredCurrency.rawValue
                )
            }
            .onChange(of: viewModel.trendType) { _, _ in
                // Trigger recalculation when trend type (Saldo/Gasto) toggle changes
                viewModel.calculateTrendData(
                    accounts: accounts,
                    transactions: transactions,
                    defaultCurrencyCode: preferredCurrency.rawValue
                )
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
                onShowMore: {
                    // TODO: Detail View
                },
                size: mapWidgetSize(config.size)
            )
        } else if config.type == .topSubcategories {
            TopSubcategoriesCardView(
                subcategories: viewModel.topSubcategories,
                currencyCode: preferredCurrency.rawValue,
                // If subcategory is selected, don't lock the header to Category (maintain "Browsing Context")
                globalCategoryFilterID: viewModel.selectedCategoryID,
                localCategoryFilterID: $viewModel.subcategoriesWidgetFilter,
                onSelectSubcategory: { name in
                    withAnimation {
                        viewModel.toggleSubcategoryFilter(
                            name,
                            transactions: transactions,
                            accounts: accounts,
                            defaultCurrencyCode: preferredCurrency.rawValue
                        )
                    }
                },
                selectedSubcategoryID: viewModel.selectedSubcategoryID,
                size: mapWidgetSize(config.size)
            )
        } else if config.type == .cashFlow {
            if let summary = viewModel.cashFlowSummary {
                CashFlowCardView(
                    summary: summary,
                    size: config.size,
                    period: viewModel.selectedPeriod.rawValue,
                    grouping: viewModel.cashFlowGrouping,
                    onShowDetail: {
                        // Detail View Placeholder
                    }
                )
            } else {
                // Empty / Loading logic
                EmptyView()
            }
        }
    }

    private func mapWidgetSize(_ size: WidgetSize) -> TopSpendingCardView.CardSize {
        switch size {
        case .small: return .small
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
/// Using a struct with unique ID ensures SwiftUI creates a fresh sheet each time.
struct AccountFormSheet: Identifiable {
    let id = UUID()
    let account: Account?
}

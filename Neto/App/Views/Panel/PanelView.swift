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
                .navigationTitle("Habla neto, Usuario")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            isPresentingSettings = true
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.electricIndigo)
                                .frame(width: 34, height: 34)
                                .background(
                                    Circle()
                                        .fill(Color.white)
                                )
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
                    SettingsRootView()
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
            Text("Tendencias")
                .font(.title2.weight(.semibold))

            let preferredCurrency = CurrencyCode(rawValue: defaultCurrencyCodeRaw) ?? .pen

            // Filter chips (side by side)
            let hasAccountFilter = viewModel.selectedAccountID != nil
            let hasDateFilter = viewModel.focusedDate != nil

            if hasAccountFilter || hasDateFilter {
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

                    Spacer()
                }
                .padding(.bottom, 4)
            }

            let balance = viewModel.displayedBalanceInDefaultCurrency(
                accounts: accounts,
                transactions: transactions,
                defaultCurrencyCode: defaultCurrencyCodeRaw
            )

            // FIN-XX: Nueva tarjeta de tendencia
            BalanceTrendCardView(
                currentBalance: balance,
                totalExpense: viewModel.totalExpenseInDefaultCurrency(
                    accounts: accounts,
                    transactions: transactions,
                    defaultCurrencyCode: defaultCurrencyCodeRaw
                ),
                currencyCode: preferredCurrency.rawValue,

                transactions: viewModel.chartTransactions,
                balanceStatus: viewModel.balanceStatus,
                historicalThreshold: viewModel.historicalThreshold,
                grouping: viewModel.trendGrouping,
                interval: viewModel.panelDateInterval,
                trendType: $viewModel.trendType,
                focusedDate: $viewModel.focusedDate,
                onViewDetail: { selectedType in
                    trendDetailType = selectedType
                    showTrendDetail = true
                }
            )

            // Hidden NavigationLink for programmatic navigation
            EmptyView()
                .navigationDestination(isPresented: $showTrendDetail) {
                    TrendDetailView(trendType: trendDetailType)
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

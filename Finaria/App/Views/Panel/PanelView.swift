//
//  PanelView.swift
//  Finaria
//
//  Created by Finaria Refactoring.
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

    @State private var isPresentingAccountForm = false
    @State private var isPresentingSettings = false

    /// FIN-56: Cuenta que se está editando en el formulario de cuenta.
    @State private var accountToEdit: Account?

    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCodeRaw: String = CurrencyCode.pen
        .rawValue
    @AppStorage("accountsSortOrderNames") private var accountsSortOrderNamesRaw: String = ""

    // FIN-57: Persistencia del filtro de periodo seleccionado en el Panel
    @AppStorage("panelPeriodType") private var panelPeriodTypeRaw: String = PanelPeriodType
        .thisMonth.rawValue
    @AppStorage("panelPeriodCustomStartISO") private var panelPeriodCustomStartISO: String = ""
    @AppStorage("panelPeriodCustomEndISO") private var panelPeriodCustomEndISO: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        accountsSection
                        periodFilterSection
                        totalBalanceSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Panel")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .imageScale(.large)
                    }
                }
            }
            .sheet(isPresented: $isPresentingAccountForm) {
                let namesForValidation: [String] = {
                    guard let editingAccount = accountToEdit else {
                        return accounts.map { $0.name }
                    }
                    return
                        accounts
                        .filter { $0.persistentModelID != editingAccount.persistentModelID }
                        .map { $0.name }
                }()

                AccountFormView(
                    existingNames: namesForValidation,
                    accountToEdit: accountToEdit
                )
            }
            .sheet(isPresented: $isPresentingSettings) {
                SettingsRootView()
            }
            .sheet(isPresented: $viewModel.isPresentingCustomPeriodSheet) {
                customPeriodSheetContent
                    .presentationDetents([.height(230)])
            }
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
        .onChange(of: viewModel.panelPeriodType) {
            panelPeriodTypeRaw = viewModel.panelPeriodType.rawValue
        }
        .onChange(of: viewModel.customPeriodStart) {
            if let date = viewModel.customPeriodStart {
                panelPeriodCustomStartISO = ISO8601DateFormatter().string(from: date)
            }
        }
        .onChange(of: viewModel.customPeriodEnd) {
            if let date = viewModel.customPeriodEnd {
                panelPeriodCustomEndISO = ISO8601DateFormatter().string(from: date)
            }
        }
    }

    private func syncStateToViewModel() {
        if let type = PanelPeriodType(rawValue: panelPeriodTypeRaw) {
            viewModel.panelPeriodType = type
        }
        let isoFormatter = ISO8601DateFormatter()
        viewModel.customPeriodStart = isoFormatter.date(from: panelPeriodCustomStartISO)
        viewModel.customPeriodEnd = isoFormatter.date(from: panelPeriodCustomEndISO)
    }

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                    accountToEdit = nil
                    isPresentingAccountForm = true
                },
                onEditAccount: { account in
                    accountToEdit = account
                    isPresentingAccountForm = true
                }
            )
        }
    }

    private var periodFilterSection: some View {
        PanelFilterView(viewModel: viewModel)
    }

    private var totalBalanceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            let preferredCurrency = CurrencyCode(rawValue: defaultCurrencyCodeRaw) ?? .pen
            let preferredInfo = currencyInfo(for: preferredCurrency)

            if let selectedID = viewModel.selectedAccountID,
                let account = accounts.first(where: { $0.persistentModelID == selectedID })
            {
                HStack {
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

                    Spacer()
                }
            }

            Text("Saldo total")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            let balance = viewModel.displayedBalanceInDefaultCurrency(
                accounts: accounts,
                transactions: transactions,
                defaultCurrencyCode: defaultCurrencyCodeRaw
            )

            Text("\(preferredInfo.code) \(formattedAmount(balance))")
                .font(.title3.weight(.semibold))
        }
        .padding(.top, 8)
    }

    private func formattedAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "0.00"
    }

    // MARK: - Custom Period Sheet

    private var customPeriodSheetContent: some View {
        NavigationStack {
            ZStack {
                Color.clear
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    Text("Periodo personalizado")
                        .font(.headline)
                        .padding(.top, 12)

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Desde")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            DatePicker(
                                "",
                                selection: $viewModel.customPeriodStartDraft,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Hasta")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            DatePicker(
                                "",
                                selection: $viewModel.customPeriodEndDraft,
                                in: viewModel.customPeriodStartDraft...,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                        }
                    }
                    .padding(.horizontal, 4)

                    if let error = viewModel.customPeriodErrorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Color.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }

                    HStack(spacing: 12) {
                        Button {
                            viewModel.isPresentingCustomPeriodSheet = false
                        } label: {
                            Text("Cancelar")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.secondary)

                        Button {
                            _ = viewModel.applyCustomPeriod()
                        } label: {
                            Text("Aplicar")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
    }
}

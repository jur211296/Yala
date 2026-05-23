//
//  AccountsSettingsListView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftData
import SwiftUI

// MARK: - Lista de cuentas desde Ajustes

struct AccountsSettingsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(SessionState.self) private var sessionState
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    @State private var viewModel = AccountsSettingsListViewModel()
    @State private var showUpgradeSheet = false

    private var activeAccountsCount: Int {
        viewModel.orderedActiveAccounts.count
    }

    private var isAtLimit: Bool {
        FeatureGateService.shared.isAtLimit(.accounts, currentCount: activeAccountsCount)
    }

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Contextual guide for new users
                    ContextualGuideBanner.accounts()

                    // Limit reached banner
                    if isAtLimit {
                        LimitReachedBanner(
                            feature: .accounts,
                            currentCount: activeAccountsCount
                        ) {
                            showUpgradeSheet = true
                        }
                    }

                    if viewModel.isEmpty {
                        emptyState
                    } else {
                        if !viewModel.orderedActiveAccounts.isEmpty {
                            listBasedSection
                        }

                        if !viewModel.systemAccounts.isEmpty {
                            accountsSection(
                                title: L10n.Account.System.badge,
                                accounts: viewModel.systemAccounts,
                                readOnly: true
                            )
                        }

                        if !viewModel.archivedAccounts.isEmpty {
                            accountsSection(title: L10n.Common.archived, accounts: viewModel.archivedAccounts)
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxxl)
            }
        }
        .navigationTitle(L10n.Settings.accounts)
        .navigationBarTitleDisplayMode(.inline)
        .swipeBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: DS.Spacing.md) {
                    YalaToolbarButton(systemName: viewModel.isEditMode ? "checkmark" : "arrow.up.arrow.down", label: viewModel.isEditMode ? L10n.Action.done : L10n.Action.reorder)
                    {
                        dsWithAnimation(reduceMotion) {
                            viewModel.isEditMode.toggle()
                        }
                    }

                    YalaToolbarButton(systemName: "plus", label: L10n.Action.add) {
                        if FeatureGateService.shared.canCreate(.accounts, currentCount: activeAccountsCount) {
                            viewModel.isPresentingCreateAccount = true
                        } else {
                            showUpgradeSheet = true
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.isPresentingCreateAccount, onDismiss: {
            viewModel.loadData()
        }) {
            AccountFormView(existingNames: viewModel.existingNames)
        }
        .sheet(item: $viewModel.accountToEdit, onDismiss: {
            viewModel.loadData()
        }) { account in
            AccountFormView(
                existingNames: viewModel.existingNamesExcluding(account),
                accountToEdit: account
            )
        }
        .sheet(isPresented: $showUpgradeSheet) {
            UpgradePromptSheet(feature: .accounts, context: .limitReached)
        }
        .onAppear {
            viewModel.setContext(modelContext)
            viewModel.accountsSortOrderNames = appPreferences.accountsSortOrderNames
        }
        .onChange(of: appPreferences.accountsSortOrderNames) { _, newValue in
            viewModel.accountsSortOrderNames = newValue
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "creditcard")
                .font(DS.Typography.amountLarge)
                .foregroundStyle(.tertiary)

            Text(L10n.Empty.noAccounts)
                .font(DS.Typography.headline)
                .foregroundStyle(.secondary)

            Text(L10n.Empty.accountsDescription)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.xxxl)
        }
        .padding(.top, DS.Spacing.sheetTop)
    }

    // Caja blanca de sección reutilizable para cuentas archivadas y sistema.
    // `readOnly: true` renderiza el row sin Button wrapper (no tap, sin chevron).
    @ViewBuilder
    private func accountsSection(title: String, accounts: [Account], readOnly: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(title)
                .font(DS.Typography.headline)
                .foregroundStyle(Color.primary.opacity(0.6))
                .padding(.leading, DS.Chip.paddingV)

            VStack(spacing: DS.Spacing.none) {
                ForEach(Array(accounts.enumerated()), id: \.element.id) { index, account in
                    if readOnly {
                        accountRow(account, showsChevron: false)
                    } else {
                        Button {
                            viewModel.accountToEdit = account
                        } label: {
                            accountRow(account)
                        }
                        .buttonStyle(.plain)
                    }

                    if index < accounts.count - 1 {
                        SubsectionDivider()
                    }
                }
            }
            .solidCard()
        }
    }

    // MARK: - Active Accounts Section (List with Drag and Drop)

    private var listBasedSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Common.active)
                .font(DS.Typography.headline)
                .foregroundStyle(Color.primary.opacity(0.6))
                .padding(.leading, DS.Chip.paddingV)

            List {
                ForEach(Array(viewModel.orderedActiveAccounts.enumerated()), id: \.element.id) {
                    index, account in
                    Button {
                        if !viewModel.isEditMode {
                            viewModel.accountToEdit = account
                        }
                    } label: {
                        listAccountRow(account)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(
                        index == 0 || index == viewModel.orderedActiveAccounts.count - 1 ? .hidden : .visible,
                        edges: index == 0 ? .top : .bottom)
                }
                .onMove(perform: moveAccountList)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .frame(height: CGFloat(viewModel.orderedActiveAccounts.count) * 80)
            .solidCard()
            .environment(\.editMode, .constant(viewModel.isEditMode ? .active : .inactive))
        }
    }

    private func listAccountRow(_ account: Account) -> some View {
        let normalizedCode = normalizeCurrencyCode(account.currencyCode)
        let currency = CurrencyCode(rawValue: normalizedCode) ?? .pen
        let currencyInfoData = currencyInfo(for: currency)
        let primaryText: String = {
            if let number = account.accountNumber, !number.isEmpty { return number }
            return account.name
        }()

        return HStack(spacing: DS.Spacing.md) {
            Circle()
                .fill(colorForHex(account.colorHex))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: displayIconName(for: account))
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(primaryText)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(accountTypeText(for: account))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)

                Text(currencyInfoData.name.capitalized)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            HStack(spacing: DS.Spacing.xs) {
                if !sessionState.isExpensesOnlyMode {
                    Text(viewModel.formattedBalance(for: account))
                        .font(DS.Typography.headline)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(.primary)
                }

                if !viewModel.isEditMode {
                    Image(systemName: "chevron.right")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .contentShape(Rectangle())
    }

    private func moveAccountList(from source: IndexSet, to destination: Int) {
        let newOrder = viewModel.moveAccount(from: source, to: destination)
        appPreferences.accountsSortOrderNames = newOrder
    }

    // MARK: - Presentación de filas

    private func accountTypeText(for account: Account) -> String {
        if account.isSystemAccount { return L10n.Account.System.badge }
        if let accountType = AccountType(rawValue: account.type) {
            return accountType.localizedName
        }
        return account.type.replacing("_", with: " ").capitalized
    }

    @ViewBuilder
    private func accountRow(_ account: Account, showsChevron: Bool = true) -> some View {
        let normalizedCode = normalizeCurrencyCode(account.currencyCode)
        let currency = CurrencyCode(rawValue: normalizedCode) ?? .pen
        let currencyInfoTuple = currencyInfo(for: currency)

        let primaryText: String = {
            if let number = account.accountNumber, !number.isEmpty { return number }
            return account.name
        }()

        let baseRow = HStack(spacing: DS.Spacing.md) {
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(colorForHex(account.colorHex))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: displayIconName(for: account))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(primaryText)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)

                // Cuentas sistema viven bajo el header de sección "Sistema" — repetir el
                // tipo aquí sería redundante. Mostramos solo nombre + moneda.
                if !account.isSystemAccount {
                    Text(accountTypeText(for: account))
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(currencyInfoTuple.name.capitalized)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: DS.Spacing.xs) {
                if !sessionState.isExpensesOnlyMode {
                    Text(viewModel.formattedBalance(for: account))
                        .font(DS.Typography.headline)
                        .foregroundStyle(.primary)
                }

                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
        .contentShape(Rectangle())

        // Rows con Button externo (showsChevron=true) heredan accessibility unified del
        // Button por default — NO añadir modifier propio (lo rompería al sobreescribir
        // con `.contain` que hace VoiceOver navegar Text por Text). Rows read-only
        // (sin Button wrapper) necesitan `.combine` explícito para unificar los Text.
        if showsChevron {
            baseRow
        } else {
            baseRow.accessibilityElement(children: .combine)
        }
    }
}

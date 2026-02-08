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

    @State private var viewModel = AccountsSettingsListViewModel()
    @State private var showUpgradeSheet = false

    @AppStorage("accountsSortOrderNames") private var accountsSortOrderNamesRaw: String = ""

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
                YalaToolbarButton(systemName: "chevron.left", label: "Atrás") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: DS.Spacing.md) {
                    YalaToolbarButton(systemName: viewModel.isEditMode ? "checkmark" : "arrow.up.arrow.down", label: viewModel.isEditMode ? "Listo" : "Reordenar")
                    {
                        dsWithAnimation(reduceMotion) {
                            viewModel.isEditMode.toggle()
                        }
                    }

                    YalaToolbarButton(systemName: "plus", label: "Agregar") {
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
            viewModel.accountsSortOrderNamesRaw = accountsSortOrderNamesRaw
        }
        .onChange(of: accountsSortOrderNamesRaw) { _, newValue in
            viewModel.accountsSortOrderNamesRaw = newValue
        }
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "creditcard")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text(L10n.Empty.noAccounts)
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(L10n.Empty.accountsDescription)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.xxxl)
        }
        .padding(.top, 64)
    }

    // Caja blanca de sección para cuentas archivadas
    @ViewBuilder
    private func accountsSection(title: String, accounts: [Account]) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.primary.opacity(0.6))
                .padding(.leading, 6)

            VStack(spacing: 0) {
                ForEach(Array(accounts.enumerated()), id: \.element.id) { index, account in
                    Button {
                        viewModel.accountToEdit = account
                    } label: {
                        accountRow(account)
                    }
                    .buttonStyle(.plain)

                    if index < accounts.count - 1 {
                        SubsectionDivider()
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(Color.yalaCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
        }
    }

    // MARK: - Active Accounts Section (List with Drag and Drop)

    private var listBasedSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Common.active)
                .font(.headline)
                .foregroundStyle(Color.primary.opacity(0.6))
                .padding(.leading, 6)

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
                    .listRowBackground(Color.yalaCard)
                    .listRowSeparator(
                        index == 0 || index == viewModel.orderedActiveAccounts.count - 1 ? .hidden : .visible,
                        edges: index == 0 ? .top : .bottom)
                }
                .onMove(perform: moveAccountList)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .frame(height: CGFloat(viewModel.orderedActiveAccounts.count) * 84)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(Color.yalaCard)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
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
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(colorForHex(account.colorHex))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: displayIconName(for: account))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(primaryText)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(accountTypeText(for: account))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(currencyInfoData.name.capitalized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            HStack(spacing: DS.Spacing.xs) {
                if !sessionState.isExpensesOnlyMode {
                    Text(viewModel.formattedBalance(for: account))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                if !viewModel.isEditMode {
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .contentShape(Rectangle())
    }

    private func moveAccountList(from source: IndexSet, to destination: Int) {
        let newRaw = viewModel.moveAccount(from: source, to: destination)
        accountsSortOrderNamesRaw = newRaw
    }

    // MARK: - Presentación de filas

    private func accountTypeText(for account: Account) -> String {
        if let accountType = AccountType(rawValue: account.type) {
            return accountType.localizedName
        }
        return account.type.replacingOccurrences(of: "_", with: " ").capitalized
    }

    @ViewBuilder
    private func accountRow(_ account: Account) -> some View {
        let normalizedCode = normalizeCurrencyCode(account.currencyCode)
        let currency = CurrencyCode(rawValue: normalizedCode) ?? .pen
        let currencyInfoTuple = currencyInfo(for: currency)

        let primaryText: String = {
            if let number = account.accountNumber, !number.isEmpty { return number }
            return account.name
        }()

        HStack(spacing: DS.Spacing.md) {
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(colorForHex(account.colorHex))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: displayIconName(for: account))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(primaryText)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(accountTypeText(for: account))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(currencyInfoTuple.name.capitalized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: DS.Spacing.xs) {
                if !sessionState.isExpensesOnlyMode {
                    Text(viewModel.formattedBalance(for: account))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
        .contentShape(Rectangle())
    }
}

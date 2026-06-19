//
//  AccountSelectorSheet.swift
//  Yala
//
//  Created by Yala - New Transaction Form.
//

import SwiftData
import SwiftUI

// MARK: - Account Selector Sheet

/// Sheet para seleccionar una cuenta
struct AccountSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var viewModel = AccountSelectorViewModel()

    @Binding var selectedAccount: Account?
    let title: String
    var excludeAccount: Account?
    var currencyFilter: String?

    init(
        selectedAccount: Binding<Account?>,
        title: String? = nil,
        excludeAccount: Account? = nil,
        currencyFilter: String? = nil
    ) {
        _selectedAccount = selectedAccount
        self.title = title ?? L10n.Account.selectAccount
        self.excludeAccount = excludeAccount
        self.currencyFilter = currencyFilter
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    let filteredAccounts = viewModel.activeAccounts.filter { account in
                        if let exclude = excludeAccount,
                           account.persistentModelID == exclude.persistentModelID {
                            return false
                        }
                        if let currencyFilter, account.currencyCode != currencyFilter {
                            return false
                        }
                        return true
                    }

                    if filteredAccounts.isEmpty {
                        YalaEmptyState.noAccounts()
                    } else {
                        SectionBox(title: "") {
                            VStack(spacing: DS.Spacing.none) {
                                ForEach(
                                    Array(filteredAccounts.enumerated()),
                                    id: \.element.persistentModelID
                                ) { index, account in
                                    if index > 0 {
                                        SubsectionDivider()
                                    }

                                    AccountSelectorRow(
                                        account: account,
                                        isSelected: isSelected(account)
                                    ) {
                                        selectedAccount = account
                                        dismiss()
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
            }
            .yalaScreenBackground(.subtle)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
        }

        .onAppear {
            viewModel.setContext(modelContext)
        }
    }

    private func isSelected(_ account: Account) -> Bool {
        guard let selected = selectedAccount else { return false }
        return selected.persistentModelID == account.persistentModelID
    }
}

// MARK: - Account Selector Row

struct AccountSelectorRow: View {
    let account: Account
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                Circle()
                    .fill(Color(hex: account.colorHex))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: displayIconName(for: account))
                            .font(DS.Typography.label)
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(account.name)
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)

                    Text(account.currencyCode)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(DS.Typography.headline)
                        .foregroundStyle(.thAccent)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("account_selector_row_\(account.name)")
        .accessibilityLabel(L10n.Accessibility.accountRow(account.name, account.currencyCode))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    AccountSelectorSheet(selectedAccount: .constant(nil))
}

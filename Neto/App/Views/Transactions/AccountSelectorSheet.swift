//
//  AccountSelectorSheet.swift
//  Neto
//
//  Created by Neto - New Transaction Form.
//

import SwiftData
import SwiftUI

// MARK: - Account Selector Sheet

/// Sheet para seleccionar una cuenta
struct AccountSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.name, order: .forward) private var accounts: [Account]

    @Binding var selectedAccount: Account?
    let title: String

    init(selectedAccount: Binding<Account?>, title: String? = nil) {
        _selectedAccount = selectedAccount
        self.title = title ?? L10n.Account.selectAccount
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: 24) {
                        SectionBox(title: "") {
                            VStack(spacing: 0) {
                                ForEach(
                                    Array(activeAccounts.enumerated()),
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
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NetoToolbarButton(systemName: "xmark") {
                        dismiss()
                    }
                }
            }
        }
        .tint(Color.electricIndigo)
    }

    private var activeAccounts: [Account] {
        accounts.filter { !$0.isArchived }
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
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(hex: account.colorHex))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: displayIconName(for: account))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Text(account.currencyCode)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.electricIndigo)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AccountSelectorSheet(selectedAccount: .constant(nil))
}

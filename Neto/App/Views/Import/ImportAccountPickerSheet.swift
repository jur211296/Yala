//
//  ImportAccountPickerSheet.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftUI

/// Hoja de selección de cuenta destino para la importación
struct ImportAccountPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let accounts: [Account]
    @Binding var selectedAccount: Account?
    let onContinue: (Account) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                if accounts.isEmpty {
                    VStack(spacing: 12) {
                        Text(L10n.Import.noAccountsAvailable)
                            .font(.headline)
                        Text(L10n.Import.createAccountBeforeImport)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            SectionBox(title: "") {
                                VStack(spacing: 0) {
                                    ForEach(Array(accounts.enumerated()), id: \.element.id) { index, account in
                                        if index > 0 {
                                            SubsectionDivider()
                                        }

                                        Button {
                                            selectedAccount = account
                                        } label: {
                                            accountRow(for: account)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 24)
                    }
                }
            }
            .navigationTitle(L10n.Import.selectAccount)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NetoToolbarButton(systemName: "xmark") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NetoSaveButton(
                        action: {
                            if let account = selectedAccount {
                                onContinue(account)
                            }
                        },
                        isDisabled: selectedAccount == nil
                    )
                }
            }
        }
    }

    // Fila de cuenta reutilizable para el selector
    @ViewBuilder
    private func accountRow(for account: Account) -> some View {
        let normalizedCode = normalizeCurrencyCode(account.currencyCode)
        let currency = CurrencyCode(rawValue: normalizedCode) ?? .pen
        let info = currencyInfo(for: currency)

        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colorForHex(account.colorHex))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: displayIconName(for: account))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(.body.weight(.semibold))
                Text(info.name.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if selectedAccount == account {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.brandPrimary)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

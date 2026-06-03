//
//  ImportAccountPickerSheet.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftUI

/// Hoja de selección de cuenta destino para la importación
struct ImportAccountPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme

    let accounts: [Account]
    @Binding var selectedAccount: Account?
    let onContinue: (Account) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                if accounts.isEmpty {
                    VStack(spacing: DS.Spacing.md) {
                        Text(L10n.Import.noAccountsAvailable)
                            .font(DS.Typography.headline)
                        Text(L10n.Import.createAccountBeforeImport)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else {
                    ScrollView {
                        VStack(spacing: DS.Spacing.xxl) {
                            SectionBox(title: "") {
                                VStack(spacing: DS.Spacing.none) {
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
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.xxl)
                    }
                }
            }
            .navigationTitle(L10n.Import.selectAccount)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    YalaSaveButton(
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

        HStack(spacing: DS.Spacing.md) {
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(colorForHex(account.colorHex))
                .frame(width: DS.ListRow.iconSize, height: DS.ListRow.iconSize)
                .overlay(
                    Image(systemName: displayIconName(for: account))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(account.name)
                    .font(DS.Typography.headline)
                Text(info.name.capitalized)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if selectedAccount == account {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.thAccent)
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .contentShape(Rectangle())
    }
}

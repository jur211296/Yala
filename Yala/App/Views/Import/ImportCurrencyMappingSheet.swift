//
//  ImportCurrencyMappingSheet.swift
//  Yala
//
//  Multi-currency import: assign an account per detected currency.
//

import SwiftUI

/// Sheet for assigning accounts to each detected currency in multi-currency import
struct ImportCurrencyMappingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme

    let detectedCurrencies: Set<String>
    let accounts: [Account]
    let onImport: ([String: Account]) -> Void

    @State private var currencyAccountMap: [String: Account] = [:]
    @State private var expandedCurrency: String?

    private var sortedCurrencies: [String] {
        detectedCurrencies.sorted()
    }

    private var allCurrenciesAssigned: Bool {
        sortedCurrencies.allSatisfy { currencyAccountMap[$0] != nil }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                VStack(spacing: DS.Spacing.none) {
                    ScrollView {
                        VStack(spacing: DS.Spacing.xxl) {
                            headerSection
                            currencyMappingSection
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.vertical, DS.Spacing.xxl)
                    }

                    importButton
                }
            }
            .navigationTitle(L10n.Import.multiCurrencyDetected)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: "Cerrar") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "dollarsign.arrow.circlepath")
                .font(DS.Typography.amountLarge)
                .foregroundStyle(.thAccent)
                .padding(.bottom, DS.Spacing.sm)

            Text(L10n.Import.currenciesDetected(sortedCurrencies.count))
                .font(Typography.title2)
                .foregroundStyle(.thPrimaryText)

            Text(L10n.Import.assignAccountPerCurrency)
                .font(Typography.body)
                .foregroundStyle(.thSecondaryText)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Currency Mapping Section

    private var currencyMappingSection: some View {
        SectionBox(title: "") {
            VStack(spacing: DS.Spacing.none) {
                ForEach(Array(sortedCurrencies.enumerated()), id: \.element) { index, currencyCode in
                    if index > 0 {
                        SubsectionDivider()
                    }

                    currencyRow(for: currencyCode)
                }
            }
        }
    }

    @ViewBuilder
    private func currencyRow(for currencyCode: String) -> some View {
        let currency = CurrencyCode(rawValue: currencyCode) ?? .pen
        let info = currencyInfo(for: currency)
        let selectedAccount = currencyAccountMap[currencyCode]
        let availableAccounts = accounts.filter {
            normalizeCurrencyCode($0.currencyCode) == currencyCode && !$0.isArchived
        }
        let isExpanded = expandedCurrency == currencyCode

        VStack(spacing: DS.Spacing.none) {
            // Main row - currency info and selected account
            Button {
                dsWithAnimation(reduceMotion) {
                    expandedCurrency = isExpanded ? nil : currencyCode
                }
            } label: {
                HStack(spacing: DS.Spacing.md) {
                    // Currency flag and code
                    Text(info.flag)
                        .font(DS.Typography.largeTitle)

                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(currencyCode)
                            .font(Typography.bodyBold)
                            .foregroundStyle(.thPrimaryText)
                        Text(info.name.capitalized)
                            .font(Typography.caption)
                            .foregroundStyle(.thSecondaryText)
                    }

                    Spacer()

                    // Selected account or placeholder
                    if let account = selectedAccount {
                        HStack(spacing: DS.Spacing.sm) {
                            RoundedRectangle(cornerRadius: DS.Radius.xs)
                                .fill(colorForHex(account.colorHex))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Image(systemName: displayIconName(for: account))
                                        .font(DS.Typography.caption)
                                        .foregroundStyle(.white)
                                )
                            Text(account.name)
                                .font(Typography.body)
                                .foregroundStyle(.thPrimaryText)
                                .lineLimit(1)
                        }
                    } else {
                        Text(L10n.Import.selectAccountForCurrency)
                            .font(Typography.body)
                            .foregroundStyle(.thSecondaryText)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.thSecondaryText)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded account list
            if isExpanded {
                VStack(spacing: DS.Spacing.none) {
                    Divider()
                        .padding(.horizontal, DS.Spacing.lg)

                    if availableAccounts.isEmpty {
                        Text(L10n.Import.noAccountsForCurrency(currencyCode))
                            .font(Typography.caption)
                            .foregroundStyle(.thSecondaryText)
                            .padding(.vertical, DS.Spacing.md)
                    } else {
                        ForEach(availableAccounts, id: \.id) { account in
                            accountOptionRow(account: account, currencyCode: currencyCode)
                        }
                    }
                }
                .background(.thBackground.opacity(0.5))
            }
        }
    }

    @ViewBuilder
    private func accountOptionRow(account: Account, currencyCode: String) -> some View {
        let isSelected = currencyAccountMap[currencyCode]?.id == account.id

        Button {
            currencyAccountMap[currencyCode] = account
            dsWithAnimation(reduceMotion) {
                expandedCurrency = nil
            }
        } label: {
            HStack(spacing: DS.Spacing.md) {
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(colorForHex(account.colorHex))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: displayIconName(for: account))
                            .font(DS.Typography.caption)
                            .foregroundStyle(.white)
                    )

                Text(account.name)
                    .font(Typography.body)
                    .foregroundStyle(.thPrimaryText)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.thAccent)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.vertical, DS.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Import Button

    private var importButton: some View {
        VStack {
            Button {
                onImport(currencyAccountMap)
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "square.and.arrow.down")
                    Text(L10n.Import.importAction)
                }
                .font(Typography.bodyLarge)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(allCurrenciesAssigned ? theme.accent : DS.Semantic.disabledForeground)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .disabled(!allCurrenciesAssigned)
            .accessibilityHint(!allCurrenciesAssigned ? "Asigna todas las divisas" : "")
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.lg)
    }
}

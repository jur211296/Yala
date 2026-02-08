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

                VStack(spacing: 0) {
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
                .font(.system(size: 48))
                .foregroundStyle(Color.brandPrimary)
                .padding(.bottom, DS.Spacing.sm)

            Text(L10n.Import.currenciesDetected(sortedCurrencies.count))
                .font(Typography.title2)
                .foregroundStyle(Color.yalaPrimaryText)

            Text(L10n.Import.assignAccountPerCurrency)
                .font(Typography.body)
                .foregroundStyle(Color.yalaSecondaryText)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Currency Mapping Section

    private var currencyMappingSection: some View {
        SectionBox(title: "") {
            VStack(spacing: 0) {
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

        VStack(spacing: 0) {
            // Main row - currency info and selected account
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedCurrency = isExpanded ? nil : currencyCode
                }
            } label: {
                HStack(spacing: DS.Spacing.md) {
                    // Currency flag and code
                    Text(info.flag)
                        .font(.system(size: 28))

                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        Text(currencyCode)
                            .font(Typography.bodyBold)
                            .foregroundStyle(Color.yalaPrimaryText)
                        Text(info.name.capitalized)
                            .font(Typography.caption)
                            .foregroundStyle(Color.yalaSecondaryText)
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
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white)
                                )
                            Text(account.name)
                                .font(Typography.body)
                                .foregroundStyle(Color.yalaPrimaryText)
                                .lineLimit(1)
                        }
                    } else {
                        Text(L10n.Import.selectAccountForCurrency)
                            .font(Typography.body)
                            .foregroundStyle(Color.yalaSecondaryText)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(Color.yalaSecondaryText)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded account list
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.horizontal, DS.Spacing.lg)

                    if availableAccounts.isEmpty {
                        Text(L10n.Import.noAccountsForCurrency(currencyCode))
                            .font(Typography.caption)
                            .foregroundStyle(Color.yalaSecondaryText)
                            .padding(.vertical, DS.Spacing.md)
                    } else {
                        ForEach(availableAccounts, id: \.id) { account in
                            accountOptionRow(account: account, currencyCode: currencyCode)
                        }
                    }
                }
                .background(Color.yalaBackground.opacity(0.5))
            }
        }
    }

    @ViewBuilder
    private func accountOptionRow(account: Account, currencyCode: String) -> some View {
        let isSelected = currencyAccountMap[currencyCode]?.id == account.id

        Button {
            currencyAccountMap[currencyCode] = account
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedCurrency = nil
            }
        } label: {
            HStack(spacing: DS.Spacing.md) {
                RoundedRectangle(cornerRadius: DS.Radius.sm)
                    .fill(colorForHex(account.colorHex))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: displayIconName(for: account))
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                    )

                Text(account.name)
                    .font(Typography.body)
                    .foregroundStyle(Color.yalaPrimaryText)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.brandPrimary)
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
            .tint(allCurrenciesAssigned ? Color.brandPrimary : Color.gray)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .disabled(!allCurrenciesAssigned)
            .accessibilityHint(!allCurrenciesAssigned ? "Asigna todas las divisas" : "")
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.lg)
    }
}

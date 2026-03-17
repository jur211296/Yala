//
//  CurrencyPickerSheet.swift
//  Yala
//
//  Sheet for selecting a single currency, grouped by continent.
//

import SwiftUI

struct CurrencyPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @Binding var selectedCurrency: CurrencyCode

    // MARK: - Recommended Currencies

    private let globalRecommendedPool: [CurrencyCode] = [.usd, .eur, .gbp]

    private var userRegionalCurrency: CurrencyCode {
        CurrencyDefaults.detectCurrencyFromRegion()
    }

    /// Recommended currencies: regional first, then USD/EUR/GBP (no duplicates)
    private var recommendedCurrencies: [CurrencyCode] {
        var result: [CurrencyCode] = [userRegionalCurrency]
        for currency in globalRecommendedPool where currency != userRegionalCurrency {
            result.append(currency)
        }
        return result
    }

    /// Continent groups excluding recommended currencies
    private var filteredContinentGroups: [(continent: Continent, currencies: [CurrencyCode])] {
        CurrencyCode.groupedByContinent.compactMap { group in
            let filtered = group.currencies.filter { !recommendedCurrencies.contains($0) }
            guard !filtered.isEmpty else { return nil }
            return (continent: group.continent, currencies: filtered)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: DS.Spacing.lg) {
                        // Recommended section
                        recommendedSection

                        // Remaining currencies by continent
                        ForEach(filteredContinentGroups, id: \.continent) { group in
                            SectionBox(title: group.continent.localizedName) {
                                VStack(spacing: DS.Spacing.none) {
                                    ForEach(Array(group.currencies.enumerated()), id: \.element) {
                                        index, currency in
                                        if index > 0 {
                                            SubsectionDivider()
                                        }
                                        currencyRow(currency: currency)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.lg)
                }
            }
            .navigationTitle(L10n.Settings.preferredCurrency)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Recommended Section

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(L10n.Settings.recommendedCurrencies)
                .font(DS.Typography.labelSmall)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, DS.Spacing.xs)

            VStack(spacing: DS.Spacing.none) {
                ForEach(Array(recommendedCurrencies.enumerated()), id: \.element) { index, currency in
                    if index > 0 {
                        SubsectionDivider()
                    }
                    currencyRow(currency: currency)
                }
            }
            .background(theme.accent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl)
                    .stroke(theme.accent.opacity(0.15), lineWidth: 1)
            )
        }
    }

    // MARK: - Currency Row

    @ViewBuilder
    private func currencyRow(currency: CurrencyCode) -> some View {
        let info = currencyInfo(for: currency)
        let isSelected = currency == selectedCurrency

        Button {
            selectedCurrency = currency
            dismiss()
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Text(info.flag)
                    .font(DS.Typography.title)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(info.name.capitalized)
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)
                    Text(info.code)
                        .font(DS.Typography.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.thAccent)
                        .font(DS.Typography.headline)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CurrencyPickerSheet(selectedCurrency: .constant(.pen))
}

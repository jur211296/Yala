//
//  SecondaryCurrencyPickerSheet.swift
//  Yala
//
//  Sheet for selecting up to 2 secondary currencies.
//

import SwiftUI

struct SecondaryCurrencyPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @Binding var selectedCurrencies: Set<CurrencyCode>
    let preferredCurrency: CurrencyCode

    /// Maximum number of secondary currencies allowed
    private let maxSelections = 2

    /// Base pool of globally recommended currencies
    private let globalRecommendedPool: [CurrencyCode] = [.usd, .eur, .gbp]

    /// User's regional currency
    private var userRegionalCurrency: CurrencyCode {
        CurrencyDefaults.detectCurrencyFromRegion()
    }

    /// Currencies to show in the recommended section: regional first, then USD/EUR/GBP (no duplicates)
    private var recommendedCurrencyPool: [CurrencyCode] {
        var result: [CurrencyCode] = [userRegionalCurrency]
        for currency in globalRecommendedPool where currency != userRegionalCurrency {
            result.append(currency)
        }
        return result
    }

    /// All currencies except the preferred one, grouped by continent (excluding recommended)
    private var availableCurrencies: [(continent: Continent, currencies: [CurrencyCode])] {
        let pool = recommendedCurrencyPool
        return CurrencyCode.groupedByContinent.compactMap { group in
            let filtered = group.currencies.filter { currency in
                currency != preferredCurrency && !pool.contains(currency)
            }
            guard !filtered.isEmpty else { return nil }
            return (continent: group.continent, currencies: filtered)
        }
    }

    /// Recommended currencies that are available (not preferred, not already selected)
    private var recommendedCurrencies: [CurrencyCode] {
        recommendedCurrencyPool.filter { currency in
            currency != preferredCurrency && !selectedCurrencies.contains(currency)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: DS.Spacing.lg) {
                        // Selected section (only if there are selections)
                        if !selectedCurrencies.isEmpty {
                            selectedSection
                        }

                        // Recommended section (only if there are available recommendations)
                        if !recommendedCurrencies.isEmpty {
                            recommendedSection
                        }

                        // All currencies by continent
                        ForEach(availableCurrencies, id: \.continent) { group in
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
            .navigationTitle(L10n.Settings.secondaryCurrencies)
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

    // MARK: - Selected Section

    private var selectedSection: some View {
        SectionBox(title: L10n.Common.selected.capitalized) {
            VStack(spacing: DS.Spacing.none) {
                let sortedSelected = selectedCurrencies.sorted { $0.localizedName < $1.localizedName }
                ForEach(Array(sortedSelected.enumerated()), id: \.element) { index, currency in
                    if index > 0 {
                        SubsectionDivider()
                    }
                    currencyRow(currency: currency)
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
                    if index > 0 { SubsectionDivider() }
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
        let isSelected = selectedCurrencies.contains(currency)
        let canSelect = isSelected || selectedCurrencies.count < maxSelections

        Button {
            toggleCurrency(currency)
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

                Image(systemName: isSelected ? "star.fill" : "star")
                    .font(DS.Typography.title)
                    .foregroundStyle(isSelected ? theme.accent : .secondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(canSelect ? 1.0 : 0.5)
        .disabled(!canSelect)
        .accessibilityHint(!canSelect ? L10n.Accessibility.maxCurrenciesSelected : "")
    }

    private func toggleCurrency(_ currency: CurrencyCode) {
        if selectedCurrencies.contains(currency) {
            selectedCurrencies.remove(currency)
        } else if selectedCurrencies.count < maxSelections {
            selectedCurrencies.insert(currency)
        }
    }
}

#Preview {
    SecondaryCurrencyPickerSheet(
        selectedCurrencies: .constant([.eur, .gbp]),
        preferredCurrency: .pen
    )
}

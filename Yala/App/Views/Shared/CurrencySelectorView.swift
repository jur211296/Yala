//
//  CurrencySelectorView.swift
//  Yala
//
//  Currency selector view grouped by continent (used in AccountFormView).
//

import SwiftUI

struct CurrencySelectorView: View {
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

    /// Lo que la persona escribe en el buscador (auditoría UX 2.2, lote 7, L7-9).
    @State private var query: String = ""

    /// La moneda elegida va arriba, sola, cuando no está ya entre las recomendadas: antes, una cuenta en MXN
    /// abría el selector sin ver su moneda hasta bajar por los continentes (L7-9).
    private var showsCurrentOnTop: Bool {
        !recommendedCurrencies.contains(selectedCurrency)
    }

    /// Con algo escrito, una sola lista con lo que casa, sin secciones.
    private var searchResults: [CurrencyCode] {
        CurrencySearchLogic.filter(CurrencyCode.allCases, query: query)
    }

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: DS.Spacing.lg) {
            if isSearching {
                searchResultsSection
            } else {
            if showsCurrentOnTop {
                SectionBox(title: L10n.UXL7.CurrencyPicker.current) {
                    currencyRow(currency: selectedCurrency)
                }
            }

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
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.lg)
        }
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: L10n.UXL7.CurrencyPicker.searchPrompt
        )
        .autocorrectionDisabled()
        .refreshable {}
        .yalaScreenBackground(.subtle)
        // «Moneda», no «Divisa preferida»: aquí se elige la de una cuenta o un grupo, nunca la de la app
        // (esa la elige `CurrencyPickerSheet`). Con el título viejo, cambiar la moneda de una cuenta
        // parecía cambiar la de toda la app (auditoría UX 2.2, lote 7, B5).
        .navigationTitle(L10n.Account.currency)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Search Results

    @ViewBuilder
    private var searchResultsSection: some View {
        let results = searchResults
        if results.isEmpty {
            Text(L10n.UXL7.CurrencyPicker.noResults(query.trimmingCharacters(in: .whitespacesAndNewlines)))
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.xxl)
                .accessibilityIdentifier("currency_selector_no_results")
        } else {
            SectionBox(title: "") {
                VStack(spacing: DS.Spacing.none) {
                    ForEach(Array(results.enumerated()), id: \.element) { index, currency in
                        if index > 0 {
                            SubsectionDivider()
                        }
                        currencyRow(currency: currency)
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

                if currency == selectedCurrency {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.thAccent)
                        .font(DS.Typography.headline)
                }
            }
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("currency_selector_row_\(currency.rawValue)")
    }
}

#Preview {
    NavigationStack {
        CurrencySelectorView(selectedCurrency: .constant(.pen))
    }
}

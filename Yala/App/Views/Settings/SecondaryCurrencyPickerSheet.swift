//
//  SecondaryCurrencyPickerSheet.swift
//  Yala
//
//  Sheet for selecting up to 2 secondary currencies.
//

import SwiftUI

struct SecondaryCurrencyPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCurrencies: Set<CurrencyCode>
    let preferredCurrency: CurrencyCode

    /// Maximum number of secondary currencies allowed
    private let maxSelections = 2

    /// All currencies except the preferred one, grouped by continent
    private var availableCurrencies: [(continent: Continent, currencies: [CurrencyCode])] {
        CurrencyCode.groupedByContinent.compactMap { group in
            let filtered = group.currencies.filter { $0 != preferredCurrency }
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
                        // Selected section (only if there are selections)
                        if !selectedCurrencies.isEmpty {
                            selectedSection
                        }

                        // All currencies by continent
                        ForEach(availableCurrencies, id: \.continent) { group in
                            SectionBox(title: group.continent.localizedName) {
                                VStack(spacing: 0) {
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
                    YalaToolbarButton(systemName: "xmark") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Selected Section

    private var selectedSection: some View {
        SectionBox(title: L10n.Common.selected.capitalized) {
            VStack(spacing: 0) {
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
                    .font(.title3)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(info.name.capitalized)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(info.code)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "star.fill" : "star")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.electricIndigo : .secondary)
            }
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(canSelect ? 1.0 : 0.5)
        .disabled(!canSelect)
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

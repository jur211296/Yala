//
//  CurrencyPickerSheet.swift
//  Yala
//
//  Sheet for selecting a single currency, grouped by continent.
//

import SwiftUI

struct CurrencyPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCurrency: CurrencyCode

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                ScrollView {
                    VStack(spacing: DS.Spacing.lg) {
                        ForEach(CurrencyCode.groupedByContinent, id: \.continent) { group in
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
            .navigationTitle(L10n.Settings.preferredCurrency)
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

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.electricIndigo)
                        .font(.body.weight(.semibold))
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

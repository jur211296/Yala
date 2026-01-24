//
//  CurrencySelectorView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftUI

struct CurrencySelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCurrency: CurrencyCode

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    SectionBox(title: "") {
                        VStack(spacing: 0) {
                            ForEach(Array(CurrencyCode.allCases.enumerated()), id: \.element) {
                                index, currency in
                                if index > 0 {
                                    SubsectionDivider()
                                }

                                currencyRow(currency: currency)
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xxl)
            }
        }
        .navigationTitle(L10n.Settings.preferredCurrency)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                YalaToolbarButton(systemName: "chevron.left") {
                    dismiss()
                }
            }
        }
    }

    @ViewBuilder
    private func currencyRow(currency: CurrencyCode) -> some View {
        let info = currencyInfo(for: currency)

        Button {
            selectedCurrency = currency
            dismiss()
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Text(info.flag)
                    .font(.title3)

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(info.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(info.code)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if currency == selectedCurrency {
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

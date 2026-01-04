//
//  CurrencySelectorView.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftUI

struct CurrencySelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCurrency: CurrencyCode

    var body: some View {
        ZStack {
            PanelBackgroundView()

            ScrollView {
                VStack(spacing: 24) {
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
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
        }
        .navigationTitle("Divisa preferida")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NetoToolbarButton(systemName: "chevron.left") {
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
            HStack(spacing: 12) {
                Text(info.flag)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
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
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

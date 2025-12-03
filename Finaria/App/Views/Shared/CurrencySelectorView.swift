//
//  CurrencySelectorView.swift
//  Finaria
//
//  Created by Finaria Refactoring.
//

import SwiftUI

struct CurrencySelectorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCurrency: CurrencyCode

    var body: some View {
        List {
            ForEach(CurrencyCode.allCases) { currency in
                HStack(spacing: 12) {
                    let info = currencyInfo(for: currency)

                    Text(info.flag)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(info.name)
                        Text(info.code)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if currency == selectedCurrency {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedCurrency = currency
                    dismiss()
                }
            }
        }
        .navigationTitle("Moneda")
    }
}

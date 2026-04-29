//
//  TransactionSnippetView.swift
//  Yala
//
//  Visual snippet shown after Siri/Atajos/Lock Screen ejecuta un intent que crea
//  una transacción o draft. Reemplaza el dialog textual por una tarjeta rica
//  con monto + cuenta + categoría + fecha (similar a Apple Wallet).
//
//  Reusable por QuickExpenseIntent (F5), ApplePayTransactionIntent (F6) y
//  SiriNaturalEntryIntent (F7) vía la prop `isDraft`.
//

import SwiftUI

struct TransactionSnippetView: View {
    let amount: Double
    let currencyCode: String
    let accountName: String
    let subcategoryName: String
    let subcategoryIcon: String
    let date: Date
    let isExpense: Bool
    /// Si es draft (Inbox) muestra badge "Borrador" + CTA. Para tx real → false.
    let isDraft: Bool

    private var formattedAmount: String {
        let signed = isExpense ? -abs(amount) : abs(amount)
        return YalaFormatterStatic.currency(value: signed, currencyCode: currencyCode, forceFullPrecision: true)
    }

    private var dateFormatted: String {
        date.formatted(date: .numeric, time: .omitted)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Monto grande centrado
            Text(formattedAmount)
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.top, 8)

            Divider()

            // Filas de detalle
            VStack(spacing: 14) {
                row(icon: "creditcard", label: String(localized: "shortcut.snippet.account"), value: accountName)
                row(icon: subcategoryIcon, label: String(localized: "shortcut.snippet.category"), value: subcategoryName)
                row(icon: "calendar", label: String(localized: "shortcut.snippet.date"), value: dateFormatted)
            }

            // Badge "Borrador" si aplica
            if isDraft {
                HStack(spacing: 6) {
                    Image(systemName: "tray")
                    Text(String(localized: "shortcut.snippet.draftBadge"))
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func row(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .font(.body)
    }
}

#Preview("Transacción real") {
    TransactionSnippetView(
        amount: 25.0,
        currencyCode: "EUR",
        accountName: "Main CBC",
        subcategoryName: "Comestibles",
        subcategoryIcon: "cart.fill",
        date: .now,
        isExpense: true,
        isDraft: false
    )
    .padding()
}

#Preview("Borrador") {
    TransactionSnippetView(
        amount: 50.0,
        currencyCode: "PEN",
        accountName: "BBVA",
        subcategoryName: "Café",
        subcategoryIcon: "cup.and.saucer.fill",
        date: .now,
        isExpense: true,
        isDraft: true
    )
    .padding()
}

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
    /// `nil` (o vacía) cuando aún no se sabe: la fila no se pinta (decisión 76 de 2.3; antes decía «Cuenta: —»).
    let accountName: String?
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

    /// Con el mes en letras (decisión 76 de 2.3): «12/11/2026» se lee al revés según el país.
    private var dateFormatted: String {
        TransactionSnippetLogic.dateText(date)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Monto grande centrado. Escala con el tamaño del texto (decisión 76 de 2.3; iba a 38 pt fijos) y encoge
            // antes que partirse si no cabe.
            Text(formattedAmount)
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.top, 8)

            Divider()

            // Filas de detalle
            VStack(spacing: 14) {
                if let account = TransactionSnippetLogic.visibleAccountName(accountName) {
                    row(icon: "creditcard", label: String(localized: "shortcut.snippet.account"), value: account)
                }
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

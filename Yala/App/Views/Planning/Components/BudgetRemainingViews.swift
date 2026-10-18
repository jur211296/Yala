//
//  BudgetRemainingViews.swift
//  Yala
//
//  Auditoría UX 2.2 · lote 9: la cifra principal de un presupuesto es lo que queda (o lo que te pasaste), y lo gastado
//  va en UNA línea gris. Lo comparten la fila de Planificación (L9-1), el detalle (L9-6) y la tarjeta del Panel (L9-10).
//

import SwiftUI

/// «Te quedan» / «Te pasaste por» sobre el importe. En rosa solo si te pasaste: se colorea la excepción.
struct BudgetRemainingFigure: View {
    let limit: Double
    let spent: Double
    let currencyCode: String
    var alignment: HorizontalAlignment = .trailing
    var labelFont: Font = DS.Typography.captionSmall
    var amountFont: Font = DS.Typography.headline

    @Environment(AppPreferences.self) private var appPreferences

    private var remaining: Double { BudgetRemainingLogic.remaining(limit: limit, spent: spent) }
    private var isOver: Bool { BudgetRemainingLogic.isOver(limit: limit, spent: spent) }

    var body: some View {
        VStack(alignment: alignment, spacing: DS.Spacing.xxs) {
            Text(isOver ? L10n.UXL9.overLabel : L10n.UXL9.remainingLabel)
                .font(labelFont)
                .foregroundStyle(isOver ? Color.overBudgetText : Color.secondary)
                .lineLimit(1)

            // A su tamaño si cabe; solo si no cabe (un importe en COP, texto de accesibilidad) se encoge. Con
            // `minimumScaleFactor` a secas la cifra salía encogida aunque cupiera (medido en la fila, iPhone 17 Pro).
            ViewThatFits(in: .horizontal) {
                amountText
                amountText.minimumScaleFactor(0.5)
            }
            .accessibilityIdentifier("budget_remaining_amount")
        }
        // La cifra manda: la línea gris de al lado es la que pasa a sin decimales.
        .layoutPriority(1)
        .accessibilityElement(children: .combine)
    }
}

extension BudgetRemainingFigure {
    fileprivate var amountText: some View {
        Text(appPreferences.currency(abs(remaining), currencyCode: currencyCode))
            .font(amountFont)
            .foregroundStyle(isOver ? Color.overBudgetText : Color.primary)
            .lineLimit(1)
    }
}

/// «S/ 1,408.00 de S/ 1,800.00 · 18 días» en una sola línea. Si con decimales no cabe, prueba sin ellos; nunca se parte
/// en dos (L9-1, medido en el iPhone 17 Pro: «78% gastado · 18 días restantes» se partía).
struct BudgetSpentLine: View {
    let spent: Double
    let limit: Double
    let currencyCode: String
    /// Lo que va tras el «·» (los días, o el porcentaje en el Panel). `nil` = nada.
    var suffix: String?
    var font: Font = DS.Typography.captionSmall

    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        ViewThatFits(in: .horizontal) {
            line(decimals: appPreferences.decimalPlaces)
            line(decimals: 0)
            line(decimals: 0)
                .minimumScaleFactor(0.7)
        }
    }

    private func line(decimals: Int) -> some View {
        Text(text(decimals: decimals))
            .font(font)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }

    private func text(decimals: Int) -> String {
        let identifier = appPreferences.currencyIdentifier(for: currencyCode)
        let spentText = CurrencyFormattingHelper.currency(spent, decimals: decimals, identifier: identifier, forceSign: false, isEstimate: false)
        let limitText = CurrencyFormattingHelper.currency(limit, decimals: decimals, identifier: identifier, forceSign: false, isEstimate: false)
        let base = L10n.UXL9.spentOfLimit(spentText, limitText)
        guard let suffix, !suffix.isEmpty else { return base }
        return "\(base) · \(suffix)"
    }
}

/// «Cuenta todos tus gastos» (L9-2): sin filtros, el presupuesto suma todo lo gastado, y eso no se veía en ningún sitio.
struct BudgetCountsAllExpensesNote: View {
    var font: Font = DS.Typography.captionSmall

    var body: some View {
        Label(L10n.UXL9.countsAllExpenses, systemImage: "tray.full")
            .font(font)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .accessibilityIdentifier("budget_counts_all_expenses")
    }
}

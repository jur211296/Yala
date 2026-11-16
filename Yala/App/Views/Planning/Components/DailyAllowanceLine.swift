//
//  DailyAllowanceLine.swift
//  Yala
//
//  El cupo del día de un presupuesto (2.3), como guía neutra (decisión 23 de la revisión 2.3, Jürgen 2026-11-09):
//  «Quedan 5 días y S/ 400: unos S/ 80 al día. Hoy llevas S/ 120, S/ 40 más que eso». Sin rosa ni alerta: pasarse un
//  día es válido, y el estado del presupuesto ya lo dicen la barra y su palabra. La cuenta es la de siempre
//  (`DailyAllowanceLogic`). Una sola vista para la fila del widget del Panel y el detalle del presupuesto. Sin cupo que
//  enseñar (período cerrado, presupuesto ya agotado) no pinta nada.
//

import SwiftUI

struct DailyAllowanceLine: View {
    let summary: BudgetSummary
    var font: Font = DS.Typography.captionSmall

    @Environment(AppPreferences.self) private var appPreferences

    /// Un presupuesto desactivado no tiene cupo: no cuenta para nada hasta que se reactive.
    private var guide: DailyAllowanceLogic.Guide? {
        guard summary.status != .inactive else { return nil }
        return DailyAllowanceLogic.guide(
            limit: summary.budget.limitAmount,
            spent: summary.spent,
            spentToday: summary.spentToday,
            daysRemaining: summary.daysRemaining
        )
    }

    var body: some View {
        if let guide {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(ThemeColor.thAccentText)
                    .accessibilityHidden(true)
                // La frase entera, en varias líneas si hace falta: encogida a una sola no se leía.
                Text(text(for: guide))
                    .foregroundStyle(Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(font)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("budget_daily_allowance")
        }
    }

    /// El cupo del día en negrita: es lo que se lee de un vistazo.
    private func text(for guide: DailyAllowanceLogic.Guide) -> AttributedString {
        let code = summary.budget.currencyCode
        let perDay = appPreferences.currency(guide.perDay, currencyCode: code)
        let sentence = L10n.DailyAllowance.guide(
            daysRemaining: guide.daysRemaining,
            leftAtStartOfDay: appPreferences.currency(guide.leftAtStartOfDay, currencyCode: code),
            perDay: perDay,
            spentToday: guide.spentToday > 0 ? appPreferences.currency(guide.spentToday, currencyCode: code) : nil,
            overPerDay: guide.overPerDay > 0 ? appPreferences.currency(guide.overPerDay, currencyCode: code) : nil
        )
        var attributed = AttributedString(sentence)
        // El último día no nombra el cupo (es todo lo que queda): no hay nada que resaltar.
        if guide.daysRemaining > 1, let range = attributed.range(of: perDay) {
            attributed[range].font = font.weight(.semibold)
            attributed[range].foregroundColor = Color.primary
        }
        return attributed
    }
}

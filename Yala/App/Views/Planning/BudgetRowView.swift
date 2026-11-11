//
//  BudgetRowView.swift
//  Yala
//
//  Individual budget card component
//

import SwiftData
import SwiftUI

struct BudgetRowView: View {
    let summary: BudgetSummary
    let currencyCode: String
    /// Los días que quedan, en la fila. La lista los quita cuando ya los dice el título de la sección (todos los
    /// presupuestos del período comparten fin): repetidos en cada fila, no dejaban sitio y los importes perdían los decimales.
    var showsDaysLeft = true
    /// «Te quedan» sobre la cifra; la lista lo quita cuando ya lo dice el título de la sección.
    var showsRemainingLabel = true

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // Borrar un presupuesto desde su editor o su detalle deja esta fila montada hasta que la lista recalcula (150 ms
        // después, `BudgetsViewModel.scheduleRecalculation`), y puede volver a pintarse con él ya borrado: en iOS 27.x
        // leerlo aborta la app. Molde de `RecordRowView` (card f8rj).
        if summary.budget.isDeleted || summary.budget.modelContext == nil {
            EmptyView()
        } else {
            row
        }
    }

    private var row: some View {
        NavigationLink(value: BudgetNavigationID(id: summary.budget.persistentModelID)) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Top row: Icon + Name + Amount. A tamaños de accesibilidad el importe baja bajo el
                // nombre (`AdaptiveRowStack`): en fila se partía carácter a carácter («S/ 435. / 00»).
                AdaptiveRowStack(spacing: DS.Spacing.md, stackedSpacing: DS.Spacing.sm) {
                    // Icon badge
                    budgetIcon

                    // Budget name
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        HStack(spacing: DS.Spacing.xs) {
                            // body (peso normal): la cifra de la derecha es lo único en semibold de la fila.
                            Text(summary.budget.name)
                                .font(DS.Typography.body)
                                .foregroundStyle(.primary)
                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)

                            if summary.budget.isFavorite {
                                Image(systemName: "star.fill")
                                    .font(DS.Typography.captionSmall)
                                    .foregroundStyle(DS.Semantic.favoriteIcon)
                                    .accessibilityHidden(true)
                            }
                        }

                        // Status info (% spent + days remaining)
                        statusInfo
                    }
                } trailing: {
                    // Lo que queda, o lo que te pasaste (UX 2.2 · L9-1): es lo que se viene a mirar. Lo gastado va en la
                    // línea gris de la izquierda; la fila no crece.
                    HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xxs) {
                        if BudgetRemainingLogic.isOver(limit: summary.budget.limitAmount, spent: summary.spent) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(DS.Typography.captionSmall)
                                .foregroundStyle(Color.overBudgetText)
                                .accessibilityHidden(true)
                        }
                        BudgetRemainingFigure(
                            limit: summary.budget.limitAmount,
                            spent: summary.spent,
                            currencyCode: currencyCode,
                            daysRemaining: summary.daysRemaining,
                            alignment: .trailingUnlessStacked(dynamicTypeSize),
                            showsLabel: showsRemainingLabel
                        )
                    }
                }

                // Progress bar
                // Barra y palabra del mismo estado (decisión 23 de 2.3): rosa y «Te pasaste» solo por encima del límite.
                BudgetProgressBar(
                    percentage: summary.percentage,
                    color: summary.color,
                    isExceeded: budgetStatus == .overLimit,
                    height: DS.Sizing.budgetRowProgressBarHeight
                )

                BudgetStatusLabel(status: budgetStatus)

                // Sin filtros cuenta TODO lo gastado (UX 2.2 · L9-2): «Viajes» salió al 1522% sin que nada lo dijera.
                if summary.budget.countsAllExpenses {
                    BudgetCountsAllExpensesNote()
                }

                // Exceeded encouragement (brand voice: constructive, never scolding)
                if summary.status == .exceeded {
                    Text(NSLocalizedString("budgets.exceeded.encouragement", comment: ""))
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(DS.Spacing.lg)
            .contentShape(Rectangle())
            .solidCard(radius: DS.Radius.md)
        }
        .buttonStyle(.plain)
        .pointerHighlight(cornerRadius: DS.Radius.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityIdentifier("budget_row_\(summary.budget.name)")
    }

    // MARK: - Components

    private var budgetIcon: some View {
        ZStack {
            Circle()
                .fill(Color(hex: summary.color))
                .frame(width: 40, height: 40)

            Image(systemName: summary.icon)
                .font(DS.Typography.label)
                .foregroundStyle(.white)
        }
    }

    /// «S/ 1,408.00 de S/ 1,800.00 · 18 días» (UX 2.2 · L9-1): sin porcentaje y en una línea. Un período cerrado dice
    /// «Cerrado».
    private var statusInfo: some View {
        BudgetSpentLine(
            spent: summary.spent,
            limit: summary.budget.limitAmount,
            currencyCode: currencyCode,
            suffix: showsDaysLeft ? L10n.UXL9.shortDays(summary.daysRemaining) : nil
        )
    }

    private var budgetStatus: BudgetCounterStatus {
        BudgetStatusCounter.classify(spent: summary.spent, limit: summary.budget.limitAmount)
    }

    /// La fila combina sus hijos con etiqueta propia: sin añadirla aquí, VoiceOver no diría la palabra del estado. Lleva lo
    /// que la fila enseña en grande —«Te quedan S/ 392.00»— y los días, también cuando la fila no los pinta porque van
    /// en el título de la sección (lote 04 de mejoras necesarias 2.3: VoiceOver no decía ni lo uno ni lo otro).
    private var accessibilityLabelText: String {
        let base = L10n.Accessibility.budgetRow(summary.budget.name, Int(summary.percentage), formattedSpent, formattedLimit)
        var parts = [base, remainingSpoken, L10n.UXL9.shortDays(summary.daysRemaining)]
        if let word = BudgetStatusLabel.word(for: budgetStatus) { parts.append(word) }
        return parts.joined(separator: ", ")
    }

    private var remainingSpoken: String {
        let limit = summary.budget.limitAmount
        let label = BudgetRemainingLogic.figureLabel(limit: limit, spent: summary.spent, daysRemaining: summary.daysRemaining)
        let amount = appPreferences.currency(abs(BudgetRemainingLogic.remaining(limit: limit, spent: summary.spent)),
                                             currencyCode: currencyCode)
        return "\(L10n.UXL9.figureLabel(label)) \(amount)"
    }

    // MARK: - Formatters

    private var formattedSpent: String {
        appPreferences.currency(summary.spent, currencyCode: currencyCode)
    }

    private var formattedLimit: String {
        appPreferences.currency(summary.budget.limitAmount, currencyCode: currencyCode)
    }
}

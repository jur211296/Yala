//
//  CashFlowMonthDetailView.swift
//  Yala
//
//  Full-width detail view for the selected month in cash flow.
//
//  Auditoría UX 2.2 · lote 18 decidido:
//  - L18-11 (opción C, variante 2): arriba, el mes («octubre de 2026 · Este mes» y «Llevas el 68 % de lo que planeaste
//    gastar») y su resumen en frases —«Este mes te sobran S/ 3,283», «Si sigue así, a fin de diciembre tendrías S/ X»,
//    «Empezaste con S/ 0 · Cambiar»— en lugar del pie «Disponible / Acumulado» con «?» y un lápiz (L18-10).
//  - Lienzo «Una sola Yala»: el resumen es la cifra grande de los heros, «Ingresos» y «Gastos» son títulos de sección
//    de la app con su total en blanco a la derecha, y cada línea es una tarjeta como un presupuesto (2A).
//

import SwiftData
import SwiftUI

struct CashFlowMonthDetailView: View {
    let month: CashFlowMonth
    @Bindable var viewModel: CashFlowPlanViewModel
    let currencyCode: String
    let transactions: [TransactionItem]
    var onCellDetailDismiss: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var incomeCollapsed = false
    @State private var expenseCollapsed = false
    @State private var selectedCellLineID: UUID?
    /// La línea que el menú contextual pidió borrar; el diálogo la confirma o la suelta.
    @State private var pendingDeleteLine: CashFlowLine?
    @State private var showDeleteLineConfirmation = false

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    /// Para el pago de las tarjetas del mes (card nmtk): todas, porque qué es línea lo decide `AccountLineLogic` con todas.
    @Query private var accounts: [Account]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            monthTitleRow

            monthSummary
                .coachMarkAnchor("cfTableAvailable")

            incomeSection

            expenseSection

            cardPayments
        }
        // Plegar Ingresos o Gastos recoge sus filas. Implícita: el `withAnimation` del rótulo no anima dentro de una
        // pestaña (card 8atf; regla de `swiftui-ds.md`).
        .animation(reduceMotion ? nil : .easeInOut(duration: DS.Animation.fast), value: incomeCollapsed)
        .animation(reduceMotion ? nil : .easeInOut(duration: DS.Animation.fast), value: expenseCollapsed)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.lg)
        .sheet(isPresented: Binding(
            get: { selectedCellLineID != nil },
            set: { if !$0 { selectedCellLineID = nil } }
        ), onDismiss: onCellDetailDismiss) {
            if let lineID = selectedCellLineID,
               let lineResult = allLines.first(where: { $0.lineID == lineID }) {
                CashFlowCellDetailSheet(
                    lineResult: lineResult,
                    line: viewModel.line(for: lineID),
                    month: month,
                    currencyCode: currencyCode,
                    transactions: transactions,
                    viewModel: viewModel
                )
            }
        }
        // Alerta y no `confirmationDialog`: dentro del scroll, iOS 26 pinta el diálogo como un globo anclado sin
        // «Cancelar» (medido; regla de `swiftui-ds.md`), y borrar una línea es una decisión sobre datos: la salida
        // de no borrar tiene que verse.
        .alert(
            L10n.CashFlowPlan.deleteLineConfirmation,
            isPresented: $showDeleteLineConfirmation,
            presenting: pendingDeleteLine
        ) { line in
            Button(L10n.Action.delete, role: .destructive) {
                viewModel.removeLine(line)
                pendingDeleteLine = nil
            }
            .accessibilityIdentifier("cashflow_line_delete_confirm")
            Button(L10n.Action.cancel, role: .cancel) {
                pendingDeleteLine = nil
            }
            .accessibilityIdentifier("cashflow_line_delete_cancel")
        }
    }

    // MARK: - El mes (L18-11)

    private var monthTitleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
            // Título de la pantalla: con mayúscula («Octubre de 2026»); el formato del mes la da en minúscula.
            Text(ComparativeLabelsLogic.capitalizedFirst(
                month.date.formatted(.dateTime.month(.wide).year()), locale: AppLocale.current
            ))
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
                .accessibilityIdentifier("cashflow_month_title")

            if month.isCurrent {
                Text(L10n.CashFlowPlan.thisMonth)
                    .font(DS.Typography.captionSmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(.thOnAccent)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(Capsule().fill(theme.accent))
            } else {
                Text(month.isPast ? L10n.CashFlowPlan.pastMonth : L10n.CashFlowPlan.futureMonth)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: DS.Spacing.sm)

            if let share = CashFlowMonthSummaryLogic.spentShare(of: month) {
                Text(L10n.UXL18.spentShare(share))
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("cashflow_month_spent_share")
            }
        }
    }

    /// La cifra grande del mes con las frases de C2 debajo.
    private var monthSummary: some View {
        HeroHeader {
            HeroHeaderLabel(text: CashFlowMonthSummaryLogic.heroLabel(for: month))
        } period: {
            EmptyView()
        } content: {
            AmountText(
                value: abs(month.netFlow),
                currencyCode: currencyCode,
                font: DS.Typography.panelHeroAmount,
                secondaryFont: DS.Typography.panelHeroAmountSecondary
            )
            .accessibilityIdentifier("cashflow_month_net")

            if viewModel.plan?.showAccumulatedBalance ?? true {
                if let end = CashFlowMonthSummaryLogic.projectedEnd(of: viewModel.projection?.months ?? []),
                   let balance = end.accumulatedBalance {
                    Text(L10n.UXL18.projectedEnd(
                        CashFlowMonthSummaryLogic.monthName(end.date),
                        appPreferences.currency(balance, currencyCode: currencyCode)
                    ))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("cashflow_month_projected_end")
                }
                startingBalanceRow
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cashflow_month_summary")
    }

    /// «Empezaste con S/ X · Cambiar» (L18-10): sustituye al lápiz tachado del pie.
    private var startingBalanceRow: some View {
        HStack(spacing: DS.Spacing.xs) {
            Text(L10n.UXL18.startedWith(
                appPreferences.currency(viewModel.plan?.startingBalance ?? 0, currencyCode: currencyCode)
            ))
            .font(DS.Typography.caption)
            .foregroundStyle(.secondary)
            Button {
                viewModel.showEditStartingBalance = true
            } label: {
                Text("· " + L10n.UXL18.change)
                    .font(DS.Typography.caption.weight(.semibold))
                    .foregroundStyle(theme.accentText)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // Suelto en el rotor de VoiceOver, «Cambiar» no dice qué cambia.
            .accessibilityLabel(L10n.CashFlowPlan.editStartingBalance)
            .accessibilityIdentifier("cashflow_change_starting_balance")
        }
    }

    // MARK: - Secciones

    private var incomeSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(
                title: L10n.CashFlowPlan.incomeSection,
                total: month.totalIncome,
                isCollapsed: $incomeCollapsed
            )

            if !incomeCollapsed {
                lineRows(for: month.incomeLines)
                uncategorizedRow(
                    result: month.otherIncome,
                    label: L10n.CashFlowPlan.otherIncomeLabel,
                    action: { viewModel.showOthersIncomeBreakdown = true }
                )
                addLineButton(isIncome: true)
            }
        }
    }

    private var expenseSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            sectionHeader(
                title: L10n.CashFlowPlan.expenseSection,
                total: month.totalExpense,
                isCollapsed: $expenseCollapsed
            )
            .coachMarkAnchor("cfTableCell")

            if !expenseCollapsed {
                lineRows(for: month.expenseLines)
                uncategorizedRow(
                    result: month.otherExpenses,
                    label: L10n.CashFlowPlan.otherExpensesLabel,
                    action: { viewModel.showOthersBreakdown = true }
                )
                addLineButton(isIncome: false)
                    .coachMarkAnchor("cfTableAdd")
            }
        }
    }

    // MARK: - Pago de tarjetas (D4-A)

    /// El pago de lo facturado de cada tarjeta cuya fecha de pago cae en este mes. Informa, no suma.
    @ViewBuilder
    private var cardPayments: some View {
        let payments = CreditCardStatementSummary.payments(
            accounts: accounts, inMonthOf: month.date, now: .now, calendar: .current)
        if !payments.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                ForEach(payments, id: \.accountID) { card in
                    CashFlowCardPaymentRow(card: card)
                }
            }
        }
    }

    // MARK: - Line Rows

    @ViewBuilder
    private func lineRows(for lines: [CashFlowLineResult]) -> some View {
        ForEach(lines, id: \.lineID) { lineResult in
            let line = viewModel.line(for: lineResult.lineID)
            CashFlowDetailLineRow(
                lineResult: lineResult,
                line: line,
                month: month,
                currencyCode: currencyCode,
                onTapLine: {
                    selectedCellLineID = lineResult.lineID
                },
                onDeleteLine: line.map { l in
                    {
                        pendingDeleteLine = l
                        showDeleteLineConfirmation = true
                    }
                }
            )
        }
    }

    // MARK: - Uncategorized Row

    @ViewBuilder
    private func uncategorizedRow(result: CashFlowOtherResult?, label: String, action: @escaping () -> Void) -> some View {
        if let result, result.plannedAmount > 0 {
            Button(action: action) {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "ellipsis")
                        .font(DS.Typography.label)
                        .foregroundStyle(.secondary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(DS.Semantic.neutralBackground))
                    Text(label)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    let displayAmount = result.realAmount ?? result.plannedAmount
                    AmountText(
                        value: displayAmount,
                        currencyCode: currencyCode,
                        font: DS.Typography.headline.monospacedDigit(),
                        tint: .secondary
                    )
                    Image(systemName: "chevron.right")
                        .font(DS.Typography.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(DS.Spacing.lg)
                .contentShape(Rectangle())
                .solidCard(radius: DS.Radius.md)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Section Header

    /// Título de sección de la app (sin mayúsculas) con su total en blanco a la derecha; tocarlo pliega la sección.
    private func sectionHeader(title: String, total: Double, isCollapsed: Binding<Bool>) -> some View {
        Button {
            withAnimation(.easeInOut(duration: DS.Animation.fast)) {
                isCollapsed.wrappedValue.toggle()
            }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Text(title)
                    .font(DS.Typography.title3.weight(.bold))
                    .foregroundStyle(.primary)

                Spacer()

                AmountText(
                    value: total,
                    currencyCode: currencyCode,
                    font: DS.Typography.headline.monospacedDigit()
                )

                Image(systemName: isCollapsed.wrappedValue ? "chevron.down" : "chevron.up")
                    .font(DS.Typography.label)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.primary)
                    .frame(width: DS.Panel.headerAccessorySize, height: DS.Panel.headerAccessorySize)
                    .glassEffect(.regular.interactive(), in: Circle())
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Add Line Button

    private var allLines: [CashFlowLineResult] {
        month.incomeLines + month.expenseLines
    }

    private func addLineButton(isIncome: Bool) -> some View {
        Button {
            viewModel.addLineIsIncome = isIncome
            viewModel.showAddLine = true
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "plus.circle")
                    .font(DS.Typography.subheadline)
                Text(L10n.CashFlowPlan.addLine)
                    .font(DS.Typography.subheadline.weight(.semibold))
            }
            .foregroundStyle(theme.accentText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Spacing.xs)
            .padding(.vertical, DS.Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(isIncome ? "cashflow_add_line_income" : "cashflow_add_line_expense")
    }
}

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
//  - S2 del replanteo (decisiones de Jürgen del 18-nov-2026): una sola historia, «Empezaste con · Entró · Salió · Terminas
//    con» (`FlujoDetalleMesLogica`), en lugar de «Al 30 tendrías», «Este mes te quedaría», «Si sigue así, a fin de…» y
//    «Empezaste con S/ 0 · Cambiar». Y cada categoría agrupa sus líneas (la subcategoría es la fila base) y se pliega.
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
    /// Las categorías plegadas (por su id). Vive en la pantalla: no se guarda.
    @State private var collapsedGroups: Set<PersistentIdentifier> = []
    /// La hoja del «?» de la cifra del mes (hero claro, 2026-11-16).
    @State private var heroInfo: HeroInfoRequest?
    @State private var selectedCellLineID: UUID?
    /// La línea que el menú contextual pidió borrar; el diálogo la confirma o la suelta.
    @State private var pendingDeleteLine: CashFlowLine?
    @State private var showDeleteLineConfirmation = false

    @Environment(\.yalaTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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

            convertedLimitsNote

            cardPayments
        }
        // Plegar Ingresos o Gastos recoge sus filas. Implícita: el `withAnimation` del rótulo no anima dentro de una
        // pestaña (card 8atf; regla de `swiftui-ds.md`).
        .animation(reduceMotion ? nil : .easeInOut(duration: DS.Animation.fast), value: incomeCollapsed)
        .animation(reduceMotion ? nil : .easeInOut(duration: DS.Animation.fast), value: expenseCollapsed)
        .animation(reduceMotion ? nil : .easeInOut(duration: DS.Animation.fast), value: collapsedGroups)
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

    /// Con texto de accesibilidad el mes, su estado y «Llevas el…» van uno debajo del otro: en una fila el mes se partía
    /// por sílabas («No-viem-bre») y la frase de la derecha quedaba en una columna estrecha (lote 05 de 2.3, zona 36 P5).
    @ViewBuilder
    private var monthTitleRow: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                monthTitle
                monthStatus
                spentShare
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                monthTitle

                monthStatus

                Spacer(minLength: DS.Spacing.sm)

                spentShare
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private var monthTitle: some View {
        // Título de la pantalla: con mayúscula («Octubre de 2026»); el formato del mes la da en minúscula.
        Text(ComparativeLabelsLogic.capitalizedFirst(
            month.date.formatted(.dateTime.month(.wide).year()), locale: AppLocale.current
        ))
            .font(DS.Typography.headline)
            .foregroundStyle(.primary)
            .accessibilityIdentifier("cashflow_month_title")
    }

    @ViewBuilder
    private var monthStatus: some View {
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
    }

    /// «Llevas el 68 % de lo que planeaste gastar»; sin plan de gasto, nada. La alineación la pone quien la coloca.
    @ViewBuilder
    private var spentShare: some View {
        if let share = CashFlowMonthSummaryLogic.spentShare(of: month) {
            Text(L10n.UXL18.spentShare(share))
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("cashflow_month_spent_share")
        }
    }

    /// «Al 30 de noviembre tendrías» del mes en curso (decisión 30 de 2.3): de ahí sale la línea de qué cuentas suman
    /// hoy. La cifra es la de la historia del mes, que el motor calcula igual que el Panel.
    private var currentMonthEnd: MonthEndBalanceLogic.Result? {
        month.isCurrent ? viewModel.monthEnd : nil
    }

    private var historia: FlujoDetalleMesLogica.Historia { FlujoDetalleMesLogica.historia(month) }

    /// La cifra grande del mes —con cuánto terminas— y debajo la historia que la explica: empezaste, entró, salió. Sin
    /// cuentas que sumen, la cifra es lo que queda (o falta) ese mes, como antes.
    private var monthSummary: some View {
        let historia = historia
        let label = historia.terminas != nil
            ? L10n.FlujoDetalleMes.terminas(historia.tiempo)
            : CashFlowMonthSummaryLogic.netLabel(for: month)
        // El hero claro (2026-11-16): el rótulo con su «?» y la cifra pegada a él, sin el aire de antes.
        return HeroClaroHeader {
            HeroHeaderLabel(text: label)
            HeroInfoButton(identifier: "cashflow_hero_info") {
                heroInfo = HeroInfoRequest(
                    topic: HeroClaroLogic.cashFlowTopic(
                        isCurrentMonth: month.isCurrent, hasMonthEnd: month.isCurrent && historia.terminas != nil
                    ),
                    figureLabel: label,
                    isClosedPeriod: month.isPast
                )
            }
        } period: {
            EmptyView()
        } figure: {
            if let terminas = historia.terminas {
                AmountText(
                    value: terminas,
                    currencyCode: currencyCode,
                    font: DS.Typography.panelHeroAmount,
                    secondaryFont: DS.Typography.panelHeroAmountSecondary,
                    isEstimate: historia.esEstimada
                )
                .accessibilityIdentifier("cashflow_month_end_closing")
            } else {
                AmountText(
                    value: abs(month.netFlow),
                    currencyCode: currencyCode,
                    font: DS.Typography.panelHeroAmount,
                    secondaryFont: DS.Typography.panelHeroAmountSecondary,
                    isEstimate: historia.esEstimada
                )
                .accessibilityIdentifier("cashflow_month_net")
            }
        } detail: {
            FlujoDetalleMesHistoriaView(historia: historia, currencyCode: currencyCode)

            if let end = currentMonthEnd, historia.terminas != nil {
                Text(L10n.ProjectedFlow.source(end.source))
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .heroInfoSheet($heroInfo, currencyCode: currencyCode)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cashflow_month_summary")
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
                groupedLines(month.incomeLines, groups: month.incomeGroups)
                uncategorizedRow(
                    result: month.otherIncome,
                    label: L10n.CashFlowPlan.otherIncomeLabel,
                    identifier: "cashflow_others_income_row",
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
                groupedLines(month.expenseLines, groups: month.expenseGroups)
                uncategorizedRow(
                    result: month.otherExpenses,
                    label: L10n.CashFlowPlan.otherExpensesLabel,
                    identifier: "cashflow_others_expense_row",
                    action: { viewModel.showOthersBreakdown = true }
                )
                addLineButton(isIncome: false)
                    .coachMarkAnchor("cfTableAdd")
            }
        }
    }

    // MARK: - Límites en otra moneda (encargo del 2026-11-20)

    /// «Incluye 2 límites en USD convertidos al promedio de noviembre (3.70).» bajo las líneas del mes.
    @ViewBuilder
    private var convertedLimitsNote: some View {
        let convertidas = (month.incomeLines + month.expenseLines).compactMap { $0.limitBreakdown }
            .filter { !$0.monedasExtranjeras.isEmpty }
        if !convertidas.isEmpty {
            let monedas = convertidas.reduce(into: Set<String>()) { $0.formUnion($1.monedasExtranjeras) }
            let unica = monedas.count == 1 ? monedas.first : nil
            // Con una sola moneda, su tasa del mes (todas las líneas usan la misma).
            let tasa = unica != nil ? convertidas.lazy.compactMap(\.tasa).first : nil
            let futuro = !month.isPast && !month.isCurrent
            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(L10n.FlujoDetalleLinea.resumenConvertidos(
                    cuantos: convertidas.count, moneda: unica,
                    mes: CashFlowMonthSummaryLogic.monthInSentence(month.date),
                    tasa: tasa.map { FlujoMonedaTexto.tasa($0) }, futuro: futuro
                ))
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(DS.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(Color.secondary.opacity(0.1))
            )
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("cashflow_month_converted_note")
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

    // MARK: - Líneas por categoría

    /// Cada categoría agrupa sus líneas y se pliega; las líneas sin categoría van después (ajuste obligatorio de Jürgen
    /// del 18-nov-2026: la subcategoría es la fila base, la categoría su suma).
    @ViewBuilder
    private func groupedLines(_ lines: [CashFlowLineResult], groups: [CashFlowCategoryGroup]) -> some View {
        let tabla = FlujoDetalleMesLogica.tabla(lineas: lines, grupos: groups)
        ForEach(tabla.grupos) { grupo in
            let category = groupCategory(grupo)
            FlujoDetalleMesGrupoView(
                grupo: grupo,
                iconName: category?.iconName,
                colorHex: category?.colorHex,
                currencyCode: currencyCode,
                isCollapsed: collapsedGroups.contains(grupo.id),
                onToggle: { toggleGroup(grupo.id) }
            ) { lineResult in
                lineRow(lineResult)
            }
        }
        lineRows(for: tabla.sueltas)
    }

    /// La categoría del grupo, para su icono: la de cualquiera de sus líneas.
    private func groupCategory(_ grupo: FlujoDetalleMesLogica.Grupo) -> Category? {
        for lineResult in grupo.lineas {
            guard let line = viewModel.line(for: lineResult.lineID) else { continue }
            if let category = line.category ?? line.subcategory?.category { return category }
        }
        return nil
    }

    private func toggleGroup(_ id: PersistentIdentifier) {
        if collapsedGroups.contains(id) {
            collapsedGroups.remove(id)
        } else {
            collapsedGroups.insert(id)
        }
    }

    // MARK: - Line Rows

    @ViewBuilder
    private func lineRows(for lines: [CashFlowLineResult]) -> some View {
        ForEach(lines, id: \.lineID) { lineResult in
            lineRow(lineResult)
        }
    }

    private func lineRow(_ lineResult: CashFlowLineResult) -> some View {
        let line = viewModel.line(for: lineResult.lineID)
        return CashFlowDetailLineRow(
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

    // MARK: - Uncategorized Row

    @ViewBuilder
    private func uncategorizedRow(
        result: CashFlowOtherResult?, label: String, identifier: String, action: @escaping () -> Void
    ) -> some View {
        // En un mes que viene, con plan, la fila se ve también en 0 (19-nov-2026): la hoja dice que no hay fijos fuera
        // del plan y deja volver a encender una partida apagada en «Considerar a futuro».
        if let result, result.plannedAmount > 0 || result.isFixedOnly {
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
            .accessibilityIdentifier(identifier)
        }
    }

    // MARK: - Section Header

    /// Título de sección de la app (sin mayúsculas) con su total en blanco a la derecha; tocarlo pliega la sección.
    private func sectionHeader(title: String, total: Double, isCollapsed: Binding<Bool>) -> some View {
        Button {
            // Lo anima la implícita de `incomeCollapsed` / `expenseCollapsed` (card oxyr).
            isCollapsed.wrappedValue.toggle()
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

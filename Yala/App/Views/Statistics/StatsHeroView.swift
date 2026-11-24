//
//  StatsHeroView.swift
//  Yala
//
//  El hero de las cuatro pestañas de Estadísticas y de Registros (decisión de Jürgen del 20-nov-2026, «hero limpio»):
//  rótulo con su «?», la píldora del período, la cifra grande y debajo ingresos y gastos con sus flechas. Nada más: sin
//  «Ingresos»/«Gastos» escritos encima de cada monto (las flechas ya lo dicen) y sin la línea de abajo («X registros ·
//  Sigue así», «X categorías», la variación del neto).
//
//  Antes cada pestaña montaba su hero y Distribución tenía uno distinto, sin flechas. Uno solo para las cuatro es lo que
//  las deja iguales al deslizar entre ellas: misma tipografía, mismo aire y misma altura.
//
//  La cifra grande es «Tu dinero hoy» (`StatsMoneyTodayLogic`, la misma del Panel) salvo en los estados de un solo lado
//  (gasto, ingreso o total), que pone la pestaña. El hero la calcula él mismo cuando cambia algo de lo que depende,
//  como `PanelHeroSection`: no en cada repintado, porque recorre todos los movimientos.
//

import SwiftData
import SwiftUI

/// Ingresos y gastos del período, bajo la cifra.
struct StatsHeroFlow: Equatable {
    var income: Double
    var expense: Double
    var incomeIsApproximate = false
    var expenseIsApproximate = false
    var incomeVariation: Double?
    var expenseVariation: Double?
}

extension StatsHeroFlow {
    /// Ingresos y gastos del resumen del período, con su variación: los de Resumen, Tendencias y Distribución.
    init(_ summary: PeriodSummary) {
        self.init(
            income: summary.totalIncome,
            expense: summary.totalExpense,
            incomeIsApproximate: summary.incomeAmountsAreApproximate,
            expenseIsApproximate: summary.expenseAmountsAreApproximate,
            incomeVariation: summary.incomeVariation,
            expenseVariation: summary.expenseVariation
        )
    }
}

/// Las flechas que filtran (Registros): tocar una deja solo ese lado, y la otra se atenúa.
struct StatsHeroNatureFilter {
    let selected: Set<TransactionNature>
    let toggle: (TransactionNature) -> Void
}

extension EnvironmentValues {
    /// «Tu dinero hoy» ya calculado en este contenedor de Estadísticas (`StatsMoneyTodayMemory`). Lo pone
    /// `DetailContainerView`; fuera de él, `nil` y cada hero calcula el suyo.
    @Entry var statsMoneyTodayMemory: StatsMoneyTodayMemory? = nil
}

/// De dónde sale «Tu dinero hoy»: los movimientos y las cuentas que ya cargó la pantalla.
struct StatsHeroMoneySource {
    let accounts: [Account]
    let transactions: [TransactionItem]
    /// `DetailContainerViewModel.dataGeneration`: avanza con cada recarga que trae algo.
    let dataGeneration: Int
}

struct StatsHeroView<Period: View>: View {
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(SessionState.self) private var sessionState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// La memoria de «Tu dinero hoy» del contenedor de Estadísticas; `nil` fuera de él (la pestaña Registros).
    @Environment(\.statsMoneyTodayMemory) private var moneyMemory

    let caption: StatsHeroCaption
    /// La cifra cuando es de un lado (gasto, ingreso o total); `nil` si no hay nada que enseñar. Con `.moneyToday` no se lee.
    var sideFigure: StatsMoneyTodayLogic.Figure?
    /// Ingresos y gastos; `nil` mientras no hay resumen del período.
    var flow: StatsHeroFlow?
    /// «Solo gastos»: la variación del gasto bajo la cifra (`.some(nil)` = sin período anterior). Fuera de ese modo, `nil`.
    var expensesOnlyVariation: Double?? = nil
    let money: StatsHeroMoneySource
    let currencyCode: String
    var natureFilter: StatsHeroNatureFilter?
    var isShort = false
    let verticalPadding: CGFloat
    var figureIdentifier = "stats_hero_amount"
    var incomeIdentifier = "stats_kpi_income"
    var expenseIdentifier = "stats_kpi_expense"
    @ViewBuilder var period: Period

    /// La hoja del «?»: qué es la cifra y cómo se calcula.
    @State private var heroInfo: HeroInfoRequest?
    /// «Tu dinero hoy» ya calculado; `nil` hasta el primer cálculo, para no pintar un 0 que luego rueda.
    @State private var moneyFigure: StatsMoneyTodayLogic.Figure?

    var body: some View {
        let figure = displayedFigure
        let isClosed = self.isClosed
        SummaryHeaderStack(isShort: isShort, verticalPadding: verticalPadding) {
            period
        } caption: {
            if figure != nil {
                HStack(spacing: DS.Spacing.xs) {
                    HeroHeaderLabel(text: caption.text(isClosed: isClosed))
                        .accessibilityIdentifier("stats_hero_caption")
                    HeroInfoButton(identifier: "stats_hero_info") {
                        heroInfo = HeroInfoRequest(
                            topic: HeroClaroLogic.topic(for: caption),
                            figureLabel: caption.text(isClosed: isClosed),
                            isClosedPeriod: isClosed
                        )
                    }
                }
            }
        } figure: {
            if let figure {
                AmountText(
                    value: figure.value,
                    currencyCode: currencyCode,
                    font: DS.Typography.panelHeroAmount, secondaryFont: DS.Typography.panelHeroAmountSecondary,
                    isEstimate: figure.isApproximate,
                    animatesValue: true
                )
                .accessibilityIdentifier(figureIdentifier)
            }
        } detail: {
            if figure != nil {
                if sessionState.isExpensesOnlyMode {
                    // La fila de flechas sería solo el gasto, que ya es la cifra grande: queda su variación.
                    if let variation = expensesOnlyVariation {
                        ExpensesOnlyHeroVariation(variation: variation)
                    }
                } else if let flow {
                    flowRow(flow)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
        .heroInfoSheet($heroInfo, currencyCode: currencyCode)
        .onChange(of: moneyInputs, initial: true) { _, inputs in
            recalculateMoney(inputs)
        }
    }

    // MARK: - La cifra

    private var isClosed: Bool {
        PeriodTenseLogic.isClosed(period: sessionState.selectedPeriod, customRange: sessionState.customDateRange)
    }

    private var displayedFigure: StatsMoneyTodayLogic.Figure? {
        guard caption == .moneyToday else { return sideFigure }
        return money.accounts.isEmpty ? nil : moneyFigure
    }

    /// Lo que mueve «Tu dinero hoy» (`StatsHeroMoneyInputs`).
    private var moneyInputs: StatsHeroMoneyInputs {
        let closed = isClosed
        let interval = closed
            ? sessionState.selectedPeriod.dateInterval(customRange: sessionState.customDateRange)
            : nil
        return StatsHeroMoneyInputs(
            needed: caption == .moneyToday,
            generation: money.dataGeneration,
            transactionCount: money.transactions.count,
            accountScopes: money.accounts.map {
                "\($0.shortcutID.uuidString)|\($0.type)|\($0.parentAccountID?.uuidString ?? "")|\($0.sumsInBalance)"
            },
            currencyCode: currencyCode,
            includeGroups: appPreferences.includeGroupsInPanelTotal,
            overrides: appPreferences.panelMoneyAccountOverrides,
            selectedAccountIDs: sessionState.selectedAccountIDs,
            excludedAccountIDs: sessionState.excludedAccountIDs,
            closedAt: interval.map { StatsMoneyTodayLogic.asOf(isClosed: true, interval: $0) }
        )
    }

    private func recalculateMoney(_ inputs: StatsHeroMoneyInputs) {
        guard inputs.needed else { return }
        // Dentro de Estadísticas, la cifra ya calculada por otra página del mismo contenedor con las mismas entradas se
        // reutiliza: cada página que se montaba al cambiar de chip la volvía a calcular (`StatsMoneyTodayMemory`).
        guard let memory = moneyMemory else {
            let figure = computeMoney(inputs)
            if figure != moneyFigure { moneyFigure = figure }
            return
        }
        let figure = memory.figure(for: inputs, day: Calendar.current.startOfDay(for: .now)) { computeMoney(inputs) }
        if figure != moneyFigure { moneyFigure = figure }
    }

    private func computeMoney(_ inputs: StatsHeroMoneyInputs) -> StatsMoneyTodayLogic.Figure {
        StatsMoneyTodayLogic.figure(
            accounts: money.accounts,
            transactions: money.transactions,
            currencyCode: inputs.currencyCode,
            includeGroups: inputs.includeGroups,
            selectedAccountIDs: inputs.selectedAccountIDs,
            excludedAccountIDs: inputs.excludedAccountIDs,
            overrides: inputs.overrides,
            asOf: inputs.closedAt ?? .now
        )
    }

    // MARK: - Ingresos y gastos

    @ViewBuilder
    private func flowRow(_ flow: StatsHeroFlow) -> some View {
        // Con texto de accesibilidad van en dos líneas (`AdaptiveRowStack`), y cada chip de variación baja bajo su cifra
        // (`AmountWithChipStack`): en una sola, la cifra de gastos se quedaba en «……».
        AdaptiveRowStack(spacing: DS.Spacing.lg, stackedSpacing: DS.Spacing.xs) {
            flowSide(.income, flow: flow)
            flowSide(.expense, flow: flow)
        }
        // El lado que no filtra se atenúa animado. Implícita: en una pestaña un `withAnimation` no anima.
        .dsAnimation(DS.Animation.selection, value: natureFilter?.selected, reduceMotion: reduceMotion)
    }

    @ViewBuilder
    private func flowSide(_ nature: TransactionNature, flow: StatsHeroFlow) -> some View {
        let isIncome = nature == .income
        let value = isIncome ? flow.income : flow.expense
        let isEstimate = isIncome ? flow.incomeIsApproximate : flow.expenseIsApproximate
        let label = isIncome ? L10n.Accessibility.metricIncome : L10n.Accessibility.metricExpense
        let spoken = appPreferences.currency(value, currencyCode: currencyCode, isEstimate: isEstimate)
        let side = AmountWithChipStack {
            Image(systemName: isIncome ? "arrow.up.right" : "arrow.down.right")
                .font(DS.Typography.labelSmall)
                .foregroundStyle(isIncome ? Color.incomeGraph : Color.expenseGraph)
                .accessibilityHidden(true)
            AmountText(
                value: value,
                currencyCode: currencyCode,
                font: DS.Typography.subheadline, secondaryFont: DS.Typography.captionSmall,
                tint: .secondary,
                isEstimate: isEstimate,
                animatesValue: true
            )
            // Sin el rótulo escrito, VoiceOver tiene que decir de qué lado es la cifra: «Ingreso, S/ 500». El importe se
            // queda en la etiqueta, donde lo leía antes (y lo leen los XCUITest, `IncomeExpenseClassificationUITests`).
            .accessibilityLabel("\(label), \(spoken)")
            .accessibilityIdentifier(isIncome ? incomeIdentifier : expenseIdentifier)
        } chip: {
            if appPreferences.showVariations,
               let variation = isIncome ? flow.incomeVariation : flow.expenseVariation {
                VariationChip(variation: variation, size: .small, isExpenseContext: !isIncome)
            }
        }

        if let natureFilter {
            let dimmed = natureFilter.selected.count == 1 && !natureFilter.selected.contains(nature)
            Button {
                natureFilter.toggle(nature)
            } label: {
                side
                    .contentShape(Rectangle())
                    .opacity(dimmed ? 0.3 : 1.0)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
            // El `accessibilityLabel` del botón tapa el de dentro: sin el valor, VoiceOver no lee la cifra.
            .accessibilityValue(spoken)
        } else {
            side
        }
    }
}

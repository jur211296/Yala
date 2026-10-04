//
//  HeroMonthView.swift
//  Yala
//
//  Hero del Panel (PP2-01). Sin card y edge-to-edge — aprovecha todo el
//  ancho del Panel. Fila superior con saludo + `TrendsPeriodMenu`, y resumen
//  "Disponible · Período".
//
//  Amounts use `appPreferences.currency(...)`, which is reactive: any change
//  to decimalPlaces or currencyDisplayFormat invalidates the view immediately.
//

import SwiftUI

struct HeroMonthView: View {
    let data: HeroMonthData
    let currencyCode: String
    let selectedPeriod: DetailPeriod
    let customDateRange: DateInterval?
    let onSelectPeriod: (DetailPeriod) -> Void
    let onCustomPeriodTapped: () -> Void

    /// Income/expense del período actual del Panel — alimentan el resumen
    /// flotante "Disponible · Período". Independiente de `data.income/expense` (que
    /// siempre son del mes calendario para anclar la frase motivacional).
    var periodSummary: PanelHeroPeriodData = .init()

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(SessionState.self) private var sessionState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // La maqueta (rótulo y período arriba, cifra y detalle debajo, todo a la izquierda) es `HeroHeader`, la misma
    // que usan las pestañas de Estadísticas: así las dos cabeceras no pueden volver a divergir.
    var body: some View {
        HeroHeader {
            HeroHeaderLabel(text: summaryLabel)
        } period: {
            TrendsPeriodMenu(
                selectedPeriod: selectedPeriod,
                customDateRange: customDateRange,
                onSelect: onSelectPeriod,
                onCustomTapped: onCustomPeriodTapped
            )
        } content: {
            summaryRow
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel(heroAccessibilityLabel)
    }

    // MARK: - Rótulo del KPI
    //
    // El saludo salió del hero (2026-09-02, sesión de diseño): ocupaba la línea
    // más grande de la pantalla para no decir ningún dato, y el nombre sigue
    // apareciendo en el título de la barra al hacer scroll (`PanelView`).
    // Su hueco lo ocupa el label del KPI, que antes vivía centrado dentro de
    // `summaryRow` — así el hero tiene UN SOLO eje de lectura, el mismo margen
    // izquierdo que el resto del Panel. A tamaños de accesibilidad la píldora
    // del período baja bajo el label (`AdaptiveRowStack`, dentro de `HeroHeader`):
    // en fila no cabían los dos en el ancho de un iPhone SE (medido el 2026-09-28).

    /// Label del KPI SIN el período: la píldora de `TrendsPeriodMenu` va al lado
    /// y ya lo dice. Compuesto con el período seguiría en el label accesible,
    /// donde no hay «al lado» que valga.
    private var summaryLabel: String {
        sessionState.isExpensesOnlyMode ? L10n.Panel.spent : L10n.Panel.Hero.availableLabel
    }

    // MARK: - Summary row ("Disponible · Período" + monto + chips)
    //
    // Los chips income/expense escriben a `sessionState.selectedTransactionNatures`
    // — el filtro propaga al resto del Panel via SSOT. Opacity 0.3 cuando el
    // otro filtro está activo.

    private var summaryRow: some View {
        @Bindable var sessionState = sessionState

        let isIncomeFiltered = sessionState.selectedTransactionNatures == [.income]
        let isExpenseFiltered = sessionState.selectedTransactionNatures == [.expense]
        let hasNatureFilter = isIncomeFiltered || isExpenseFiltered

        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if sessionState.isExpensesOnlyMode {
                // Solo Gastos: el "Disponible" (income - expense) siempre es 0
                // sin ingresos → se muestra el GASTO del período como KPI, con un
                // comparativo "vs período anterior" (MTD-alineado) que le da lectura.
                // Sin pills: la naturaleza está forzada a gasto y el número YA es el gasto.
                AmountText(
                    value: periodSummary.expense,
                    currencyCode: currencyCode,
                    font: DS.Typography.panelHeroAmount,
                    secondaryFont: DS.Typography.panelHeroAmountSecondary,
                    // Solo el lado del gasto: este número no incluye los ingresos.
                    isEstimate: periodSummary.expenseApproximate
                )

                // Gateado también por `showVariations`: `VariationChip` se
                // auto-oculta con la preferencia off, así que sin este guard el
                // caption "vs período anterior" quedaría huérfano sin chip.
                if appPreferences.showVariations, let variation = periodSummary.spentVariation {
                    HStack(spacing: DS.Spacing.xs) {
                        VariationChip(variation: variation, size: .small, isExpenseContext: true)
                        Text(L10n.Statistics.vsPreviousPeriod)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                AmountText(
                    value: periodSummary.available,
                    currencyCode: currencyCode,
                    font: DS.Typography.panelHeroAmount,
                    secondaryFont: DS.Typography.panelHeroAmountSecondary,
                    isEstimate: periodSummary.amountsAreApproximate
                )

                // A tamaños de accesibilidad los dos importes van uno bajo otro (`AdaptiveRowStack`): en fila no
                // cabían y se cortaban por el medio («S/1,7…10»).
                AdaptiveRowStack(spacing: DS.Spacing.md, stackedSpacing: DS.Spacing.xs) {
                    // Income — pill de filtro por naturaleza (income está oculto en
                    // expenses-only, rama que ya no entra aquí).
                    Button {
                        DS.Haptic.selection()
                        dsWithAnimation(reduceMotion) {
                            if isIncomeFiltered {
                                sessionState.selectedTransactionNatures.removeAll()
                            } else {
                                sessionState.selectedTransactionNatures = [.income]
                            }
                        }
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "arrow.up.right")
                                .font(DS.Typography.labelSmall)
                                .foregroundStyle(Color.incomeGraph)
                                .accessibilityHidden(true)
                            AmountText(
                                value: periodSummary.income,
                                currencyCode: currencyCode,
                                font: DS.Typography.subheadline, secondaryFont: DS.Typography.captionSmall,
                                tint: .secondary,
                                isEstimate: periodSummary.incomeApproximate
                            )
                        }
                        .opacity(hasNatureFilter && !isIncomeFiltered ? 0.3 : 1.0)
                    }
                    .buttonStyle(.plain)

                    // Expense pill.
                    Button {
                        DS.Haptic.selection()
                        dsWithAnimation(reduceMotion) {
                            if isExpenseFiltered {
                                sessionState.selectedTransactionNatures.removeAll()
                            } else {
                                sessionState.selectedTransactionNatures = [.expense]
                            }
                        }
                    } label: {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "arrow.down.right")
                                .font(DS.Typography.labelSmall)
                                .foregroundStyle(Color.expenseGraph)
                                .accessibilityHidden(true)
                            AmountText(
                                value: periodSummary.expense,
                                currencyCode: currencyCode,
                                font: DS.Typography.subheadline, secondaryFont: DS.Typography.captionSmall,
                                tint: .secondary,
                                // El MISMO número que el hero pinta con «≈» en Solo Gastos: sin esto
                                // el usuario ve el gasto marcado en un modo y exacto en el otro.
                                isEstimate: periodSummary.expenseApproximate
                            )
                        }
                        .opacity(hasNatureFilter && !isExpenseFiltered ? 0.3 : 1.0)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .contentShape(Rectangle())
    }

    // MARK: - Copy

    /// Lo que oye VoiceOver al llegar al hero. Antes era el saludo, que además
    /// de no ser un dato ya no existe. Aquí SÍ se compone con el período: el
    /// lector no ve la píldora de al lado como parte de la misma frase.
    private var heroAccessibilityLabel: String {
        let valor = sessionState.isExpensesOnlyMode
            ? periodSummary.expense
            : periodSummary.available
        // El `isEstimate` va aquí también, o VoiceOver leería como exacto el mismo número que en
        // pantalla lleva el «≈»: la marca es información, y dejarla solo en el glifo la esconde de
        // quien no lo ve.
        let esAproximado = sessionState.isExpensesOnlyMode
            ? periodSummary.expenseApproximate
            : periodSummary.amountsAreApproximate
        let monto = appPreferences.currency(
            valor, currencyCode: currencyCode, isEstimate: esAproximado
        )
        return "\(summaryLabel) · \(selectedPeriod.displayName), \(monto)"
    }

}

// MARK: - Preview

#Preview("Hero states") {
    VStack(alignment: .leading, spacing: DS.Spacing.xl) {
        HeroMonthView(
            data: HeroMonthData(
                state: .monthStart, income: 0, expense: 0,
                daysRemaining: 28, daysElapsed: 2
            ),
            currencyCode: "PEN",
            selectedPeriod: .thisMonth,
            customDateRange: nil,
            onSelectPeriod: { _ in },
            onCustomPeriodTapped: {}
        )
        HeroMonthView(
            data: HeroMonthData(
                state: .onTrack, income: 11356, expense: 6019,
                daysRemaining: 20, daysElapsed: 10
            ),
            currencyCode: "PEN",
            selectedPeriod: .thisMonth,
            customDateRange: nil,
            onSelectPeriod: { _ in },
            onCustomPeriodTapped: {}
        )
        // Estado neutro — la frase motivacional y el upsellCTA viven en
        // `PanelPanoramaSection`, no en este view.
        HeroMonthView(
            data: HeroMonthData(
                state: .neutral, income: 4500, expense: 1500,
                daysRemaining: 20, daysElapsed: 10
            ),
            currencyCode: "PEN",
            selectedPeriod: .thisMonth,
            customDateRange: nil,
            onSelectPeriod: { _ in },
            onCustomPeriodTapped: {}
        )
    }
    .padding(.vertical)
    .environment(AppPreferences(defaults: .standard))
    .environment(SessionState.shared)
}

#Preview("Hero — Solo Gastos") {
    // Instancia propia (no `.shared`) para no contaminar el SessionState de otros
    // previews. El didSet de `isExpensesOnlyMode` sí escribe a UserDefaults/App
    // Group, pero es inofensivo en el proceso efímero del preview (DEBUG-only).
    let session = SessionState()
    session.isExpensesOnlyMode = true
    return VStack(alignment: .leading, spacing: DS.Spacing.xl) {
        // Con comparativo (gastó menos que el período anterior → chip índigo).
        HeroMonthView(
            data: HeroMonthData(
                state: .neutral, income: 0, expense: 1250,
                daysRemaining: 12, daysElapsed: 18
            ),
            currencyCode: "PEN",
            selectedPeriod: .thisMonth,
            customDateRange: nil,
            onSelectPeriod: { _ in },
            onCustomPeriodTapped: {},
            periodSummary: PanelHeroPeriodData(income: 0, expense: 1250, periodPrevExpense: 1420)
        )
        // Sin previo comparable (usuario nuevo) → sin chip.
        HeroMonthView(
            data: HeroMonthData(
                state: .monthStart, income: 0, expense: 320,
                daysRemaining: 25, daysElapsed: 5
            ),
            currencyCode: "PEN",
            selectedPeriod: .thisMonth,
            customDateRange: nil,
            onSelectPeriod: { _ in },
            onCustomPeriodTapped: {},
            periodSummary: PanelHeroPeriodData(income: 0, expense: 320, periodPrevExpense: nil)
        )
    }
    .padding(.vertical)
    .environment(AppPreferences(defaults: .standard))
    .environment(session)
}

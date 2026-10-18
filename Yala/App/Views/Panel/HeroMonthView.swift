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

    /// Saldo de las cuentas que suma el Panel, para la línea «Tienes X en tus cuentas» de un período sin
    /// movimientos (UX 2.2 · L3-1). `nil` sin cuentas: no hay nada que decir.
    var totalBalance: Double? = nil
    var totalBalanceIsApproximate: Bool = false

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(SessionState.self) private var sessionState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // La maqueta (rótulo y período arriba, cifra y detalle debajo, todo a la izquierda) es `HeroHeader`, la misma
    // que usan las pestañas de Estadísticas: así las dos cabeceras no pueden volver a divergir.
    var body: some View {
        HeroHeader {
            labelWithDetailHint
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
        if sessionState.isExpensesOnlyMode { return L10n.Panel.spent }
        return PanelHeroFigureLogic.label(figure: figure, period: selectedPeriod)
    }

    /// Qué cuenta la cifra grande: el balance, o lo mismo que filtra la píldora puesta (UX 2.2 · L3-3).
    private var figure: PanelHeroFigure {
        PanelHeroFigureLogic.figure(natures: sessionState.selectedTransactionNatures)
    }

    /// Todo el hero lleva a Estadísticas; «Ver detalle ›» junto al rótulo lo dice (UX 2.2 · L3-2). Si el rótulo
    /// largo no deja sitio, queda solo la flecha.
    private var labelWithDetailHint: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DS.Spacing.xs) {
                HeroHeaderLabel(text: summaryLabel)
                detailHint(showsText: true)
            }
            HStack(spacing: DS.Spacing.xs) {
                HeroHeaderLabel(text: summaryLabel)
                detailHint(showsText: false)
            }
        }
    }

    private func detailHint(showsText: Bool) -> some View {
        HStack(spacing: DS.Spacing.xxs) {
            if showsText {
                Text(L10n.Panel.Hero.seeDetail)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.right")
                .font(DS.Typography.captionSmall)
                .fontWeight(.semibold)
        }
        .font(DS.Typography.caption)
        .foregroundStyle(.tertiary)
        .fixedSize()
        .accessibilityHidden(true)
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
                    value: figure.value(income: periodSummary.income, expense: periodSummary.expense),
                    currencyCode: currencyCode,
                    font: DS.Typography.panelHeroAmount,
                    secondaryFont: DS.Typography.panelHeroAmountSecondary,
                    isEstimate: figureIsApproximate
                )

                // A tamaños de accesibilidad los dos importes van uno bajo otro (`AdaptiveRowStack`): en fila no
                // cabían y se cortaban por el medio («S/1,7…10»). Son botones de filtro: van en cápsula, y la elegida
                // rellena de su color (UX 2.2 · L3-3; criterio de foco: lo elegido va relleno, no solo atenuando lo otro).
                AdaptiveRowStack(spacing: DS.Spacing.sm, stackedSpacing: DS.Spacing.xs) {
                    naturePill(
                        nature: .income,
                        isSelected: isIncomeFiltered,
                        isDimmed: hasNatureFilter && !isIncomeFiltered,
                        value: periodSummary.income,
                        isEstimate: periodSummary.incomeApproximate
                    )
                    naturePill(
                        nature: .expense,
                        isSelected: isExpenseFiltered,
                        isDimmed: hasNatureFilter && !isExpenseFiltered,
                        value: periodSummary.expense,
                        // El MISMO número que el hero pinta con «≈» en Solo Gastos: sin esto
                        // el usuario ve el gasto marcado en un modo y exacto en el otro.
                        isEstimate: periodSummary.expenseApproximate
                    )
                }

                heroCaption(isIncomeFiltered: isIncomeFiltered, isExpenseFiltered: isExpenseFiltered)
            }
        }
        .contentShape(Rectangle())
    }

    /// El «≈» de la cifra grande: el de su lado cuando la píldora filtra, el del balance si no.
    private var figureIsApproximate: Bool {
        switch figure {
        case .balance: return periodSummary.amountsAreApproximate
        case .expense: return periodSummary.expenseApproximate
        case .income: return periodSummary.incomeApproximate
        }
    }

    // MARK: - Píldoras de naturaleza (UX 2.2 · L3-3)

    private func naturePill(
        nature: TransactionNature,
        isSelected: Bool,
        isDimmed: Bool,
        value: Double,
        isEstimate: Bool
    ) -> some View {
        let isIncome = nature == .income
        // Relleno sólido con texto blanco: los tonos oscurecidos de la paleta pasan AA con blanco (#0F7A80 y
        // #D6006B); `incomeGraph`/`expenseGraph` no.
        let fill = isIncome ? Color.incomeAmount : Color.emphasisPinkFill
        return Button {
            DS.Haptic.selection()
            dsWithAnimation(reduceMotion) { toggleNature(nature) }
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: isIncome ? "arrow.up.right" : "arrow.down.right")
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(isSelected ? Color.white : (isIncome ? Color.incomeGraph : Color.expenseGraph))
                    .accessibilityHidden(true)
                AmountText(
                    value: value,
                    currencyCode: currencyCode,
                    font: DS.Typography.subheadline, secondaryFont: DS.Typography.captionSmall,
                    tint: isSelected ? .color(.white) : .secondary,
                    isEstimate: isEstimate
                )
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background {
                if isSelected {
                    Capsule().fill(fill)
                }
            }
            .glassEffect(isSelected ? .identity : .regular.interactive(), in: Capsule())
            .contentShape(Capsule())
            .opacity(isDimmed ? 0.45 : 1.0)
        }
        .buttonStyle(.plain)
        // VoiceOver lee qué es y cuánto («Entró S/ 3.101»): sin la línea de debajo, el importe suelto no decía de qué era.
        .accessibilityLabel(isIncome
            ? L10n.Panel.Hero.incomePill(appPreferences.currency(value, currencyCode: currencyCode, isEstimate: isEstimate))
            : L10n.Panel.Hero.expensePill(appPreferences.currency(value, currencyCode: currencyCode, isEstimate: isEstimate)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(isIncome ? "panel_hero_income_pill" : "panel_hero_expense_pill")
    }

    private func toggleNature(_ nature: TransactionNature) {
        if sessionState.selectedTransactionNatures == [nature] {
            sessionState.selectedTransactionNatures.removeAll()
        } else {
            sessionState.selectedTransactionNatures = [nature]
        }
    }

    // MARK: - Línea bajo la cifra (UX 2.2 · L3-1 y L3-3)

    /// Con un filtro puesto, un chip que lo dice y lo quita. Sin filtro, solo si el período aún no tiene movimientos: lo dice
    /// y enseña lo que hay en las cuentas (el primer día salía «S/ 0» a secas).
    @ViewBuilder
    private func heroCaption(isIncomeFiltered: Bool, isExpenseFiltered: Bool) -> some View {
        if isIncomeFiltered || isExpenseFiltered {
            Button {
                DS.Haptic.selection()
                dsWithAnimation(reduceMotion) { sessionState.selectedTransactionNatures.removeAll() }
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Text(isExpenseFiltered ? L10n.Panel.Hero.onlyExpensesChip : L10n.Panel.Hero.onlyIncomeChip)
                    Image(systemName: "xmark")
                        .font(DS.Typography.captionSmall)
                        .fontWeight(.bold)
                        .accessibilityHidden(true)
                }
                .font(DS.Typography.subheadlineEmphasized)
                .foregroundStyle(Color.white)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
                .background(Capsule().fill(Color.selectedIndigoFill))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityHint(L10n.Panel.Hero.clearNatureFilter)
            .accessibilityIdentifier("panel_hero_nature_chip")
        } else if periodSummary.income == 0 && periodSummary.expense == 0 {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.Panel.Hero.noMovements)
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(.primary)
                if let totalBalance {
                    Text(L10n.Panel.Hero.totalInAccounts(
                        appPreferences.currency(totalBalance, currencyCode: currencyCode, isEstimate: totalBalanceIsApproximate)
                    ))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("panel_hero_caption")
        }
        // Con movimientos no hay línea: «Entró … − salió …» repetía los importes de las pastillas de encima (decisión de
        // Jürgen del 18-oct). Las pastillas ya los dicen, también en VoiceOver (`naturePill`).
    }

    // MARK: - Copy

    /// Lo que oye VoiceOver al llegar al hero. Antes era el saludo, que además
    /// de no ser un dato ya no existe. Aquí SÍ se compone con el período: el
    /// lector no ve la píldora de al lado como parte de la misma frase.
    private var heroAccessibilityLabel: String {
        let valor = sessionState.isExpensesOnlyMode
            ? periodSummary.expense
            : figure.value(income: periodSummary.income, expense: periodSummary.expense)
        // El `isEstimate` va aquí también, o VoiceOver leería como exacto el mismo número que en
        // pantalla lleva el «≈»: la marca es información, y dejarla solo en el glifo la esconde de
        // quien no lo ve.
        let esAproximado = sessionState.isExpensesOnlyMode
            ? periodSummary.expenseApproximate
            : figureIsApproximate
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

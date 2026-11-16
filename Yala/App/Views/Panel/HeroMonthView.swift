//
//  HeroMonthView.swift
//  Yala
//
//  Hero del Panel (PP2-01). Sin card y edge-to-edge — aprovecha todo el
//  ancho del Panel. Fila superior con el rótulo + `TrendsPeriodMenu`; debajo, la
//  cifra grande («Tienes hoy», lo que hay en las cuentas) y la línea del mes
//  («Te queda», lo que entró menos lo que salió). Decisión 8 de la revisión 2.3.
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

    /// Saldo de las cuentas que suma el Panel: la cifra grande, «Tienes hoy» (decisión 8 de 2.3). No sigue al período;
    /// con una cuenta elegida es la suya. `nil` sin cuentas: se enseña 0.
    var totalBalance: Double? = nil
    var totalBalanceIsApproximate: Bool = false

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(SessionState.self) private var sessionState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// «Ocultar montos» del Panel (`AmountPrivacy`): lo pone el ojo de este mismo hero.
    @Environment(\.amountsHidden) private var amountsHidden
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// La cifra crece con el texto de accesibilidad, con techo (pase de estrés 2.2, card eb9i): con los 36 pt fijos de
    /// `panelHeroAmount`, a AX5 los chips de entradas y salidas medían casi el doble y la jerarquía se invertía. El molde
    /// es el de Grupos (`GroupSummaryHeader.netFont`). Hasta xxxLarge sigue siendo el token de siempre.
    @ScaledMetric(relativeTo: .largeTitle) private var scaledFigureSize: CGFloat = 36
    /// Símbolo y decimales de la cifra, en la misma proporción que el token (17 de 36).
    @ScaledMetric(relativeTo: .largeTitle) private var scaledFigureSecondarySize: CGFloat = 17
    /// Techo de la cifra: el `largeTitle` de AX5. Con el `minimumScaleFactor(0.7)` de `AmountText` no baja de 42 pt.
    private static let figureMaxSize: CGFloat = 60
    /// Rótulo y chips dejan de crecer en AX2: son detalle de la cifra, no compiten con ella (como en Grupos).
    private static let sidesMaxTypeSize = DynamicTypeSize.accessibility2

    private var figureFont: Font {
        guard dynamicTypeSize.isAccessibilitySize else { return DS.Typography.panelHeroAmount }
        // A11Y-DT: tamaño escalado a mano con techo; el token es fijo a propósito y aquí tiene que crecer.
        return .system(size: min(scaledFigureSize, Self.figureMaxSize), weight: .semibold)
    }

    private var figureSecondaryFont: Font {
        guard dynamicTypeSize.isAccessibilitySize else { return DS.Typography.panelHeroAmountSecondary }
        // A11Y-DT: el mismo techo, en la proporción del token.
        return .system(size: min(scaledFigureSecondarySize, Self.figureMaxSize * 17 / 36), weight: .regular)
    }

    // La maqueta (rótulo y período arriba, cifra y detalle debajo, todo a la izquierda) es `HeroHeader`, la misma
    // que usan las pestañas de Estadísticas: así las dos cabeceras no pueden volver a divergir.
    var body: some View {
        HeroHeader {
            labelWithDetailHint
                .dynamicTypeSize(...Self.sidesMaxTypeSize)
        } period: {
            // El título de la píldora se releva fundido y la cápsula cambia de ancho animada (card C2), como en
            // Estadísticas. Con Reducir movimiento, en seco.
            TrendsPeriodMenu(
                selectedPeriod: selectedPeriod,
                customDateRange: customDateRange,
                onSelect: onSelectPeriod,
                onCustomTapped: onCustomPeriodTapped,
                titleMotion: reduceMotion ? nil : .fade
            )
            .animation(reduceMotion ? nil : DS.Animation.selection, value: selectedPeriod)
            .animation(reduceMotion ? nil : DS.Animation.selection, value: customDateRange)
        } content: {
            summaryRow
            // Días 1 y 2 de «Este mes»: «Día N de 31» con dos atajos al selector (decisión 10 de 2.3).
            PanelMonthStartLine(selectedPeriod: selectedPeriod, onSelectPeriod: onSelectPeriod)
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
    /// «Tienes hoy» (o «Debes hoy»); en «Solo gastos», «Gastos de <mes>», que es lo que cuenta su cifra.
    private var summaryLabel: String {
        if sessionState.isExpensesOnlyMode {
            return PanelHeroFigureLogic.label(figure: .expense, period: selectedPeriod)
        }
        return PanelHeroFigureLogic.bigFigureCaption(totalBalance: totalBalance ?? 0).text
    }

    /// Qué cuenta la línea del mes: el neto, o lo mismo que filtra la píldora puesta (UX 2.2 · L3-3). La cifra grande
    /// no cambia con la píldora: es lo que hay en las cuentas.
    private var figure: PanelHeroFigure {
        PanelHeroFigureLogic.figure(natures: sessionState.selectedTransactionNatures)
    }

    /// El rótulo de la línea del mes: «Te queda», «Te quedó», «En octubre te quedó» o el lado que filtra.
    private var monthLine: PanelHeroMonthLine {
        PanelHeroFigureLogic.monthLine(figure: figure, period: selectedPeriod, customRange: customDateRange)
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

    /// La cifra grande con el ojo a su derecha. Junto al rótulo no cabía: en un iPhone 17 Pro apartaba «Ver detalle».
    private func figureWithVisibilityButton(_ figure: AmountText) -> some View {
        HStack(alignment: .center, spacing: DS.Spacing.sm) {
            figure
                .accessibilityIdentifier("panel_hero_figure")
            amountsVisibilityButton
                // El ojo es detalle de la cifra, como rótulo y chips: deja de crecer en AX2 y no le quita ancho.
                .dynamicTypeSize(...Self.sidesMaxTypeSize)
        }
    }

    /// El ojo que oculta y enseña los montos del Panel (`AmountPrivacy`), al lado de la cifra que oculta, como en las
    /// apps de banco. Ojo abierto con los montos a la vista; tachado con los montos ocultos. La preferencia se queda
    /// entre arranques (`AppPreferences.panelAmountsHidden`).
    private var amountsVisibilityButton: some View {
        let hidden = appPreferences.panelAmountsHidden
        return Button {
            DS.Haptic.selection()
            appPreferences.panelAmountsHidden.toggle()
        } label: {
            Image(systemName: hidden ? "eye.slash" : "eye")
                .font(DS.Typography.title3)
                .foregroundStyle(.secondary)
                .contentTransition(.symbolEffect(.replace))
                // Hueco táctil de 44 pt sin ocupar 44 pt de fila: el margen se suma dentro y se resta fuera, así el ojo
                // no aparta «Ver detalle» ni empuja el rótulo hacia abajo.
                .padding(DS.Spacing.sm)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(-DS.Spacing.sm)
        .accessibilityLabel(hidden ? L10n.Panel.showAmounts : L10n.Panel.hideAmounts)
        .accessibilityIdentifier("panel_hero_amounts_visibility")
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
                figureWithVisibilityButton(AmountText(
                    value: periodSummary.expense,
                    currencyCode: currencyCode,
                    font: figureFont,
                    secondaryFont: figureSecondaryFont,
                    // Solo el lado del gasto: este número no incluye los ingresos.
                    isEstimate: periodSummary.expenseApproximate,
                    animatesValue: true
                ))

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
                // Lo que hay en las cuentas, sin signo: el rótulo ya dice si es deuda («Debes hoy»).
                figureWithVisibilityButton(AmountText(
                    value: PanelHeroFigureLogic.bigFigureValue(totalBalance: totalBalance ?? 0),
                    currencyCode: currencyCode,
                    font: figureFont,
                    secondaryFont: figureSecondaryFont,
                    isEstimate: totalBalanceIsApproximate,
                    animatesValue: true
                ))

                monthLineRow(hasNatureFilter: hasNatureFilter)

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
                // Topados en AX2 para que la cifra siga siendo lo mayor del hero (card eb9i, molde de Grupos).
                .dynamicTypeSize(...Self.sidesMaxTypeSize)

                heroCaption(isIncomeFiltered: isIncomeFiltered, isExpenseFiltered: isExpenseFiltered)
            }
        }
        // La píldora elegida se rellena, la otra se atenúa y el chip «solo gastos» entra fundido (card C2). Implícita: el
        // `withAnimation` del toque no anima dentro de una pestaña.
        .animation(reduceMotion ? nil : DS.Animation.selection, value: sessionState.selectedTransactionNatures)
        .contentShape(Rectangle())
    }

    /// El «≈» de la línea del mes: el de su lado cuando la píldora filtra, el del neto si no.
    private var figureIsApproximate: Bool {
        switch figure {
        case .balance: return periodSummary.amountsAreApproximate
        case .expense: return periodSummary.expenseApproximate
        case .income: return periodSummary.incomeApproximate
        }
    }

    // MARK: - Línea del mes (decisión 8 de 2.3)

    /// «Te queda S/ X»: lo que entró menos lo que salió en el período, o el lado que filtra la píldora. Sin movimientos
    /// en el período y sin filtro, lo dice en vez de enseñar un 0.
    @ViewBuilder
    private func monthLineRow(hasNatureFilter: Bool) -> some View {
        if periodSummary.hasNoMovements && !hasNatureFilter {
            Text(L10n.Panel.Hero.noMovements)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("panel_hero_caption")
        } else {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                Text(monthLine.text)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    // El texto cambia con el período: un valor, una vista, o el de antes se funde con el nuevo.
                    .transaction { $0.animation = nil }
                AmountText(
                    value: figure.value(income: periodSummary.income, expense: periodSummary.expense),
                    currencyCode: currencyCode,
                    font: DS.Typography.subheadlineEmphasized, secondaryFont: DS.Typography.captionSmall,
                    isEstimate: figureIsApproximate
                )
            }
            .dynamicTypeSize(...Self.sidesMaxTypeSize)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("panel_hero_month_line")
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
        let fill = isIncome ? Color.incomeFill : Color.emphasisPinkFill
        return Button {
            DS.Haptic.selection()
            toggleNature(nature)
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
            ? L10n.Panel.Hero.incomePill(AmountPrivacy.spoken(appPreferences.currency(value, currencyCode: currencyCode, isEstimate: isEstimate), hidden: amountsHidden))
            : L10n.Panel.Hero.expensePill(AmountPrivacy.spoken(appPreferences.currency(value, currencyCode: currencyCode, isEstimate: isEstimate), hidden: amountsHidden)))
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

    /// Con un filtro puesto, un chip que lo dice y lo quita. Sin filtro no hay nada más: la línea del mes ya dice «Te queda»
    /// o que el período no tiene movimientos, y lo que hay en las cuentas es la cifra grande.
    @ViewBuilder
    private func heroCaption(isIncomeFiltered: Bool, isExpenseFiltered: Bool) -> some View {
        if isIncomeFiltered || isExpenseFiltered {
            Button {
                DS.Haptic.selection()
                sessionState.selectedTransactionNatures.removeAll()
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
            // Entra fundido y se va en el acto: lo de debajo del hero (la fila de acciones) sube sin animar, y un chip
            // que se fundiera al irse quedaría encima de ella (medido en vídeo, card C2).
            // Un chip por filtro: de «solo ingresos» a «solo gastos» es uno que se va y otro que entra, no un texto que
            // se funde con el anterior.
            .id(isExpenseFiltered)
            .transition(.asymmetric(insertion: .opacity, removal: .identity))
            .accessibilityHint(L10n.Panel.Hero.clearNatureFilter)
            .accessibilityIdentifier("panel_hero_nature_chip")
        }
        // Sin rótulos «Entró / Salió» en pantalla (decisión de Jürgen del 18-oct, confirmada en la decisión 8 de 2.3): las
        // flechas de las pastillas bastan, y VoiceOver los lee en cada pastilla (`naturePill`).
    }

    // MARK: - Copy

    /// Lo que oye VoiceOver al llegar al hero. Antes era el saludo, que además
    /// de no ser un dato ya no existe. Aquí SÍ se compone con el período: el
    /// lector no ve la píldora de al lado como parte de la misma frase.
    private var heroAccessibilityLabel: String {
        if sessionState.isExpensesOnlyMode {
            // El `isEstimate` va aquí también, o VoiceOver leería como exacto el mismo número que en pantalla lleva el
            // «≈»: la marca es información, y dejarla solo en el glifo la esconde de quien no lo ve.
            let gasto = appPreferences.currency(
                periodSummary.expense, currencyCode: currencyCode, isEstimate: periodSummary.expenseApproximate
            )
            return "\(summaryLabel) · \(selectedPeriod.displayName), \(AmountPrivacy.spoken(gasto, hidden: amountsHidden))"
        }
        // «Tienes hoy, S/ 64.690. Te queda S/ 6.882 · Este mes»: las dos cifras, cada una con su marca.
        let tienes = appPreferences.currency(
            PanelHeroFigureLogic.bigFigureValue(totalBalance: totalBalance ?? 0),
            currencyCode: currencyCode, isEstimate: totalBalanceIsApproximate
        )
        let queda = appPreferences.currency(
            figure.value(income: periodSummary.income, expense: periodSummary.expense),
            currencyCode: currencyCode, isEstimate: figureIsApproximate
        )
        let linea = periodSummary.hasNoMovements && figure == .balance
            ? L10n.Panel.Hero.noMovements
            : "\(monthLine.text) \(AmountPrivacy.spoken(queda, hidden: amountsHidden))"
        return "\(summaryLabel), \(AmountPrivacy.spoken(tienes, hidden: amountsHidden)). \(linea) · \(selectedPeriod.displayName)"
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

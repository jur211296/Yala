//
//  HeroMonthView.swift
//  Yala
//
//  Hero del Panel (PP2-01). Sin card y edge-to-edge — aprovecha todo el
//  ancho del Panel. Fila superior con el rótulo, el «?» y `TrendsPeriodMenu`; debajo, la cifra grande («Tu saldo hoy»,
//  todas las cuentas con su signo) y, en chico, «Tu dinero hoy» (sin las cuentas que no cuentan como dinero para usar).
//  Encargo del 2026-11-16; la línea del mes («Te queda» y sus flechas) salió: la cuenta Flujo de caja.
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

    /// Saldo de las cuentas que suma el Panel: la cifra grande, «Tu saldo hoy», con su signo. No sigue al período; con una
    /// cuenta elegida es la suya. `nil` sin cuentas: se enseña 0.
    var totalBalance: Double? = nil
    var totalBalanceIsApproximate: Bool = false
    /// «Tu dinero hoy», la línea chica: el saldo sin las cuentas que no cuentan como dinero (`PanelMoneyScopeLogic`).
    /// `nil` cuando ninguna cuenta queda fuera: las dos cifras serían la misma y no se pinta.
    var moneyBalance: Double? = nil
    var moneyBalanceIsApproximate: Bool = false
    /// Las cuentas del Panel, para la lista de la hoja del «?» (qué cuentas suman en «Tu dinero hoy»).
    var accounts: [Account] = []

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(SessionState.self) private var sessionState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// «Ocultar montos» del Panel (`AmountPrivacy`): lo pone el ojo de este mismo hero.
    @Environment(\.amountsHidden) private var amountsHidden
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// La hoja del «?»: qué son las dos cifras y qué cuentas suman.
    @State private var isShowingSaldoInfo = false

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
        HeroHeader(labelToContentSpacing: DS.Spacing.xs) {
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
        .sheet(isPresented: $isShowingSaldoInfo) {
            PanelSaldoInfoSheet(accounts: accounts, currencyCode: currencyCode)
        }
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
    /// «Tu saldo hoy»; en «Solo gastos», «Gastos de <mes>», que es lo que cuenta su cifra.
    private var summaryLabel: String {
        if sessionState.isExpensesOnlyMode {
            return PanelHeroFigureLogic.label(figure: .expense, period: selectedPeriod)
        }
        return L10n.Panel.Hero.haveToday
    }

    /// Todo el hero lleva a Estadísticas; «Ver detalle ›» junto al rótulo lo dice (UX 2.2 · L3-2). Si el rótulo
    /// largo no deja sitio, queda solo la flecha.
    private var labelWithDetailHint: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DS.Spacing.xs) {
                HeroHeaderLabel(text: summaryLabel)
                saldoInfoButton
                detailHint(showsText: true)
            }
            HStack(spacing: DS.Spacing.xs) {
                HeroHeaderLabel(text: summaryLabel)
                saldoInfoButton
                detailHint(showsText: false)
            }
        }
    }

    /// El «?» junto a «Tu saldo hoy»: el mismo círculo de vidrio que la ayuda de los widgets (`WidgetHelpCircleLabel`), y
    /// como ellos sale solo con «Mostrar ayudas» encendido. En «Solo gastos» no: la cifra es el gasto, no el saldo.
    @ViewBuilder
    private var saldoInfoButton: some View {
        if appPreferences.showWidgetHints && !sessionState.isExpensesOnlyMode {
            Button {
                DS.Haptic.light()
                isShowingSaldoInfo = true
            } label: {
                WidgetHelpCircleLabel()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.SaldoPanel.infoButton)
            .accessibilityIdentifier("panel_hero_saldo_info")
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

    // MARK: - Las cifras

    private var summaryRow: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
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
                // «Tu saldo hoy»: todas las cuentas, tarjetas incluidas, con su signo.
                figureWithVisibilityButton(AmountText(
                    value: PanelHeroFigureLogic.bigFigureValue(totalBalance: totalBalance ?? 0),
                    currencyCode: currencyCode,
                    font: figureFont,
                    secondaryFont: figureSecondaryFont,
                    isEstimate: totalBalanceIsApproximate,
                    animatesValue: true
                ))

                moneyLine
            }
        }
        .contentShape(Rectangle())
    }

    /// «Tu dinero hoy S/ X», en chico bajo la cifra grande. Solo si alguna cuenta queda fuera: si no, repetiría la cifra.
    @ViewBuilder
    private var moneyLine: some View {
        if let moneyBalance {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
                Text(L10n.SaldoPanel.moneyToday)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                AmountText(
                    value: moneyBalance,
                    currencyCode: currencyCode,
                    font: DS.Typography.subheadlineEmphasized, secondaryFont: DS.Typography.captionSmall,
                    isEstimate: moneyBalanceIsApproximate,
                    animatesValue: true
                )
            }
            // Detalle de la cifra, como el ojo: deja de crecer en AX2 para que la cifra siga siendo lo mayor del hero.
            .dynamicTypeSize(...Self.sidesMaxTypeSize)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("panel_hero_money_line")
        }
    }

    // MARK: - Copy

    /// Lo que oye VoiceOver al llegar al hero. Antes era el saludo, que además
    /// de no ser un dato ya no existe. En «Solo gastos» SÍ se compone con el período: el
    /// lector no ve la píldora de al lado como parte de la misma frase. Las cifras de hoy no dependen de él.
    private var heroAccessibilityLabel: String {
        if sessionState.isExpensesOnlyMode {
            // El `isEstimate` va aquí también, o VoiceOver leería como exacto el mismo número que en pantalla lleva el
            // «≈»: la marca es información, y dejarla solo en el glifo la esconde de quien no lo ve.
            let gasto = appPreferences.currency(
                periodSummary.expense, currencyCode: currencyCode, isEstimate: periodSummary.expenseApproximate
            )
            return "\(summaryLabel) · \(selectedPeriod.displayName), \(AmountPrivacy.spoken(gasto, hidden: amountsHidden))"
        }
        // «Tu saldo hoy, S/ 1.390. Tu dinero hoy, S/ 2.656»: las dos cifras de hoy, cada una con su marca.
        let saldo = appPreferences.currency(
            PanelHeroFigureLogic.bigFigureValue(totalBalance: totalBalance ?? 0),
            currencyCode: currencyCode, isEstimate: totalBalanceIsApproximate
        )
        let first = "\(summaryLabel), \(AmountPrivacy.spoken(saldo, hidden: amountsHidden))"
        guard let moneyBalance else { return first }
        let dinero = appPreferences.currency(moneyBalance, currencyCode: currencyCode, isEstimate: moneyBalanceIsApproximate)
        return "\(first). \(L10n.SaldoPanel.moneyToday), \(AmountPrivacy.spoken(dinero, hidden: amountsHidden))"
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

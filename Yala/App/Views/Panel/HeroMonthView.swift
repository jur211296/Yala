//
//  HeroMonthView.swift
//  Yala
//
//  Hero del Panel (PP2-01). Sin card y edge-to-edge — aprovecha todo el
//  ancho del Panel. Fila superior con saludo + `TrendsPeriodMenu`, y resumen
//  "Disponible · Período". La frase motivacional (aiSubtitle / fallback
//  rule-based) y el upsellCTA "Personaliza tu mensaje con IA" viven en el
//  subtítulo de "Tus finanzas" — la lógica del KPI se expone vía
//  `HeroMonthView.kpiText(...)` para que el callsite ahí pueda reusarla.
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

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            topRow
            summaryRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel(chipText)
    }

    // MARK: - Top row (saludo + period selector inline)

    private var topRow: some View {
        HStack(spacing: DS.Spacing.xs) {
            chip
            Spacer(minLength: DS.Spacing.sm)
            TrendsPeriodMenu(
                selectedPeriod: selectedPeriod,
                customDateRange: customDateRange,
                onSelect: onSelectPeriod,
                onCustomTapped: onCustomPeriodTapped
            )
        }
    }

    private var chip: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "sparkles")
                .font(DS.Typography.title2)
                .foregroundStyle(DS.Semantic.favoriteIcon)
            Text(chipText)
                .font(DS.Typography.title2)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
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

        return VStack(alignment: .center, spacing: DS.Spacing.sm) {
            if sessionState.isExpensesOnlyMode {
                // Solo Gastos: el "Disponible" (income - expense) siempre es 0
                // sin ingresos → se muestra el GASTO del período como KPI, con un
                // comparativo "vs período anterior" (MTD-alineado) que le da lectura.
                // Sin pills: la naturaleza está forzada a gasto y el número YA es el gasto.
                Text("\(L10n.Panel.spent) · \(selectedPeriod.displayName)")
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)

                AmountText(
                    value: periodSummary.expense,
                    currencyCode: currencyCode,
                    font: DS.Typography.heroAmount, secondaryFont: DS.Typography.heroAmountSecondary
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
                Text("\(L10n.Panel.Hero.availableLabel) · \(selectedPeriod.displayName)")
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)

                AmountText(
                    value: periodSummary.available,
                    currencyCode: currencyCode,
                    font: DS.Typography.heroAmount, secondaryFont: DS.Typography.heroAmountSecondary
                )

                HStack(spacing: DS.Spacing.md) {
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
                                tint: .secondary
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
                                tint: .secondary
                            )
                        }
                        .opacity(hasNatureFilter && !isExpenseFiltered ? 0.3 : 1.0)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.sm)
        .contentShape(Rectangle())
    }

    // MARK: - Copy

    private var chipText: String {
        // Saludo único para todos los estados — el icon `sparkles` cyan ya
        // transmite "empezamos" sin ocupar espacio horizontal en el chip.
        L10n.Panel.Hero.chipDefault(userName: appPreferences.userName)
    }

    /// SSOT del KPI motivacional: LLM cuando disponible, si no un fallback
    /// rule-based por estado (frase motivacional genérica; los montos income/
    /// spent/available se pasan por compatibilidad de firma pero los strings
    /// actuales no los interpolan). Static para reusarse desde otras secciones
    /// del Panel (subtítulo de "Tus finanzas") sin duplicar la lógica.
    static func kpiText(
        data: HeroMonthData,
        aiSubtitle: String?,
        currencyCode: String,
        appPreferences: AppPreferences
    ) -> String {
        if let aiSubtitle, !aiSubtitle.isEmpty { return aiSubtitle }
        let income = appPreferences.currency(data.income, currencyCode: currencyCode)
        let spent = appPreferences.currency(data.expense, currencyCode: currencyCode)
        let available = appPreferences.currency(data.available, currencyCode: currencyCode)
        switch data.state {
        case .monthStart:
            return L10n.Panel.Hero.kpiMonthStart(income: income, daysRemaining: data.daysRemaining)
        case .onTrack:
            return L10n.Panel.Hero.kpiOnTrack(
                income: income, spent: spent, available: available, daysRemaining: data.daysRemaining
            )
        case .neutral:
            return L10n.Panel.Hero.kpiNeutral(
                income: income, spent: spent, available: available, daysRemaining: data.daysRemaining
            )
        case .tight:
            return L10n.Panel.Hero.kpiTight(
                spent: spent, available: available, daysRemaining: data.daysRemaining
            )
        case .overBudget:
            return L10n.Panel.Hero.kpiOverBudget(spent: spent, income: income)
        }
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

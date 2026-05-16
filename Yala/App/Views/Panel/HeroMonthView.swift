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
                .font(DS.Typography.subheadline)
                .foregroundStyle(DS.Semantic.favoriteIcon)
            Text(chipText)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.thSecondaryText)
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
            Text(L10n.Panel.Hero.availableLabel)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)

            AmountText(
                value: periodSummary.available,
                currencyCode: currencyCode,
                size: .hero
            )

            HStack(spacing: DS.Spacing.md) {
                // Income — oculto en expenses-only mode (mismo gating que RecordsTabView).
                if !sessionState.isExpensesOnlyMode {
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
                            Text(appPreferences.currency(periodSummary.income, currencyCode: currencyCode))
                                .font(DS.Typography.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .opacity(hasNatureFilter && !isIncomeFiltered ? 0.3 : 1.0)
                    }
                    .buttonStyle(.plain)
                }

                // Expense — siempre visible.
                Button {
                    DS.Haptic.selection()
                    dsWithAnimation(reduceMotion) {
                        if isExpenseFiltered {
                            // En expenses-only mode no se permite quitar el filtro.
                            if !sessionState.isExpensesOnlyMode {
                                sessionState.selectedTransactionNatures.removeAll()
                            }
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
                        Text(appPreferences.currency(periodSummary.expense, currencyCode: currencyCode))
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .opacity(hasNatureFilter && !isExpenseFiltered ? 0.3 : 1.0)
                }
                .buttonStyle(.plain)
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

    /// SSOT del KPI motivacional: LLM cuando disponible, fallback rule-based
    /// con cifras concretas (income, spent, available, days). Static para
    /// poder reusarse desde otras secciones del Panel (subtítulo de "Tus
    /// finanzas") sin duplicar la lógica.
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

//
//  StatisticsPeriodControl.swift
//  Yala
//
//  UX 2.2 · L11-3. La píldora del período de Estadísticas con flechas ‹ › a los lados, que pasan al período anterior
//  o siguiente del mismo tipo (como Planificación), y debajo los días que cubre en una línea («1–18 oct»). Antes
//  solo había un menú de nueve períodos fijos sin fechas, y ver agosto exigía «Personalizado» y dos ruedas.
//
//  Va en las cuatro pestañas; el Panel y los Informes siguen con la píldora sola.
//

import SwiftUI

struct StatisticsPeriodControl: View {
    let onCustomTapped: () -> Void
    /// Tras cada elección (menú o flechas), para quien lleve una copia propia del período (Registros).
    var onChosen: () -> Void = {}

    @Environment(SessionState.self) private var sessionState

    private var selection: PeriodStepLogic.Selection {
        PeriodStepLogic.Selection(period: sessionState.selectedPeriod, customRange: sessionState.customDateRange)
    }

    private var previous: PeriodStepLogic.Selection? {
        PeriodStepLogic.step(selection, .previous, unitHint: sessionState.periodStepUnit)
    }
    private var next: PeriodStepLogic.Selection? {
        PeriodStepLogic.step(selection, .next, unitHint: sessionState.periodStepUnit)
    }

    /// El paso que dan las flechas desde lo que hay puesto, para recordarlo en el rango al que llevan.
    private var currentUnit: PeriodStepLogic.Unit? {
        if sessionState.selectedPeriod == .custom, let hint = sessionState.periodStepUnit { return hint }
        let interval = sessionState.selectedPeriod.dateInterval(customRange: sessionState.customDateRange)
        return PeriodStepLogic.unit(of: selection, interval: interval)
    }

    private var rangeText: String? {
        PeriodStepLogic.rangeText(period: sessionState.selectedPeriod, customRange: sessionState.customDateRange)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
            HStack(spacing: DS.Spacing.xs) {
                if PeriodStepLogic.isSteppable(sessionState.selectedPeriod) {
                    arrow(.previous, target: previous)
                }

                TrendsPeriodMenu(
                    selectedPeriod: sessionState.selectedPeriod,
                    customDateRange: sessionState.customDateRange,
                    onSelect: { choose($0, customRange: nil, stepUnit: nil) },
                    onCustomTapped: onCustomTapped
                )
                .equatable()

                if PeriodStepLogic.isSteppable(sessionState.selectedPeriod) {
                    arrow(.next, target: next)
                }
            }

            if let rangeText {
                Text(rangeText)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.thSecondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityLabel(L10n.UXL11.periodRangeAccessibility(rangeText))
                    .accessibilityIdentifier("stats_period_range")
            }
        }
    }

    private func choose(_ period: DetailPeriod, customRange: DateInterval?, stepUnit: PeriodStepLogic.Unit?) {
        sessionState.choosePeriod(period, customRange: customRange, stepUnit: stepUnit)
        onChosen()
    }

    private func arrow(_ direction: PeriodStepLogic.Direction, target: PeriodStepLogic.Selection?) -> some View {
        Button {
            guard let target else { return }
            choose(target.period, customRange: target.customRange, stepUnit: target.period == .custom ? currentUnit : nil)
        } label: {
            Image(systemName: direction == .previous ? "chevron.left" : "chevron.right")
                .font(DS.Typography.labelSmall.weight(.semibold))
                .foregroundStyle(target == nil ? Color.secondary.opacity(0.4) : Color.primary)
                .frame(width: 32, height: 32)
                .glassEffect(.regular.interactive(), in: .circle)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(target == nil)
        .accessibilityLabel(direction == .previous ? L10n.UXL11.previousPeriod : L10n.UXL11.nextPeriod)
        .accessibilityIdentifier(direction == .previous ? "stats_period_previous" : "stats_period_next")
    }
}

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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Cómo entra el título del próximo cambio: desde el lado de la flecha pulsada, o fundido si viene del menú.
    @State private var titleMotion: PeriodTitleMotion = .fade
    /// La elección que el control ya enseña y la pantalla aún no: el período se aplica cuando la píldora termina de
    /// animarse (ver `choose`).
    @State private var pending: Pending?

    private struct Pending: Equatable {
        let selection: PeriodStepLogic.Selection
        let stepUnit: PeriodStepLogic.Unit?
    }

    /// La píldora cambia de ancho y las flechas se recolocan en el mismo movimiento (antes la píldora saltaba en un
    /// fotograma y se montaba sobre la flecha pulsada).
    private static let changeAnimation: Animation = .snappy(duration: DS.Animation.normal)

    /// Lo que enseña el control: la elección pendiente si la hay, y si no la de la sesión.
    private var selection: PeriodStepLogic.Selection {
        pending?.selection
            ?? PeriodStepLogic.Selection(period: sessionState.selectedPeriod, customRange: sessionState.customDateRange)
    }

    private var stepUnitHint: PeriodStepLogic.Unit? {
        if let pending { return pending.stepUnit }
        return sessionState.periodStepUnit
    }

    private var previous: PeriodStepLogic.Selection? {
        PeriodStepLogic.step(selection, .previous, unitHint: stepUnitHint)
    }
    private var next: PeriodStepLogic.Selection? {
        PeriodStepLogic.step(selection, .next, unitHint: stepUnitHint)
    }

    /// El paso que dan las flechas desde lo que hay puesto, para recordarlo en el rango al que llevan.
    private var currentUnit: PeriodStepLogic.Unit? {
        if selection.period == .custom, let hint = stepUnitHint { return hint }
        let interval = selection.period.dateInterval(customRange: selection.customRange)
        return PeriodStepLogic.unit(of: selection, interval: interval)
    }

    private var rangeText: String? {
        PeriodStepLogic.rangeText(period: selection.period, customRange: selection.customRange)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: DS.Spacing.xxs) {
            HStack(spacing: DS.Spacing.xs) {
                if PeriodStepLogic.isSteppable(selection.period) {
                    arrow(.previous, target: previous)
                }

                TrendsPeriodMenu(
                    selectedPeriod: selection.period,
                    customDateRange: selection.customRange,
                    onSelect: { period in
                        choose(period, customRange: nil, stepUnit: nil, motion: .fade)
                    },
                    onCustomTapped: onCustomTapped,
                    titleMotion: titleMotion
                )
                .equatable()

                if PeriodStepLogic.isSteppable(selection.period) {
                    arrow(.next, target: next)
                }
            }

            if let rangeText {
                // Los días también se relevan sin cruzarse: el texto viejo se quita y el nuevo aparece fundido después.
                ZStack(alignment: .trailing) {
                    Text(rangeText)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.thSecondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .id(rangeText)
                        .transition(PeriodTitleMotion.sequentialFade)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(L10n.UXL11.periodRangeAccessibility(rangeText))
                .accessibilityIdentifier("stats_period_range")
            }
        }
        // La animación la pone este control para sí mismo, y de forma implícita: `ContentView` anula la animación de toda
        // transacción que cruza el `TabView` (`.transaction { $0.animation = nil }`), así que un `withAnimation` o un
        // `withTransaction` animado no llegaban aquí (medido en el simulador, iOS 27.0: sin ese apagado, la píldora sí
        // se animaba). Un `.animation(_:value:)` actúa por debajo de él.
        .animation(reduceMotion ? nil : Self.changeAnimation, value: selection)
        // Si la pantalla se va antes de que acabe la animación, la elección no se pierde.
        .onDisappear { if let pending { commit(pending) } }
    }

    /// Aplica la elección en dos tiempos: primero la enseña el control, animado (solo él lee `pending`), y cuando la
    /// animación termina se aplica a la sesión, sin animación.
    ///
    /// **Por qué en dos tiempos.** El período lo lee la pantalla entera, y recalcular cifras, gráficas y listas bloquea
    /// el hilo principal (~0,07 s medidos en el vídeo del iPhone de Jürgen). Las animaciones de SwiftUI avanzan en ese
    /// mismo hilo, así que con el recálculo a la vez la píldora perdería ese trozo del movimiento. Y animar el cambio de
    /// la sesión animaría además todo lo que la lee. Con Reducir movimiento, se aplica en el acto y sin animación.
    private func choose(
        _ period: DetailPeriod,
        customRange: DateInterval?,
        stepUnit: PeriodStepLogic.Unit?,
        motion: PeriodTitleMotion
    ) {
        let target = Pending(
            selection: PeriodStepLogic.Selection(period: period, customRange: customRange),
            stepUnit: stepUnit
        )
        guard !reduceMotion else {
            commit(target)
            return
        }
        titleMotion = motion
        // La transacción trae el aviso de fin; la animación en sí la pone el `.animation(_:value:)` del `body`, porque la
        // de la transacción la anula `ContentView`. Así el aviso llega al terminar la píldora (medido: ~0,34 s tras el
        // toque, con 0,3 s de animación; hoy dura `DS.Animation.normal`, 0,25 s).
        var animated = Transaction(animation: Self.changeAnimation)
        animated.addAnimationCompletion(criteria: .logicallyComplete) {
            // Si otro toque llegó antes de que acabara, gana el último: su propia animación lo aplicará.
            guard pending == target else { return }
            commit(target)
        }
        withTransaction(animated) { pending = target }
    }

    private func commit(_ target: Pending) {
        var quiet = Transaction()
        quiet.disablesAnimations = true
        withTransaction(quiet) {
            sessionState.choosePeriod(
                target.selection.period, customRange: target.selection.customRange, stepUnit: target.stepUnit
            )
            pending = nil
        }
        onChosen()
    }

    private func arrow(_ direction: PeriodStepLogic.Direction, target: PeriodStepLogic.Selection?) -> some View {
        Button {
            guard let target else { return }
            choose(
                target.period,
                customRange: target.customRange,
                stepUnit: target.period == .custom ? currentUnit : nil,
                motion: .push(from: direction == .previous ? .leading : .trailing)
            )
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

//
//  SetupDeckProgress.swift
//  Yala
//
//  El progreso de Primeros pasos dentro del mazo (opción B de Jürgen, 20-nov-2026, tema 2 de las maquetas). Sustituye a
//  la hoja «Ver los 7 pasos», que repetía a pantalla completa lo que el mazo ya decía y pintaba igual un paso omitido que
//  uno pendiente. Ahora: siete segmentos en la carta de adelante y, debajo del mazo, la fila de los siete pasos con su
//  estado (hecho, para después, el de ahora, pendiente). Tocar uno que no esté hecho lo abre, aunque no sea el siguiente
//  (la decisión de Jürgen del 13-nov que la hoja ya cumplía).
//

import SwiftUI

/// Las reglas del progreso del mazo, sin efectos.
enum SetupDeckProgressLogic {
    /// Cómo se ve un paso en el progreso.
    enum State: Equatable {
        case done
        /// Omitido: queda para después y se distingue de lo pendiente (la hoja los pintaba igual).
        case later
        /// El de adelante del mazo.
        case current
        case pending
    }

    static func state(of step: SetupStep, current: SetupStepID?) -> State {
        if step.isCompleted { return .done }
        if step.isSkipped { return .later }
        return step.id == current ? .current : .pending
    }

    /// Se abre cualquier paso que no esté hecho, también uno omitido o uno que no es el siguiente.
    static func opens(_ step: SetupStep) -> Bool { !step.isCompleted }

    /// Cuántos hay hechos y cuántos quedaron para después.
    static func counts(_ steps: [SetupStep]) -> (done: Int, later: Int) {
        (steps.count { $0.isCompleted }, steps.count { !$0.isCompleted && $0.isSkipped })
    }

    /// Los que quedaron para después, en orden: el final de Primeros pasos los nombra.
    static func later(_ steps: [SetupStep]) -> [SetupStepID] {
        steps.filter { !$0.isCompleted && $0.isSkipped }.map(\.id)
    }
}

/// Cómo se reparte la fila de pasos debajo del mazo.
enum SetupDeckStepsLayoutLogic {
    /// La rejilla de respaldo: dos filas de cuatro.
    static let fallbackColumns = 4

    /// Con texto de accesibilidad ni se intenta la fila de siete: va directo a la rejilla.
    static func triesSingleRow(isAccessibilitySize: Bool) -> Bool { !isAccessibilitySize }
}

/// Los siete segmentos de la carta de adelante: llenos los hechos, punteados los de después, marcado el de ahora.
struct SetupDeckSegments: View {
    let steps: [SetupStep]
    let current: SetupStepID?
    /// El color del texto sobre el acento (`theme.onAccent`): los segmentos van encima de la carta.
    let ink: Color

    var body: some View {
        HStack(spacing: DS.Spacing.xxs) {
            ForEach(steps) { step in
                segment(SetupDeckProgressLogic.state(of: step, current: current))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func segment(_ state: SetupDeckProgressLogic.State) -> some View {
        switch state {
        case .done:
            Capsule().fill(ink)
        case .current:
            Capsule().fill(ink.opacity(0.55))
                .overlay(Capsule().stroke(ink, lineWidth: 1))
        case .later:
            Capsule().stroke(ink.opacity(0.75), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
        case .pending:
            Capsule().fill(ink.opacity(0.22))
        }
    }
}

/// La fila de los siete pasos, debajo del mazo, con «Hechos: N · Para después: M · Toca un paso para abrirlo».
struct SetupDeckStepsRow: View {
    private typealias T = PrimerosPasosPaso7Text.Deck

    let steps: [SetupStep]
    let current: SetupStepID?
    /// La línea de debajo (`nil`: «Hechos · Para después · Toca un paso»; vacía: ninguna, la del final ya lo dice).
    var caption: String?
    let onOpen: (SetupStepID) -> Void

    @Environment(\.yalaTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// La rejilla de respaldo: cuatro por fila, en dos (la maqueta: «ahí pasa a dos líneas»).
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.xxs, alignment: .top),
              count: SetupDeckStepsLayoutLogic.fallbackColumns)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            // Las siete etiquetas al mismo tamaño (observación del iPhone 14, 25-nov-2026): en columnas iguales,
            // «Presupuesto» se encogía y quedaba más chica que sus vecinas. Ahora cada columna mide lo que su palabra y
            // los huecos se reparten; si la fila no cabe (iPhone chico, texto grande), pasa a dos filas de cuatro.
            if SetupDeckStepsLayoutLogic.triesSingleRow(isAccessibilitySize: dynamicTypeSize.isAccessibilitySize) {
                ViewThatFits(in: .horizontal) {
                    singleRow
                    grid
                }
            } else {
                grid
            }
            if let line = caption ?? summary, !line.isEmpty {
                Text(line)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.thSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("setup_deck_progress_caption")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("setup_deck_progress")
    }

    /// Una fila con cada paso a la medida de su etiqueta y huecos iguales entre ellos.
    private var singleRow: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                if index > 0 { Spacer(minLength: DS.Spacing.xs) }
                item(step, fitsLabel: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: DS.Spacing.sm) {
            ForEach(steps) { step in
                item(step, fitsLabel: false)
            }
        }
    }

    private var summary: String? {
        let counts = SetupDeckProgressLogic.counts(steps)
        return T.summary(done: counts.done, later: counts.later)
    }

    @ViewBuilder
    /// `fitsLabel`: en la fila de siete, la etiqueta a su tamaño entero (nunca se encoge; si no cabe, la fila cede a la
    /// rejilla). En la rejilla, la columna es fija y encoger queda de último recurso.
    private func item(_ step: SetupStep, fitsLabel: Bool) -> some View {
        let state = SetupDeckProgressLogic.state(of: step, current: current)
        let content = VStack(spacing: DS.Spacing.xxs) {
            badge(step, state: state)
            Text(T.shortName(step.id))
                .font(DS.Typography.captionSmall.weight(state == .current ? .semibold : .regular))
                .foregroundStyle(state == .later || state == .pending ? theme.secondaryText : theme.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(fitsLabel ? 1 : 0.6)
                .fixedSize(horizontal: fitsLabel, vertical: false)
        }
        .frame(minWidth: fitsLabel ? 44 : nil, maxWidth: fitsLabel ? nil : .infinity, minHeight: 44)
        .contentShape(Rectangle())
        if SetupDeckProgressLogic.opens(step) {
            Button {
                DS.Haptic.selection()
                onOpen(step.id)
            } label: { content }
            .buttonStyle(.plain)
            .accessibilityLabel(step.id.localizedTitle)
            .accessibilityValue(value(state))
            .accessibilityIdentifier("setup_deck_step_\(String(describing: step.id))")
        } else {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(step.id.localizedTitle)
                .accessibilityValue(value(state))
                .accessibilityIdentifier("setup_deck_step_\(String(describing: step.id))")
        }
    }

    @ViewBuilder
    private func badge(_ step: SetupStep, state: SetupDeckProgressLogic.State) -> some View {
        let size: CGFloat = 30
        ZStack {
            switch state {
            case .done:
                Circle().fill(theme.accent)
                Image(systemName: "checkmark").foregroundStyle(theme.onAccent)
            case .current:
                Circle().fill(theme.accentText.opacity(0.15))
                Circle().stroke(theme.accentText, lineWidth: 2)
                Image(systemName: step.icon).foregroundStyle(theme.accentText)
            case .later:
                Circle().stroke(theme.secondaryText, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                Image(systemName: step.icon).foregroundStyle(theme.secondaryText)
            case .pending:
                Circle().fill(Color.primary.opacity(0.08))
                Image(systemName: step.icon).foregroundStyle(theme.secondaryText)
            }
        }
        .font(DS.Typography.caption.weight(.semibold))
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func value(_ state: SetupDeckProgressLogic.State) -> String {
        switch state {
        case .done: T.valueDone
        case .later: L10n.PrimerosPasos23.appText("setup.deck.skippedValue")
        case .current: T.valueCurrent
        case .pending: T.valuePending
        }
    }
}

//
//  SetupChecklistCard.swift
//  Yala
//
//  «Primeros pasos» en el Panel. Mientras quedan pasos, es el MAZO (Y23-05, bienvenida 2.3): el paso actual adelante,
//  en el color de la app, con «Primeros pasos · N de 7», y los dos siguientes asomando detrás («Después: …», «Luego:
//  …»). Al resolver el séptimo, el mazo desaparece y queda la tarjeta de fin.
//
//  Opción B de Jürgen (20-nov-2026, tema 2): sin la hoja «Ver los 7 pasos». El progreso va en el mazo: siete segmentos en
//  la carta de adelante, «Seguir donde iba» junto al paso, y debajo la fila de los siete con su estado
//  (`SetupDeckProgress`); tocar uno lo abre. El final dice qué quedó para después y deja la fila para hacerlos.
//

import SwiftData
import SwiftUI

struct SetupChecklistCard: View {

    // MARK: - Environment

    @Environment(\.yalaTheme) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Properties

    let manager: SetupChecklistManager
    let onStepTapped: (SetupStepID) -> Void

    // MARK: - State

    @State private var showCelebration = false
    @Environment(\.self) private var environment

    /// Si el texto sobre el acento es claro (blanco en los temas índigo) u oscuro (negro en Teal, Rosa y Minimalista).
    private var onAccentIsLight: Bool {
        let c = theme.onAccent.resolve(in: environment)
        return 0.2126 * Double(c.linearRed) + 0.7152 * Double(c.linearGreen) + 0.0722 * Double(c.linearBlue) > 0.5
    }

    // MARK: - Body

    var body: some View {
        if manager.shouldShow {
            ZStack {
                if manager.isAllComplete {
                    completedView
                } else if let deck = manager.deck {
                    deckView(deck)
                }

                if showCelebration {
                    // El confeti se desvanece antes de la franja de abajo, donde vive «Cerrar»: caía encima del botón
                    // (observación del iPhone 14, 25-nov-2026).
                    ConfettiView()
                        .allowsHitTesting(false)
                        .mask { SetupCelebrationMask() }
                }
            }
            // Con Reducir movimiento, sin animación (card C6); el mazo cambia de paso con un fundido.
            .animation(reduceMotion ? nil : DS.Animation.appear, value: manager.isAllComplete)
            .animation(reduceMotion ? nil : DS.Animation.appear, value: manager.deck)
            // Card ds09: quien volvió por «Ya tengo una cuenta» con datos no ve Primeros pasos. Pregunta al aparecer y
            // cada vez que cambia el progreso: los datos que llegan marcan solos el primer paso (el «1 de 7» que vio
            // Jürgen), que es justo cuando ya se puede decidir. Si se resuelve, la tarjeta se retira
            // (`ReturningUserBeginnerTips`).
            .task(id: manager.completedCount) { ReturningUserBeginnerTips.settleIfPending(context: modelContext) }
            .onChange(of: manager.isAllComplete) { _, isComplete in
                if isComplete {
                    showCelebration = true
                    DS.Haptic.success()
                }
            }
        }
    }

    // MARK: - Deck

    private func deckView(_ deck: SetupDeckLogic.Deck) -> some View {
        VStack(spacing: 0) {
            Button {
                onStepTapped(deck.current)
            } label: {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    SetupDeckSegments(steps: manager.steps, current: deck.current, ink: theme.onAccent)
                    HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                        Text(L10n.SetupChecklist.Deck.counter(deck.position, deck.total).uppercased())
                            .font(DS.Typography.badgeLabel)
                            .tracking(0.6) // A11Y-DT: espaciado del rótulo en mayúsculas del prototipo; no cambia el tamaño
                        Spacer(minLength: DS.Spacing.sm)
                        // «Seguir donde iba», junto al paso: la carta entera lo abre.
                        HStack(spacing: DS.Spacing.xxs) {
                            Text(L10n.SetupChecklist.Deck.resume)
                            Image(systemName: "chevron.right").accessibilityHidden(true)
                        }
                        .font(DS.Typography.labelSmall.weight(.semibold))
                        .accessibilityIdentifier("setup_deck_resume")
                    }
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "plus")
                            .font(DS.Typography.headline)
                            .accessibilityHidden(true)
                        Text(deck.current.localizedTitle)
                            .font(DS.Typography.headline)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .foregroundStyle(theme.onAccent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.md)
                .background(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous).fill(theme.accent))
                .shadow(color: DS.Shadow.large.color, radius: DS.Shadow.large.radius,
                        x: DS.Shadow.large.x, y: DS.Shadow.large.y)
                .contentShape(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous))
            }
            .buttonStyle(.plain)
            .zIndex(3)
            .accessibilityLabel(L10n.SetupChecklist.Deck.counter(deck.position, deck.total) + ", " + deck.current.localizedTitle)
            .accessibilityHint(L10n.SetupChecklist.nextStep(deck.current.localizedTitle))
            .accessibilityIdentifier("setup_deck_current")

            ForEach(Array(deck.upcoming.enumerated()), id: \.element) { index, step in
                peekingCard(step, index: index)
            }

            SetupDeckStepsRow(steps: manager.steps, current: deck.current, onOpen: onStepTapped)
                .padding(.top, DS.Spacing.sm)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("setup_deck")
    }

    /// Una carta que asoma detrás: más estrecha y más oscura cuanto más atrás. Solo se ve; VoiceOver la salta, como en
    /// el prototipo (el paso que sigue lo cuenta la fila de pasos de debajo).
    private func peekingCard(_ step: SetupStepID, index: Int) -> some View {
        let text = index == 0
            ? L10n.SetupChecklist.Deck.after(step.localizedTitle)
            : L10n.SetupChecklist.Deck.then(step.localizedTitle)
        let shape = UnevenRoundedRectangle(
            bottomLeadingRadius: DS.Radius.xl - DS.Spacing.xs,
            bottomTrailingRadius: DS.Radius.xl - DS.Spacing.xs,
            style: .continuous)
        // Cuanto más atrás, más lejos del color del texto: más oscura si el texto del acento es claro (Índigo) y más
        // clara si es oscuro (Teal, Rosa, Minimalista). Así el contraste solo sube respecto al botón de adelante, cuyo
        // par acento/texto ya mide `ThemeTokenContrastTests`. Oscurecer siempre dejaba Rosa en 1,7 (review del lote).
        let away: Color = onAccentIsLight ? .black : .white
        let fill = theme.accent.mix(with: away, by: index == 0 ? 0.3 : 0.5) // A11Y-DM: profundidad del mazo
        return Text(text)
            .font(DS.Typography.labelSmall)
            .foregroundStyle(theme.onAccent)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.top, DS.Spacing.lg + DS.Spacing.xxs)
            .padding(.bottom, DS.Spacing.xs)
            .padding(.horizontal, DS.Spacing.md)
            .background(shape.fill(fill))
            .padding(.horizontal, index == 0 ? DS.Spacing.md : DS.Spacing.xxl)
            .padding(.top, -DS.Spacing.lg)
            .zIndex(Double(2 - index))
            .accessibilityHidden(true)
    }

    // MARK: - Completed View

    /// Y23-18: en una instalación con el mazo, «¡Primeros pasos completos!» con chispas y «Cerrar» (prototipo v35). La
    /// lista de 2.2 conserva su final de siempre.
    @ViewBuilder
    private var completedView: some View {
        if manager.showsDeck {
            deckCompletedView
        } else {
            legacyCompletedView
        }
    }

    private var deckCompletedView: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "checkmark")
                .font(DS.Typography.headline.weight(.bold))
                .foregroundStyle(theme.onAccent)
                .frame(width: 40, height: 40)
                .background(Circle().fill(theme.accent))
                .accessibilityHidden(true)
            // Con pasos para después no dice «completos» (observación del iPhone 14, 25-nov-2026).
            Text(PrimerosPasosFinalTitleLogic.title(laterCount: laterSteps.count).text)
                .font(DS.Typography.headline)
                .foregroundStyle(.thPrimaryText)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("setup_deck_done_title")
            Text(doneMessage)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.thSecondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("setup_deck_done_message")
            // Lo que quedó para después se hace desde aquí (la maqueta decía «Ajustes › Tutoriales», que no los tiene
            // todos: no tiene grupos ni gráficas).
            if !laterSteps.isEmpty {
                SetupDeckStepsRow(steps: manager.steps, current: nil, caption: "", onOpen: onStepTapped)
            }
            Button(L10n.Action.close) { manager.dismissCompleted() }
                .font(DS.Typography.body.weight(.semibold))
                .foregroundStyle(.thAccentText)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityIdentifier("setup_deck_done_close")
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.lg)
        .background(DS.Semantic.infoBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .accessibilityElement(children: .contain)
    }

    private var laterSteps: [SetupStepID] { SetupDeckProgressLogic.later(manager.steps) }

    /// Con pasos para después, los nombra; si no, el mensaje de siempre.
    private var doneMessage: String {
        guard !laterSteps.isEmpty else { return L10n.PrimerosPasos23.Final.doneMessage }
        let names = laterSteps.map { PrimerosPasosPaso7Text.Deck.shortName($0) }
        return PrimerosPasosPaso7Text.Deck.doneWithLater(names.formatted(.list(type: .and).locale(LanguageManager.resolved.locale)))
    }

    private var legacyCompletedView: some View {
        HStack {
            VStack(spacing: DS.Spacing.sm) {
                // Con algún paso saltado no dice «¡Ya eres experto!» (UX 2.2 · L5-2).
                Text(manager.hasSkippedSteps ? L10n.SetupChecklist.basicsTitle : L10n.SetupChecklist.completeTitle)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)

                Text(manager.hasSkippedSteps ? L10n.SetupChecklist.basicsSubtitle : L10n.SetupChecklist.completeSubtitle)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.thSecondaryText)
            }
            .frame(maxWidth: .infinity)

            Button {
                manager.dismissCompleted()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.thSecondaryText)
                    .frame(width: DS.Button.actionSize, height: DS.Button.actionSize)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(NSLocalizedString("action.close", comment: "Close"))
        }
        .padding(DS.Spacing.lg)
        .background(DS.Semantic.infoBackground)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

}

// MARK: - Preview

#Preview("Expanded") {
    SetupChecklistCard(
        manager: .shared,
        onStepTapped: { _ in }
    )
    .padding()
}

/// La máscara del confeti del cierre: entero arriba, se desvanece y deja limpia la franja de abajo, la de «Cerrar».
struct SetupCelebrationMask: View {
    /// Lo que mide la franja limpia de abajo: el botón «Cerrar» (44) y el margen de la tarjeta.
    static let clearBottom: CGFloat = 44 + DS.Spacing.lg
    /// Lo que dura el fundido, por encima de la franja limpia.
    static let fadeHeight: CGFloat = DS.Spacing.xxl

    var body: some View {
        VStack(spacing: 0) {
            Color.black
            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: Self.fadeHeight)
            Color.clear.frame(height: Self.clearBottom)
        }
    }
}

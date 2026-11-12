//
//  SetupChecklistCard.swift
//  Yala
//
//  «Primeros pasos» en el Panel. Mientras quedan pasos, es el MAZO (Y23-05, bienvenida 2.3): el paso actual adelante,
//  en el color de la app, con «Primeros pasos · N de 7», y los dos siguientes asomando detrás («Después: …», «Luego:
//  …»). «Ver los 7 pasos» abre la lista con los hechos marcados. Al resolver el séptimo, el mazo desaparece y queda la
//  tarjeta de fin (la reharán en Y23-18).
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
    @State private var showsAllSteps = false
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
                    ConfettiView()
                        .allowsHitTesting(false)
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
            .sheet(isPresented: $showsAllSteps) {
                SetupStepsListSheet(manager: manager)
            }
        }
    }

    // MARK: - Deck

    private func deckView(_ deck: SetupDeckLogic.Deck) -> some View {
        VStack(spacing: 0) {
            Button {
                onStepTapped(deck.current)
            } label: {
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(L10n.SetupChecklist.Deck.counter(deck.position, deck.total).uppercased())
                        .font(DS.Typography.badgeLabel)
                        .tracking(0.6) // A11Y-DT: espaciado del rótulo en mayúsculas del prototipo; no cambia el tamaño
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

            Button {
                showsAllSteps = true
            } label: {
                Text(L10n.SetupChecklist.showAllSteps(deck.total))
                    .font(DS.Typography.labelSmall)
                    .foregroundStyle(theme.accentText)
                    .frame(minHeight: DS.Button.actionSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, DS.Spacing.xxs)
            .accessibilityIdentifier("setup_checklist_toggle_steps")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("setup_deck")
    }

    /// Una carta que asoma detrás: más estrecha y más oscura cuanto más atrás. Solo se ve; VoiceOver la salta, como en
    /// el prototipo (el paso que sigue lo cuenta «Ver los 7 pasos»).
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

    private var completedView: some View {
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

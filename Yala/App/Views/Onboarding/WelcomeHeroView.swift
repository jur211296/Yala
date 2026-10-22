//
//  WelcomeHeroView.swift
//  Yala
//
//  Pantalla de presentación entre splash y Welcome Chooser. Mientras el user lee
//  las cards animadas no corre ninguna detección: al tap "Empezar" el flow va
//  SIEMPRE al Chooser.
//
//  **La reentrada es decisión del usuario** (decisión del owner 2026-08-11, punto 2
//  de MODO-NUBE-REVISION-FLUJOS-NOTAS). El Hero ofrecía un alert «Detectamos tu
//  cuenta» disparado por la señal del KV-store (`RestoreOfferGate.hasReturningSignal`),
//  y esa señal solo habla de la cuenta iCloud del container: empujaba hacia esa mitad
//  a quien podía tener su cuenta en la nube (Apple/Google). Quien vuelve entra por
//  "Ya tengo una cuenta", que ofrece las tres vías. La señal del KV-store NO se
//  retiró — MEDIDO: la siguen leyendo `ContentView` y `WelcomeRestoreView`.
//

import SwiftData
import SwiftUI

// MARK: - WelcomeHeroView

struct WelcomeHeroView: View {
    var onContinue: () -> Void

    // MARK: Constants

    /// Intervalo entre rotaciones de cards. Spring animation 0.45s ya cubre el movimiento.
    private static let cardRotationInterval: Duration = .seconds(3.5)

    /// Dimensiones del card.
    private static let cardWidth: CGFloat = 200
    private static let cardIdealHeight: CGFloat = 130
    private static let cardMaxHeight: CGFloat = 160

    /// Animación canónica del carousel (rotación auto + tap en page indicator).
    private static let cardAnimation: Animation = .smooth(duration: 0.45, extraBounce: 0.15)

    /// Layout del stack visual: front centrado → 1 side card a cada lado.
    /// Front siempre en (0,0) con scale 1; side se refleja con signo según
    /// `relative` sea +/- en `position(for:)`. Las cards a distancia ≥2 quedan
    /// invisibles para evitar cruce/transparencia con la front card.
    private static let scaleSide: CGFloat = 0.82
    private static let offsetSideX: CGFloat = 200
    private static let offsetSideY: CGFloat = 10
    private static let rotationSide: Double = 5
    private static let opacitySide: Double = 0.55

    // MARK: State

    @State private var currentCardIndex: Int = 0
    @State private var rotationTask: Task<Void, Never>?
    @State private var cards: [HeroCard] = []
    @State private var hasTappedEmpezar: Bool = false

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: Cards data

    private struct HeroCard: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let body: String
        let accentColor: Color
    }

    /// Cacheado en `@State`: 16 lookups `ls(...)` × cada body recompute (animation
    /// 60fps) sería derroche. Se popula una vez en `.task`.
    private static func makeCards() -> [HeroCard] {
        [
            HeroCard(icon: "camera.fill", title: L10n.Welcome.Hero.captureTitle, body: L10n.Welcome.Hero.captureBody, accentColor: .electricIndigo),
            HeroCard(icon: "bubble.left.and.bubble.right.fill", title: L10n.Welcome.Hero.assistantTitle, body: L10n.Welcome.Hero.assistantBody, accentColor: .hotPink),
            HeroCard(icon: "person.2.fill", title: L10n.Welcome.Hero.groupsTitle, body: L10n.Welcome.Hero.groupsBody, accentColor: .priorityNeed),
            HeroCard(icon: "target", title: L10n.Welcome.Hero.budgetsTitle, body: L10n.Welcome.Hero.budgetsBody, accentColor: .essentialNeed),
            HeroCard(icon: "creditcard.fill", title: L10n.Welcome.Hero.multiAndCurrenciesTitle, body: L10n.Welcome.Hero.multiAndCurrenciesBody, accentColor: .priorityNeedNew),
            HeroCard(icon: "arrow.down.doc.fill", title: L10n.Welcome.Hero.importTitle, body: L10n.Welcome.Hero.importBody, accentColor: .electricIndigo),
            HeroCard(icon: "icloud.fill", title: L10n.Welcome.Hero.icloudTitle, body: L10n.Welcome.Hero.icloudBody, accentColor: .hotPink),
            HeroCard(icon: "sparkles", title: L10n.Welcome.Hero.moreTitle, body: L10n.Welcome.Hero.moreBody, accentColor: .essentialNeed),
        ]
    }

    // MARK: Body

    var body: some View {
        WelcomeFlowScreen { logoTopSpacing in
            VStack(spacing: 0) {
                Spacer(minLength: logoTopSpacing)

                Image("YalaLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 128)
                    .colorMultiply(.white)
                    .accessibilityHidden(true)

                Spacer(minLength: DS.Spacing.lg)

                cardCarousel
                    .frame(height: 200)

                pageIndicator
                    .padding(.top, DS.Spacing.md)

                Spacer(minLength: DS.Spacing.lg)

                heroTitle
                    .padding(.horizontal, DS.Spacing.xl)

                Spacer(minLength: DS.Spacing.xl)

                ctaSection
                    .padding(.horizontal, DS.Spacing.xl)
                    .padding(.bottom, DS.Spacing.xl)
            }
        }
        .task {
            if cards.isEmpty {
                cards = Self.makeCards()
            }
            startCardRotation()
        }
        .onDisappear {
            rotationTask?.cancel()
        }
    }

    // MARK: Card carousel

    /// Renderiza las 8 cards a la vez con posiciones relativas al `currentCardIndex`.
    /// Cada card cambia sus propiedades visuales (offset/scale/rotation/opacity)
    /// según la posición relativa, animadas implícitamente por `withAnimation`
    /// del rotationTask. Sin `.id` + transition → no hay re-mount, todas las
    /// cards se mueven en sincro como un carousel real.
    private var cardCarousel: some View {
        ZStack {
            if !cards.isEmpty {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    let pos = position(for: index)
                    heroCardView(card)
                        .scaleEffect(pos.scale)
                        .rotationEffect(.degrees(pos.rotation))
                        .offset(x: pos.offsetX, y: pos.offsetY)
                        .opacity(pos.opacity)
                        .zIndex(pos.zIndex)
                        .accessibilityHidden(index != currentCardIndex)
                        .accessibilityLabel(index == currentCardIndex ? "\(card.title). \(card.body)" : "")
                }
            }
        }
    }

    /// Posición visual derivada de la distancia signed `(idx - currentCardIndex) mod n`.
    /// Mostramos -2..+2; el resto invisible.
    private func position(for index: Int) -> CardPosition {
        let n = cards.count
        guard n > 0 else { return .hidden }
        let raw = ((index - currentCardIndex) % n + n) % n
        let relative = raw > n / 2 ? raw - n : raw
        let sign: Double = relative > 0 ? 1 : -1
        switch abs(relative) {
        case 0:
            return CardPosition(scale: 1.0, offsetX: 0, offsetY: 0, rotation: 0, opacity: 1, zIndex: 100)
        case 1:
            return CardPosition(
                scale: Self.scaleSide,
                offsetX: Self.offsetSideX * sign,
                offsetY: Self.offsetSideY,
                rotation: Self.rotationSide * sign,
                opacity: Self.opacitySide,
                zIndex: 90
            )
        default:
            return .hidden
        }
    }

    private struct CardPosition {
        let scale: CGFloat
        let offsetX: CGFloat
        let offsetY: CGFloat
        let rotation: Double
        let opacity: Double
        let zIndex: Double
        static let hidden = CardPosition(scale: 0.6, offsetX: 0, offsetY: 0, rotation: 0, opacity: 0, zIndex: 0)
    }

    /// Card translúcida estilo widgets del Panel, con colores FIJOS de
    /// `WelcomeFlowStyle` (el fondo hero no adapta al tema — ver WelcomeFlowLayout).
    /// Icono mantiene gradient brand para diferenciar.
    private func heroCardView(_ card: HeroCard) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(card.accentColor.opacity(0.18))
                    .frame(width: 56, height: 56)
                Image(systemName: card.icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [card.accentColor, card.accentColor.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text(card.title)
                .font(DS.Typography.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)
                .lineLimit(1)

            Text(card.body)
                .font(DS.Typography.caption)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)
                .lineLimit(2)
        }
        .padding(DS.Spacing.md)
        .frame(width: Self.cardWidth)
        .frame(idealHeight: Self.cardIdealHeight, maxHeight: Self.cardMaxHeight)
        .welcomeFlowCard(radius: DS.Panel.widgetRadius)
    }

    // MARK: Page indicator

    private var pageIndicator: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(cards.indices, id: \.self) { idx in
                Capsule()
                    .fill(idx == currentCardIndex ? Color.white : Color.white.opacity(0.3))
                    .frame(width: idx == currentCardIndex ? 18 : 6, height: 3)
                    .contentShape(Rectangle().inset(by: -8))
                    .onTapGesture {
                        DS.Haptic.selection()
                        jumpTo(idx)
                    }
                    .accessibilityLabel(L10n.Accessibility.pageIndicator(idx + 1, cards.count))
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Navega a una card específica + reset del timer de rotación.
    private func jumpTo(_ idx: Int) {
        guard idx != currentCardIndex, !cards.isEmpty else { return }
        withAnimation(reduceMotion ? nil : Self.cardAnimation) {
            currentCardIndex = idx
        }
        rotationTask?.cancel()
        startCardRotation()
    }

    // MARK: Title

    /// Sin subtítulo (decisión del owner 2026-08-11, punto 1): las 8 cards que rotan justo
    /// encima ya cuentan qué hace Yala, y la línea «Tú captura. Yala se encarga.» repetía la
    /// primera de ellas. La key `welcome.hero.subtitle` se retiró de los 16 locales.
    private var heroTitle: some View {
        VStack(spacing: 0) {
            Text(L10n.Welcome.Hero.title)
                .foregroundStyle(.white)
            Text(L10n.Welcome.Hero.titleAccent)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.hotPink, .white],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .font(DS.Typography.largeTitle)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(L10n.Welcome.Hero.title) \(L10n.Welcome.Hero.titleAccent)")
    }

    // MARK: CTA

    private var ctaSection: some View {
        VStack(spacing: DS.Spacing.md) {
            YalaPrimaryButton(L10n.Welcome.Hero.cta) {
                handleEmpezar()
            }
            .accessibilityIdentifier("welcome_hero_cta")

            Text(L10n.Welcome.Hero.trust)
                .font(DS.Typography.caption)
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Empezar handler

    /// Single-shot y sin espera: el Hero ya no consulta nada antes de continuar, así que
    /// tampoco hay `isLoading` ni timeout post-tap que gastar. El `guard` se conserva para
    /// que un doble tap no dispare dos transiciones del container.
    private func handleEmpezar() {
        guard !hasTappedEmpezar else { return }
        hasTappedEmpezar = true
        DS.Haptic.selection()
        onContinue()
    }

    // MARK: Tasks

    private func startCardRotation() {
        rotationTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.cardRotationInterval)
                guard !Task.isCancelled else { return }
                // Pausa rotation si VoiceOver activo (a11y).
                if voiceOverEnabled { continue }
                await MainActor.run {
                    withAnimation(reduceMotion ? nil : Self.cardAnimation) {
                        currentCardIndex = (currentCardIndex + 1) % cards.count
                    }
                }
            }
        }
    }
}

// Preview removido: WelcomeHeroView depende de AppPreferences inyectado vía
// @Environment, ModelContext y iCloudSyncService — no es trivial mockearlos
// para el canvas. Verificación visual se hace en simulator (`/device-qa`).

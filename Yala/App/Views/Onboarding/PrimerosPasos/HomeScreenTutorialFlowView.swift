//
//  HomeScreenTutorialFlowView.swift
//  Yala
//
//  Y23-16 · Paso 7 de Primeros pasos: «Anota sin abrir Yala» (docs/onboarding-2-3/SPEC.md, prototipo oficial v35,
//  pestaña 8 · Pasos 6 y 7). Como el paso 2: una página corta con una parte por manera (avanza sola cada 3,4 s, quieta
//  con Reducir movimiento o VoiceOver) y luego un mini tutorial de cada una —widget, Apple Pay, compartir una foto y
//  Siri—, todos omitibles, con una pantalla entre uno y otro. La app no puede poner el widget ni saber si se configuró
//  algo fuera de ella: cada mini tutorial se da por hecho al tocar su botón. Las reglas viven en
//  `HomeScreenTutorialLogic`; el progreso, en `HomeScreenTutorialProgress`, que guarda quien presenta la pantalla.
//

import SwiftUI

/// Por dónde va el paso 7. Lo guarda quien presenta la pantalla: si iOS rehace su contenido sin cerrarla, no vuelve al
/// principio (la regla de hojas de `swiftui-ds.md`).
@MainActor
@Observable
final class HomeScreenTutorialProgress {
    enum Phase: Equatable {
        case intro
        case method(HomeScreenTutorialLogic.Method)
        case between
    }

    var phase: Phase = .intro
    var part = 0
    var outcomes: [HomeScreenTutorialLogic.Method: HomeScreenTutorialLogic.Outcome] = [:]

    func reset() {
        phase = .intro
        part = 0
        outcomes = [:]
    }
}

struct HomeScreenTutorialFlowView: View {
    private typealias T = L10n.PrimerosPasos23.Home
    private typealias Logic = HomeScreenTutorialLogic

    @Bindable var progress: HomeScreenTutorialProgress
    let onClose: (HomeScreenTutorialLogic.Exit) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            switch progress.phase {
            case .intro:
                intro.transition(.opacity).zIndex(1)
            case .method(let method):
                HomeScreenMethodPage(
                    method: method,
                    onDone: { resolve(method, .done) },
                    onSkip: { resolve(method, .skipped) }
                )
                .id(method)
                .transition(.opacity)
                .zIndex(1)
            case .between:
                betweenPage.transition(.opacity).zIndex(1)
            }
        }
        .animation(reduceMotion ? nil : DS.Animation.appear, value: progress.phase)
        .yalaScreenBackground(.panel)
    }

    // MARK: - La página corta

    private var intro: some View {
        TutorialStoryPage(
            eyebrow: T.eyebrow,
            count: Logic.methods.count,
            part: $progress.part,
            onBack: goBackFromIntro,
            content: { index in HomeScreenIntroPart(method: Logic.methods[index]) },
            footer: {
                VStack(spacing: DS.Spacing.xs) {
                    YalaPrimaryButton(T.start) {
                        DS.Haptic.selection()
                        progress.phase = .method(Logic.methods[0])
                    }
                    .accessibilityIdentifier("home_tutorial_start")
                    .primerosPasosButtonText()
                    Button(L10n.PrimerosPasos23.Record.skipStep) { onClose(.skippedStep) }
                        .font(DS.Typography.body.weight(.semibold))
                        .foregroundStyle(.thAccentText)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityIdentifier("home_tutorial_skip_step")
                }
            }
        )
    }

    /// «Atrás» vuelve a la parte anterior; desde la primera, cierra sin tocar el mazo.
    private func goBackFromIntro() {
        if progress.part > 0 {
            progress.part -= 1
        } else {
            onClose(.closed)
        }
    }

    // MARK: - Resolver una manera

    private func resolve(_ method: HomeScreenTutorialLogic.Method, _ outcome: HomeScreenTutorialLogic.Outcome) {
        // Un doble toque en «Omitir» no resuelve también la siguiente: la pantalla de entre medias no cambia de sitio.
        guard progress.outcomes[method] == nil else { return }
        progress.outcomes[method] = outcome
        if outcome == .done { DS.Haptic.success() }
        if let exit = Logic.exitAfterResolving(progress.outcomes) {
            onClose(exit)
        } else {
            progress.phase = .between
        }
    }

    // MARK: - Entre una manera y la siguiente

    private var betweenPage: some View {
        let next = Logic.next(after: progress.outcomes)
        let done = Logic.doneCount(progress.outcomes)
        return VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Text(L10n.PlaceGuide.stepOf(7, 7))
                .font(DS.Typography.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 44)
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    HomeScreenMethodsRow(outcomes: progress.outcomes, next: next)
                    Text(done > 0 ? T.progress(done, Logic.methods.count) : T.keepGoing)
                        .font(DS.Typography.welcomeHeadline)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("home_tutorial_between_title")
                    if let next {
                        HomeScreenNextCard(method: next)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .safeAreaBar(edge: .bottom, spacing: DS.Spacing.sm) {
            VStack(spacing: DS.Spacing.xs) {
                if let next {
                    YalaPrimaryButton(HomeScreenMethodText.nextAction(next)) {
                        DS.Haptic.selection()
                        progress.phase = .method(next)
                    }
                    .accessibilityIdentifier("home_tutorial_next")
                    .primerosPasosButtonText()
                    Button(L10n.PrimerosPasos23.Record.skip) { resolve(next, .skipped) }
                        .font(DS.Typography.body.weight(.semibold))
                        .foregroundStyle(.thAccentText)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityIdentifier("home_tutorial_next_skip")
                } else {
                    YalaPrimaryButton(T.finish) {
                        onClose(.finished(anyDone: Logic.doneCount(progress.outcomes) > 0))
                    }
                    .accessibilityIdentifier("home_tutorial_finish")
                    .primerosPasosButtonText()
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.md)
        }
    }
}

// MARK: - Textos y aspecto de cada manera

/// El nombre, el color y los textos cortos de cada manera, en un solo sitio.
@MainActor
enum HomeScreenMethodText {
    private typealias T = L10n.PrimerosPasos23.Home

    static func name(_ method: HomeScreenTutorialLogic.Method) -> String {
        switch method {
        case .widget: T.widgetName
        case .applePay: T.applePayName
        case .share: T.shareName
        case .siri: T.siriName
        }
    }

    static func icon(_ method: HomeScreenTutorialLogic.Method) -> String {
        switch method {
        case .widget: "square.grid.2x2.fill"
        case .applePay: "creditcard.fill"
        case .share: "square.and.arrow.up"
        case .siri: "waveform"
        }
    }

    /// Los colores del prototipo; el de Apple Pay, gris para que se lea sobre el fondo oscuro.
    static func color(_ method: HomeScreenTutorialLogic.Method) -> Color {
        switch method {
        case .widget: .electricIndigo
        case .applePay: .gray
        case .share: .teal
        case .siri: .purple
        }
    }

    static func nextDetail(_ method: HomeScreenTutorialLogic.Method) -> String {
        switch method {
        case .widget: T.widgetPartMessage
        case .applePay: T.applePayNextDetail
        case .share: T.shareNextDetail
        case .siri: T.siriNextDetail
        }
    }

    static func nextAction(_ method: HomeScreenTutorialLogic.Method) -> String {
        switch method {
        case .widget: T.start
        case .applePay: T.applePayNextAction
        case .share: T.shareNextAction
        case .siri: T.siriNextAction
        }
    }
}

/// El icono de una manera en su baldosa de color, con la insignia Pro si la lleva.
struct HomeScreenMethodTile: View {
    let method: HomeScreenTutorialLogic.Method
    var size: CGFloat = 52

    var body: some View {
        let color = HomeScreenMethodText.color(method)
        Image(systemName: HomeScreenMethodText.icon(method))
            .font(DS.Typography.title2.weight(.semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: DS.Radius.md).fill(color.opacity(0.18)))
            .overlay(alignment: .topTrailing) {
                if method.isPro {
                    ProBadge(size: .small).offset(x: DS.Spacing.sm, y: -DS.Spacing.xs)
                }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Las cuatro maneras, de un vistazo

/// La fila de las maneras con su estado: hecha (✓), omitida (gris), la que sigue (resaltada).
private struct HomeScreenMethodsRow: View {
    let outcomes: [HomeScreenTutorialLogic.Method: HomeScreenTutorialLogic.Outcome]
    let next: HomeScreenTutorialLogic.Method?

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            ForEach(HomeScreenTutorialLogic.methods, id: \.self) { method in
                VStack(spacing: DS.Spacing.xs) {
                    ZStack {
                        Circle()
                            .fill(fill(for: method))
                            .frame(width: 44, height: 44)
                        Image(systemName: outcomes[method] == .done ? "checkmark" : HomeScreenMethodText.icon(method))
                            .font(DS.Typography.body.weight(.semibold))
                            .foregroundStyle(outcomes[method] == .done ? theme.onAccent : HomeScreenMethodText.color(method))
                    }
                    .opacity(outcomes[method] == .skipped ? 0.45 : 1)
                    Text(HomeScreenMethodText.name(method))
                        .font(DS.Typography.captionSmall.weight(method == next ? .semibold : .regular))
                        .foregroundStyle(method == next ? .primary : .secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label(for: method))
            }
        }
    }

    private func fill(for method: HomeScreenTutorialLogic.Method) -> Color {
        switch outcomes[method] {
        case .done: theme.accent
        case .skipped: Color.primary.opacity(0.08)
        case nil: HomeScreenMethodText.color(method).opacity(method == next ? 0.3 : 0.14)
        }
    }

    private func label(for method: HomeScreenTutorialLogic.Method) -> String {
        let name = HomeScreenMethodText.name(method)
        switch outcomes[method] {
        case .done: return "\(name), \(L10n.Action.done)"
        case .skipped: return "\(name), \(L10n.PrimerosPasos23.appText("setup.deck.skippedValue"))"
        case nil: return method == next ? L10n.PrimerosPasos23.Home.nowNext(name) : name
        }
    }
}

/// La tarjeta de la que sigue: «Ahora: Apple Pay» y una línea.
private struct HomeScreenNextCard: View {
    let method: HomeScreenTutorialLogic.Method

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        HStack(alignment: .center, spacing: DS.Spacing.md) {
            HomeScreenMethodTile(method: method)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(L10n.PrimerosPasos23.Home.nowNext(HomeScreenMethodText.name(method)))
                    .font(DS.Typography.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(HomeScreenMethodText.nextDetail(method))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.md)
        .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
        .accessibilityElement(children: .combine)
    }
}

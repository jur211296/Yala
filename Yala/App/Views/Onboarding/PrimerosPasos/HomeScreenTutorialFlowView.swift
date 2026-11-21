//
//  HomeScreenTutorialFlowView.swift
//  Yala
//
//  Y23-16 · Paso 7 de Primeros pasos: «Anota sin abrir Yala». Desde la opción B de Jürgen (20-nov-2026, tema 1 de las
//  maquetas `docs/maquetas/primeros-pasos-paso-7-y-prueba/`) son HISTORIAS: una por manera (widget, Apple Pay, compartir,
//  el correo si aplica, Siri), con «Tutorial · N de M · Nombre» arriba, el ejemplo de cómo se ve en el centro y el
//  beneficio en grande abajo. No avanza sola: se toca la mitad derecha para pasar a la siguiente, la izquierda para volver.
//  Un solo botón suave, «Enséñame cómo», abre el mini tutorial de hoy (`HomeScreenMethodPage`); terminarlo la da por
//  hecha y pasa a la siguiente historia. Sin «Omitir»: pasar la última termina el paso (hecho si se vio algún mini
//  tutorial; si no, para después). La ✕ cierra sin tocar el mazo, y el paso se retoma en la misma historia. La app no
//  puede poner el widget ni saber si se configuró algo fuera de ella: cada mini tutorial se da por hecho al terminarlo.
//  Las reglas viven en `HomeScreenTutorialLogic`; el progreso, en `HomeScreenTutorialProgress`, que guarda quien
//  presenta la pantalla.
//

import SwiftUI

/// Por dónde va el paso 7. Lo guarda quien presenta la pantalla: si iOS rehace su contenido sin cerrarla, no vuelve al
/// principio (la regla de hojas de `swiftui-ds.md`), y cerrar con la ✕ lo conserva para retomarlo.
@MainActor
@Observable
final class HomeScreenTutorialProgress {
    enum Phase: Equatable {
        /// Las historias, en la de `part`.
        case story
        /// El mini tutorial de una manera, abierto con «Enséñame cómo».
        case method(HomeScreenTutorialLogic.Method)
    }

    var phase: Phase = .story
    /// La historia a la vista: su índice en `methods`.
    var part = 0
    var outcomes: [HomeScreenTutorialLogic.Method: HomeScreenTutorialLogic.Outcome] = [:]
    /// Las maneras de esta vez, fijadas al aparecer: si la sesión cambia a medias, la cuenta («3 de 5») no salta.
    var methods: [HomeScreenTutorialLogic.Method]?

    func reset() {
        phase = .story
        part = 0
        outcomes = [:]
        methods = nil
    }
}

struct HomeScreenTutorialFlowView: View {
    private typealias Logic = HomeScreenTutorialLogic
    private typealias S = PrimerosPasosPaso7Text.Story

    @Bindable var progress: HomeScreenTutorialProgress
    /// `BankEmailEntryLogic.showsRow` en el momento de presentar: con él, cinco maneras.
    let showsMail: Bool
    let onClose: (HomeScreenTutorialLogic.Exit) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var methods: [HomeScreenTutorialLogic.Method] {
        progress.methods ?? Logic.methods(showsMail: showsMail)
    }

    private var currentMethod: HomeScreenTutorialLogic.Method {
        methods[min(max(progress.part, 0), methods.count - 1)]
    }

    var body: some View {
        ZStack {
            switch progress.phase {
            case .story:
                stories.transition(.opacity).zIndex(1)
            case .method(let method):
                HomeScreenMethodPage(
                    method: method,
                    methods: methods,
                    onDone: { done(method) },
                    onBack: { progress.phase = .story }
                )
                .id(method)
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .animation(reduceMotion ? nil : DS.Animation.appear, value: progress.phase)
        .yalaScreenBackground(.panel)
        .onAppear {
            if progress.methods == nil { progress.methods = Logic.methods(showsMail: showsMail) }
        }
    }

    // MARK: - Las historias

    private var stories: some View {
        TutorialStoryPage(
            eyebrow: S.eyebrow(Logic.position(of: currentMethod, in: methods), methods.count,
                               HomeScreenMethodText.name(currentMethod)),
            count: methods.count,
            part: $progress.part,
            autoAdvances: false,
            backSystemImage: "xmark",
            backLabel: L10n.Action.close,
            onAdvancePastLast: finish,
            lastPartTrailingTitle: S.finish,
            onBack: { onClose(.closed) },
            content: { index in HomeScreenStoryPart(method: methods[index]) },
            footer: {
                YalaSecondaryButton(howToTitle(currentMethod), icon: howToIcon(currentMethod)) {
                    DS.Haptic.selection()
                    progress.phase = .method(currentMethod)
                }
                .accessibilityIdentifier("home_tutorial_how_to")
                .primerosPasosButtonText()
            }
        )
    }

    /// Siri enseña sus frases («Ver todas las frases»); las demás, el cómo («Enséñame cómo»).
    private func howToTitle(_ method: HomeScreenTutorialLogic.Method) -> String {
        method == .siri ? S.siriAllPhrases : S.howTo
    }

    private func howToIcon(_ method: HomeScreenTutorialLogic.Method) -> String {
        method == .siri ? "text.bubble" : "play.circle"
    }

    // MARK: - Terminar

    /// El mini tutorial terminó: la manera queda hecha y se pasa a la siguiente historia (o se termina el paso).
    private func done(_ method: HomeScreenTutorialLogic.Method) {
        progress.outcomes[method] = .done
        DS.Haptic.success()
        let index = methods.firstIndex(of: method) ?? progress.part
        if index >= methods.count - 1 {
            finish()
        } else {
            progress.part = index + 1
            progress.phase = .story
        }
    }

    /// Pasar la última historia: hecho si se vio algún mini tutorial; si no, para después.
    private func finish() {
        onClose(.finished(anyDone: Logic.doneCount(progress.outcomes, in: methods) > 0))
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
        case .mail: T.mailName
        case .siri: T.siriName
        }
    }

    static func icon(_ method: HomeScreenTutorialLogic.Method) -> String {
        switch method {
        case .widget: "square.grid.2x2.fill"
        case .applePay: "creditcard.fill"
        case .share: "square.and.arrow.up"
        case .mail: "envelope.fill"
        case .siri: "waveform"
        }
    }

    /// Los colores del prototipo; el de Apple Pay, gris para que se lea sobre el fondo oscuro.
    static func color(_ method: HomeScreenTutorialLogic.Method) -> Color {
        switch method {
        case .widget: .electricIndigo
        case .applePay: .gray
        case .share: .teal
        case .mail: .blue
        case .siri: .purple
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

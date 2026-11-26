//
//  TutorialStoryPage.swift
//  Yala
//
//  La página corta de Primeros pasos (patrón E2 del prototipo oficial v35): unas pocas partes que avanzan solas cada
//  3,4 s con una barra de segmentos arriba, y un botón fijo abajo. La usan las intros de los pasos 1 a 5 y el 7.
//  Desde el pulido del 2026-11-20 se comporta como las historias de Instagram, igual que la vitrina del Welcome: tocar la
//  mitad derecha avanza, la izquierda vuelve, y mantener el dedo pausa la barra donde está (al soltar sigue con lo que le
//  quedaba). El reloj y la regla de las mitades son los del Welcome (`WelcomeShowcaseLogic.StoryClock` y `tapStep`).
//  Accesibilidad de la ficha: con Reducir movimiento o VoiceOver no avanza sola y solo se funde; el gesto «Siguiente» y
//  los segmentos cambian de parte.
//

import SwiftUI

/// Cuándo pasa sola a la siguiente parte, y a cuál lleva un toque.
nonisolated enum TutorialStoryLogic {
    /// Lo que dura cada parte (ficha: 3,4 s).
    static let partDuration: Duration = .milliseconds(3400)

    /// Lo que dura cada parte de «Anota sin abrir Yala» (paso 7). Jürgen, 13-nov (E14): «deberían ir más lento»; con
    /// 3,4 s la del correo se iba antes de poder leerla. Sus partes llevan más texto que las de las cuentas o las de
    /// anotar.
    static let slowPartDuration: Duration = .milliseconds(6000)

    /// Si la página avanza sola: nunca con Reducir movimiento ni con VoiceOver, nunca con el dedo puesto (pausa) y nunca
    /// desde la última parte.
    static func advancesAutomatically(part: Int, count: Int, reduceMotion: Bool, voiceOver: Bool,
                                      paused: Bool = false) -> Bool {
        !reduceMotion && !voiceOver && !paused && part < count - 1
    }

    /// La parte que sigue al tocar: la siguiente, sin pasar de la última.
    static func tapped(part: Int, count: Int) -> Int {
        stepped(part: part, by: 1, count: count)
    }

    /// La parte tras un toque en una mitad (+1 la derecha, −1 la izquierda). No da la vuelta: en la primera, la mitad
    /// izquierda no hace nada, y en la última, la derecha tampoco (el botón de abajo es el que sigue).
    static func stepped(part: Int, by step: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(count - 1, max(0, part + step))
    }

    /// Lo que dura una parte, en segundos, para el reloj de las historias.
    static func seconds(_ duration: Duration) -> TimeInterval {
        TimeInterval(duration.components.seconds) + TimeInterval(duration.components.attoseconds) / 1e18
    }

    /// Lo que se mantiene el dedo para que cuente como pausa y no como toque: soltar tras una pausa así no cambia de
    /// parte.
    static let pauseAfter: TimeInterval = 0.25

    /// Si un toque que termina ahora fue en realidad una pausa (el dedo estuvo puesto `pauseAfter` o más).
    static func wasAHold(pressedAt start: Date?, now: Date) -> Bool {
        guard let start else { return false }
        return now.timeIntervalSince(start) >= pauseAfter
    }

    /// El alto mínimo de la zona que se toca: lo que el scroll deja ver entre las rayitas y el botón de abajo. Con él,
    /// tocar o mantener el dedo responde en toda esa zona aunque el contenido acabe a media pantalla (observación del
    /// iPhone 14, 25-nov-2026: el dedo caía en la mitad de abajo, vacía, y no pasaba nada). Un contenido más alto sigue
    /// desplazándose como antes.
    static func stageMinHeight(containerHeight: CGFloat, topInset: CGFloat, bottomInset: CGFloat) -> CGFloat {
        max(0, (containerHeight - topInset - bottomInset).rounded(.down))
    }
}

/// La barra de segmentos: hechos, el de ahora (con lo que lleva) y los que faltan. El relleno sale del reloj en cada
/// fotograma, como en el Welcome: con la pausa se queda quieto donde está.
struct TutorialStorySegments: View {
    let count: Int
    @Binding var part: Int
    /// Lo que lleva la parte de ahora, de 0 a 1. Sin avance solo (Reducir movimiento o VoiceOver), 1.
    let progress: (Date) -> Double
    let isRunning: Bool

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !isRunning)) { context in
            let current = progress(context.date)
            HStack(spacing: DS.Spacing.xs) {
                ForEach(0..<count, id: \.self) { index in
                    Button {
                        part = index
                    } label: {
                        Capsule()
                            .fill(Color.primary.opacity(0.15))
                            .frame(height: 4)
                            .overlay(alignment: .leading) {
                                GeometryReader { proxy in
                                    Capsule()
                                        .fill(theme.accent)
                                        .frame(width: proxy.size.width * WelcomeShowcaseLogic.segmentFill(
                                            at: index, current: part, progress: current))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.sm)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.PrimerosPasos23.partOf(index + 1, count))
                    .accessibilityAddTraits(index == part ? .isSelected : [])
                }
            }
        }
        // Cambiar de parte llena la anterior y vacía las siguientes en el acto, sin animarlo.
        .transaction { $0.animation = nil }
    }
}

/// Una página de partes con su botón fijo abajo.
struct TutorialStoryPage<Part: View, Footer: View>: View {
    let eyebrow: String
    let count: Int
    @Binding var part: Int
    /// Lo que dura cada parte antes de pasar sola a la siguiente.
    var partDuration: Duration = TutorialStoryLogic.partDuration
    /// `false`: solo avanza al tocar (el paso 7, opción B de Jürgen del 20-nov-2026: «la historia no puede avanzar sola
    /// mientras se mira el ejemplo»). La de ahora se ve llena.
    var autoAdvances: Bool = true
    /// El botón de arriba a la izquierda: «‹» (Atrás) en las intros; «✕» (Cerrar) en las historias del paso 7.
    var backSystemImage: String = "chevron.left"
    var backLabel: String = L10n.Action.back
    /// Tocar a la derecha (o «Siguiente» de VoiceOver) en la última parte. `nil`: no hace nada, como hasta ahora.
    var onAdvancePastLast: (() -> Void)?
    /// Un botón de texto arriba a la derecha en la última parte («Terminar»), para quien no adivina el toque.
    var lastPartTrailingTitle: String?
    let onBack: () -> Void
    @ViewBuilder let content: (Int) -> Part
    @ViewBuilder let footer: () -> Footer

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.layoutDirection) private var layoutDirection

    /// El dedo está puesto sobre la parte: la barra se queda donde está.
    @State private var paused = false
    /// Cuándo se puso el dedo por última vez: un toque que llega tras mantenerlo no cambia de parte.
    @State private var pressedAt: Date?
    /// El reloj de la parte de ahora: guarda lo que ya corrió para que la pausa no la reinicie.
    @State private var clock = WelcomeShowcaseLogic.StoryClock()
    /// La parte a la que pertenece `clock`. El temporizador lo rehace él mismo al ver otra parte: rehecho en un
    /// `onChange(of: part)`, el temporizador de la parte nueva arrancaba a veces con el reloj agotado de la anterior y se
    /// saltaba una parte entera (medido el 2026-11-20 en el simulador: de la 1 a la 3).
    @State private var clockPart = -1
    /// El ancho de la zona que se toca, para saber en qué mitad cayó el dedo.
    @State private var stageWidth: CGFloat = 0
    /// El alto que el scroll deja ver: la zona que se toca llega hasta el botón aunque el contenido sea corto.
    @State private var stageMinHeight: CGFloat = 0

    private var canRun: Bool { autoAdvances && !reduceMotion && !voiceOver }

    private var runs: Bool {
        autoAdvances && TutorialStoryLogic.advancesAutomatically(part: part, count: count, reduceMotion: reduceMotion,
                                                                 voiceOver: voiceOver, paused: paused)
    }

    private var isLastPart: Bool { part >= count - 1 }

    private var dwell: TimeInterval { TutorialStoryLogic.seconds(partDuration) }

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack {
                YalaToolbarButton(systemName: backSystemImage, label: backLabel, action: onBack)
                    .accessibilityIdentifier("tutorial_story_back")
                Spacer()
                Text(eyebrow)
                    .font(DS.Typography.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("tutorial_story_eyebrow")
                Spacer()
                if let lastPartTrailingTitle, isLastPart, let onAdvancePastLast {
                    Button(lastPartTrailingTitle, action: onAdvancePastLast)
                        .font(DS.Typography.subheadline.weight(.semibold))
                        .foregroundStyle(.thAccentText)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityIdentifier("tutorial_story_finish")
                } else {
                    Color.clear.frame(width: 44, height: 44)
                }
            }
            TutorialStorySegments(
                count: count,
                part: $part,
                progress: { date in
                    // Sin avance solo, la de ahora va llena; en la última, también (no hay a dónde pasar).
                    guard canRun && part < count - 1 else { return 1 }
                    return clockPart == part ? clock.progress(at: date, dwell: dwell) : 0
                },
                isRunning: runs
            )
            ScrollView {
                content(part)
                    .id(part)
                    .transition(.opacity)
                    // Toda la zona entre las rayitas y el botón escucha el gesto, haya contenido o no.
                    .frame(maxWidth: .infinity, minHeight: stageMinHeight, alignment: .topLeading)
                    .contentShape(Rectangle())
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { stageWidth = $0 }
                    // Como las historias: la mitad derecha avanza y la izquierda vuelve; mantener el dedo pausa. Los
                    // botones de dentro (si los hay) ganan su toque.
                    .onTapGesture(coordinateSpace: .local) { location in
                        let held = TutorialStoryLogic.wasAHold(pressedAt: pressedAt, now: .now)
                        pressedAt = nil
                        guard !held else { return }
                        let step = WelcomeShowcaseLogic.tapStep(
                            atX: location.x, width: stageWidth, rightToLeft: layoutDirection == .rightToLeft)
                        if step > 0, isLastPart, let onAdvancePastLast {
                            onAdvancePastLast()
                            return
                        }
                        move(to: TutorialStoryLogic.stepped(part: part, by: step, count: count))
                    }
                    // Duración infinita: el gesto nunca se completa y avisa al levantar el dedo. Con una duración
                    // finita, al completarse ya no avisaba del «soltar» y la historia se quedaba en pausa (medido en
                    // XCUITest el 2026-11-20).
                    .onLongPressGesture(minimumDuration: .infinity, maximumDistance: 24, perform: {},
                                        onPressingChanged: { pressing in
                                            if pressing { pressedAt = .now }
                                            paused = pressing
                                        })
                    .accessibilityAction(named: L10n.TipKit.next) {
                        if isLastPart, let onAdvancePastLast {
                            onAdvancePastLast()
                        } else {
                            move(to: TutorialStoryLogic.tapped(part: part, count: count))
                        }
                    }
                    .accessibilityIdentifier("tutorial_story_stage")
            }
            .scrollBounceBehavior(.basedOnSize)
            // El alto del propio scroll, menos lo que tapan las barras. `onScrollGeometryChange` no avisaba al aparecer
            // y la zona se quedaba del alto del contenido (medido en el simulador el 2026-11-25).
            .onGeometryChange(for: CGFloat.self) { proxy in
                TutorialStoryLogic.stageMinHeight(containerHeight: proxy.size.height,
                                                  topInset: proxy.safeAreaInsets.top,
                                                  bottomInset: proxy.safeAreaInsets.bottom)
            } action: { height in
                stageMinHeight = height
            }
            .animation(reduceMotion ? nil : DS.Animation.appear, value: part)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .safeAreaBar(edge: .bottom, spacing: DS.Spacing.sm) {
            footer()
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.md)
        }
        // Una parte nueva rearma el reloj desde cero; la pausa lo congela y al soltar sigue con lo que le quedaba.
        .task(id: TimerKey(part: part, runs: runs)) {
            guard runs else { return }
            if clockPart != part {
                clock = .started(at: .now, running: true)
                clockPart = part
            } else if !clock.isRunning {
                clock.resume(at: .now)
            }
            do { try await Task.sleep(for: .seconds(clock.remaining(at: .now, dwell: dwell))) } catch { return }
            move(to: TutorialStoryLogic.tapped(part: part, count: count))
        }
        .onChange(of: paused) { _, nowPaused in
            if nowPaused { clock.pause(at: .now) } else if canRun && clockPart == part { clock.resume(at: .now) }
        }
    }

    private func move(to next: Int) {
        guard next != part else { return }
        part = next
    }

    private struct TimerKey: Equatable {
        let part: Int
        let runs: Bool
    }
}

extension View {
    /// Los botones principales de Primeros pasos (`YalaPrimaryButton`, alto fijo) con su texto topado en el primer
    /// tamaño de accesibilidad: más grande, «Crear mi primera cuenta» se cortaba (ficha: el texto grande no corta). Con
    /// el visor de contenido grande de iOS, mantener pulsado lo lee entero.
    func primerosPasosButtonText() -> some View {
        dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .accessibilityShowsLargeContentViewer()
    }
}

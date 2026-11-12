//
//  TutorialStoryPage.swift
//  Yala
//
//  La página corta de Primeros pasos (patrón E2 del prototipo oficial v35): unas pocas partes que avanzan solas cada
//  3,4 s con una barra de segmentos arriba, y un botón fijo abajo. La usan «qué son las cuentas» (Y23-07, tres partes)
//  y «Cuatro maneras de anotar» (Y23-08, cuatro). Accesibilidad de la ficha: con Reducir movimiento o VoiceOver no
//  avanza sola y solo se funde; tocar la parte (o un segmento) pasa a la siguiente.
//

import SwiftUI

/// Cuándo pasa sola a la siguiente parte.
nonisolated enum TutorialStoryLogic {
    /// Lo que dura cada parte (ficha: 3,4 s).
    static let partDuration: Duration = .milliseconds(3400)

    /// Si la página avanza sola: nunca con Reducir movimiento ni con VoiceOver, y nunca desde la última parte.
    static func advancesAutomatically(part: Int, count: Int, reduceMotion: Bool, voiceOver: Bool) -> Bool {
        !reduceMotion && !voiceOver && part < count - 1
    }

    /// La parte que sigue al tocar: la siguiente, sin pasar de la última.
    static func tapped(part: Int, count: Int) -> Int {
        min(count - 1, part + 1)
    }
}

/// La barra de segmentos: hechos, el de ahora (que se llena mientras dura) y los que faltan.
struct TutorialStorySegments: View {
    let count: Int
    @Binding var part: Int
    let isRunning: Bool

    @Environment(\.yalaTheme) private var theme

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(0..<count, id: \.self) { index in
                Button {
                    part = index
                } label: {
                    Capsule()
                        .fill(Color.primary.opacity(0.15))
                        .frame(height: 4)
                        .overlay(alignment: .leading) {
                            if index == part && isRunning {
                                // El de ahora se llena mientras dura la parte.
                                SegmentRunningFill(color: theme.accent).id(part)
                            } else if index <= part {
                                Capsule().fill(theme.accent)
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
}

/// El relleno del segmento de ahora: de cero a lleno en lo que dura la parte. Solo existe mientras la página avanza sola
/// (sin Reducir movimiento ni VoiceOver).
private struct SegmentRunningFill: View {
    let color: Color
    @State private var filled = false

    var body: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(color)
                .frame(width: filled ? proxy.size.width : 0)
                .animation(.linear(duration: 3.4), value: filled)
        }
        .onAppear { filled = true }
    }
}

/// Una página de partes con su botón fijo abajo.
struct TutorialStoryPage<Part: View, Footer: View>: View {
    let eyebrow: String
    let count: Int
    @Binding var part: Int
    let onBack: () -> Void
    @ViewBuilder let content: (Int) -> Part
    @ViewBuilder let footer: () -> Footer

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    private var runs: Bool {
        TutorialStoryLogic.advancesAutomatically(part: part, count: count, reduceMotion: reduceMotion, voiceOver: voiceOver)
    }

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack {
                YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back, action: onBack)
                    .accessibilityIdentifier("tutorial_story_back")
                Spacer()
                Text(eyebrow)
                    .font(DS.Typography.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            TutorialStorySegments(count: count, part: $part, isRunning: runs)
            ScrollView {
                content(part)
                    .id(part)
                    .transition(.opacity)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { part = TutorialStoryLogic.tapped(part: part, count: count) }
                    .accessibilityAction(named: L10n.TipKit.next) {
                        part = TutorialStoryLogic.tapped(part: part, count: count)
                    }
            }
            .scrollBounceBehavior(.basedOnSize)
            .animation(reduceMotion ? nil : DS.Animation.appear, value: part)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .safeAreaBar(edge: .bottom, spacing: DS.Spacing.sm) {
            footer()
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.md)
        }
        // Una parte nueva rearma el reloj; con VoiceOver o Reducir movimiento no corre.
        .task(id: TimerKey(part: part, runs: runs)) {
            guard runs else { return }
            do { try await Task.sleep(for: TutorialStoryLogic.partDuration) } catch { return }
            part = TutorialStoryLogic.tapped(part: part, count: count)
        }
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

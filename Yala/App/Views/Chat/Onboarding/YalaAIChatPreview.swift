//
//  YalaAIChatPreview.swift
//  Yala
//
//  Animación dummy del chat para Step 1 del onboarding de Yala AI.
//  Loop infinito: bubble user → typing dots → bubble bot → card transacción → fade-out.
//
//  Reutiliza componentes reales (`ChatMessageBubble`, `ChatLoadingIndicator`) con
//  `ChatMessage` struct mockeado (Codable, no SwiftData), para que la animación
//  se vea idéntica al chat real al que el user va a entrar después.
//
//  - Delay inicial 800ms permite leer título antes de empezar la primera iteración.
//  - VoiceOver activo: pausa total en estado final visible.
//  - Reduce Motion: solo fades, sin slides/typing dots animados.
//  - Cancel safety: animation task cancelado en `.onDisappear`.
//

import SwiftUI

struct YalaAIChatPreview: View {

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var phase: AnimationPhase = .idle
    @State private var animationTask: Task<Void, Never>?

    @State private var userMessage: ChatMessage?
    @State private var botMessage: ChatMessage?

    /// Fases de la iteración. Cada fase controla qué subviews son visibles + transitions.
    private enum AnimationPhase: Int, CaseIterable {
        case idle           // 0.0–0.8s — pantalla vacía (deja leer título)
        case userVisible    // 0.8–1.6s — bubble user entra slide+fade desde la derecha
        case typing         // 1.6–2.6s — typing dots (3 dots animados)
        case botVisible     // 2.6–3.4s — bubble bot entra slide+fade desde la izquierda
        case cardVisible    // 3.4–5.0s — draft preview card slide-up
        case fadeOut        // 5.0–5.5s — fade general antes del loop
    }

    private static let initialDelay: Duration = .milliseconds(800)
    private static let phaseDelays: [AnimationPhase: Duration] = [
        .userVisible: .milliseconds(800),
        .typing: .milliseconds(1000),
        .botVisible: .milliseconds(800),
        .cardVisible: .milliseconds(1600),
        .fadeOut: .milliseconds(500)
    ]

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            if let userMessage, phase.rawValue >= AnimationPhase.userVisible.rawValue {
                ChatMessageBubble(message: userMessage, viewModel: nil)
                    .transition(reduceMotion
                        ? .opacity
                        : .asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
            }

            if phase == .typing {
                ChatLoadingIndicator()
                    .transition(.opacity)
            }

            if let botMessage, phase.rawValue >= AnimationPhase.botVisible.rawValue {
                ChatMessageBubble(message: botMessage, viewModel: nil)
                    .transition(reduceMotion
                        ? .opacity
                        : .asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
            }

            if phase.rawValue >= AnimationPhase.cardVisible.rawValue {
                ChatDraftPreviewCard()
                    .transition(reduceMotion
                        ? .opacity
                        : .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
            }

            Spacer(minLength: 0)
        }
        .opacity(phase == .fadeOut ? 0 : 1)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: phase)
        .frame(maxWidth: .infinity, alignment: .top)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.YalaAI.Onboarding.step1A11yLabel)
        .task {
            if userMessage == nil {
                userMessage = ChatMessage(
                    role: .user,
                    text: L10n.YalaAI.Onboarding.step1DemoUserMessage,
                    timestamp: .now
                )
                botMessage = ChatMessage(
                    role: .assistant,
                    text: L10n.YalaAI.Onboarding.step1DemoBotMessage,
                    timestamp: .now
                )
            }
            startAnimation()
        }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
        }
    }

    // MARK: - Animation loop

    private func startAnimation() {
        animationTask?.cancel()
        animationTask = Task { @MainActor in
            // Pausa total con VoiceOver: muestra estado final completo, deja al
            // user explorar con el cursor sin interrupciones.
            if voiceOverEnabled {
                phase = .cardVisible
                return
            }

            // Delay inicial — deja leer título y subtítulo antes de la primera
            // iteración. Sin esto la animación compite con la lectura.
            try? await Task.sleep(for: Self.initialDelay)
            guard !Task.isCancelled else { return }

            while !Task.isCancelled {
                for nextPhase in AnimationPhase.allCases.dropFirst() {
                    guard !Task.isCancelled else { return }
                    phase = nextPhase
                    if let delay = Self.phaseDelays[nextPhase] {
                        try? await Task.sleep(for: delay)
                    }
                }
                guard !Task.isCancelled else { return }
                phase = .idle  // reset para siguiente loop (estado oculto)
                try? await Task.sleep(for: .milliseconds(400))
            }
        }
    }
}

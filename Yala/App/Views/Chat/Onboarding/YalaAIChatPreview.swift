//
//  YalaAIChatPreview.swift
//  Yala
//
//  Animación dummy del chat para Step 1 del onboarding de Yala AI.
//  Loop infinito que rota 3 escenarios (registrar / preguntar / sugerencia)
//  con crossfade entre iteraciones para evitar parpadeo.
//
//  - VoiceOver activo: pausa total con scenario 1 en estado final visible.
//  - Reduce Motion: solo fades, sin slides ni typing dots animados.
//  - Cancel safety: animation task cancelado en `.onDisappear`.
//

import SwiftUI

struct YalaAIChatPreview: View {

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var stage: Stage = .userVisible
    @State private var scenarioIndex: Int = 0
    @State private var scenarios: [Scenario] = []
    @State private var animationTask: Task<Void, Never>?

    /// Una conversación completa user→bot, con card opcional. `ChatMessage` se cachea
    /// junto con el scenario para evitar reconstruir UUIDs/timestamps en cada render.
    private struct Scenario {
        let userMessage: ChatMessage
        let botMessage: ChatMessage
        let showsCard: Bool
    }

    private enum Stage: Int {
        case userVisible
        case typing
        case botVisible
        case cardVisible
        case holding

        /// Delay tras entrar en el stage. `cardVisible` y `holding` se manejan en el
        /// loop con duraciones propias (la card tarda más en ser apreciada; el holding
        /// depende de si el scenario tuvo card o no).
        var delay: Duration {
            switch self {
            case .userVisible: .milliseconds(900)
            case .typing:      .milliseconds(1000)
            case .botVisible:  .milliseconds(800)
            case .cardVisible: .milliseconds(1600)
            case .holding:     .zero
            }
        }
    }

    private static let holdDelayWithCard: Duration = .milliseconds(1500)
    private static let holdDelayBubblesOnly: Duration = .milliseconds(1300)
    /// Crossfade entre el final de un scenario y el inicio del siguiente.
    private static let crossfadeDuration: Duration = .milliseconds(350)

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            if let scenario = scenarios[safe: scenarioIndex] {
                if stage.rawValue >= Stage.userVisible.rawValue {
                    ChatMessageBubble(message: scenario.userMessage, viewModel: nil)
                        .id("user-\(scenarioIndex)")
                        .transition(bubbleTransition(fromTrailing: true))
                }

                if stage == .typing {
                    ChatLoadingIndicator()
                        .transition(.opacity)
                }

                if stage.rawValue >= Stage.botVisible.rawValue {
                    ChatMessageBubble(message: scenario.botMessage, viewModel: nil)
                        .id("bot-\(scenarioIndex)")
                        .transition(bubbleTransition(fromTrailing: false))
                }

                if scenario.showsCard, stage.rawValue >= Stage.cardVisible.rawValue {
                    ChatDraftPreviewCard()
                        .id("card-\(scenarioIndex)")
                        .transition(reduceMotion
                            ? .opacity
                            : .asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            )
                        )
                }
            }

            Spacer(minLength: 0)
        }
        // Un único modifier con tuple (stage, scenarioIndex) cubre tanto las
        // transiciones internas del scenario como el crossfade entre scenarios.
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: AnimationKey(stage: stage, scenarioIndex: scenarioIndex))
        .frame(maxWidth: .infinity, alignment: .top)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.YalaAI.Onboarding.step1A11yLabel)
        .task {
            if scenarios.isEmpty {
                scenarios = Self.makeScenarios()
            }
            startAnimation()
        }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
        }
    }

    private struct AnimationKey: Equatable {
        let stage: Stage
        let scenarioIndex: Int
    }

    private static func makeScenarios() -> [Scenario] {
        [
            Scenario(
                userMessage: ChatMessage(role: .user, text: L10n.YalaAI.Onboarding.step1DemoScenario1User, timestamp: .now),
                botMessage: ChatMessage(role: .assistant, text: L10n.YalaAI.Onboarding.step1DemoScenario1Bot, timestamp: .now),
                showsCard: true
            ),
            Scenario(
                userMessage: ChatMessage(role: .user, text: L10n.YalaAI.Onboarding.step1DemoScenario2User, timestamp: .now),
                botMessage: ChatMessage(role: .assistant, text: L10n.YalaAI.Onboarding.step1DemoScenario2Bot, timestamp: .now),
                showsCard: false
            ),
            Scenario(
                userMessage: ChatMessage(role: .user, text: L10n.YalaAI.Onboarding.step1DemoScenario3User, timestamp: .now),
                botMessage: ChatMessage(role: .assistant, text: L10n.YalaAI.Onboarding.step1DemoScenario3Bot, timestamp: .now),
                showsCard: false
            )
        ]
    }

    private func bubbleTransition(fromTrailing: Bool) -> AnyTransition {
        if reduceMotion { return .opacity }
        let edge: Edge = fromTrailing ? .trailing : .leading
        return .asymmetric(
            insertion: .move(edge: edge).combined(with: .opacity),
            removal: .opacity
        )
    }

    private func startAnimation() {
        animationTask?.cancel()
        animationTask = Task { @MainActor in
            // VoiceOver: estado final visible del scenario 1 (con card), sin loop —
            // permite al user explorar con el cursor sin que la animación cambie debajo.
            if voiceOverEnabled {
                stage = .cardVisible
                return
            }

            while !Task.isCancelled {
                guard let scenario = scenarios[safe: scenarioIndex] else { return }

                stage = .userVisible
                try? await Task.sleep(for: Stage.userVisible.delay)
                guard !Task.isCancelled else { return }

                stage = .typing
                try? await Task.sleep(for: Stage.typing.delay)
                guard !Task.isCancelled else { return }

                stage = .botVisible
                try? await Task.sleep(for: Stage.botVisible.delay)
                guard !Task.isCancelled else { return }

                if scenario.showsCard {
                    stage = .cardVisible
                    try? await Task.sleep(for: Stage.cardVisible.delay)
                    guard !Task.isCancelled else { return }
                }

                stage = .holding
                try? await Task.sleep(for: scenario.showsCard ? Self.holdDelayWithCard : Self.holdDelayBubblesOnly)
                guard !Task.isCancelled else { return }

                // Avance al siguiente scenario: el cambio de scenarioIndex desmonta los
                // bubbles vía `.id` mientras los nuevos entran. Sin gap intermedio —
                // ambas transiciones corren simultáneas.
                scenarioIndex = (scenarioIndex + 1) % scenarios.count
                stage = .userVisible
                try? await Task.sleep(for: Self.crossfadeDuration)
            }
        }
    }
}

// MARK: - Helpers

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

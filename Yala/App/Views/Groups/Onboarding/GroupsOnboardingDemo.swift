//
//  GroupsOnboardingDemo.swift
//  Yala
//
//  Animación loop infinito para el Step 1 del onboarding de Grupos.
//  Replica el patrón técnico de `YalaAIChatPreview`:
//   - `Task<Void, Never>` cancelable en `.onDisappear`.
//   - VoiceOver activo: salta a estado final visible, sin loop.
//   - Reduce Motion: solo fades, sin spring/slide.
//
//  Stages (~5s ciclo):
//   1. `.cardInitial` (1.0s) — solo card con "Saldo: S/ 0".
//   2. `.notifVisible` (1.5s) — notif baja desde top con spring.
//   3. `.balanceChanged` (1.5s) — balance transiciona a "Debes S/ 25".
//   4. `.holding` (1.0s) — estado final visible.
//   5. Crossfade 350ms → reset.
//

import SwiftUI

struct GroupsOnboardingDemo: View {

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var stage: Stage = .cardInitial
    @State private var animationTask: Task<Void, Never>?

    private enum Stage: Int {
        case cardInitial
        case notifVisible
        case balanceChanged
        case holding

        var delay: Duration {
            switch self {
            case .cardInitial:    .milliseconds(1000)
            case .notifVisible:   .milliseconds(1500)
            case .balanceChanged: .milliseconds(1500)
            case .holding:        .milliseconds(1000)
            }
        }
    }

    private static let crossfadeDuration: Duration = .milliseconds(350)

    private var currencyCode: String { appPreferences.defaultCurrencyCode.rawValue }
    private var memberName: String { L10n.Groups.Onboarding.step1DemoMemberName }
    private var groupName: String { L10n.Groups.Onboarding.step1DemoGroupName }
    private var formattedFifty: String { appPreferences.currency(50, currencyCode: currencyCode) }
    private var formattedTwentyFive: String { appPreferences.currency(25, currencyCode: currencyCode) }

    private var showsNotif: Bool {
        stage == .notifVisible || stage == .balanceChanged || stage == .holding
    }

    private var balanceState: OnboardingDemoBalanceState {
        (stage == .balanceChanged || stage == .holding) ? .debt : .initial
    }

    private var displayedBalance: Double {
        balanceState == .debt ? 25 : 0
    }

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            if showsNotif {
                OnboardingDemoNotificationBubble(
                    memberName: memberName,
                    formattedAmount: formattedFifty,
                    groupName: groupName
                )
                .transition(notifTransition)
            }

            OnboardingDemoGroupCard(
                balance: displayedBalance,
                currencyCode: currencyCode,
                state: balanceState
            )

            Spacer(minLength: 0)
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.35) : .smooth(duration: 0.45), value: stage)
        .frame(maxWidth: .infinity, alignment: .top)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(a11yLabel)
        .task {
            startAnimation()
        }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
        }
    }

    private var notifTransition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .opacity
        )
    }

    private var a11yLabel: String {
        String(format: L10n.Groups.Onboarding.step1A11yLabelTemplate,
               memberName, formattedFifty, groupName, formattedTwentyFive)
    }

    private func startAnimation() {
        animationTask?.cancel()
        animationTask = Task { @MainActor in
            // VoiceOver: estado final visible (notif + balance debt), sin loop —
            // permite al user explorar con el cursor sin que la animación cambie debajo.
            if voiceOverEnabled {
                stage = .balanceChanged
                return
            }

            while !Task.isCancelled {
                stage = .cardInitial
                try? await Task.sleep(for: Stage.cardInitial.delay)
                guard !Task.isCancelled else { return }

                stage = .notifVisible
                try? await Task.sleep(for: Stage.notifVisible.delay)
                guard !Task.isCancelled else { return }

                stage = .balanceChanged
                try? await Task.sleep(for: Stage.balanceChanged.delay)
                guard !Task.isCancelled else { return }

                stage = .holding
                try? await Task.sleep(for: Stage.holding.delay)
                guard !Task.isCancelled else { return }

                // Crossfade al siguiente ciclo (vuelve a .cardInitial al inicio del loop).
                try? await Task.sleep(for: Self.crossfadeDuration)
            }
        }
    }
}

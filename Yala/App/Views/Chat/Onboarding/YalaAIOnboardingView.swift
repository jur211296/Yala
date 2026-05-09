//
//  YalaAIOnboardingView.swift
//  Yala
//
//  Onboarding 4-pasos para Yala AI, mostrado una sola vez post-consent y antes
//  del primer ChatSheetView. Inspirado en Oura Advisor (cards de selección con
//  preview en vivo del tono, CTA pill, indicador de paso) adaptado al sistema
//  liquid glass + 9 temas de Yala.
//
//  Steps:
//    1. Hero con demo animada del chat (loop infinito)
//    2. Qué puedes hacer (3 cards reales)
//    3. Personaliza tono y estilo (selectors con preview)
//    4. Listo (CTA "Empezar a chatear")
//
//  Comportamiento de cierre:
//    - onComplete: tap CTA Step 4 → callback al launcher (que abre ChatSheet vía onDismiss)
//    - onSkip:     tap "Saltar" steps 1-3 → flag persistida, no abre chat
//    - onClose:    tap "X" topLeft cualquier step → flag NO persistida (vuelve a aparecer)
//

import SwiftUI

struct YalaAIOnboardingView: View {

    let launcher: YalaAIOnboardingLauncher
    var onResult: (YalaAIOnboardingResult) -> Void

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var currentStep: Step = .hero

    private enum Step: Int, CaseIterable {
        case hero = 1
        case capabilities = 2
        case personalize = 3
        case ready = 4

        var totalSteps: Int { Step.allCases.count }
    }

    var body: some View {
        ZStack {
            PanelBackgroundView()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.md)

                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, DS.Spacing.lg)

                ctaSection
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.xl)
            }
        }
        .onAppear {
            TelemetryService.track(.yalaAIOnboardingShown, parameters: ["launcher": launcher.rawValue])
        }
    }

    // MARK: - Header (close + step indicator + skip)

    private var header: some View {
        HStack {
            Button(action: { onResult(.close) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold)) // A11Y-DT: dismiss icon
                    .foregroundStyle(.thPrimaryText)
                    .frame(width: 32, height: 32) // A11Y-DT: tap target
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.YalaAI.Onboarding.close)

            Spacer()

            Text(L10n.YalaAI.Onboarding.stepIndicator(currentStep.rawValue, currentStep.totalSteps))
                .font(DS.Typography.caption)
                .foregroundStyle(.thSecondaryText)
                .accessibilityLabel("Paso \(currentStep.rawValue) de \(currentStep.totalSteps)")

            Spacer()

            if currentStep != .ready {
                Button {
                    TelemetryService.track(.yalaAIOnboardingSkipped, parameters: [
                        "launcher": launcher.rawValue,
                        "step": String(currentStep.rawValue)
                    ])
                    onResult(.skip)
                } label: {
                    Text(L10n.YalaAI.Onboarding.skip)
                        .font(DS.Typography.label)
                        .foregroundStyle(.thPrimaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.YalaAI.Onboarding.skip)
            } else {
                // Mantener simetría visual cuando no hay skip.
                Color.clear.frame(width: 32, height: 32)
            }
        }
    }

    // MARK: - Step content (switch transition)

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .hero:
            heroStep
        case .capabilities:
            capabilitiesStep
        case .personalize:
            personalizeStep
        case .ready:
            readyStep
        }
    }

    // MARK: - Step 1: Hero

    private var heroStep: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer(minLength: DS.Spacing.md)

            YalaAIChatPreview()
                .frame(maxHeight: 280)

            VStack(spacing: DS.Spacing.sm) {
                Text(L10n.YalaAI.Onboarding.step1Title)
                    .font(DS.Typography.largeTitle)
                    .foregroundStyle(.thPrimaryText)
                    .multilineTextAlignment(.center)

                Text(L10n.YalaAI.Onboarding.step1Subtitle)
                    .font(DS.Typography.body)
                    .foregroundStyle(.thSecondaryText)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)
            .padding(.horizontal, DS.Spacing.md)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Step 2: Capabilities

    private var capabilitiesStep: some View {
        VStack(spacing: DS.Spacing.lg) {
            VStack(spacing: DS.Spacing.sm) {
                Text(L10n.YalaAI.Onboarding.step2Title)
                    .font(DS.Typography.largeTitle)
                    .foregroundStyle(.thPrimaryText)
                    .multilineTextAlignment(.center)

                Text(L10n.YalaAI.Onboarding.step2Subtitle)
                    .font(DS.Typography.body)
                    .foregroundStyle(.thSecondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, DS.Spacing.md)

            VStack(spacing: DS.Spacing.md) {
                capabilityCard(
                    icon: "mic.fill",
                    iconColor: .hotPink,
                    title: L10n.YalaAI.Onboarding.step2Card1Title,
                    body: L10n.YalaAI.Onboarding.step2Card1Body,
                    badge: L10n.YalaAI.Onboarding.step2Card1Badge
                )
                capabilityCard(
                    icon: "bubble.left.and.bubble.right.fill",
                    iconColor: theme.accent,
                    title: L10n.YalaAI.Onboarding.step2Card2Title,
                    body: L10n.YalaAI.Onboarding.step2Card2Body,
                    badge: nil
                )
                capabilityCard(
                    icon: "lightbulb.fill",
                    iconColor: .essentialNeed,
                    title: L10n.YalaAI.Onboarding.step2Card3Title,
                    body: L10n.YalaAI.Onboarding.step2Card3Body,
                    badge: nil
                )
            }

            Spacer(minLength: 0)
        }
    }

    private func capabilityCard(icon: String, iconColor: Color, title: String, body: String, badge: String?) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(iconColor.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold)) // A11Y-DT: card icon
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(spacing: DS.Spacing.sm) {
                    Text(title)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.thPrimaryText)
                    if let badge {
                        Text(badge)
                            .font(DS.Typography.captionSmall.weight(.semibold))
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, 2)
                            .background(Color.essentialNeed.opacity(0.22))
                            .foregroundStyle(Color.essentialNeed)
                            .clipShape(Capsule())
                    }
                }
                Text(body)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.thSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .solidCard(padding: 0, radius: DS.Radius.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(body)")
    }

    // MARK: - Step 3: Personalize

    private var personalizeStep: some View {
        @Bindable var prefs = appPreferences

        return ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                VStack(spacing: DS.Spacing.sm) {
                    Text(L10n.YalaAI.Onboarding.step3Title)
                        .font(DS.Typography.largeTitle)
                        .foregroundStyle(.thPrimaryText)
                        .multilineTextAlignment(.center)

                    Text(L10n.YalaAI.Onboarding.step3Subtitle)
                        .font(DS.Typography.body)
                        .foregroundStyle(.thSecondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, DS.Spacing.md)

                // Sección Tono
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text(L10n.YalaAI.Onboarding.step3ToneSection)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.thPrimaryText)

                    ForEach(InsightTone.allCases) { tone in
                        toneCard(tone: tone, prefs: prefs)
                    }
                }

                // Sección Estilo
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text(L10n.YalaAI.Onboarding.step3FocusSection)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.thPrimaryText)

                    ForEach(InsightFocus.allCases) { focus in
                        focusCard(focus: focus, prefs: prefs)
                    }
                }

                // Preview
                previewBubble(tone: prefs.insightsTone)
                    .padding(.top, DS.Spacing.sm)
            }
        }
        .scrollIndicators(.hidden)
    }

    private func toneCard(tone: InsightTone, prefs: AppPreferences) -> some View {
        let isSelected = prefs.insightsTone == tone
        return Button {
            prefs.insightsTone = tone
            trackTonePicked(prefs: prefs)
        } label: {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(tone.displayName)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)
                Text(toneQuote(for: tone))
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.thSecondaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .stroke(isSelected ? theme.accent : theme.cardBorder, lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(L10n.YalaAI.Onboarding.step3ToneSection): \(tone.displayName)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func focusCard(focus: InsightFocus, prefs: AppPreferences) -> some View {
        let isSelected = prefs.insightsFocus == focus
        return Button {
            prefs.insightsFocus = focus
            trackTonePicked(prefs: prefs)
        } label: {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(focus.displayName)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)
                Text(focus.descriptionText)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.thSecondaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .stroke(isSelected ? theme.accent : theme.cardBorder, lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(L10n.YalaAI.Onboarding.step3FocusSection): \(focus.displayName)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func toneQuote(for tone: InsightTone) -> String {
        switch tone {
        case .normal:      return L10n.YalaAI.Onboarding.step3ToneNormalQuote
        case .considerate: return L10n.YalaAI.Onboarding.step3ToneConsiderateQuote
        case .sarcastic:   return L10n.YalaAI.Onboarding.step3ToneSarcasticQuote
        }
    }

    private func trackTonePicked(prefs: AppPreferences) {
        TelemetryService.track(.yalaAIOnboardingTonePicked, parameters: [
            "tone": prefs.insightsTone.rawValue,
            "focus": prefs.insightsFocus.rawValue,
            "launcher": launcher.rawValue
        ])
    }

    private func previewBubble(tone: InsightTone) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(L10n.YalaAI.Onboarding.step3PreviewLabel)
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.thSecondaryText)

            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold)) // A11Y-DT: bot avatar
                    .foregroundStyle(theme.accent)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(.thCard))

                Text(toneQuote(for: tone))
                    .font(DS.Typography.body)
                    .foregroundStyle(.thPrimaryText)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(.thCard)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                    .animation(.easeInOut(duration: 0.3), value: tone)
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Step 4: Ready

    private var readyStep: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer(minLength: DS.Spacing.xl)

            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.hotPink.opacity(0.25), theme.accent.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 96, height: 96)
                Image(systemName: "sparkles")
                    .font(.system(size: 44, weight: .semibold)) // A11Y-DT: hero icon
                    .foregroundStyle(LinearGradient(
                        colors: [.hotPink, theme.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            }
            .accessibilityHidden(true)

            VStack(spacing: DS.Spacing.sm) {
                Text(L10n.YalaAI.Onboarding.step4Title)
                    .font(DS.Typography.largeTitle)
                    .foregroundStyle(.thPrimaryText)
                    .multilineTextAlignment(.center)

                Text(L10n.YalaAI.Onboarding.step4Subtitle)
                    .font(DS.Typography.body)
                    .foregroundStyle(.thSecondaryText)
                    .multilineTextAlignment(.center)
            }

            Text(L10n.YalaAI.Onboarding.step4Tip)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.thSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.md)

            Spacer(minLength: 0)
        }
    }

    // MARK: - CTA

    private var ctaSection: some View {
        let label = currentStep == .ready
            ? L10n.YalaAI.Onboarding.step4CTA
            : L10n.YalaAI.Onboarding.continueAction

        return YalaPrimaryButton(label) {
            advance()
        }
    }

    private func advance() {
        if let next = Step(rawValue: currentStep.rawValue + 1) {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) {
                currentStep = next
            }
        } else {
            TelemetryService.track(.yalaAIOnboardingCompleted, parameters: [
                "launcher": launcher.rawValue,
                "tone": appPreferences.insightsTone.rawValue,
                "focus": appPreferences.insightsFocus.rawValue
            ])
            onResult(.complete)
        }
    }
}

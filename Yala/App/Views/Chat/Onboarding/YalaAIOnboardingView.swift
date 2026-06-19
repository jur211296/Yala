//
//  YalaAIOnboardingView.swift
//  Yala
//
//  Cierre:
//  - onResult(.complete): CTA Step 5 → launcher persiste flag + abre chat
//  - onResult(.close):    "X" topLeft → NO persiste flag (vuelve a aparecer)
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
        case tone = 3
        case focus = 4
        case ready = 5
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PanelBackgroundView()

                VStack(spacing: 0) {
                    stepContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, DS.Spacing.lg)

                    ctaSection
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.bottom, DS.Spacing.xl)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    leadingButton
                }
                ToolbarItem(placement: .principal) {
                    progressIndicator
                }
            }
        }
        .onAppear {
            TelemetryService.track(.yalaAIOnboardingShown, parameters: ["launcher": launcher.rawValue])
        }
    }

    @ViewBuilder
    private var leadingButton: some View {
        if currentStep == .hero {
            YalaToolbarButton(systemName: "xmark", label: L10n.YalaAI.Onboarding.close) {
                onResult(.close)
            }
        } else {
            YalaToolbarButton(systemName: "chevron.left", label: L10n.YalaAI.Onboarding.back) {
                goBack()
            }
        }
    }

    private var progressIndicator: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(Step.allCases, id: \.rawValue) { step in
                Capsule()
                    .fill(step.rawValue <= currentStep.rawValue ? Color.electricIndigo : theme.secondaryText.opacity(0.2))
                    .frame(width: step == currentStep ? 24 : 8, height: 8)
                    .dsAnimation(.spring(response: 0.3), value: currentStep, reduceMotion: reduceMotion)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.YalaAI.Onboarding.progressLabel(currentStep.rawValue, Step.allCases.count))
    }

    // MARK: - Step content (switch transition)

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .hero:         heroStep
        case .capabilities: capabilitiesStep
        case .tone:         toneStep
        case .focus:        focusStep
        case .ready:        readyStep
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
        VStack(spacing: DS.Spacing.xxl) {
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
            .padding(.top, DS.Spacing.xl)

            VStack(spacing: DS.Spacing.lg) {
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
                            .padding(.vertical, DS.Spacing.xxs)
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

    // MARK: - Step 3: Tone

    private var toneStep: some View {
        @Bindable var prefs = appPreferences

        return ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                stepHeader(
                    title: L10n.YalaAI.Onboarding.step3Title,
                    subtitle: L10n.YalaAI.Onboarding.step3Subtitle
                )

                VStack(spacing: DS.Spacing.md) {
                    ForEach(InsightTone.allCases) { tone in
                        toneCard(tone: tone, prefs: prefs)
                    }
                }

                previewBubble(text: toneQuote(for: prefs.insightsTone), animationKey: prefs.insightsTone)
                    .padding(.top, DS.Spacing.md)
            }
        }
        .scrollIndicators(.hidden)
    }

    private func toneCard(tone: InsightTone, prefs: AppPreferences) -> some View {
        let isSelected = prefs.insightsTone == tone
        return optionCard(
            isSelected: isSelected,
            title: tone.displayName,
            description: toneDescription(for: tone),
            a11yPrefix: L10n.YalaAI.Onboarding.step3Title
        ) {
            prefs.insightsTone = tone
            trackPersonalizationPicked(prefs: prefs)
        }
    }

    // MARK: - Step 4: Focus

    private var focusStep: some View {
        @Bindable var prefs = appPreferences

        return ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                stepHeader(
                    title: L10n.YalaAI.Onboarding.step4Title,
                    subtitle: L10n.YalaAI.Onboarding.step4Subtitle
                )

                VStack(spacing: DS.Spacing.md) {
                    ForEach(InsightFocus.allCases) { focus in
                        focusCard(focus: focus, prefs: prefs)
                    }
                }

                previewBubble(text: focusQuote(for: prefs.insightsFocus), animationKey: prefs.insightsFocus)
                    .padding(.top, DS.Spacing.md)
            }
        }
        .scrollIndicators(.hidden)
    }

    private func focusCard(focus: InsightFocus, prefs: AppPreferences) -> some View {
        let isSelected = prefs.insightsFocus == focus
        return optionCard(
            isSelected: isSelected,
            title: focus.displayName,
            description: focusDescription(for: focus),
            a11yPrefix: L10n.YalaAI.Onboarding.step4Title
        ) {
            prefs.insightsFocus = focus
            trackPersonalizationPicked(prefs: prefs)
        }
    }

    // MARK: - Step 5: Ready

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
                Text(L10n.YalaAI.Onboarding.step5Title)
                    .font(DS.Typography.largeTitle)
                    .foregroundStyle(.thPrimaryText)
                    .multilineTextAlignment(.center)

                Text(L10n.YalaAI.Onboarding.step5Subtitle)
                    .font(DS.Typography.body)
                    .foregroundStyle(.thSecondaryText)
                    .multilineTextAlignment(.center)
            }

            Text(L10n.YalaAI.Onboarding.step5Tip)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.thSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.md)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Shared subviews

    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(spacing: DS.Spacing.sm) {
            Text(title)
                .font(DS.Typography.largeTitle)
                .foregroundStyle(.thPrimaryText)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(DS.Typography.body)
                .foregroundStyle(.thSecondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.top, DS.Spacing.md)
    }

    private func optionCard(
        isSelected: Bool,
        title: String,
        description: String,
        a11yPrefix: String,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)
                Text(description)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.thSecondaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .selectableCard(isSelected: isSelected, radius: DS.Radius.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(a11yPrefix): \(title). \(description)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func previewBubble<Key: Equatable>(text: String, animationKey: Key) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(L10n.YalaAI.Onboarding.previewLabel)
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.thSecondaryText)

            HStack(alignment: .top, spacing: DS.Spacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold)) // A11Y-DT: bot avatar
                    .foregroundStyle(theme.accent)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(.thCard))

                Text(text)
                    .font(DS.Typography.body)
                    .foregroundStyle(.thPrimaryText)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(.thCard)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                    .animation(.easeInOut(duration: 0.3), value: animationKey)
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Quotes / descriptions

    private func toneQuote(for tone: InsightTone) -> String {
        switch tone {
        case .normal:      return L10n.YalaAI.Onboarding.step3ToneNormalQuote
        case .considerate: return L10n.YalaAI.Onboarding.step3ToneConsiderateQuote
        case .sarcastic:   return L10n.YalaAI.Onboarding.step3ToneSarcasticQuote
        }
    }

    private func toneDescription(for tone: InsightTone) -> String {
        switch tone {
        case .normal:      return L10n.YalaAI.Onboarding.step3ToneNormalDescription
        case .considerate: return L10n.YalaAI.Onboarding.step3ToneConsiderateDescription
        case .sarcastic:   return L10n.YalaAI.Onboarding.step3ToneSarcasticDescription
        }
    }

    private func focusQuote(for focus: InsightFocus) -> String {
        switch focus {
        case .balanced: return L10n.YalaAI.Onboarding.step4FocusBalancedQuote
        case .saver:    return L10n.YalaAI.Onboarding.step4FocusSaverQuote
        case .cautious: return L10n.YalaAI.Onboarding.step4FocusCautiousQuote
        }
    }

    private func focusDescription(for focus: InsightFocus) -> String {
        switch focus {
        case .balanced: return L10n.YalaAI.Onboarding.step4FocusBalancedDescription
        case .saver:    return L10n.YalaAI.Onboarding.step4FocusSaverDescription
        case .cautious: return L10n.YalaAI.Onboarding.step4FocusCautiousDescription
        }
    }

    private func trackPersonalizationPicked(prefs: AppPreferences) {
        TelemetryService.track(.yalaAIOnboardingTonePicked, parameters: [
            "tone": prefs.insightsTone.rawValue,
            "focus": prefs.insightsFocus.rawValue,
            "launcher": launcher.rawValue
        ])
    }

    // MARK: - CTA

    private var ctaSection: some View {
        let label = currentStep == .ready
            ? L10n.YalaAI.Onboarding.step5CTA
            : L10n.YalaAI.Onboarding.continueAction

        return YalaPrimaryButton(label) {
            advance()
        }
    }

    private func goBack() {
        guard let prev = Step(rawValue: currentStep.rawValue - 1) else { return }
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) {
            currentStep = prev
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

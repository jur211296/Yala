//
//  GroupsOnboardingView.swift
//  Yala
//
//  Onboarding informativo (3 steps) presentado al primer tap del tab Grupos.
//  Patrón análogo a YalaAIOnboardingView:
//   - "X" topLeft (step 1) → onResult(.close) — NO persiste flag.
//   - "‹" chevron back (steps 2-3) → goBack().
//   - CTA Step 3 "Ir a Grupos" → onResult(.complete) — persiste flag.
//
//  El CTA solo cierra el sheet; NO abre `GroupFormView`. El user queda en
//  `GroupsContainerView` con su empty state, que ya tiene CTA "Crear grupo".
//

import SwiftUI

struct GroupsOnboardingView: View {

    var onResult: (GroupsOnboardingResult) -> Void

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var currentStep: Step = .hero

    private enum Step: Int, CaseIterable {
        case hero = 1
        case capabilities = 2
        case privacy = 3
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
    }

    // MARK: - Toolbar

    @ViewBuilder
    private var leadingButton: some View {
        if currentStep == .hero {
            YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                onResult(.close)
            }
        } else {
            YalaToolbarButton(systemName: "chevron.left", label: L10n.Action.back) {
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
        .accessibilityLabel(
            String(format: L10n.Groups.Onboarding.progressLabel, currentStep.rawValue, Step.allCases.count)
        )
    }

    // MARK: - Step content

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .hero:         heroStep
        case .capabilities: capabilitiesStep
        case .privacy:      privacyStep
        }
    }

    // MARK: - Step 1: Hero animado

    private var heroStep: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer(minLength: DS.Spacing.md)

            GroupsOnboardingDemo()
                .frame(maxHeight: 280)

            VStack(spacing: DS.Spacing.sm) {
                Text(L10n.Groups.Onboarding.step1Title)
                    .font(DS.Typography.largeTitle)
                    .foregroundStyle(.thPrimaryText)
                    .multilineTextAlignment(.center)

                Text(L10n.Groups.Onboarding.step1Subtitle)
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
                Text(L10n.Groups.Onboarding.step2Title)
                    .font(DS.Typography.largeTitle)
                    .foregroundStyle(.thPrimaryText)
                    .multilineTextAlignment(.center)

                Text(L10n.Groups.Onboarding.step2Subtitle)
                    .font(DS.Typography.body)
                    .foregroundStyle(.thSecondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, DS.Spacing.xl)

            VStack(spacing: DS.Spacing.lg) {
                capabilityCard(
                    icon: "person.3.fill",
                    iconColor: .hotPink,
                    title: L10n.Groups.Onboarding.step2Card1Title,
                    body: L10n.Groups.Onboarding.step2Card1Body
                )
                capabilityCard(
                    icon: "creditcard.fill",
                    iconColor: theme.accent,
                    title: L10n.Groups.Onboarding.step2Card2Title,
                    body: L10n.Groups.Onboarding.step2Card2Body
                )

                // F6 awareness Perfil A: contar al user que el bridge crea TX real
                // automáticamente para que su saldo personal refleje los pagos de grupo.
                Text(L10n.Groups.Onboarding.step2BridgeAwareness)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.thSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.lg)
                capabilityCard(
                    icon: "arrow.left.arrow.right.circle.fill",
                    iconColor: .essentialNeed,
                    title: L10n.Groups.Onboarding.step2Card3Title,
                    body: L10n.Groups.Onboarding.step2Card3Body
                )
            }

            Spacer(minLength: 0)
        }
    }

    private func capabilityCard(icon: String, iconColor: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(iconColor.opacity(0.18))
                    .frame(width: DS.Button.actionSize, height: DS.Button.actionSize)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold)) // A11Y-DT: card icon
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(title)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)
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

    // MARK: - Step 3: Privacy + CTA

    private var privacyStep: some View {
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
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 44, weight: .semibold)) // A11Y-DT: hero icon
                    .foregroundStyle(LinearGradient(
                        colors: [.hotPink, theme.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            }
            .accessibilityHidden(true)

            VStack(spacing: DS.Spacing.sm) {
                Text(L10n.Groups.Onboarding.step3Title)
                    .font(DS.Typography.largeTitle)
                    .foregroundStyle(.thPrimaryText)
                    .multilineTextAlignment(.center)

                Text(L10n.Groups.Onboarding.step3Subtitle)
                    .font(DS.Typography.body)
                    .foregroundStyle(.thSecondaryText)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: DS.Spacing.md) {
                privacyPoint(icon: "icloud.fill", text: L10n.Groups.Onboarding.step3Point1)
                privacyPoint(icon: "lock.shield.fill", text: L10n.Groups.Onboarding.step3Point2)
            }
            .padding(.top, DS.Spacing.md)

            // F6 awareness: cierre Step 3 mencionando que el comportamiento del bridge
            // es configurable desde "Ajustes de Grupos".
            Text(L10n.Groups.Onboarding.step3BridgeAwareness)
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.thSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.md)

            Spacer(minLength: 0)
        }
    }

    private func privacyPoint(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold)) // A11Y-DT: bullet icon
                .foregroundStyle(theme.accent)
                .frame(width: 28)

            Text(text)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.thSecondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - CTA

    private var ctaSection: some View {
        let label = currentStep == .privacy
            ? L10n.Groups.Onboarding.step3CTA
            : L10n.Action.continueAction

        return YalaPrimaryButton(label) {
            advance()
        }
    }

    // MARK: - Navigation

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
            onResult(.complete)
        }
    }
}

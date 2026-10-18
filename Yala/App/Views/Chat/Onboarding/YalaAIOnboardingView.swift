//
//  YalaAIOnboardingView.swift
//  Yala
//
//  Cuatro pasos (UX 2.2 · lote 14, decisiones de Jürgen del 2026-10-15): qué es, qué hace, «Hazla a tu manera» (tono y
//  estilo juntos, L14-3) y «Antes de empezar» (el permiso de datos, L14-2). Antes eran cinco: tono y estilo iban en
//  pasos separados, el permiso salía en una alerta ANTES de la presentación y el último paso era «¡Todo listo!».
//
//  Cierre:
//  - onResult(.complete): «Aceptar y empezar» → la vista guarda el permiso; el launcher persiste la presentación y
//    abre el chat
//  - onResult(.close):    "X" topLeft → NO persiste nada (vuelve a aparecer, permiso incluido)
//

import SwiftUI

struct YalaAIOnboardingView: View {

    let launcher: YalaAIOnboardingLauncher
    var onResult: (YalaAIOnboardingResult) -> Void

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    @State private var currentStep: Step = .hero

    private enum Step: Int, CaseIterable {
        case hero = 1
        case capabilities = 2
        case personalize = 3
        case consent = 4
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
        case .personalize:  personalizeStep
        case .consent:      consentStep
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

    // MARK: - Step 3: Hazla a tu manera (UX 2.2 · L14-3, variante 3)

    /// Tono y estilo en un solo paso, con lo elegido RELLENO y un único ejemplo que junta las dos elecciones: es lo que
    /// se está eligiendo. Los nombres son los mismos que el usuario ve después en la hoja de ajustes del chat.
    private var personalizeStep: some View {
        @Bindable var prefs = appPreferences

        return ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                stepHeader(
                    title: L10n.UXL14.personalizeTitle,
                    subtitle: L10n.UXL14.personalizeSubtitle
                )
                .frame(maxWidth: .infinity)

                choiceGroup(
                    header: L10n.UXL14.toneHeader,
                    options: InsightTone.allCases.map { ($0, $0.displayName, $0.rawValue) },
                    selection: prefs.insightsTone,
                    description: toneDescription(for: prefs.insightsTone),
                    identifier: "yala_ai_onboarding_tone"
                ) { prefs.insightsTone = $0 }

                choiceGroup(
                    header: L10n.UXL14.focusHeader,
                    options: InsightFocus.allCases.map { ($0, $0.displayName, $0.rawValue) },
                    selection: prefs.insightsFocus,
                    description: focusDescription(for: prefs.insightsFocus),
                    identifier: "yala_ai_onboarding_focus"
                ) { prefs.insightsFocus = $0 }

                previewBubble(
                    text: combinedQuote(tone: prefs.insightsTone, focus: prefs.insightsFocus),
                    animationKey: "\(prefs.insightsTone.rawValue)-\(prefs.insightsFocus.rawValue)"
                )
                .padding(.top, DS.Spacing.sm)
            }
            .padding(.bottom, DS.Spacing.lg)
        }
        .scrollIndicators(.hidden)
    }

    /// Un rótulo, tres opciones en una cápsula (la elegida rellena de índigo con texto blanco) y la descripción de la
    /// elegida debajo. Con letra grande, las opciones se apilan en vez de cortarse.
    private func choiceGroup<Option: Hashable>(
        header: String,
        options: [(Option, String, String)],
        selection: Option,
        description: String,
        identifier: String,
        onSelect: @escaping (Option) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(header)
                .font(DS.Typography.headline)
                .foregroundStyle(.thPrimaryText)
                .accessibilityAddTraits(.isHeader)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: DS.Spacing.xxs) {
                    choiceButtons(header: header, options: options, selection: selection, identifier: identifier, onSelect: onSelect)
                }
                .padding(DS.Spacing.xxs)
                .background(Capsule().fill(.thCard))

                VStack(spacing: DS.Spacing.xxs) {
                    choiceButtons(header: header, options: options, selection: selection, identifier: identifier, onSelect: onSelect)
                }
                .padding(DS.Spacing.xxs)
                .background(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous).fill(.thCard))
            }

            Text(description)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.thSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .animation(.easeInOut(duration: 0.2), value: description)
        }
    }

    @ViewBuilder
    private func choiceButtons<Option: Hashable>(
        header: String,
        options: [(Option, String, String)],
        selection: Option,
        identifier: String,
        onSelect: @escaping (Option) -> Void
    ) -> some View {
        ForEach(Array(options.enumerated()), id: \.offset) { _, entry in
            let (option, title, key) = entry
            let isSelected = option == selection
            Button {
                DS.Haptic.selection()
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { onSelect(option) }
            } label: {
                Text(title)
                    .font(DS.Typography.label)
                    // A11Y-DM: blanco fijo sobre el relleno índigo de la opción elegida (4,6:1, AA).
                    .foregroundStyle(isSelected ? AnyShapeStyle(Color.white) : AnyShapeStyle(.thPrimaryText))
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, DS.Spacing.md)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Capsule().fill(isSelected ? Color.electricIndigo : Color.clear))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(header): \(title)")
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityIdentifier("\(identifier)_\(key)")
        }
    }

    // MARK: - Step 4: Antes de empezar (UX 2.2 · L14-2, variante 2)

    /// El permiso de datos, después de saber qué es Yala IA. Reparte en tres filas el mismo texto legal que decía el
    /// aviso (qué se envía, a quién y para qué), sin añadirle nada, y nombra el sitio real donde se apaga.
    private var consentStep: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xl) {
                stepHeader(
                    title: L10n.UXL14.consentTitle,
                    subtitle: L10n.UXL14.consentSubtitle
                )

                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    consentRow(
                        icon: "doc.text.magnifyingglass",
                        fill: .selectedIndigoFill,
                        title: L10n.UXL14.consentReadsTitle,
                        body: L10n.UXL14.consentReadsBody
                    )
                    consentRow(
                        icon: "checkmark.shield.fill",
                        fill: .incomeAmount,
                        title: L10n.UXL14.consentUseTitle,
                        body: L10n.UXL14.consentUseBody
                    )
                    consentRow(
                        icon: "hand.raised.fill",
                        fill: .emphasisPinkFill,
                        title: L10n.UXL14.consentDecideTitle,
                        body: L10n.UXL14.consentDecideBody("\(L10n.Profile.title) › \(L10n.Settings.aiPrivacy)")
                    )
                }
                .padding(DS.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .solidCard(padding: 0, radius: DS.Radius.lg)
                .accessibilityIdentifier("yala_ai_onboarding_consent")

                Button {
                    openURL(AppConstants.privacyURL)
                } label: {
                    Text(L10n.AIConsent.privacyPolicy)
                        .font(DS.Typography.label)
                        .foregroundStyle(theme.accent)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("yala_ai_onboarding_privacy")
            }
            .padding(.bottom, DS.Spacing.lg)
        }
        .scrollIndicators(.hidden)
    }

    private func consentRow(icon: String, fill: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            SolidIconTile(systemName: icon, fill: fill)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
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
        .accessibilityElement(children: .combine)
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

    /// El ejemplo del paso: la frase del estilo, precedida de la entrada del tono. Así se ve el efecto de las dos
    /// elecciones a la vez con los textos de ejemplo de siempre.
    private func combinedQuote(tone: InsightTone, focus: InsightFocus) -> String {
        let opener: String?
        switch tone {
        case .normal:      opener = nil
        case .considerate: opener = L10n.UXL14.toneOpenerConsiderate
        case .sarcastic:   opener = L10n.UXL14.toneOpenerSarcastic
        }
        let quote = focusQuote(for: focus)
        guard let opener else { return quote }
        return "\(opener) \(quote)"
    }

    private func toneDescription(for tone: InsightTone) -> String {
        switch tone {
        case .normal:      return L10n.YalaAI.Onboarding.step3ToneNormalDescription
        case .considerate: return L10n.YalaAI.Onboarding.step3ToneConsiderateDescription
        case .sarcastic:   return L10n.YalaAI.Onboarding.step3ToneSarcasticDescription
        }
    }

    /// Importes de ejemplo en la divisa principal (ticket `ai-onboarding-demo-speaks-english-and-dollars`).
    private var demoAmounts: YalaAIOnboardingDemoAmounts.Amounts {
        YalaAIOnboardingDemoAmounts.amounts(for: appPreferences.defaultCurrencyCode)
    }

    private func demoAmountText(_ value: Double) -> String {
        YalaAIOnboardingDemoAmounts.formatted(
            value,
            identifier: appPreferences.currencyIdentifier(for: appPreferences.defaultCurrencyCode.rawValue)
        )
    }

    private func focusQuote(for focus: InsightFocus) -> String {
        switch focus {
        case .balanced: return L10n.YalaAI.Onboarding.step4FocusBalancedQuote
        case .saver:    return L10n.YalaAI.Onboarding.step4FocusSaverQuote(demoAmountText(demoAmounts.saverSavingPerMonth))
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

    // MARK: - CTA

    private var ctaSection: some View {
        let label = currentStep == .consent
            ? L10n.UXL14.consentCTA
            : L10n.YalaAI.Onboarding.continueAction

        return YalaPrimaryButton(label) {
            advance()
        }
        .accessibilityIdentifier(currentStep == .consent ? "yala_ai_onboarding_accept" : "yala_ai_onboarding_continue")
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
            // «Aceptar y empezar»: el permiso se guarda aquí, con el mismo valor que guardaba el aviso. La presentación
            // vista la persiste el launcher al recibir `.complete`.
            appPreferences.aiChatConsentAccepted = true
            onResult(.complete)
        }
    }
}

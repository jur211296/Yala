//
//  YalaAIPersonalizeForm.swift
//  Yala
//
//  Tono y estilo de Yala IA con lo elegido RELLENO y un único ejemplo que junta las dos elecciones (UX 2.2 · L14-3,
//  variante 3). Lo comparten el paso «Hazla a tu manera» de la presentación y la hoja «Tono de Yala IA» (L14-10,
//  opción C): antes la hoja eran dos menús sin descripción ni ejemplo, y se elegía sin ver el efecto.
//

import SwiftUI

struct YalaAIPersonalizeForm: View {

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var prefs = appPreferences

        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
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
                    .accessibilityIdentifier("yala_ai_personalize_preview")
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Ejemplo y descripciones

    /// La frase del estilo, precedida de la entrada del tono. Así se ve el efecto de las dos elecciones a la vez con
    /// los textos de ejemplo de siempre.
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
}

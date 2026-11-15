//
//  GroupsTutorialFlowView.swift
//  Yala
//
//  Y23-13 · Paso 5 de Primeros pasos: «Divide gastos con tu grupo» (prototipo oficial v35, pestaña 7 · Grupos). Es el
//  onboarding de Grupos de hoy (`GroupsOnboardingView`: la animación, los tres pasos y el consentimiento, con sus mismos
//  textos) como página corta del tutorial: las dos primeras partes avanzan solas; el consentimiento no («Aceptar y
//  continuar» / «Ahora no»). Después, «¿Qué quieres hacer?»: crear el primer grupo o unirse con un enlace siguen por los
//  caminos de siempre (el formulario de grupo en la pestaña Grupos, con su puerta de cuenta, y la pantalla de pegar el
//  enlace), que el Panel abre al cerrarse esta pantalla (`GroupsTutorialLogic`).
//

import SwiftUI

struct GroupsTutorialFlowView: View {
    private typealias T = L10n.PrimerosPasos23.Groups

    /// Al salir: cómo termina y, si se une, el enlace pegado.
    let onClose: (_ exit: GroupsTutorialLogic.Exit, _ inviteLink: URL?) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.yalaTheme) private var theme
    @Environment(\.openURL) private var openURL

    @State private var part = 0
    @State private var asksWhatToDo = false
    @State private var showsLinkEntry = false
    /// El enlace pegado: se entrega al cerrarse la pantalla de pegar, no a la vez. Cerrar las dos pantallas completas en
    /// el mismo instante (la hija y la madre) puede dejar la de fuera pintada con su bandera ya en falso.
    @State private var pastedLink: URL?

    var body: some View {
        ZStack {
            if asksWhatToDo {
                whatToDo.transition(.opacity)
            } else {
                intro.transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : DS.Animation.appear, value: asksWhatToDo)
        .yalaScreenBackground(.panel)
        .fullScreenCover(isPresented: $showsLinkEntry, onDismiss: deliverPastedLink) {
            InviteRecoveryView(
                onSuccess: { url in
                    pastedLink = url
                    showsLinkEntry = false
                },
                onBack: { showsLinkEntry = false }
            )
        }
    }

    // MARK: - El onboarding, como página corta

    private var intro: some View {
        TutorialStoryPage(
            eyebrow: T.eyebrow(part + 1, 3),
            count: 3,
            part: $part,
            onBack: goBackFromIntro,
            content: { index in partView(index) },
            footer: { footer }
        )
    }

    /// El consentimiento se acepta aquí cuando hay que aceptarlo (la misma regla que el onboarding de Grupos); si ya
    /// estaba aceptado o el canal está apagado, el botón solo sigue.
    private var acceptsConsent: Bool {
        GroupsOnboardingLogic.lastStepAcceptsConsent(
            isLastStep: true,
            flagOn: CloudSyncFlags.groupsBackendEnabled,
            isConsented: GroupsConsentState.isAccepted
        )
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: DS.Spacing.xs) {
            if part < 2 {
                YalaPrimaryButton(L10n.Action.continueAction) { part += 1 }
                    .accessibilityIdentifier("groups_tutorial_continue")
                    .primerosPasosButtonText()
                textButton(L10n.PrimerosPasos23.Record.skipStep, id: "groups_tutorial_skip_step") {
                    onClose(.skipped, nil)
                }
            } else {
                YalaPrimaryButton(acceptsConsent ? L10n.Groups.Consent.accept : L10n.Action.continueAction) {
                    if acceptsConsent { GroupsConsentView.registerAcceptance(path: "tutorial") }
                    DS.Haptic.selection()
                    asksWhatToDo = true
                }
                .accessibilityIdentifier("groups_tutorial_accept")
                .primerosPasosButtonText()
                textButton(L10n.Action.notNow, id: "groups_tutorial_not_now") { onClose(.seenNotNow, nil) }
            }
        }
    }

    private func textButton(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(DS.Typography.body.weight(.semibold))
            .foregroundStyle(.thAccentText)
            .frame(maxWidth: .infinity, minHeight: 44)
            .accessibilityIdentifier(id)
    }

    @ViewBuilder
    private func partView(_ index: Int) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            switch index {
            case 0:
                heading(L10n.Groups.Onboarding.step1Title, L10n.Groups.Onboarding.step1Subtitle)
                GroupsOnboardingDemo()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 280)
            case 1:
                heading(L10n.Groups.Onboarding.step2Title, L10n.Groups.Onboarding.step2Subtitle)
                capabilities
            default:
                consent
            }
        }
        .padding(.top, DS.Spacing.md)
    }

    private func heading(_ title: String, _ message: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(title)
                .font(DS.Typography.welcomeHeadline)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .font(DS.Typography.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// «Tres pasos, cero hojas de cálculo»: las tres tarjetas de hoy y la nota del registro en la cuenta personal.
    private var capabilities: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            capabilityCard(icon: "person.3.fill", color: .hotPink,
                           title: L10n.Groups.Onboarding.step2Card1Title, body: L10n.Groups.Onboarding.step2Card1Body)
            capabilityCard(icon: "creditcard.fill", color: theme.accent,
                           title: L10n.Groups.Onboarding.step2Card2Title, body: L10n.Groups.Onboarding.step2Card2Body)
            capabilityCard(icon: "arrow.left.arrow.right.circle.fill", color: .essentialNeed,
                           title: L10n.Groups.Onboarding.step2Card3Title, body: L10n.Groups.Onboarding.step2Card3Body)
            Text("\(L10n.Groups.Onboarding.step2BridgeAwareness) \(L10n.GroupsCreate.bridgeOff)")
                .font(DS.Typography.captionSmall)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func capabilityCard(icon: String, color: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(DS.Typography.title3)
                .foregroundStyle(color)
                .frame(width: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title).font(DS.Typography.headline)
                Text(body).font(DS.Typography.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Spacing.md)
        .background(RoundedRectangle(cornerRadius: DS.Radius.lg).fill(theme.card))
        .accessibilityElement(children: .combine)
    }

    /// El consentimiento de Grupos: su título, los cuatro puntos y la política de privacidad.
    private var consent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Image(systemName: "lock.shield.fill")
                .font(DS.Typography.title.weight(.semibold))
                .foregroundStyle(Color.electricIndigo)
                .frame(width: 64, height: 64)
                .background(Circle().fill(Color.electricIndigo.opacity(0.18)))
                .accessibilityHidden(true)
            Text(L10n.Groups.Consent.title)
                .font(DS.Typography.welcomeHeadline)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            GroupsConsentPoints()
            Button {
                openURL(AppConstants.privacyURL)
            } label: {
                Text(L10n.Storage.Consent.privacyLink)
                    .font(DS.Typography.caption.weight(.medium))
                    .foregroundStyle(DS.Semantic.infoForeground)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("groups_tutorial_privacy_link")
        }
    }

    /// «Atrás» vuelve a la parte anterior; desde la primera, cierra sin tocar el mazo.
    private func goBackFromIntro() {
        if part > 0 {
            part -= 1
        } else {
            onClose(.closed, nil)
        }
    }

    /// Ya cerrada la pantalla de pegar el enlace, sale el tutorial con él.
    private func deliverPastedLink() {
        guard let link = pastedLink else { return }
        pastedLink = nil
        onClose(.joinWithLink, link)
    }

    // MARK: - ¿Qué quieres hacer?

    private var whatToDo: some View {
        TutorialQuestionScreen(
            subtitle: T.chatSubtitle,
            stepCount: 2,
            stepIndex: 0,
            isDone: false,
            question: T.whatQuestion,
            detail: T.whatSubtitle,
            identity: "what",
            backID: "groups_tutorial_back",
            onBack: { asksWhatToDo = false },
            dock: {
                VStack(spacing: DS.Spacing.sm) {
                    TutorialOptionButton(title: T.whatCreate, subtitle: T.whatCreateHint, icon: "person.2.fill",
                                         highlighted: true, id: "groups_tutorial_create") {
                        onClose(.createGroup, nil)
                    }
                    TutorialOptionButton(title: T.whatLink, subtitle: T.whatLinkHint, icon: "link",
                                         id: "groups_tutorial_link") {
                        showsLinkEntry = true
                    }
                    TutorialOptionButton(title: L10n.Action.notNow, id: "groups_tutorial_what_not_now") {
                        onClose(.seenNotNow, nil)
                    }
                }
            }
        )
    }
}

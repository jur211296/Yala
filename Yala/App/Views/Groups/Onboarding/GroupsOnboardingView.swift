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
//  A1 (D-A7, P1(b)): SIN sesión Yala el Step 3 ofrece ADEMÁS "Iniciar sesión"
//  (`onResult(.completeAndSignIn)`), que reusa el MISMO intent que el CTA del empty state
//  (`.presentGroupsSignIn`) — no monta una presentación nueva. La visibilidad la decide
//  `GroupsOnboardingLogic.shouldShowSignInCTA` (lógica pura, tests de tabla).
//
//  UX 2.2 · L12-4/L12-5/L12-6 (decisiones B de Jürgen, 2026-10-18): el Step 3 ES el consentimiento de Grupos —sus
//  cuatro puntos, un solo título y «Aceptar y continuar»— cuando hay que aceptarlo; antes contaba lo mismo que la hoja
//  «Grupos en la nube» y la persona leía dos veces lo mismo. La frase de Ajustes de Grupos bajó al Step 2, pegada a la
//  nota del registro personal a la que se refiere. L12-12: la rama «Crear mi primer grupo» arranca en el Step 3.
//

import SwiftUI

struct GroupsOnboardingView: View {

    /// Por dónde entró (`tab` | `organizer`): viaja al registro del consentimiento como diagnóstico, igual que en la
    /// hoja (`GroupsConsentView.path`). Sin valor por defecto, para que cada llamada se pronuncie.
    let consentPath: String
    /// UX 2.2 · L12-12: quien ya eligió «Crear mi primer grupo» en la bienvenida empieza en el Step 3; los dos
    /// primeros le cuentan qué es un grupo, y eso ya lo decidió.
    let startsAtConsent: Bool
    var onResult: (GroupsOnboardingResult) -> Void

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var currentStep: Step

    init(consentPath: String, startsAtConsent: Bool = false, onResult: @escaping (GroupsOnboardingResult) -> Void) {
        self.consentPath = consentPath
        self.startsAtConsent = startsAtConsent
        self.onResult = onResult
        self._currentStep = State(initialValue: startsAtConsent ? .privacy : .hero)
    }
    @Environment(\.openURL) private var openURL

    /// El primer step que esta presentación enseña: atrás de él no hay nada, así que lleva la «X».
    private var firstStep: Step { startsAtConsent ? .privacy : .hero }

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
        if currentStep == firstStep {
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
            ForEach(visibleSteps, id: \.rawValue) { step in
                Capsule()
                    .fill(step.rawValue <= currentStep.rawValue ? Color.electricIndigo : theme.secondaryText.opacity(0.2))
                    .frame(width: step == currentStep ? 24 : 8, height: 8)
                    .dsAnimation(.spring(response: 0.3), value: currentStep, reduceMotion: reduceMotion)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(format: L10n.Groups.Onboarding.progressLabel,
                   currentStep.rawValue - firstStep.rawValue + 1, visibleSteps.count)
        )
        // Un solo step no tiene progreso que enseñar.
        .opacity(visibleSteps.count > 1 ? 1 : 0)
        .accessibilityHidden(visibleSteps.count <= 1)
    }

    private var visibleSteps: [Step] { Step.allCases.filter { $0.rawValue >= firstStep.rawValue } }

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
                // L12-6: la frase de Ajustes de Grupos va aquí, pegada a la nota a la que se refiere. En el Step 3,
                // debajo de los puntos de privacidad, se leía como que la privacidad se podía apagar.
                Text("\(L10n.Groups.Onboarding.step2BridgeAwareness) \(L10n.GroupsCreate.bridgeOff)")
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.thSecondaryText)
                    .multilineTextAlignment(.center)
                    // Sin esto la pila la comprimía a una línea y la frase salía cortada con «…»
                    // (medido en el iPhone 17 Pro, 2026-10-15): la nota entera es la que cuenta el registro automático.
                    .fixedSize(horizontal: false, vertical: true)
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

    // MARK: - Step 3: el consentimiento (L12-4)

    private var privacyStep: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                // Sin degradado (criterio de Jürgen para toda la auditoría): un círculo índigo suave y el icono lleno.
                ZStack {
                    Circle()
                        .fill(Color.electricIndigo.opacity(0.18))
                        .frame(width: 96, height: 96)
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 44, weight: .semibold)) // A11Y-DT: hero icon
                        .foregroundStyle(Color.electricIndigo)
                }
                .accessibilityHidden(true)
                .padding(.top, DS.Spacing.xl)

                // L12-5: UN solo título, el de la hoja «Grupos en la nube», que es lo que aquí se acepta.
                Text(L10n.Groups.Consent.title)
                    .font(DS.Typography.largeTitle)
                    .foregroundStyle(.thPrimaryText)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)

                GroupsConsentPoints()
                    .padding(.top, DS.Spacing.sm)

                Button {
                    openURL(AppConstants.privacyURL)
                } label: {
                    Text(L10n.Storage.Consent.privacyLink)
                        .font(DS.Typography.caption.weight(.medium))
                        .foregroundStyle(DS.Semantic.infoForeground)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("groups_onboarding_privacy_link")
            }
            .padding(.bottom, DS.Spacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - CTA

    @ViewBuilder
    private var ctaSection: some View {
        let label = currentStep == .privacy
            ? L10n.Groups.Onboarding.step3CTA
            : L10n.Action.continueAction
        let isLastStep = currentStep == .privacy
        // Las señales vivas, leídas una vez para las dos decisiones del cierre (las mismas que lee el estado vacío).
        let channelOn = CloudSyncFlags.groupsBackendEnabled
        let sessionAlive = CloudAuthService.shared.hasSession

        if GroupsOnboardingLogic.lastStepAcceptsConsent(
            isLastStep: isLastStep,
            flagOn: channelOn,
            isConsented: GroupsConsentState.isAccepted
        ) {
            // L12-4: aceptar aquí es aceptar el consentimiento, por el mismo escritor que la hoja. Sin sesión sigue a la
            // cuenta; con sesión, a Grupos. «Ir a Grupos» sale sin aceptar, como hasta hoy: qué hacer con ese segundo
            // botón está en una card aparte, esperando la decisión de Jürgen.
            VStack(spacing: DS.Spacing.sm) {
                YalaPrimaryButton(L10n.Groups.Consent.accept, icon: "checkmark.shield") {
                    GroupsConsentView.registerAcceptance(path: consentPath)
                    onResult(GroupsOnboardingLogic.resultAfterAcceptingConsent(hasSession: sessionAlive))
                }
                .accessibilityIdentifier("groups_onboarding_consent_accept")

                YalaSecondaryButton(label) {
                    advance()
                }
                .accessibilityIdentifier("groups_onboarding_cta")
            }
        } else if GroupsOnboardingLogic.shouldShowSignInCTA(
            isLastStep: isLastStep,
            flagOn: CloudSyncFlags.groupsBackendEnabled,
            hasSession: CloudAuthService.shared.hasSession
        ) {
            // A1: sin sesión Yala (y con el consentimiento ya dado), el cierre convierte — el sign-in manda y «Ir a
            // Grupos» queda como salida visible (nunca un muro: quien lo salte se topa con el CTA del empty state).
            VStack(spacing: DS.Spacing.sm) {
                // C2 · el MISMO CTA con el copy honesto por caso: a quien nunca tuvo cuenta se le está CREANDO una, y
                // «Iniciar sesión» le pide volver a un sitio donde no ha estado. La señal es el latch
                // `GroupsSessionHistoryMarker`, la misma que decide el empty state — no una segunda fuente.
                YalaPrimaryButton(
                    GroupsSessionHistoryMarker.hadSessionEver()
                        ? L10n.Groups.Onboarding.step3SignInCTA
                        : L10n.Groups.Onboarding.step3CreateAccountCTA
                ) {
                    onResult(.completeAndSignIn)
                }
                .accessibilityIdentifier("groups_onboarding_signin_cta")

                YalaSecondaryButton(label) {
                    advance()
                }
                .accessibilityIdentifier("groups_onboarding_cta")
            }
        } else {
            YalaPrimaryButton(label) {
                advance()
            }
            .accessibilityIdentifier("groups_onboarding_cta")
        }
    }

    // MARK: - Navigation

    private func goBack() {
        guard currentStep != firstStep, let prev = Step(rawValue: currentStep.rawValue - 1) else { return }
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

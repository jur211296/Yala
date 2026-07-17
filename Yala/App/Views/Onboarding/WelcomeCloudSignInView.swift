//
//  WelcomeCloudSignInView.swift
//  Yala
//
//  Re-entrada a una cuenta del Modo Nube desde el Welcome (H4/pieza 2).
//  Flujo: consent (paridad con Ajustes) → SIWA → GET /account/exists (read-only —
//  el claim con `created` CREA cuenta server-side, por eso JAMÁS se claimea sin
//  `exists == true`) → guard cross-cuenta → adopt vía la máquina de migración
//  existente (`startAdoptWithExistingSession`, sin re-SIWA) → relaunch asistido.
//
//  Los flags de onboarding se marcan TEMPRANO (`onAdoptStarted`, antes de conducir
//  la máquina): un kill a mitad del adopt aterriza en MainTab con la card de
//  Almacenamiento reflejando el estado real — el seed del onboarding JAMÁS corre
//  sobre una cuenta existente (hazard seed-over-account).
//

import AuthenticationServices
import SwiftUI

struct WelcomeCloudSignInView: View {

    /// Provider del sign-in (sesión 2 Google): `.apple` conserva el flujo actual BYTE-IDÉNTICO
    /// (mismo botón SIWA, mismo subtitle, mismos catches); `.google` monta el botón custom y
    /// distingue cancel de fallo real. El chooser lo setea EXPLÍCITO por card.
    let provider: CloudSignInProvider
    /// Corpus personal en el device, evaluado EN el momento de la decisión (S5: el
    /// mirror de iCloud puede estar re-importando en background durante el Welcome —
    /// un snapshot sería stale). Input del guard cross-cuenta F0-C.
    let hasLocalDataNow: @MainActor () -> Bool
    /// ContentView marca onboarding completado (restore-skip) ANTES del adopt.
    var onAdoptStarted: () -> Void
    /// M1 (D1): variante para la ENTRADA SECUNDARIA — marca los flags SIN trial pendiente
    /// (la invitada no recibe la oferta del device del dueño) ni `markAsNewInstall` (el
    /// checklist es estado device-global del dueño).
    var onSecondaryEntryFlagsMarked: () -> Void
    /// Salida a la app (waitingLeader → "Continuar a la app").
    var onFinishedToApp: () -> Void
    /// Volver al chooser (solo en fases no comprometidas: intro/notFound/blocked/error).
    var onBack: () -> Void

    @State private var phase: CloudWelcomeSignInPhase = .intro
    @State private var showConsent = false
    /// Task del flujo/poll en vuelo — se cancela en onDisappear (el Task nace de un
    /// callback, NO de `.task`, así que el desmontaje no lo cancela solo).
    @State private var flowTask: Task<Void, Never>?

    var body: some View {
        WelcomeFlowScreen { logoTopSpacing in
            VStack(spacing: 0) {
                Spacer(minLength: logoTopSpacing)

                Image("YalaLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 128)
                    .colorMultiply(.white)
                    .accessibilityHidden(true)

                Spacer(minLength: DS.Spacing.lg)

                phaseContent

                Spacer(minLength: DS.Spacing.xl)
            }
        }
        .welcomeBackButton(tint: .white, action: canGoBack ? onBack : nil)
        .sheet(isPresented: $showConsent) {
            CloudConsentView(path: .adopt) {
                showConsent = false
                launchFlow { await runSignInFlow() }
            }
        }
        .onDisappear { flowTask?.cancel() }
        .interactiveDismissDisabled()
    }

    private func launchFlow(_ operation: @escaping @MainActor () async -> Void) {
        flowTask?.cancel()
        flowTask = Task { await operation() }
    }

    /// Back solo en fases donde nada está comprometido; adopt en vuelo o relaunch = sin salida.
    /// `.secondaryConfirm` usa su botón Cancelar propio (suelta la sesión SIWA — el back genérico
    /// la dejaría colgada); `.relaunchSecondary` es terminal como `.relaunch`.
    private var canGoBack: Bool {
        switch phase {
        // `.providerMismatch`: sesión ya soltada y sin claim — nada comprometido.
        case .intro, .notFound, .blockedForeignData, .error, .providerMismatch: true
        case .checking, .adopting, .waitingLeader, .relaunch, .secondaryConfirm, .relaunchSecondary: false
        }
    }

    // MARK: - Contenido por fase

    @ViewBuilder
    private var phaseContent: some View {
        switch phase {
        case .intro:
            introContent
        case .checking:
            progressContent(L10n.Welcome.Cloud.checking, hint: nil)
        case .adopting(let fraction):
            adoptingContent(fraction: fraction)
        case .waitingLeader:
            waitingLeaderContent
        case .relaunch:
            relaunchContent
        case .secondaryConfirm:
            secondaryConfirmContent
        case .relaunchSecondary:
            secondaryRelaunchContent
        case .notFound:
            messageContent(
                icon: "person.crop.circle.badge.questionmark",
                title: L10n.Welcome.Cloud.notFoundTitle,
                body: L10n.Welcome.Cloud.notFoundBody)
        case .providerMismatch(let knownProvider):
            messageContent(
                icon: "person.crop.circle.badge.exclamationmark",
                title: L10n.Welcome.Cloud.providerMismatchTitle,
                body: providerMismatchBody(knownProvider: knownProvider))
                .accessibilityIdentifier("welcome_cloud_provider_mismatch")
        case .blockedForeignData:
            messageContent(
                icon: "lock.shield",
                title: L10n.Welcome.Cloud.blockedTitle,
                body: L10n.Welcome.Cloud.blockedBody)
        case .error(let retryable):
            VStack(spacing: DS.Spacing.lg) {
                messageContent(
                    icon: "wifi.exclamationmark",
                    title: L10n.Welcome.Cloud.errorTitle,
                    body: L10n.Welcome.Cloud.errorBody)
                if retryable {
                    YalaPrimaryButton(L10n.Welcome.Cloud.retry) {
                        launchFlow { await runSignInFlow() }
                    }
                    .padding(.horizontal, DS.Spacing.xl)
                    .accessibilityIdentifier("welcome_cloud_retry")
                }
            }
        }
    }

    private var introContent: some View {
        VStack(spacing: DS.Spacing.lg) {
            VStack(spacing: DS.Spacing.sm) {
                Text(L10n.Welcome.Cloud.title)
                    .font(DS.Typography.title2)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(provider == .google
                    ? L10n.Welcome.Cloud.subtitleGoogle
                    : L10n.Welcome.Cloud.subtitle)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.lg)
            }
            switch provider {
            case .apple:
                AppleSignInButton {
                    DS.Haptic.selection()
                    showConsent = true
                }
                .frame(height: 50)
                .padding(.horizontal, DS.Spacing.xl)
                .accessibilityIdentifier("welcome_cloud_signin_button")
            case .google:
                GoogleSignInButton(variant: .light) {
                    DS.Haptic.selection()
                    showConsent = true
                }
                .frame(height: 50)
                .padding(.horizontal, DS.Spacing.xl)
                .accessibilityIdentifier("welcome_cloud_signin_button_google")
            }
            // Nota §13 del primer sign-in (AMBOS providers): la cuenta queda ligada al método.
            Text(L10n.Welcome.Cloud.providerNote)
                .font(DS.Typography.caption)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.xl)
        }
    }

    /// Body del mismatch R9: con provider CONOCIDO interpola su nombre visible; nil o
    /// desconocido → copy genérico (jamás interpolar un rawValue del wire en UI).
    private func providerMismatchBody(knownProvider: String?) -> String {
        if let name = ProviderMismatchLogic.displayName(forProvider: knownProvider) {
            return L10n.Welcome.Cloud.providerMismatchBody(name)
        }
        return L10n.Welcome.Cloud.providerMismatchBodyGeneric
    }

    private func progressContent(_ text: String, hint: String?) -> some View {
        VStack(spacing: DS.Spacing.md) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.4)
            Text(text)
                .font(DS.Typography.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            if let hint {
                Text(hint)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xl)
            }
        }
    }

    private func adoptingContent(fraction: Double) -> some View {
        VStack(spacing: DS.Spacing.md) {
            ProgressView(value: fraction)
                .tint(.white)
                .padding(.horizontal, DS.Spacing.xl)
            Text(L10n.Welcome.Cloud.adopting)
                .font(DS.Typography.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(L10n.Welcome.Cloud.adoptingHint)
                .font(DS.Typography.caption)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.xl)
        }
        .accessibilityIdentifier("welcome_cloud_adopting")
    }

    private var waitingLeaderContent: some View {
        VStack(spacing: DS.Spacing.lg) {
            messageContent(
                icon: "iphone.gen3.radiowaves.left.and.right",
                title: L10n.Welcome.Cloud.waitingTitle,
                body: L10n.Welcome.Cloud.waitingBody)
            YalaPrimaryButton(L10n.Welcome.Cloud.retry) {
                launchFlow { await retryLeaderPoll() }
            }
            .padding(.horizontal, DS.Spacing.xl)
            Button(L10n.Welcome.Cloud.continueToApp) {
                onFinishedToApp()
            }
            .font(DS.Typography.subheadline)
            .foregroundStyle(.white.opacity(0.8))
            .accessibilityIdentifier("welcome_cloud_continue_to_app")
        }
    }

    private var relaunchContent: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.8))
                .accessibilityHidden(true)
            Text(L10n.Storage.Relaunch.title)
                .font(DS.Typography.title2)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(L10n.Storage.Relaunch.body)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.xl)
        }
        .accessibilityIdentifier("welcome_cloud_relaunch")
    }

    private var secondaryConfirmContent: some View {
        VStack(spacing: DS.Spacing.lg) {
            messageContent(
                icon: "person.2.badge.key",
                title: L10n.Welcome.Cloud.secondaryConfirmTitle,
                body: L10n.Welcome.Cloud.secondaryConfirmBody)
            YalaPrimaryButton(L10n.Welcome.Cloud.secondaryConfirmCta) {
                confirmSecondaryEntry()
            }
            .padding(.horizontal, DS.Spacing.xl)
            .accessibilityIdentifier("welcome_cloud_secondary_confirm_cta")
            Button(L10n.Common.cancel) {
                // Suelta la sesión SIWA (no dejarla colgada) y vuelve al intro.
                launchFlow {
                    await CloudAuthService.shared.signOut()
                    phase = .intro
                }
            }
            .font(DS.Typography.subheadline)
            .foregroundStyle(.white.opacity(0.8))
            .accessibilityIdentifier("welcome_cloud_secondary_confirm_cancel")
        }
    }

    private var secondaryRelaunchContent: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.8))
                .accessibilityHidden(true)
            Text(L10n.Storage.Relaunch.title)
                .font(DS.Typography.title2)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            // La ventana de ENTRADA secundaria auto-exita en background (ContentView) —
            // el copy refleja que basta ir al inicio. El `.relaunch` del adopt (arriba)
            // NO auto-exita y conserva `body`.
            Text(L10n.Storage.Relaunch.bodyAutoExit)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.xl)
        }
        .accessibilityIdentifier("welcome_cloud_secondary_relaunch")
    }

    private func messageContent(icon: String, title: String, body bodyText: String) -> some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.8))
                .accessibilityHidden(true)
            Text(title)
                .font(DS.Typography.title3)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.lg)
            Text(bodyText)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.xl)
        }
    }

    // MARK: - Flujo

    private func runSignInFlow() async {
        phase = .checking
        // Retry con sesión ya viva (falló solo el exists): no re-pedir Face ID.
        if !CloudAuthService.shared.hasSession {
            do {
                try await CloudAuthService.shared.signIn(with: provider)
            } catch CloudAuthError.cancelled {
                // Cancel EXPLÍCITO (Google) → volver al intro en silencio (el user re-tapea).
                phase = .intro
                return
            } catch {
                #if DEBUG
                print("WelcomeCloudSignInView: sign-in \(provider.rawValue) falló/cancelado: \(error)")
                #endif
                switch provider {
                case .apple:
                    // BYTE-IDÉNTICO con hoy: ASAuthorization no distingue cancel de fallo →
                    // volver al intro sin alarma.
                    phase = .intro
                case .google:
                    // Google SÍ distingue (el cancel ya salió arriba): esto es fallo REAL
                    // (red/SDK/exchange) → error visible con retry.
                    phase = .error(retryable: true)
                    track(outcome: "error")
                }
                return
            }
        }

        guard let userID = CloudAuthService.shared.currentUserID,
              let jwt = await CloudAuthService.shared.accessToken() else {
            phase = .error(retryable: true)
            track(outcome: "error")
            return
        }

        switch CloudWelcomeSignInFlow.route(await CloudAccountClient().exists(jwt: jwt)) {
        case .accountMissing:
            // Guard R9 SUB-FIRST (sesión 2, H4): antes del `.notFound` engañoso, consultar el
            // faro del device — si la cuenta nube de este Apple ID se creó con OTRO método y
            // este sub NO la matchea, lo probable es "método equivocado", no "sin cuenta".
            let beacon = CloudBeacon()
            let verdict = ProviderMismatchLogic.decide(
                accountExists: false,
                beaconLinked: beacon.isCloudAccountLinked,
                beaconAccountHash: beacon.accountHash,
                beaconProvider: beacon.linkedProvider,
                sessionSubHash: CloudBeacon.hash(userID),
                sessionProvider: provider.rawValue)
            // Sin claim no se creó NADA server-side; soltar la sesión SIEMPRE (no dejar el
            // sign-in colgado) — también en mismatch (jamás dejar un sub huérfano vivo).
            await CloudAuthService.shared.signOut()
            switch verdict {
            case .mismatch(let knownProvider):
                TelemetryService.cloudSignInProviderMismatch()
                phase = .providerMismatch(knownProvider: knownProvider)
                track(outcome: "providerMismatch")
            case .proceed:
                phase = .notFound
                track(outcome: "notFound")
            }
        case .failed(let retryable):
            phase = .error(retryable: retryable)
            track(outcome: "error")
        case .accountFound:
            let decision = CrossAccountEntryGuardLogic.decide(
                hasLocalData: hasLocalDataNow(),
                sameAccountClaimExists: CloudClaimActionStore.shared.action(forUserID: userID) != nil,
                accountExists: true,
                secondarySessionEnabled: CloudSyncFlags.secondarySessionEntryAvailable)
            switch decision {
            case .blockedForeignData:
                await CloudAuthService.shared.signOut()
                phase = .blockedForeignData
                track(outcome: "blocked")
            case .proceedSecondarySession:
                // M1 belt: invariante estructural — durante el Welcome post sign-out la key
                // PERSISTIDA es `.icloud` (el sign-out cloud siempre la resetea antes de llegar
                // aquí). Si no lo es, hay estado corrupto: delatarlo temprano, jamás armar.
                guard StorageModePersistence.read() == .icloud else {
                    await CloudAuthService.shared.signOut()
                    phase = .error(retryable: false)
                    track(outcome: "secondaryInvariantViolated")
                    return
                }
                track(outcome: "secondaryOffered")
                phase = .secondaryConfirm
            case .proceed:
                track(outcome: "found")
                onAdoptStarted()
                phase = .adopting(fraction: 0)
                await CloudMigrationController.shared?.startAdoptWithExistingSession()
                await pollAdoptProgress()
            }
        }
    }

    /// M1: la invitada confirmó — arma la sesión secundaria EN ORDEN (claim → descriptor →
    /// flags, kill-safety en `SecondaryEntryLogic`) y muestra el relaunch terminal. JAMÁS
    /// adopt aquí (correría sobre el store del DUEÑO montado) ni signOut (el runtime necesita
    /// la sesión SIWA post-relaunch).
    private func confirmSecondaryEntry() {
        guard let userID = CloudAuthService.shared.currentUserID else {
            phase = .error(retryable: true)
            track(outcome: "error")
            return
        }
        SecondaryEntryLogic.begin(
            userID: userID,
            recordClaim: { CloudClaimActionStore.shared.record(.routeReturningUser, forUserID: $0) },
            activateDescriptor: { SecondarySessionStore.activate(userID: $0) },
            markOnboardingFlags: onSecondaryEntryFlagsMarked)
        CloudSyncBreadcrumb.secondaryEntryArmed()
        track(outcome: "secondaryArmed")
        phase = .relaunchSecondary
    }

    /// Deriva la fase de pantalla del uiState de la máquina cada segundo
    /// (molde del refresh de StorageSettingsView) hasta un estado terminal.
    private func pollAdoptProgress() async {
        guard let controller = CloudMigrationController.shared else {
            phase = .error(retryable: true)
            return
        }
        while true {
            controller.refresh()
            let next = CloudWelcomeSignInFlow.phase(for: controller.uiState)
            phase = next
            switch next {
            case .relaunch, .error:
                return
            case .waitingLeader:
                track(outcome: "leaderWait")
                return
            default:
                break
            }
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return  // task cancelada (view desmontada)
            }
        }
    }

    private func retryLeaderPoll() async {
        phase = .adopting(fraction: 0)
        await CloudMigrationController.shared?.pollLeader()
        await pollAdoptProgress()
    }

    private func track(outcome: String) {
        TelemetryService.track(.welcomeCloudSignInOutcome, parameters: ["outcome": outcome])
    }
}

// MARK: - Botón SIWA nativo

/// `ASAuthorizationAppleIDButton` (obligado por HIG/App Review 4.8 — aquí SIWA es el único
/// login). El flujo real (nonce, exchange, captura de perfil) vive en
/// `CloudAuthService.signInWithApple()`; este botón es solo el afford visual + target-action.
private struct AppleSignInButton: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .white)
        button.cornerRadius = DS.Radius.lg
        button.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    final class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tapped() { action() }
    }
}

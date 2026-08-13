//
//  WelcomeCloudSignInView.swift
//  Yala
//
//  Las DOS entradas a una cuenta del Modo Nube desde el Welcome, en una sola pantalla.
//
//  · `.reentry` (H4/pieza 2) — la cuenta YA existe:
//      consent (paridad con Ajustes) → SIWA/Google → GET /account/exists (read-only — el claim con
//      `created` CREA cuenta server-side, por eso JAMÁS se claimea sin `exists == true`) → guard
//      cross-cuenta → adopt vía la máquina de migración existente
//      (`startAdoptWithExistingSession`, sin re-SIWA) → relaunch asistido.
//
//  · `.bornCloud` (A5 de D-A7) — el ALTA de un usuario nuevo que elige la nube:
//      consent (`path: .bornCloud`) → sign-in → claim (`BornCloudSignUpService`, A2) → par
//      `.cloud` + `mirrorOffArmed` (A3) → terminal «Cierra y reabre Yala» → [el usuario relanza] →
//      `OnboardingView` NORMAL, ya con el store montado sin mirror.
//      **NO hay máquina de estados y NO se journalea nada**: en born-cloud no hay corpus que mover.
//
//  POR QUÉ UNA VISTA PARAMETRIZADA Y NO UNA HERMANA (decisión de A5, y su razón principal no es
//  ahorrar código): el claim del alta puede devolver `existing_stable` —2º device del mismo Apple ID,
//  o un reintento tras un `created` previo— y entonces el contrato es «encamina al returning-user que
//  ya existe, JAMÁS siembres». Aquí eso es una transición de FASE con la sesión ya viva
//  (`runSignInFlow` salta el sign-in cuando `hasSession`); con una vista hermana sería un segundo
//  anchor presentando mientras el primero se desmonta, que es la carrera de reconciliación de la
//  regla (4) de Presentaciones (`.claude/rules/swiftui-ds.md`) y ya costó el bug del sign-out del
//  2026-07-14. De paso, las cuatro fases terminales que ya existen (`relaunch`, `waitingLeader`,
//  `providerMismatch`, `error`) se comparten en vez de duplicarse, y el alta no añade ninguna
//  presentación nueva a la matriz de readiness: cuelga del cover que ya está en ella.
//
//  M0 (ola M, §6.3 del spec M1 revival) — QUIÉN escribe el registro GDPR del consent, y cuándo. El
//  consent SIGUE presentándose antes del sign-in en las dos entradas; lo que cambió es que en `.reentry`
//  la ESCRITURA se difiere hasta que el guard cross-cuenta dice la ruta (tabla:
//  `CloudConsentRegistrationLogic`). Antes se escribía al aceptar, cuando el único modo que
//  `PreferenceSyncService` podía resolver era el `.icloud` del DUEÑO ⇒ un intento cross-cuenta que
//  terminaba BLOQUEADO dejaba el epoch de la otra persona en el iKV de él. El alta born-cloud escribe al
//  aceptar como siempre: su ruta ya se conoce ahí y su claim la VERIFICA.
//
//  Los flags de onboarding se marcan TEMPRANO (`onAdoptStarted`, antes de conducir
//  la máquina): un kill a mitad del adopt aterriza en MainTab con la card de
//  Almacenamiento reflejando el estado real — el seed del onboarding JAMÁS corre
//  sobre una cuenta existente (hazard seed-over-account). El alta born-cloud NO los marca: su
//  onboarding es justamente lo que corre después del relanzamiento.
//

import AuthenticationServices
import SwiftData
import SwiftUI

struct WelcomeCloudSignInView: View {

    /// Qué está haciendo el usuario en esta pantalla. Decide el `ConsentPath`, el intro y qué pasa
    /// después del sign-in — el resto de fases son comunes.
    enum Entry: Equatable {
        /// Re-entrada a una cuenta que ya existe. El provider lo eligió la card del chooser (o lo
        /// dictó el faro) y se setea EXPLÍCITO por el productor: jamás se hereda el del intento previo.
        case reentry(CloudSignInProvider)
        /// Alta born-cloud desde la card «nube» de «Soy nuevo». El provider NO viene decidido: se
        /// elige aquí, con los dos botones de prominencia equivalente (guideline 4.8).
        case bornCloud
    }

    let entry: Entry
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
    /// R2: el alta born-cloud terminó **sin relanzamiento** (el mount ya era compatible) ⇒ cerrar este
    /// cover y presentar el onboarding NORMAL. Distinto de `onFinishedToApp`, que solo cierra: sin este
    /// callback el `onDismiss` del cover devolvería al usuario al chooser (`!hasCompletedOnboarding`),
    /// que es justo el sitio del que acaba de salir.
    var onBornCloudCompleted: () -> Void
    /// Volver al chooser (solo en fases no comprometidas: intro/notFound/blocked/error).
    var onBack: () -> Void

    /// R2: el alta sin relanzar arranca el motor del dominio EN ESTA SESIÓN y `startShared` necesita un
    /// contexto. Es el mismo `mainContext` que el bootstrap le pasa en el paso 14.7.
    @Environment(\.modelContext) private var modelContext

    @State private var phase: CloudWelcomeSignInPhase = .intro
    @State private var showConsent = false
    /// M0 · el usuario ACEPTÓ el consent y su epoch todavía no está escrito. Solo la RE-ENTRADA lo deja
    /// pendiente: hasta que el guard cross-cuenta decida, escribirlo resolvería el destino con el modo
    /// del DUEÑO. Se consume al escribir (una sola vez — el epoch conserva su T0 aunque el flujo
    /// reintente).
    @State private var consentPendingPersistence = false
    /// A5: el método que el usuario tapeó en el intro del ALTA (en `.reentry` no se usa — ahí el
    /// provider lo trae el `Entry`). Se fija ANTES de abrir el consent y de ahí sale el `provider`
    /// que ve `CloudAuthService`.
    @State private var chosenProvider: CloudSignInProvider?
    /// Task del flujo/poll en vuelo — se cancela en onDisappear (el Task nace de un
    /// callback, NO de `.task`, así que el desmontaje no lo cancela solo).
    @State private var flowTask: Task<Void, Never>?
    /// H-2026-07-17-5: detector de drive aparcado del poll (auto-resume + botón manual).
    @State private var autoResumeState = WelcomeAdoptAutoResume.State()
    /// Fase journaleada del tick anterior del poll — alimenta `machineAdvanced` (un avance
    /// real repone intentos de auto-resume). `nil` = primer tick (jamás cuenta como avance).
    @State private var lastObservedPhase: MigrationPhase?

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
        // EL CONSENT VA SIEMPRE ANTES DEL SIGN-IN, en las dos entradas: el login envía identidad, así
        // que pedir permiso después sería pedirlo para algo ya hecho (docblock de `CloudConsentView`).
        // Estructuralmente lo garantiza que el ÚNICO productor del flujo sea este `onAccept`: los
        // botones del intro solo abren el sheet, nunca firman.
        .sheet(isPresented: $showConsent) {
            CloudConsentView(path: consentPath, persistsOnAccept: persistsConsentOnAccept) {
                showConsent = false
                consentPendingPersistence = !persistsConsentOnAccept
                launchFlow { await runFlowAfterConsent() }
            }
        }
        .onDisappear { flowTask?.cancel() }
        .interactiveDismissDisabled()
    }

    private func launchFlow(_ operation: @escaping @MainActor () async -> Void) {
        flowTask?.cancel()
        flowTask = Task { await operation() }
    }

    /// Método con el que se va a firmar. En `.reentry` lo trae el `Entry`; en `.bornCloud` es el que
    /// el usuario acaba de tapear. El `?? .apple` no es una elección silenciosa: el flujo del alta no
    /// arranca sin pasar por un botón, y ese botón siempre escribe `chosenProvider`.
    private var provider: CloudSignInProvider {
        switch entry {
        case .reentry(let p): return p
        case .bornCloud:      return chosenProvider ?? .apple
        }
    }

    /// Ruta que se registra con el consent (telemetría §j.4). El alta tiene la suya para que el
    /// dashboard pueda separar «cuánta gente entra a una cuenta que ya tenía» de «cuánta se da de alta».
    private var consentPath: CloudMigrationController.ConsentPath {
        switch entry {
        case .reentry:   return .adopt
        case .bornCloud: return .bornCloud
        }
    }

    /// M0 · quién ESCRIBE el registro GDPR del consent. El alta born-cloud ya conoce su ruta al aceptar
    /// (no pasa por el guard cross-cuenta) y su claim la VERIFICA (paso 5 de `BornCloudSignUpService`),
    /// así que ahí escribe la pantalla, como siempre. La RE-ENTRADA no: su ruta la decide el guard
    /// DESPUÉS del sign-in, y escribir antes deja el epoch de la invitada en el iKV del DUEÑO.
    private var persistsConsentOnAccept: Bool {
        switch entry {
        case .bornCloud: true
        case .reentry:   false
        }
    }

    /// M0 · escribe el registro GDPR del consent SOLO si (a) la pantalla lo dejó pendiente —re-entrada—
    /// y (b) la ruta que decidió el guard cae en ESTE punto del flujo. La tabla vive en
    /// `CloudConsentRegistrationLogic`, así que llamar desde el punto equivocado es un no-op y no una
    /// fuga: la decisión no se re-deriva aquí.
    private func persistConsentIfDue(
        at point: CloudConsentRegistrationLogic.Placement,
        routedBy decision: CrossAccountEntryGuardLogic.Decision
    ) {
        CloudConsentRegistrationLogic.persistIfDue(
            at: point,
            routedBy: decision,
            pending: &consentPendingPersistence,
            persist: { CloudConsentRegistrar.register() })
    }

    /// Qué corre al aceptar el consent. Es el ÚNICO punto donde el flujo se bifurca por entrada.
    private func runFlowAfterConsent() async {
        switch entry {
        case .reentry:   await runSignInFlow()
        case .bornCloud: await runBornCloudFlow()
        }
    }

    /// Back solo en fases donde nada está comprometido; adopt en vuelo o relaunch = sin salida.
    /// `.secondaryConfirm` usa su botón Cancelar propio (suelta la sesión SIWA — el back genérico
    /// la dejaría colgada); `.relaunchSecondary` es terminal como `.relaunch`.
    private var canGoBack: Bool {
        switch phase {
        // `.providerMismatch`: sesión ya soltada y sin claim — nada comprometido.
        case .intro, .notFound, .blockedForeignData, .error, .providerMismatch: true
        // `.creating`: el claim está en vuelo y puede CREAR la cuenta server-side — salir a mitad
        // dejaría al usuario sin saber si se dio de alta. Mismo criterio que `.checking`.
        // `.bornCloudReady` es terminal como `.relaunch`: la cuenta está creada y el par escrito.
        case .checking, .creating, .adopting, .waitingLeader, .relaunch, .bornCloudReady,
             .secondaryConfirm, .relaunchSecondary: false
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
        case .creating:
            progressContent(L10n.Welcome.BornCloud.creating, hint: nil)
        case .adopting(let fraction):
            adoptingContent(fraction: fraction)
        case .waitingLeader:
            waitingLeaderContent
        case .relaunch:
            relaunchContent
        case .bornCloudReady:
            bornCloudReadyContent
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
            // La pantalla describe DOS mundos porque el detector no sabe distinguirlos: `hasLocalDataNow`
            // cuenta filas, así que dice «hay datos», nunca «hay datos de otro». El cuerpo habla del caso
            // dominante —datos de otro humano— y el hint nombra el otro, que es el que dejaba a una persona
            // sin salida: el dueño que restauró de iCloud y volvió atrás con el import a medias ve sus
            // PROPIAS filas contadas en su contra. El veredicto no se toca aquí (eso es
            // `ICloudRestoreSessionSignal`, la otra mitad); esto es que la pantalla deje de ser un callejón.
            VStack(spacing: DS.Spacing.lg) {
                messageContent(
                    icon: "lock.shield",
                    title: L10n.Welcome.Cloud.blockedTitle,
                    body: L10n.Welcome.Cloud.blockedBody)
                    // M4 · gancho de QA, hoy sin XCUITest y así declarado: llegar a esta fase exige un
                    // sign-in REAL con SIWA/Google sobre un device con corpus ajeno, y el simulador no
                    // firma. Lo que sí puede afirmarse en sim es su GEMELA de la puerta de Grupos-first
                    // (`welcome_groups_gate_foreign_data`, mismo hecho y mismo copy), que es lo que
                    // cubre `SecondarySessionGateUITests`. El identifier va puesto para que el device-QA
                    // pueda anclarse a él sin recompilar y para que el día que exista un seam de sign-in
                    // el test no dependa de texto localizado.
                    .accessibilityIdentifier("welcome_cloud_blocked_foreign_data")

                Text(L10n.Welcome.Cloud.blockedRestoreHint)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xl)

                // La flecha de la toolbar (`canGoBack` la incluye) sigue ahí, pero una pantalla que acaba
                // de bloquear la entrada a una cuenta no puede dejar su única salida en una esquina.
                YalaPrimaryButton(L10n.Welcome.Cloud.blockedBack) {
                    onBack()
                }
                .padding(.horizontal, DS.Spacing.xl)
                .accessibilityIdentifier("welcome_cloud_blocked_back")
            }
        case .error(let retryable):
            VStack(spacing: DS.Spacing.lg) {
                messageContent(
                    icon: "wifi.exclamationmark",
                    title: L10n.Welcome.Cloud.errorTitle,
                    body: L10n.Welcome.Cloud.errorBody)
                if retryable {
                    YalaPrimaryButton(L10n.Welcome.Cloud.retry) {
                        launchFlow { await runFlowAfterConsent() }
                    }
                    .padding(.horizontal, DS.Spacing.xl)
                    .accessibilityIdentifier("welcome_cloud_retry")
                }
            }
        }
    }

    @ViewBuilder
    private var introContent: some View {
        switch entry {
        case .reentry:   reentryIntro
        case .bornCloud: bornCloudIntro
        }
    }

    /// A5 · intro del ALTA. Los dos métodos con prominencia EQUIVALENTE (guideline 4.8, patrón
    /// apilado de `StorageSignInChooserView`): aquí el usuario no re-entra a nada, elige con qué
    /// nace su cuenta.
    ///
    /// W4 (decisión del owner 2026-08-11, puntos 15 y 16): por eso los dos botones dicen CREAR
    /// —`.signUp` en los dos, el del sistema y el nuestro— y la nota es la del alta y no la de la
    /// re-entrada. La compartían, y su primera mitad («entra con el mismo método que usaste») no
    /// significa nada para quien no ha usado ninguno: lo que sí informa aquí es la segunda, que la
    /// cuenta queda ligada al método que elija.
    private var bornCloudIntro: some View {
        VStack(spacing: DS.Spacing.lg) {
            VStack(spacing: DS.Spacing.sm) {
                Text(L10n.Welcome.BornCloud.title)
                    .font(DS.Typography.title2)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(L10n.Welcome.BornCloud.subtitle)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.lg)
            }
            VStack(spacing: DS.Spacing.md) {
                AppleSignInButton(type: .signUp) {
                    DS.Haptic.selection()
                    beginBornCloudSignUp(with: .apple)
                }
                .frame(height: 50)
                .accessibilityIdentifier("welcome_borncloud_signup_apple")

                GoogleSignInButton(variant: .light, purpose: .signUp) {
                    DS.Haptic.selection()
                    beginBornCloudSignUp(with: .google)
                }
                .frame(height: 50)
                .accessibilityIdentifier("welcome_borncloud_signup_google")
            }
            .padding(.horizontal, DS.Spacing.xl)

            Text(L10n.Welcome.BornCloud.providerNote)
                .font(DS.Typography.caption)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.xl)
        }
        // SIN identifier de contenedor a propósito: uno aplicado al `VStack` PISA el de sus hijos
        // —medido con `snapshot_ui`: los dos botones salían como `welcome_borncloud_intro` y sus
        // propios ids no existían en el árbol— y dejaría el XCUITest sin poder targetearlos
        // (`.claude/rules/testing.md`). La pantalla se identifica por sus botones.
    }

    /// Fija el método y abre el consent. **No firma nada**: el sign-in vive detrás del `onAccept`
    /// del sheet, que es lo que mantiene el orden consent → sign-in.
    private func beginBornCloudSignUp(with provider: CloudSignInProvider) {
        chosenProvider = provider
        showConsent = true
    }

    private var reentryIntro: some View {
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
            // W4: aquí la cuenta YA existe ⇒ el verbo es iniciar sesión, en los dos botones.
            switch provider {
            case .apple:
                AppleSignInButton(type: .signIn) {
                    DS.Haptic.selection()
                    showConsent = true
                }
                .frame(height: 50)
                .padding(.horizontal, DS.Spacing.xl)
                .accessibilityIdentifier("welcome_cloud_signin_button")
            case .google:
                GoogleSignInButton(variant: .light, purpose: .signIn) {
                    DS.Haptic.selection()
                    showConsent = true
                }
                .frame(height: 50)
                .padding(.horizontal, DS.Spacing.xl)
                .accessibilityIdentifier("welcome_cloud_signin_button_google")
            }
            // Nota §13 del primer sign-in (AMBOS providers): entra con el método que usaste, y la
            // cuenta queda ligada a él. La primera mitad es lo que la separa de la del alta (W4).
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
            // #36 (H1): pre-espera de quiescencia en curso (hasta 300s) — estado honesto,
            // misma key que la card de Almacenamiento. Leer la propiedad @Observable en
            // body registra la dependencia.
            if CloudMigrationController.shared?.resumeWaitingForImport == true {
                Text(L10n.Storage.Progress.waitingImport)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.xl)
                    .accessibilityIdentifier("welcome_cloud_adopt_waiting_import")
            }
            // H-2026-07-17-5: autos agotados sin avance → Retomar manual (el poll sigue
            // vivo: un avance por otro camino —p.ej. rekick de foreground— lo oculta solo).
            if autoResumeState.showManualRetry {
                YalaPrimaryButton(L10n.Welcome.Cloud.retry) {
                    launchFlow { await retryAdoptResume() }
                }
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.top, DS.Spacing.sm)
                .accessibilityIdentifier("welcome_cloud_adopt_retry")
            }
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
                // En el ALTA no hay máquina de migración que pollear: lo que se reintenta es el
                // CLAIM, idempotente por contrato (§f.1, el re-claim del mismo device colapsa a
                // `created`). Llamar a `pollLeader()` aquí conduciría una máquina que born-cloud no
                // tiene y dejaría la pantalla clavada.
                switch entry {
                case .reentry:   launchFlow { await retryLeaderPoll() }
                case .bornCloud: launchFlow { await runBornCloudFlow() }
                }
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

    /// R2 · el alta terminó y NO hay nada que reabrir. Es una pantalla de continuidad, no una terminal de
    /// espera: por eso lleva CTA y no un texto pasivo. El copy no promete sincronización todavía —el motor
    /// acaba de arrancar— sino que la cuenta está lista, que es lo único medido en este instante.
    private var bornCloudReadyContent: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.9))
                .accessibilityHidden(true)
            Text(L10n.Welcome.BornCloud.readyTitle)
                .font(DS.Typography.title2)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(L10n.Welcome.BornCloud.readyBody)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.xl)
            YalaPrimaryButton(L10n.Welcome.BornCloud.readyCta) {
                onBornCloudCompleted()
            }
            .padding(.horizontal, DS.Spacing.xl)
            .accessibilityIdentifier("welcome_born_cloud_ready_cta")
        }
        .accessibilityIdentifier("welcome_born_cloud_ready")
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

    /// Sign-in con el método elegido. Devuelve `false` cuando NO hay que seguir (y deja la fase ya
    /// puesta). Extraído para que el alta y la re-entrada compartan literalmente los mismos catches
    /// —incluida la asimetría Apple/Google, que no es cosmética— en vez de tener dos copias que se
    /// separen a la primera.
    private func ensureSignedIn() async -> Bool {
        // Retry con sesión ya viva (falló solo el paso siguiente): no re-pedir Face ID.
        guard !CloudAuthService.shared.hasSession else { return true }
        do {
            try await CloudAuthService.shared.signIn(with: provider)
            return true
        } catch CloudAuthError.cancelled {
            // Cancel EXPLÍCITO (Google) → volver al intro en silencio (el user re-tapea).
            phase = .intro
            return false
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
            }
            return false
        }
    }

    // MARK: - A5 · el alta born-cloud

    /// El encadenado del ALTA, y **el orden ES el contrato**: sign-in (el consent ya se aceptó, es
    /// quien invoca esto) → claim → par `.cloud` + terminal de relanzamiento.
    ///
    /// Lo que NO hace, y no por olvido: no marca los flags de onboarding (el onboarding NORMAL corre
    /// después del relanzamiento — `hasShownWelcomeChooser` ya quedó `true`, así que
    /// `presentNextOnboardingScreen` va directo a `OnboardingView`), no journalea ninguna fase (el
    /// journal se queda en `notStarted`, que YA es estable para el runtime) y no conduce ninguna
    /// máquina de migración: en born-cloud no hay corpus que mover.
    private func runBornCloudFlow() async {
        phase = .creating
        guard await ensureSignedIn() else { return }

        let service = BornCloudSignUpService(session: LiveCloudSessionProvider())
        switch BornCloudSignUpFlow.step(for: await service.signUp()) {
        case .activateStorageAndRelaunch:
            // El par se escribe ANTES de sembrar nada — en born-cloud es trivialmente cierto porque
            // no hay nada pre-relanzamiento que sembrar. La primitiva DEVUELVE la fase terminal;
            // jamás mata el proceso.
            //
            // R2: qué terminal sale de ahí lo decide el TESTIGO de mount de este proceso, no la pantalla.
            // Se le pasa desde aquí (y no lo lee la primitiva por dentro) para que la decisión sea
            // inyectable y su tabla, testeable sin montar un container.
            phase = service.activateBornCloudStorage(
                mountedDecision: SwiftDataConfiguration.personalStoreMountedDecision,
                context: modelContext)
        case .continueAsReturningUser:
            // Variante A de §f.1: la cuenta ya estaba poblada ⇒ **NO se siembra**. Con la sesión ya
            // viva, `runSignInFlow` salta el sign-in y sigue por el returning-user que YA existe
            // (`exists` → guard cross-cuenta → adopt). Sin cover nuevo y sin pantalla nueva.
            await runSignInFlow()
        case .show(let terminal):
            phase = terminal
        case .releaseSessionAndShowError:
            // 401: soltar la sesión ANTES de mostrar el error, o el retry la reusaría muerta.
            await CloudAuthService.shared.signOut()
            phase = .error(retryable: true)
        }
    }

    // MARK: - Re-entrada (H4)

    private func runSignInFlow() async {
        phase = .checking
        guard await ensureSignedIn() else { return }

        guard let userID = CloudAuthService.shared.currentUserID,
              let jwt = await CloudAuthService.shared.accessToken() else {
            phase = .error(retryable: true)
            return
        }

        // `CloudAccountClient` SIN `attestProvider` a propósito: `GET /account/exists` va por `requireUser`
        // (`gateway/src/sync/account.ts:256`). Es PRE-SESIÓN de nube por definición — cablear attest aquí
        // es justo lo que puede romper el alta.
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
                MetricsService.cloudSignInProviderMismatch()
                phase = .providerMismatch(knownProvider: knownProvider)
            case .proceed:
                phase = .notFound
            }
        case .failed(let retryable):
            phase = .error(retryable: retryable)
        case .accountFound:
            let decision = CrossAccountEntryGuardLogic.decide(
                hasLocalData: hasLocalDataNow(),
                sameAccountClaimExists: CloudClaimActionStore.shared.action(forUserID: userID) != nil,
                accountExists: true,
                secondarySessionEnabled: CloudSyncFlags.secondarySessionEntryAvailable)
            switch decision {
            case .blockedForeignData:
                // M0: aquí NO se escribe el consent — la tabla dice `.never`. La sesión se descarta sin
                // dejar rastro en el device y el registro GDPR real de esa cuenta vive en SU backend;
                // escribirlo antes de saber la ruta era el bug del chip (caía en el iKV del dueño).
                await CloudAuthService.shared.signOut()
                phase = .blockedForeignData
            case .proceedSecondarySession:
                // M0: tampoco aquí — la escritura va en `confirmSecondaryEntry`, DESPUÉS del descriptor
                // (es el único punto donde el behavior de prefs resuelve `.localOnly`).
                //
                // M1 belt: invariante estructural — durante el Welcome post sign-out la key
                // PERSISTIDA es `.icloud` (el sign-out cloud siempre la resetea antes de llegar
                // aquí). Si no lo es, hay estado corrupto: delatarlo temprano, jamás armar.
                guard StorageModePersistence.read() == .icloud else {
                    await CloudAuthService.shared.signOut()
                    phase = .error(retryable: false)
                    return
                }
                phase = .secondaryConfirm
            case .proceed:
                // M0: la ruta ya se conoce y es la del PROPIO dueño ⇒ el epoch se escribe AQUÍ, antes de
                // arrancar la máquina: el paso 5-bis de `adoptBackendAccount` re-emite el epoch
                // PERSISTIDO y sin él cae al fallback `now()`, que es la hora de FIN del adopt.
                persistConsentIfDue(at: .beforeAdopt, routedBy: decision)
                onAdoptStarted()
                phase = .adopting(fraction: 0)
                // Detector de aparcada FRESCO por adopt (un retry tras `.error` no debe
                // heredar attempts/showManualRetry del ciclo anterior).
                autoResumeState = WelcomeAdoptAutoResume.State()
                lastObservedPhase = nil
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
            return
        }
        // M1 · el slot es de UNA cuenta. Con el descriptor de OTRA invitada vivo, sus archivos
        // `-Secondary` siguen en disco y `activate(userID:)` se limitaría a reescribir el nombre del
        // ocupante: el boot montaría el corpus de ella bajo esta sesión. Se bloquea con la pantalla
        // que ya dice ese hecho (`blockedForeignData`) y se suelta la sesión SIWA, igual que la otra
        // salida bloqueada del guard — dejarla colgada es lo que `runSignInFlow` evita a mano.
        // Va en la ENTRADA y JAMÁS en el mount, que honra el descriptor incondicionalmente.
        if SecondarySlotOccupancyLogic.decide(
            occupantUserID: SecondarySessionStore.activeUserID(),
            enteringUserID: userID) == .occupiedByOther {
            launchFlow {
                await CloudAuthService.shared.signOut()
                phase = .blockedForeignData
            }
            return
        }
        SecondaryEntryLogic.begin(
            userID: userID,
            recordClaim: { CloudClaimActionStore.shared.record(.routeReturningUser, forUserID: $0) },
            activateDescriptor: { SecondarySessionStore.activate(userID: $0) },
            markOnboardingFlags: onSecondaryEntryFlagsMarked)
        // M0: DESPUÉS del descriptor, y ese orden ES el fix. `PrefsSyncBehavior.resolve` pregunta por el
        // descriptor VIVO en CADA llamada, así que solo a partir de `activate` el epoch de la invitada
        // resuelve `.localOnly` — ni el iKV del dueño ni el outbox de nadie. Un paso antes se propagaría
        // a los otros devices del Apple ID del dueño.
        persistConsentIfDue(at: .afterSecondaryDescriptor, routedBy: .proceedSecondarySession)
        CloudSyncBreadcrumb.secondaryEntryArmed()
        phase = .relaunchSecondary
    }

    /// Deriva la fase de pantalla del uiState de la máquina cada segundo
    /// (molde del refresh de StorageSettingsView) hasta un estado terminal.
    /// H-2026-07-17-5: además DETECTA el drive aparcado (transient a mitad de página →
    /// `startAdoptWithExistingSession` retornó con el journal transicional) y re-conduce
    /// solo por el MISMO camino del boot/rekick (`resumeIfNeeded`, guard de reentrada A2).
    /// El `await` del auto-resume es ESTRUCTURADO dentro del task del poll: el cancel de
    /// onDisappear le propaga igual que al sleep (sin Tasks huérfanos). Durante el drive
    /// del resume el poll no tickea (UI congelada en la última fase) — paridad con el
    /// drive inicial, y la pre-espera larga la cubre el hint `resumeWaitingForImport`.
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
                return
            default:
                break
            }
            await evaluateAutoResume(controller: controller, screenPhase: next)
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return  // task cancelada (view desmontada)
            }
        }
    }

    /// Un tick del detector de aparcada (lógica pura en `WelcomeAdoptAutoResume`).
    private func evaluateAutoResume(
        controller: CloudMigrationController,
        screenPhase: CloudWelcomeSignInPhase
    ) async {
        let journaled = controller.journaledPhase
        let advanced = lastObservedPhase != nil && lastObservedPhase != journaled
        lastObservedPhase = journaled
        var isAdopting = false
        if case .adopting = screenPhase { isAdopting = true }
        let (newState, fire) = WelcomeAdoptAutoResume.tick(
            isAdopting: isAdopting,
            isWorking: controller.isWorking,
            machineAdvanced: advanced,
            state: autoResumeState)
        // Breadcrumb del agotamiento SOLO en la transición false→true (sin spam por tick).
        if newState.showManualRetry && !autoResumeState.showManualRetry {
            CloudSyncBreadcrumb.welcomeAdoptAutoResumeExhausted(phase: "\(journaled)")
        }
        autoResumeState = newState
        guard fire else { return }
        // Belt de paridad con `rekickIfParked`: jamás conducir con el wipe de sign-out armado.
        guard !StorageModePersistence.isSignOutWipeArmed() else { return }
        CloudSyncBreadcrumb.welcomeAdoptAutoResume(attempt: newState.attempts, phase: "\(journaled)")
        await controller.resumeIfNeeded()
    }

    /// Retomar manual (autos agotados). Espejo de `retryLeaderPoll`: cancela el poll viejo
    /// (via launchFlow), conduce y re-pollea. Con el journal normalizado a `notStarted` sin
    /// efectos (`uiState == .idle`, adopt perdido antes del claim) `resumeIfNeeded` sería un
    /// no-op perpetuo → re-arranca el adopt con la sesión aún viva (este camino nunca la soltó);
    /// la decisión de RE-claimear queda detrás del gesto del usuario, jamás en el auto.
    private func retryAdoptResume() async {
        autoResumeState = WelcomeAdoptAutoResume.State()
        lastObservedPhase = nil
        guard let controller = CloudMigrationController.shared else {
            phase = .error(retryable: true)
            return
        }
        controller.refresh()
        if case .idle = controller.uiState {
            await controller.startAdoptWithExistingSession()
        } else {
            await controller.resumeIfNeeded()
        }
        await pollAdoptProgress()
    }

    private func retryLeaderPoll() async {
        phase = .adopting(fraction: 0)
        await CloudMigrationController.shared?.pollLeader()
        await pollAdoptProgress()
    }
}

// MARK: - Botón SIWA nativo

/// `ASAuthorizationAppleIDButton` (obligado por HIG/App Review 4.8 — aquí SIWA es el único
/// login). El flujo real (nonce, exchange, captura de perfil) vive en
/// `CloudAuthService.signInWithApple()`; este botón es solo el afford visual + target-action.
///
/// W4: el `type` lo decide el contexto y NO tiene default, igual que el `purpose` del botón de
/// Google — el par tiene que decir lo mismo o la pantalla se contradice a sí misma. Los gemelos de
/// `StorageSignInChooserView` y `GroupsSignInView` conservan su `.signIn` fijo: sus pantallas están
/// fuera del alcance del punto 15, y ahí sus dos botones siguen diciendo lo mismo entre ellos.
private struct AppleSignInButton: UIViewRepresentable {
    let type: ASAuthorizationAppleIDButton.ButtonType
    let action: () -> Void

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: type, style: .white)
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

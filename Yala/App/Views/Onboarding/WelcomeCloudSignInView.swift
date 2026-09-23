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
        /// Re-entrada a una cuenta que ya existe. El provider lo eligió la card del chooser (o la salida
        /// «Iniciar sesión con…» del mismatch) y se setea EXPLÍCITO por el productor: jamás se hereda el del
        /// intento previo.
        case reentry(CloudSignInProvider)
        /// **Paso 6 · «Soy nuevo» con el faro puesto** (ADR 2026-09-09 §10). El faro dice que este Apple ID
        /// ya tiene una cuenta en la nube y la pantalla ENCAMINA a entrar con ella, sin decidir por la
        /// persona: el intro dice de dónde viene («Este Apple ID ya tiene una cuenta de Yala creada con …»)
        /// y ofrece «Crear otra cuenta». `accountProvider` es el método SEGÚN EL FARO; `nil` = no lo dice.
        ///
        /// Caso propio y no un `.reentry` con un flag: su productor es otro (el faro, no una card) y cada
        /// productor del cover escribe su `Entry` EXPLÍCITO — un `Bool` aparte en `ContentView` se heredaría
        /// del intento anterior. Después del sign-in es una re-entrada como la otra.
        case beaconRouted(accountProvider: CloudSignInProvider?)
        /// Alta born-cloud desde la card «nube» de «Soy nuevo». El provider NO viene decidido: se
        /// elige aquí, con los dos botones de prominencia equivalente (guideline 4.8).
        case bornCloud
    }

    let entry: Entry
    /// **Bloque [I]** · esta pantalla se abrió con la sesión YA firmada en otra puerta, así que arranca en
    /// el consentimiento en vez de en el intro.
    ///
    /// Sin esto, la adopción desde Grupos le pedía **dos gestos** a quien solo quería ver un grupo: un
    /// «Iniciar sesión con Apple» que acababa de hacer hace dos segundos, y luego el consentimiento. La
    /// decisión de Jürgen (2026-09-09) es explícita: «sin aviso, sin banner y sin preguntar… **no añadas
    /// ceremonia por prudencia**». El tap redundante es ceremonia y se va.
    ///
    /// **El consentimiento se queda**, y no por descuido: Jürgen lo llamó «el único paso que no se
    /// recorta» al decidir el `.notFound`, y adoptar mueve datos personales a la nube — es el registro
    /// GDPR de esa cuenta. Un gesto, y es el que él protegió.
    var startsAtConsent: Bool = false
    /// **Bloque [I]** · el estado de sesión de este dispositivo, evaluado EN el momento de la decisión y
    /// no al montar la pantalla: entre una cosa y otra puede asentar un import de iCloud, o el usuario
    /// puede llegar aquí desde la puerta de Grupos con el onboarding ya completado.
    let deviceStateNow: @MainActor () -> CloudIdentityRoutingLogic.DeviceSessionState
    /// Corpus personal en el device, evaluado EN el momento de la decisión (S5: el
    /// mirror de iCloud puede estar re-importando en background durante el Welcome —
    /// un snapshot sería stale). Input del guard cross-cuenta F0-C.
    let hasLocalDataNow: @MainActor () -> Bool
    /// ContentView marca onboarding completado (restore-skip) ANTES del adopt.
    var onAdoptStarted: () -> Void
    /// M1 (D1): variante para la ENTRADA SECUNDARIA — marca los flags SIN trial pendiente
    /// (la invitada no recibe la oferta del device del dueño) ni `markAsNewInstall` (el
    /// checklist es estado device-global del dueño).
    /// Salida a la app (waitingLeader → "Continuar a la app").
    var onFinishedToApp: () -> Void
    /// R2: el alta born-cloud terminó **sin relanzamiento** (el mount ya era compatible) ⇒ cerrar este
    /// cover y presentar el onboarding NORMAL. Distinto de `onFinishedToApp`, que solo cierra: sin este
    /// callback el `onDismiss` del cover devolvería al usuario al chooser (`!hasCompletedOnboarding`),
    /// que es justo el sitio del que acaba de salir.
    var onBornCloudCompleted: () -> Void
    /// **Bloque [I]** · el backend dijo que esta cuenta solo lleva grupos, así que NO se adopta: se cierra
    /// este cover y el recorrido sigue por la mini-app de Grupos con la sesión ya viva.
    ///
    /// Es un callback y no un `phase` propio porque lo que sigue no es una pantalla de este flujo: es la
    /// cadena de Grupos, cuyo anchor es de `GroupsBackendInviteModifier`. Presentarla desde aquí sería el
    /// segundo anchor que la regla (4) de Presentaciones prohíbe.
    ///
    /// `offersFullActivation` (paso 8) distingue los dos destinos de [I] que llegan aquí: quien entró por
    /// «Primera vez → nube» venía a estrenar Yala entero y su cuenta resultó ser de grupos, así que cuando su
    /// sesión solo-grupos quede montada se le pone delante «Activar Yala completo» (ADR §7).
    var onEnterGroupsOnly: (_ offersFullActivation: Bool) -> Void
    /// **Paso 6** · «Crear otra cuenta» desde la entrada encaminada por el faro: cerrar este cover y volver
    /// a «Elige dónde quieres guardar tus datos» ENTERO —las dos cards, privado incluido (decisión de
    /// Jürgen 2026-09-09, que deroga el «card nube activa» del ticket)—. Es un callback y no una fase propia
    /// porque ese chooser es un step del `WelcomeFlowContainer`, que es OTRO cover: presentarlo desde aquí
    /// sería el segundo anchor de la regla (4) de Presentaciones.
    var onCreateAnotherAccount: () -> Void
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
    /// Bloque [I] + paso 6 · la pantalla se reencaminó a sí misma: al alta (desde «No encontramos una cuenta»
    /// o desde el «Crear cuenta con…» del mismatch) o a entrar con otro método (el «Iniciar sesión con…» del
    /// mismatch). `nil` = manda `entry`.
    @State private var entryOverride: Entry?
    /// Bloque [I] · latch del auto-arranque en el consent (ver el `onAppear`). Sin él, cancelar el consent
    /// lo reabre en bucle: sus condiciones vuelven a cumplirse todas.
    @State private var didAutoOpenConsent = false
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
        .onAppear {
            // La sesión ya está firmada en otra puerta ⇒ el intro no tiene nada que pedir. Se abre el
            // consent directamente y su `onAccept` sigue por `runFlowAfterConsent`, igual que si el
            // usuario hubiera tapeado el botón.
            //
            // **One-shot, y no un guard por estado.** SwiftUI invoca `onAppear` más de una vez, y las tres
            // condiciones «obvias» (`startsAtConsent`, fase inicial, nada presentado) vuelven a ser TODAS
            // ciertas en cuanto la persona CANCELA el consent: se le reabriría en bucle y no habría forma
            // de llegar al intro. Con el latch, cancelar deja el intro del alta, que es la salida.
            guard startsAtConsent, !didAutoOpenConsent else { return }
            didAutoOpenConsent = true
            showConsent = true
        }
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

    /// La entrada que manda AHORA. Es `entry` salvo que la pantalla se haya reencaminado a sí misma.
    ///
    /// **Los reencaminamientos son tres, y los tres salen de una pantalla sin nada comprometido.** El del bloque
    /// [I], `.notFound` → alta: quien entró por «Ya tengo cuenta» y no tiene ninguna consigue un botón que le
    /// crea la cuenta con el proveedor que ya eligió. Y los dos del paso 6, las salidas del mismatch: alta con
    /// el método que la persona usó, o re-entrada con el del faro. Los dos que llevan al alta solo existen si el
    /// teléfono puede darse de alta (`WelcomeNewOptionsGate.offersCloudSignUp`). Se hace con un `@State` y no re-presentando el cover con otro `entry` a propósito: el cover
    /// es el mismo, así que cambiarlo desde fuera dejaría la `phase` de esta pantalla en `.notFound` —el
    /// `@State` no se reinicia porque la identidad de la vista no cambia— y el usuario vería el mismo
    /// callejón. Y una vista hermana sería un segundo anchor, que es lo que el docblock de arriba prohíbe.
    private var activeEntry: Entry { entryOverride ?? entry }

    /// Cuál de las cinco puertas del ADR §7 es esta pantalla. Las dos que sirve están en la tabla con
    /// nombres propios porque su celda «nueva» es distinta: el alta la CREA, la re-entrada ofrece crearla.
    private var identityGate: CloudIdentityRoutingLogic.Gate {
        switch activeEntry {
        case .reentry:   return .welcomeExistingAccount
        // Paso 6: la persona tocó «Soy nuevo», y ésa es la puerta física. Hoy da los mismos destinos que la
        // de «Ya tengo cuenta» —la cuenta nueva se resuelve ANTES de la tabla, con el faro—; cuando el
        // ticket 8 separe los dos «solo grupos», le ofrecerá Yala completo a quien venía a estrenarlo.
        case .beaconRouted: return .welcomeFirstTimeCloud
        case .bornCloud: return .welcomeFirstTimeCloud
        }
    }

    /// Método con el que se va a firmar. En `.reentry` lo trae el `Entry`; en `.bornCloud` es el que
    /// el usuario acaba de tapear. El `?? .apple` no es una elección silenciosa: el flujo del alta no
    /// arranca sin pasar por un botón, y ese botón siempre escribe `chosenProvider`.
    private var provider: CloudSignInProvider {
        switch activeEntry {
        case .reentry(let p): return p
        case .beaconRouted(let accountProvider):
            return WelcomeAccountChoiceLogic.signInProvider(forBeaconAccount: accountProvider)
        case .bornCloud:      return chosenProvider ?? .apple
        }
    }

    /// Ruta que se registra con el consent (telemetría §j.4). El alta tiene la suya para que el
    /// dashboard pueda separar «cuánta gente entra a una cuenta que ya tenía» de «cuánta se da de alta».
    private var consentPath: CloudMigrationController.ConsentPath {
        switch activeEntry {
        case .reentry:   return .adopt
        // La entrada que encamina el faro es una re-entrada: su consentimiento es el del adopt, y el
        // dashboard la cuenta con quien entra a una cuenta que ya tenía, no con las altas.
        case .beaconRouted: return .adopt
        case .bornCloud: return .bornCloud
        }
    }

    /// M0 · quién ESCRIBE el registro GDPR del consent. El alta born-cloud ya conoce su ruta al aceptar
    /// (no pasa por el guard cross-cuenta) y su claim la VERIFICA (paso 5 de `BornCloudSignUpService`),
    /// así que ahí escribe la pantalla, como siempre. La RE-ENTRADA no: su ruta la decide el guard
    /// DESPUÉS del sign-in, y escribir antes deja el epoch de la invitada en el iKV del DUEÑO.
    private var persistsConsentOnAccept: Bool {
        switch activeEntry {
        case .bornCloud: true
        case .reentry:   false
        // La entrada que encamina el faro ES una re-entrada: su ruta también la decide el guard DESPUÉS del
        // sign-in, así que tampoco escribe al aceptar.
        case .beaconRouted: false
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
        switch activeEntry {
        case .reentry, .beaconRouted: await runSignInFlow()
        case .bornCloud:              await runBornCloudFlow()
        }
    }

    /// Back solo en fases donde nada está comprometido; adopt en vuelo o relaunch = sin salida.
    private var canGoBack: Bool {
        switch phase {
        // `.providerMismatch`: sesión ya soltada y sin claim — nada comprometido.
        // `.accountBlocked`: el claim fue RECHAZADO (403) — tampoco se creó nada, y sin retry ni
        // salida sería un callejón (mismo criterio que `.blockedForeignData`).
        case .intro, .notFound, .blockedForeignData, .error, .providerMismatch, .accountBlocked: true
        // `.creating`: el claim está en vuelo y puede CREAR la cuenta server-side — salir a mitad
        // dejaría al usuario sin saber si se dio de alta. Mismo criterio que `.checking`.
        // `.bornCloudReady` es terminal como `.relaunch`: la cuenta está creada y el par escrito.
        // `.reentryReady` lo es por la otra mitad del mismo hecho: la cuenta ya existía y es el ADOPT
        // el que terminó — el par está escrito y el motor corriendo, así que no hay a dónde volver.
        case .checking, .creating, .adopting, .waitingLeader, .relaunch, .bornCloudReady,
             .reentryReady: false
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
        case .reentryReady:
            reentryReadyContent
        case .notFound:
            notFoundContent
        case .providerMismatch(let exits):
            providerMismatchContent(exits)
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
                    // firma. **Y desde el 2026-09-11 tampoco tiene gemela**: la puerta de Grupos-first
                    // dejó de bloquear por corpus —vuelve al neutro— así que este bloqueo se quedó como
                    // la única superficie del hecho «este dispositivo tiene datos de otra cuenta», y
                    // sigue vivo porque aquí sí hay alguien conectando una cuenta distinta. El
                    // identifier va puesto para que el device-QA pueda anclarse a él sin recompilar y
                    // para que el día que exista un seam de sign-in el test no dependa de texto
                    // localizado.
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
        case .accountBlocked:
            // Icono de CUENTA y no de wifi: el 403 llega con la conexión perfectamente sana, y el copy
            // de `.error` —que empieza por «Revisa tu conexión»— mandaba a la gente a mirar su router.
            // Sin botón de reintentar a propósito: esperar no despierta una cuenta bloqueada.
            messageContent(
                icon: "person.crop.circle.badge.xmark",
                title: L10n.Welcome.Cloud.accountBlockedTitle,
                body: L10n.Welcome.Cloud.accountBlockedBody(AppConstants.supportEmail))
                .accessibilityIdentifier("welcome_cloud_account_blocked")
        }
    }

    @ViewBuilder
    private var introContent: some View {
        switch activeEntry {
        case .reentry, .beaconRouted: reentryIntro
        case .bornCloud:              bornCloudIntro
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
                Text(reentrySubtitle.text)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.lg)
                    .accessibilityIdentifier(reentrySubtitle.identifier)
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
            // **Paso 6 · el faro ENCAMINA, no decide** (ADR §10). Solo en la entrada a la que llevó el faro:
            // quien entró por la card «Ya tengo cuenta» dijo que tenía una, y si no la tiene, «No encontramos
            // una cuenta» ya le ofrece crearla cuando el teléfono puede darse de alta. Botón secundario, en el tono
            // de «Continuar a la app»:
            // encaminar sigue siendo lo que se propone.
            if isBeaconRouted {
                Button(L10n.Welcome.Cloud.createAnother) {
                    DS.Haptic.selection()
                    onCreateAnotherAccount()
                }
                .font(DS.Typography.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .accessibilityIdentifier("welcome_cloud_create_another")
            }
        }
    }

    /// ¿Esta pantalla la abrió el faro? Se lee de `activeEntry` y no de `entry`: si la pantalla se reencaminó
    /// a sí misma (al alta, o a entrar con otro método desde el mismatch), la oferta ya no aplica.
    private var isBeaconRouted: Bool {
        if case .beaconRouted = activeEntry { return true }
        return false
    }

    /// El subtítulo del intro de re-entrada. **El encaminado por el faro dice de dónde viene** (decisión de
    /// Jürgen 2026-09-09: «nombra el proveedor y nada más», sin correo); con el método desconocido, la variante
    /// genérica — jamás se afirma un método que el faro no dice.
    ///
    /// El nombre sale de `accountProvider` —lo que dice el FARO— y nunca de `provider`, que ya lleva el
    /// fallback a Apple del botón: tomarlo de ahí haría decir «creada con Apple» a un faro sin método. El
    /// identificador separa las dos variantes para que el XCUITest pueda verlo sin leer texto localizado.
    private var reentrySubtitle: (text: String, identifier: String) {
        if case .beaconRouted(let accountProvider) = activeEntry {
            guard let name = ProviderMismatchLogic.displayName(forProvider: accountProvider?.rawValue) else {
                return (L10n.Welcome.Cloud.beaconOriginGeneric, "welcome_cloud_beacon_origin_generic")
            }
            return (L10n.Welcome.Cloud.beaconOrigin(name), "welcome_cloud_beacon_origin")
        }
        let subtitle = provider == .google ? L10n.Welcome.Cloud.subtitleGoogle : L10n.Welcome.Cloud.subtitle
        return (subtitle, "welcome_cloud_reentry_subtitle")
    }

    /// **Paso 6 · el mismatch ya no es una pared** (ADR 2026-09-09 §10). Informa con qué método se creó la
    /// cuenta que recuerda el faro y ofrece las DOS salidas del veredicto: entrar con ese método, o crear una
    /// cuenta con el que la persona acaba de usar. La flecha de atrás sigue (`canGoBack`), pero ya no es la
    /// única forma de avanzar.
    ///
    /// **La de crear pasa por la puerta del alta** (`WelcomeNewOptionsGate.offersCloudSignUp`, la de la card «Tu cuenta
    /// en la nube»). Sin ella —un teléfono sin App Attest, o el kill del alta— queda una sola salida hacia delante, la de
    /// entrar, y el cuerpo («Tu cuenta de Yala se creó con …») sigue siendo cierto.
    ///
    /// Botones de MARCA con su verbo por salida: el del método del faro dice INICIAR SESIÓN (esa cuenta
    /// existe) y el del método usado dice CREAR (con él no la hay). Es la única pantalla del Welcome con un
    /// verbo distinto en cada botón, y a propósito: son dos acciones distintas.
    ///
    /// El identificador del mensaje va SOLO en su bloque: puesto en el contenedor pisaría el de los botones
    /// (`.claude/rules/testing.md`).
    private func providerMismatchContent(_ exits: ProviderMismatchLogic.Exits) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            messageContent(
                icon: "person.crop.circle.badge.exclamationmark",
                title: L10n.Welcome.Cloud.providerMismatchTitle,
                body: providerMismatchBody(accountProvider: exits.accountProvider))
                .accessibilityIdentifier("welcome_cloud_provider_mismatch")
            VStack(spacing: DS.Spacing.md) {
                // Las acciones toman el método de `exits` y no un literal por `case`: así un botón no puede firmar
                // con un método distinto del que pinta (lente C de la review).
                switch exits.signInWith {
                case .apple:
                    AppleSignInButton(type: .signIn) {
                        DS.Haptic.selection()
                        signInWithAccountMethod(exits.signInWith, from: exits)
                    }
                    .frame(height: 50)
                    .accessibilityIdentifier("welcome_cloud_mismatch_sign_in")
                case .google:
                    GoogleSignInButton(variant: .light, purpose: .signIn) {
                        DS.Haptic.selection()
                        signInWithAccountMethod(exits.signInWith, from: exits)
                    }
                    .frame(height: 50)
                    .accessibilityIdentifier("welcome_cloud_mismatch_sign_in")
                }
                // La salida de CREAR pasa por la puerta del alta; la de entrar, no: entrar a una cuenta que ya existe es
                // otra decisión.
                if WelcomeNewOptionsGate.offersCloudSignUp {
                    switch exits.createWith {
                    case .apple:
                        AppleSignInButton(type: .signUp) {
                            DS.Haptic.selection()
                            switchToSignUp(with: exits.createWith)
                        }
                        .frame(height: 50)
                        .accessibilityIdentifier("welcome_cloud_mismatch_create")
                    case .google:
                        GoogleSignInButton(variant: .light, purpose: .signUp) {
                            DS.Haptic.selection()
                            switchToSignUp(with: exits.createWith)
                        }
                        .frame(height: 50)
                        .accessibilityIdentifier("welcome_cloud_mismatch_create")
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
        }
    }

    /// Body del mismatch R9: con provider CONOCIDO interpola su nombre visible; nil o
    /// desconocido → copy genérico (jamás interpolar un rawValue del wire en UI).
    private func providerMismatchBody(accountProvider: CloudSignInProvider?) -> String {
        if let name = ProviderMismatchLogic.displayName(forProvider: accountProvider?.rawValue) {
            return L10n.Welcome.Cloud.providerMismatchBody(name)
        }
        return L10n.Welcome.Cloud.providerMismatchBodyGeneric
    }

    /// «Iniciar sesión con <método del faro>», desde el mismatch. **Sin volver a pedir el consentimiento**
    /// (Paso 0, D6): es la MISMA ruta —entrar a una cuenta que existe— que la persona acaba de consentir, y
    /// su registro sigue pendiente hasta que el guard cross-cuenta decida (`consentPendingPersistence`). Solo
    /// cambia el método: la pantalla pasa a una re-entrada EXPLÍCITA con él y relanza el flujo, que empieza
    /// por firmar.
    ///
    /// **Si la persona cancela la hoja de Apple o de Google, vuelve a ESTA pantalla** (lente A de la review):
    /// `ensureSignedIn` la dejaría en el intro de una re-entrada normal, sin «Crear cuenta con…» y pidiéndole
    /// otra vez el consentimiento.
    ///
    /// Dos defensas para un mismatch que llegara desde el ALTA, hoy inalcanzable (la variante B del claim es
    /// solo de la re-entrada) pero mapeado por `BornCloudSignUpFlow`: el alta NO suelta la sesión, así que se
    /// suelta aquí antes de firmar —si no, `ensureSignedIn` reusaría la de Google para «entrar con Apple»—; y
    /// su consentimiento se escribió al aceptar, para OTRA ruta, así que el del adopt se vuelve a pedir.
    private func signInWithAccountMethod(_ method: CloudSignInProvider, from exits: ProviderMismatchLogic.Exits) {
        entryOverride = .reentry(method)
        let consentStillPending = consentPendingPersistence
        launchFlow {
            if CloudAuthService.shared.hasSession { await CloudAuthService.shared.signOut() }
            guard consentStillPending else {
                phase = .intro
                showConsent = true
                return
            }
            await runSignInFlow()
            if phase == .intro { phase = .providerMismatch(exits) }
        }
    }

    /// **Bloque [I] + paso 6** · reencamina ESTA pantalla al alta con el método ya elegido y abre su
    /// consentimiento. La usan las dos salidas que crean cuenta —el CTA de «No encontramos una cuenta» y el
    /// «Crear cuenta con…» del mismatch— y es UNA función para que no diverjan.
    ///
    /// **Aquí no se vuelve a preguntar si el teléfono puede darse de alta**: las dos salidas solo se pintan dentro de la
    /// puerta del alta (`WelcomeNewOptionsGate.offersCloudSignUp`), y un guard en esta función dejaría un botón muerto el
    /// día que pintar y pulsar no coincidieran. Por eso toda llamada nueva va dentro de esa puerta, y
    /// `WelcomeNewChooserWiringTests` lo exige a cada llamada del fichero.
    ///
    /// La sesión ya se soltó en las dos (`signOut()` en la rama de cuenta nueva) y **se queda soltada**: lo
    /// que viaja al alta es el método, no la sesión — dejarla viva haría que un «atrás» + otra card la
    /// reusara (`ensureSignedIn` salta con `hasSession`) y la persona entraría con una cuenta que no eligió.
    /// La fase vuelve al intro para que cerrar el consentimiento aterrice en el intro del ALTA, con sus dos
    /// botones, y no otra vez en la pantalla de la que se sale.
    private func switchToSignUp(with signUpProvider: CloudSignInProvider) {
        chosenProvider = signUpProvider
        entryOverride = .bornCloud
        phase = .intro
        showConsent = true
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
                switch activeEntry {
                case .reentry, .beaconRouted: launchFlow { await retryLeaderPoll() }
                case .bornCloud:              launchFlow { await runBornCloudFlow() }
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
        readyContent(id: "welcome_born_cloud_ready", action: onBornCloudCompleted)
    }

    /// R3 · la RE-ENTRADA terminó y no hay nada que reabrir. **Misma pantalla que el alta y a propósito**
    /// —mismo copy, mismo icono, mismo botón— porque el hecho que anuncia es el mismo: la cuenta quedó
    /// lista en este proceso. Lo único que cambia es a dónde lleva el botón.
    ///
    /// `onFinishedToApp` y NO `onBornCloudCompleted`: quien re-entra ya tiene `hasCompletedOnboarding`
    /// marcado por `onAdoptStarted` —que existe justamente para que el seed del onboarding no corra sobre
    /// una cuenta existente— así que su siguiente pantalla es la app. Es también el destino EXACTO al que
    /// llegaba antes de este chip: tras el relanzamiento, `checkInitialSyncState` ve el flag puesto y sale
    /// por `runReturningUserPostChecks` sin pasar por `presentNextOnboardingScreen`. El chip le ahorra el
    /// relanzamiento sin cambiarle el destino, que era la condición de la decisión del 6-sep.
    private var reentryReadyContent: some View {
        readyContent(id: "welcome_reentry_ready", action: onFinishedToApp)
    }

    /// El cuerpo compartido de las dos terminales de «listo». **Una sola definición a propósito:** son la
    /// MISMA pantalla para el usuario y lo único que las separa es a dónde va su botón. Duplicar el layout
    /// dejaba dos copias del mismo copy que divergirían al primer retoque — que es exactamente la clase de
    /// deriva que el ticket de este chip vino a corregir en otro sitio.
    ///
    /// El identificador de accesibilidad SÍ es distinto por terminal: el device-QA necesita distinguirlas,
    /// porque el defecto que se comprueba ahí es precisamente cuál de las dos salidas se tomó.
    private func readyContent(id: String, action: @escaping () -> Void) -> some View {
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
            YalaPrimaryButton(L10n.Welcome.BornCloud.readyCta, action: action)
                .padding(.horizontal, DS.Spacing.xl)
                .accessibilityIdentifier("\(id)_cta")
        }
        .accessibilityIdentifier(id)
    }

    /// «No encontramos una cuenta». **El botón de crearla pasa por la puerta del alta**, la misma de la card «Tu cuenta en
    /// la nube» (`WelcomeNewOptionsGate.offersCloudSignUp`). Sin ella —un teléfono sin App Attest, o el kill del alta— el
    /// botón principal es «Volver», el mismo del bloqueo por datos de otra cuenta, y lleva a donde la flecha: decisión de
    /// Jürgen del 2026-09-16, para que la pantalla no vuelva a ser el callejón con la salida en una esquina que el bloque
    /// [I] quitó. El copy no promete crear nada, así que sigue siendo cierto con cualquiera de los dos botones.
    ///
    /// El identificador del mensaje va SOLO en su bloque: puesto en el contenedor pisaría el de los botones
    /// (`.claude/rules/testing.md`).
    private var notFoundContent: some View {
        VStack(spacing: DS.Spacing.lg) {
            messageContent(
                icon: "person.crop.circle.badge.questionmark",
                title: L10n.Welcome.Cloud.notFoundTitle,
                body: L10n.Welcome.Cloud.notFoundBody)
                .accessibilityIdentifier("welcome_cloud_not_found")
            if WelcomeNewOptionsGate.offersCloudSignUp {
                YalaPrimaryButton(L10n.Welcome.Cloud.notFoundCta) {
                    DS.Haptic.selection()
                    // El proveedor se captura ANTES de reencaminar —el argumento se evalúa antes de que la función
                    // toque nada—: `provider` se deriva de `activeEntry`, y en cuanto el override dice `.bornCloud`
                    // pasa a leer `chosenProvider`. Leído después, caería en el `?? .apple` y mandaría a Apple a
                    // quien acababa de entrar con Google.
                    switchToSignUp(with: provider)
                }
                .padding(.horizontal, DS.Spacing.xl)
                .accessibilityIdentifier("welcome_cloud_not_found_cta")
            } else {
                YalaPrimaryButton(L10n.Welcome.Cloud.blockedBack) {
                    onBack()
                }
                .padding(.horizontal, DS.Spacing.xl)
                .accessibilityIdentifier("welcome_cloud_not_found_back")
            }
        }
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

        guard let userID = CloudAuthService.shared.currentUserID else {
            phase = .error(retryable: true)
            return
        }

        // **El descubrimiento va por `CloudIdentityDiscovery`, el motor del bloque [I].** Antes esta función
        // tenía su propia copia de la secuencia —pedir el JWT, `GET /account/exists`, cachear el tipo— y la
        // puerta de Grupos la suya: dos sitios donde el mismo hecho se averigua y se guarda, y ya guardaban
        // distinto (uno por `AccountKindLogic.snapshotToPersist`, que NO pisa con un `kind` ausente, y el
        // otro escribiendo el snapshot a pelo). El motor conserva por dentro `CloudWelcomeSignInFlow.route`,
        // así que la tabla que traduce el wire sigue siendo la misma y sus tests siguen valiendo. Y sigue
        // construyendo `CloudAccountClient` SIN `attestProvider` a propósito: `/account/exists` va por
        // `requireUser` y es PRE-SESIÓN por definición (`.claude/rules/gateway-attest.md`).
        //
        // Paso 6: el método se le pasa al motor desde AQUÍ, que acaba de firmar con él, y no se deja que lo lea
        // del Keychain: una escritura fallida de `storedProvider` dejaría el de una sesión anterior, y con él la
        // prueba de Apple del faro huérfano podría borrar el faro de una cuenta viva (lente B de la review).
        let firmadoCon = provider
        switch await CloudIdentityDiscovery(sessionProviderName: { firmadoCon.rawValue }).discover(gate: identityGate) {
        case .discovered(.newAccount, _):
            // Guard R9 SUB-FIRST (sesión 2, H4): antes del `.notFound` engañoso, consultar el
            // faro del device — si la cuenta nube de este Apple ID se creó con OTRO método y
            // este sub NO la matchea, lo probable es "método equivocado", no "sin cuenta".
            //
            // Paso 6: si el faro apuntaba a una cuenta que esta respuesta PRUEBA borrada, el motor ya lo
            // limpió (`CloudIdentityDiscovery`), así que aquí se lee apagado y sale el `.notFound` honesto. Y
            // el mismatch que queda ya no es una pared: lleva sus dos salidas.
            let beacon = CloudBeacon()
            let verdict = ProviderMismatchLogic.decide(
                accountExists: false,
                beaconLinked: beacon.isCloudAccountLinked,
                beaconAccountHash: beacon.accountHash,
                beaconProvider: beacon.linkedProvider,
                sessionSubHash: CloudBeacon.hash(userID),
                sessionProvider: provider)
            // Sin claim no se creó NADA server-side; soltar la sesión SIEMPRE (no dejar el
            // sign-in colgado) — también en mismatch (jamás dejar un sub huérfano vivo).
            await CloudAuthService.shared.signOut()
            switch verdict {
            case .mismatch(let exits):
                MetricsService.cloudSignInProviderMismatch()
                phase = .providerMismatch(exits)
            case .proceed:
                phase = .notFound
            }
        case .unavailable(let retryable):
            phase = .error(retryable: retryable)
        case .discovered(let discovery, _):
            // El tipo de cuenta ya lo cacheó el motor: es el único punto de la app donde el backend lo dice
            // antes de que la sesión esté en marcha.
            //
            // **Bloque [I]**: aquí es donde el tipo de cuenta por fin elige pantalla. Hasta hoy esta rama
            // iba SIEMPRE al adopt, así que quien solo tenía grupos acababa con Yala completo montado.
            //
            // El estado del dispositivo se PREGUNTA, no se asume. La versión anterior lo cableaba a
            // «móvil limpio» justificándolo con «esta pantalla solo se alcanza desde el Welcome, y el
            // Welcome solo se muestra con el onboarding sin completar» — y ese razonamiento lo rompió el
            // propio bloque [I]: `adoptCompleteAccountFromGroups` presenta este cover desde la puerta de
            // GRUPOS, donde el onboarding sí puede estar completado. `nil` en la cuenta asociada porque
            // esta puerta no puede saberlo y la tabla no se lo pregunta.
            let destino = CloudIdentityRoutingLogic.destination(
                gate: identityGate,
                discovery: discovery,
                deviceState: deviceStateNow(),
                isAssociatedGroupsAccount: nil)
            switch destino {
            case .enterGroupsOnly, .enterGroupsOnlyOfferingFullActivation:
                // La cuenta existe y solo lleva grupos: **no se adopta**. La sesión se queda VIVA —es la
                // suya y la mini-app la necesita— y el recorrido sigue por la cadena de Grupos, que ya
                // sabe pedir lo que falte en este dispositivo. Los dos destinos comparten rama porque van al
                // mismo sitio; lo único que los separa es la oferta de «Activar Yala completo» al terminar
                // (paso 8), y viaja como argumento.
                onEnterGroupsOnly(destino == .enterGroupsOnlyOfferingFullActivation)
                return
            // `.adoptAsComplete` es el destino NORMAL de esta puerta: sigue al guard cross-cuenta y al
            // adopt de abajo, intactos. Los demás son inalcanzables aquí con `exists == true` —lo afirma
            // `soloTresDestinosSalenDelWelcome`, que solo permite estos tres— y comparten rama porque, si
            // algún día saliera otro, caer en el camino de HOY es no-regresión y no silencio.
            case .adoptAsComplete,
                 .createCompleteAccountThenPersonalOnboarding, .adoptAsCompleteAndOpenGroups,
                 .continueGroupsSetup, .associateGroupsAccount, .offerSignUpNoAccountFound,
                 .blockedAccountIsComplete, .blockedAnotherGroupsAccountAssociated,
                 .cutoverPrivateToCloud, .promoteAssociatedAccountThenCutover:
                break
            }
            let decision = CrossAccountEntryGuardLogic.decide(
                hasLocalData: hasLocalDataNow(),
                sameAccountClaimExists: CloudClaimActionStore.shared.action(forUserID: userID) != nil,
                // Se lee AQUÍ y no se cachea: el mirror puede asentar entre que se monta la pantalla y
                // que el usuario firma, y con el import ya asentado sus filas dejan de ser «las que
                // estoy bajando». Mismo criterio que `hasLocalDataNow`, que es un closure por eso mismo.
                restoreInProgress: ICloudRestoreSessionSignal.isRestoringNow)
            switch decision {
            case .blockedForeignData:
                // M0: aquí NO se escribe el consent — la tabla dice `.never`. La sesión se descarta sin
                // dejar rastro en el device y el registro GDPR real de esa cuenta vive en SU backend;
                // escribirlo antes de saber la ruta era el bug del chip (caía en el iKV del dueño).
                await CloudAuthService.shared.signOut()
                phase = .blockedForeignData
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
            // `nil` = el journal no se dejó leer en este tick: la pantalla se queda como estaba y el poll sigue. El
            // detector de aparcada corre igual, con la fase que se está pintando; su `resumeIfNeeded` no decide nada sin
            // journal.
            guard let next = CloudWelcomeSignInFlow.phase(
                for: controller.uiState,
                claimBlocker: controller.claimBlocker) else {
                await evaluateAutoResume(controller: controller, screenPhase: phase)
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return  // task cancelada (view desmontada)
                }
                continue
            }
            phase = next
            switch next {
            case .relaunch, .error:
                return
            case .reentryReady:
                // Terminal de ÉXITO del adopt sin relanzamiento. Para igual que `.relaunch`, y el
                // motivo de nombrarla explícitamente es que antes este caso LLEGABA como `.relaunch`:
                // dejarla caer al `default` mantendría el poll vivo a 1 Hz por debajo de una pantalla
                // terminal, reasignando `phase` y refetcheando el outbox en cada tick.
                return
            case .accountBlocked:
                // Terminal: el poll para. Seguir tickeando solo repetiría un claim que el backend ya
                // rechazó, y el auto-resume gastaría sus intentos contra una puerta cerrada.
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

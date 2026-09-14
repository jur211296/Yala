//
//  WelcomeFlowContainer.swift
//  Yala
//
//  Contenedor unificado del flow Welcome (Hero + Chooser) bajo un solo
//  `fullScreenCover`. Resuelve el "azul vacío" entre dismiss del Hero y
//  present del Chooser que aparecía con dos covers separados — el background
//  gradient persiste y la transición entre steps es un cross-fade smooth.
//
//  **El Hero desemboca SIEMPRE en el chooser** (decisión del owner 2026-08-11,
//  punto 2 de MODO-NUBE-REVISION-FLUJOS-NOTAS): aquí vivía el alert "Detectamos
//  tu cuenta", que empujaba hacia la cuenta iCloud del container a quien podía
//  tener su cuenta en la nube. La reentrada la elige el usuario en
//  "Ya tengo una cuenta", que ofrece las tres vías.
//

import SwiftUI

enum WelcomeFlowStep: Equatable {
    case hero
    case chooser
    /// 2º nivel de "Ya tengo una cuenta" (H4): Restaurar iCloud | Sign in with Apple.
    /// Solo alcanzable con >1 opción visible (bypass en `handleExistingBranch`).
    case existingChooser
    /// 2º nivel de "Soy nuevo" (A4 de D-A7, §k.2): privacidad total (iCloud) | cuenta en la nube.
    /// Solo alcanzable con >1 opción visible (bypass en `handleNewBranch`).
    case newChooser
    /// G2 · 2º nivel de «Vengo por un grupo»: los dos caminos con los que se empieza un grupo —crearlo o
    /// entrar con la invitación—. La rama `.invite` del chooser deja de salir por el portal para venir
    /// aquí; el que ya tiene enlace sale por el MISMO `Destination .inviteRecovery` desde la card.
    case groupsChooser
    /// G3 · la PUERTA de la rama organizador: re-mide el canal de Grupos con `force` y comprueba en qué
    /// estado está el store personal de este arranque. Es un step y no un alert porque el source-scan de
    /// W1 prohíbe `.alert(` en este fichero, y porque una pantalla con salida no es un camino muerto.
    /// **Nada se escribe hasta que esta puerta dice que sí** — salvo la vuelta al neutro, que sí escribe
    /// porque su trabajo ES borrar, y solo después de haberlo dicho.
    ///
    /// **El propósito va DENTRO del case, y eso es lo que hace imposible el defecto que la review cazó.**
    /// Mientras vivió al lado —un `@State` de `ContentView` que acompañaba al step— tres de los cinco
    /// productores no lo escribían y heredaban el del uso anterior: quien tapeaba «Crear mi primer grupo»
    /// después de haber vuelto atrás en una invitación acababa uniéndose al grupo de otro. Aquí el
    /// compilador obliga a cada productor a decir a qué viene.
    case groupsGate(purpose: WelcomeGroupsGateView.Purpose)
    /// La rama privada, en sesión secundaria: **informa y sigue**. No es una puerta como `.groupsGate` —no
    /// hay nada que impedir desde que el dominio de preferencias por sesión cerró las escrituras al dueño—
    /// sino el paso que faltaba para que la app no se contradijera según por dónde entres.
    /// Paso 4 del rediseño · **la puerta de la rama privada: le pregunta a iCloud qué hay ANTES de que
    /// nadie vea una pantalla de reinicio** (ADR §9). Es un step y no un alert por las mismas razones que
    /// `.groupsGate`, más una medida: un `.alert` del anchor de `ContentView` desmonta este cover entero.
    case privateICloudGate
    /// R2 · TERMINAL: este proceso montó el store NEUTRO y el destino elegido necesita el mirror de
    /// CloudKit ⇒ hay que reabrir la app. Vive DENTRO de este cover a propósito: un cover propio sería una
    /// presentación nueva colgando del anchor de `ContentView` (matriz de readiness, regla (3) de
    /// Presentaciones) para enseñar dos párrafos; aquí es un step más del contenedor que ya está montado.
    case mirrorRelaunch
}

struct WelcomeFlowContainer: View {
    /// Step inicial. Para flujo normal `.hero`; para casos como "back" desde
    /// InviteRecovery (rama C → vuelve al Chooser) se pasa `.chooser`.
    let initialStep: WelcomeFlowStep

    var onSelectBranch: (WelcomeChooserView.Branch) -> Void
    /// Sub-elección de "Ya tengo una cuenta" (también el resultado del bypass).
    var onSelectExistingOption: (WelcomeAccountChoiceLogic.ExistingOption) -> Void
    /// "Soy nuevo" con la opción PRIVADA elegida (también el resultado del bypass, que es el
    /// recorrido de producción de hoy).
    var onSelectPrivateAccount: () -> Void
    /// A5: "Soy nuevo" con la opción NUBE elegida ⇒ alta born-cloud (consent → sign-in → claim →
    /// par → relanzamiento). El destino es el MISMO cover que la re-entrada, con `Entry.bornCloud`.
    var onSelectCloudAccount: () -> Void
    /// ADR 2026-09-09 §10: el faro de iCloud-KV dice que este Apple ID YA tiene cuenta nube ⇒ «Soy nuevo»
    /// ENCAMINA a entrar con ella, y la pantalla de destino ofrece «Crear otra cuenta» (paso 6). El
    /// argumento es el método según el faro; `nil` = el faro no lo sabe.
    var onBeaconRoutesToCloudSignIn: (CloudSignInProvider?) -> Void
    /// G3: «Crear mi primer grupo» con la puerta ya CONFIRMADA abierta (canal encendido y sin datos de
    /// otro humano en el device). El container no comprueba nada aquí: eso es del step `.groupsGate`, que
    /// es el único que puede llamarlo.
    var onSelectGroupsOrganizer: () -> Void
    /// R2: el destino elegido necesita el mirror y este proceso montó neutro ⇒ el container va a su step
    /// terminal y ContentView PERSISTE el destino para retomarlo tras el relanzamiento. Se separa en dos
    /// responsabilidades porque el container no debe tocar `UserDefaults` ni los flags de onboarding.
    var onNeedsMirrorRelaunch: (WelcomeMirrorRelaunchLogic.Destination) -> Void
    /// Mitad 2 del paso 5 · la vuelta al neutro de la puerta de Grupos armó el borrado. **No es un
    /// `Destination` más y por eso no pasa por `leaveWelcome`**: aquí el relanzamiento no lo pide el
    /// destino elegido sino el borrado que acaba de armarse, y el terminal que lo cuenta es el del cierre
    /// de sesión, que vive fuera de este cover. El container solo reenvía: persistir el destino y cerrar
    /// el Welcome es de `ContentView`, por la misma razón que el callback de arriba.
    /// Recibe el propósito del step que armó el borrado: es lo que decide qué destino se persiste para el
    /// arranque siguiente —el alta del organizador o la invitación— y, en el segundo caso, que el par
    /// `{groupID, token}` cruce el wipe.
    var onGroupsGateNeutralReturnArmed: (WelcomeGroupsGateView.Purpose) -> Void
    /// La puerta del INVITADO abrió: cerrar el Welcome y retomar el join del grupo que se nombra. Separado
    /// de `onSelectGroupsOrganizer` porque son dos destinos distintos del mismo step, y **no pasa por
    /// `leaveWelcome`**: no hay `Destination` que elegir ni mirror que evaluar — el dispositivo acaba de
    /// quedar neutro a propósito, o nunca dejó de estarlo.
    ///
    /// El `groupID` VIAJA en el callback y no lo lee `ContentView` de un estado suyo: así no hay un segundo
    /// sitio donde el propósito pueda quedarse desfasado respecto al step que se está pintando.
    var onGroupsGateInviteProceed: (String) -> Void
    /// G3: fetch VIVO del corpus local para la puerta (mismo closure que alimenta el guard cross-cuenta
    /// del sign-in de nube — un snapshot no vale, el mirror puede estar re-importando).
    var hasLocalDataNow: @MainActor @Sendable () -> Bool
    /// Paso 4: el borrado del corpus de iCloud. Vive en `ContentView` —es quien tiene el `modelContext`,
    /// y el borrado tiene que llevarse también las filas que el espejo hubiera bajado ya—; el container
    /// solo lo reenvía a la puerta.
    var performICloudCorpusWipe: @MainActor () async -> String?
    /// El borrado del corpus que ya está en el TELÉFONO, con su purga del dominio de Grupos y su sello de
    /// handover. Vive en `ContentView` por lo mismo que el de arriba, y es OTRO callback y no un
    /// parámetro de aquél porque sus dos consumidores no coinciden: éste solo lo usa el Welcome, y la
    /// activación de Yala completo —que comparte la puerta— jamás debe borrar lo local.
    var performDeviceCorpusWipe: @MainActor () async -> String?

    @State private var step: WelcomeFlowStep = .hero

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        initialStep: WelcomeFlowStep = .hero,
        onSelectBranch: @escaping (WelcomeChooserView.Branch) -> Void,
        onSelectExistingOption: @escaping (WelcomeAccountChoiceLogic.ExistingOption) -> Void,
        onSelectPrivateAccount: @escaping () -> Void,
        onSelectCloudAccount: @escaping () -> Void,
        onSelectGroupsOrganizer: @escaping () -> Void,
        onBeaconRoutesToCloudSignIn: @escaping (CloudSignInProvider?) -> Void,
        onNeedsMirrorRelaunch: @escaping (WelcomeMirrorRelaunchLogic.Destination) -> Void,
        onGroupsGateNeutralReturnArmed: @escaping (WelcomeGroupsGateView.Purpose) -> Void,
        onGroupsGateInviteProceed: @escaping (String) -> Void,
        hasLocalDataNow: @escaping @MainActor @Sendable () -> Bool,
        performICloudCorpusWipe: @escaping @MainActor () async -> String?,
        performDeviceCorpusWipe: @escaping @MainActor () async -> String?
    ) {
        self.initialStep = initialStep
        self.onSelectBranch = onSelectBranch
        self.onSelectExistingOption = onSelectExistingOption
        self.onSelectPrivateAccount = onSelectPrivateAccount
        self.onSelectCloudAccount = onSelectCloudAccount
        self.onBeaconRoutesToCloudSignIn = onBeaconRoutesToCloudSignIn
        self.onSelectGroupsOrganizer = onSelectGroupsOrganizer
        self.onNeedsMirrorRelaunch = onNeedsMirrorRelaunch
        self.onGroupsGateNeutralReturnArmed = onGroupsGateNeutralReturnArmed
        self.onGroupsGateInviteProceed = onGroupsGateInviteProceed
        self.hasLocalDataNow = hasLocalDataNow
        self.performICloudCorpusWipe = performICloudCorpusWipe
        self.performDeviceCorpusWipe = performDeviceCorpusWipe
        self._step = State(initialValue: initialStep)
    }

    private var visibleExistingOptions: [WelcomeAccountChoiceLogic.ExistingOption] {
        // `-uitest-cloud-chooser` (opt-in EXPLÍCITO, sesión 2): destapa las cards cloud bajo
        // uitest SOLO para el XCUITest del chooser — el resto de uitest queda byte-idéntico
        // (bypass a restore intacto). `remoteCloudEnabled` (DIFERIDOS #34): kill-switch de la
        // ENTRADA; bajo uitest/DEV sin fetch el default es ON (byte-idéntico), y si el fetch
        // aterriza con la vista abierta se lee en el siguiente render (sin live-update — asumido).
        WelcomeAccountChoiceLogic.visibleExistingOptions(
            isConfigured: CloudBackendConfig.isConfigured,
            isUITest: SwiftDataConfiguration.isUITesting && !UITestHooks.forceCloudChooser,
            remoteCloudEnabled: CloudRemoteFlags.cloudModeEnabled)
    }

    /// A4: espejo EXACTO de los argumentos del existing (mismo opt-in de uitest, mismo kill-switch)
    /// más los dos términos propios del born-cloud: la constante COMPILADA (hoy `true`) y el
    /// sub-flag remoto de la elección. Desde el paso 8 los lee `WelcomeNewOptionsGate`, que comparte con la
    /// activación de Yala completo: el chooser es el mismo y su gate también tiene que serlo.
    private var visibleNewOptions: [WelcomeAccountChoiceLogic.NewOption] {
        WelcomeNewOptionsGate.live
    }

    /// El encaminamiento por faro (ADR §10) va a la MISMA pantalla que la card `.cloudSignIn` del
    /// sub-chooser de "Ya tengo cuenta" ⇒ su disponibilidad se DERIVA de ahí en vez de re-escribir
    /// los tres términos, que es como dos gates que deberían coincidir empiezan a divergir.
    private var cloudEntryAvailable: Bool {
        visibleExistingOptions.contains(.cloudSignIn)
    }

    var body: some View {
        ZStack {
            switch step {
            case .hero:
                WelcomeHeroView {
                    goTo(.chooser)
                }
                .transition(.opacity)
            case .chooser:
                WelcomeChooserView(
                    onSelect: { branch in
                        // "Ya tengo una cuenta" y "Soy nuevo" abren su 2º nivel (o bypass con 1
                        // opción — en producción hoy equivale exactamente al flujo actual).
                        switch branch {
                        case .restore: handleExistingBranch()
                        case .new: handleNewBranch()
                        // G2: la card ya no es «me invitaron» sino «vengo por un grupo», así que no
                        // puede salir directa a la recuperación de invitación — abre el step de los
                        // dos caminos y es ahí donde el invitado elige el suyo.
                        case .invite: goTo(.groupsChooser)
                        }
                    },
                    onBack: { goTo(.hero) }
                )
                .transition(.opacity)
            case .groupsChooser:
                WelcomeGroupsChooserView(
                    // G3: la card de crear ya está cableada y por tanto se pinta. Su handler NO sale del
                    // cover: abre la puerta, que es el step siguiente. El portal se cruza más tarde, y
                    // solo si la puerta abre.
                    onCreate: { goTo(.groupsGate(purpose: .createGroup)) },
                    onJoin: {
                        leaveWelcome(to: .inviteRecovery) { onSelectBranch(.invite) }
                    },
                    onBack: { goTo(.chooser) }
                )
                .transition(.opacity)
            case .groupsGate(let purpose):
                WelcomeGroupsGateView(
                    purpose: purpose,
                    // Re-envuelto en vez de reenviado: pasar la property directa convierte un valor de
                    // función no-Sendable y avisa (`may introduce data races`). El closure nuevo nace ya en
                    // este contexto y no cruza ninguna frontera.
                    hasLocalDataNow: { hasLocalDataNow() },
                    onProceed: {
                        // El destino del `.proceed` lo decide el propósito, y por eso la rama del invitado
                        // NO pasa por `leaveWelcome`: aquel evalúa si el destino elegido necesita el mirror
                        // y aquí no hay destino que elegir — quien viene por una invitación va a su join,
                        // sobre un dispositivo que acaba de quedar neutro o que nunca dejó de estarlo.
                        if let groupID = purpose.invitedGroupID {
                            onGroupsGateInviteProceed(groupID)
                        } else {
                            leaveWelcome(to: .groupsOrganizer) { onSelectGroupsOrganizer() }
                        }
                    },
                    onBack: { goTo(.groupsChooser) },
                    onNeutralReturnArmed: { onGroupsGateNeutralReturnArmed(purpose) }
                )
                .transition(.opacity)
            case .existingChooser:
                WelcomeExistingChooserView(
                    options: visibleExistingOptions,
                    onSelect: { option in handleExistingOption(option) },
                    onBack: { goTo(.chooser) }
                )
                .transition(.opacity)
            case .newChooser:
                WelcomeNewChooserView(
                    options: visibleNewOptions,
                    onSelect: { option in handleNewOption(option) },
                    onBack: { goTo(.chooser) }
                )
                .transition(.opacity)
            case .privateICloudGate:
                WelcomePrivateICloudGateView(
                    onProceed: {
                        leaveWelcome(to: .privateOnboarding) { onSelectPrivateAccount() }
                    },
                    // La tercera salida del aviso. Se delega en `handleExistingOption` en vez de cruzar el
                    // portal aquí: ese helper YA es el que traduce «restaurar» a su `Destination`, y
                    // escribir la traducción por segunda vez es como divergen dos caminos que deben acabar
                    // en la misma pantalla.
                    // **Y retira el arm del borrado antes de irse.** «Traer mis datos» es la voluntad
                    // expresada DESPUÉS de haberlo pedido, que es el mismo criterio con el que
                    // `presentNextOnboardingScreen` hace ganar al destino pendiente sobre el arm. Sin
                    // esto, quien sale por aquí tras un borrado fallido restaura su histórico y el
                    // arranque siguiente se lo borra entero sin preguntar: con el espejo ya adjunto esta
                    // salida NO relanza, así que no hay destino pendiente que arrastre el arm consigo.
                    onRestore: {
                        StorageModePersistence.clearICloudCorpusWipeArm()
                        handleExistingOption(.restoreICloud)
                    },
                    // Cancelar → la elección privado / nube, que es de donde vino: con bypass nunca vio el
                    // sub-chooser, así que mandarlo ahí sería enseñarle una pantalla nueva al retroceder.
                    onBack: { goTo(newBranchOriginStep) },
                    performWipe: performICloudCorpusWipe,
                    // **El Welcome SÍ pregunta por el corpus del teléfono.** Es la otra mitad del aviso de
                    // datos existentes: con el mount neutro, esta rama sale por el relanzamiento y nunca
                    // llega al `onSelectPrivateAccount` que lo levantaba. El fetch va VIVO —el mismo
                    // closure que alimenta el guard cross-cuenta— porque el espejo puede estar
                    // re-importando mientras esta pantalla está montada.
                    // Los dos RE-ENVUELTOS y no reenviados: pasar las properties directas convierte
                    // valores de función no-Sendable y avisa (`may introduce data races`). Las closures
                    // nuevas nacen ya en este contexto y no cruzan ninguna frontera — mismo remedio que
                    // `hasLocalDataNow` en el step de la puerta de Grupos.
                    deviceCorpus: deviceCorpusGate
                )
                .transition(.opacity)
            case .mirrorRelaunch:
                WelcomeMirrorRelaunchView()
                    .transition(.opacity)
            }
        }
        // **El step inicial manda AUNQUE el cover ya esté montado, y sin esto se ignoraba en silencio.**
        //
        // `@State` se inicializa una sola vez por identidad de la vista, así que un productor que escriba
        // `welcomeFlowInitialStep` mientras este cover está en pantalla no movía nada. Hasta hoy no se
        // notaba porque los cinco productores venían de sitios donde el cover estaba BAJADO. El sexto
        // —el drain del intent de la puerta del invitado— no: `dismissWelcomeChainForSupersedingIntent`
        // baja `showWelcomeFlow` y el `case` lo vuelve a subir en la MISMA vuelta síncrona, así que
        // SwiftUI no renderiza entre las dos escrituras, el cover nunca se desmonta y el step pedido se
        // perdía. El invitado se quedaba mirando el Hero con su invitación viva y sin pantalla que la
        // retomara.
        //
        // Es seguro para todos los demás porque **este valor solo se escribe para navegar**: los catorce
        // escritores de `welcomeFlowInitialStep` van seguidos de `showWelcomeFlow = true` (medido). No es
        // un dato que se actualice por su cuenta.
        .onChange(of: initialStep) { _, new in
            guard step != new else { return }
            step = new
        }
        .task {
            // DIFERIDOS #34: refresh del remote-config en la ENTRADA (fresh install pre-onboarding
            // puede no tener cache del boot todavía). Min-interval 6 h.
            // Bajo uitest NO se toca red (hermeticidad — los getters ya devuelven el default).
            guard !SwiftDataConfiguration.isUITesting else { return }
            await RemoteConfigClient.shared.refreshIfDue()
        }
    }

    /// **R2 · el único portal de salida del Welcome.** Toda elección que abandona este cover pasa por aquí,
    /// y aquí se decide si antes hay que reabrir la app.
    ///
    /// Está en el CONTAINER y no en los callbacks de `ContentView` por una razón concreta: los destinos se
    /// producen en SEIS sitios (las dos cards del sub-chooser de grupos —«Tengo una invitación» directa y
    /// «Crear mi primer grupo» a través de su puerta—, el sub-chooser existente, el encaminamiento por faro
    /// y las dos cards del sub-chooser nuevo), varios de ellos con bypass, y repartir la comprobación por
    /// los seis es exactamente cómo divergen. Con un portal único, añadir una salida nueva obliga a nombrar
    /// su `Destination`.
    ///
    /// G2 (2026-08-11) movió el primero de nivel: lo producía la card `.invite` del chooser y ahora lo
    /// produce la card de unirse DENTRO del step de grupos. El `Destination` es el MISMO —`.inviteRecovery`,
    /// con su misma fila `requiresMirror`— así que el invitado no pierde nada; lo que cambia es que
    /// `hasShownWelcomeChooser` deja de marcarse al tapear la card de nivel 1, igual que ya pasaba con las
    /// otras dos ramas cuando muestran su 2º nivel.
    ///
    /// G3 (2026-08-11) añadió el sexto, `.groupsOrganizer`, y es el único que pasa por una PUERTA: la card
    /// de crear no llama aquí, va al step `.groupsGate` y es él quien cruza el portal si —y solo si— el
    /// canal está encendido y el device no tiene datos de otro humano.
    ///
    /// Eran SEIS hasta el 2026-08-11 por otra razón: el alert «Detectamos tu cuenta» tenía el suyo
    /// (`.restoreICloud`), y se fue entero con el alert cuando la reentrada pasó a ser decisión del usuario.
    private func leaveWelcome(to destination: WelcomeMirrorRelaunchLogic.Destination,
                              proceed: () -> Void) {
        guard WelcomeMirrorRelaunchLogic.shouldRelaunch(
            destination: destination,
            mountedDecision: SwiftDataConfiguration.personalStoreMountedDecision) else {
            proceed()
            return
        }
        onNeedsMirrorRelaunch(destination)
        goTo(.mirrorRelaunch)
    }

    /// "Ya tengo una cuenta": con una sola opción visible (prod DARK / uitest) hace
    /// bypass directo — comportamiento idéntico al flujo restore de hoy; con ambas,
    /// muestra el 2º nivel.
    private func handleExistingBranch() {
        if let single = WelcomeAccountChoiceLogic.bypass(visibleExistingOptions) {
            handleExistingOption(single)
        } else {
            goTo(.existingChooser)
        }
    }

    /// R2: el sub-chooser de "Ya tengo una cuenta" y su bypass comparten portal. Solo `restoreICloud`
    /// necesita el mirror; las dos entradas a la cuenta nube montan el mismo store que el neutro ya es.
    private func handleExistingOption(_ option: WelcomeAccountChoiceLogic.ExistingOption) {
        let destination: WelcomeMirrorRelaunchLogic.Destination
        switch option {
        case .restoreICloud: destination = .restoreICloud
        case .cloudSignIn, .googleSignIn: destination = .cloudSignIn
        }
        leaveWelcome(to: destination) { onSelectExistingOption(option) }
    }

    /// "Soy nuevo" (A4). **El faro se consulta ANTES de ofrecer nada** —encaminar es el default del ADR
    /// §10— y, por tanto, antes de que `ContentView` limpie las prefs residuales del fresh-start: ese
    /// orden es el contrato. Medido el 2026-08-09: `OnboardingResetHelper.safeKeysToClear` son SOLO
    /// `userName` y `defaultCurrencyCode`, así que la limpieza no toca las `yala.cloud.*` del faro — no
    /// hay bug ahí, y el orden se respeta igual para que siga sin haberlo.
    ///
    /// **Encaminar ya no es decidir** (paso 6): la pantalla a la que lleva `.cloudSignIn` ofrece «Crear
    /// otra cuenta», que vuelve a este container en `.newChooser` —el chooser ENTERO, sin bypass—. Esa
    /// vuelta no pasa por aquí a propósito: el faro la volvería a encaminar.
    ///
    /// Con una sola opción visible NO se muestra pantalla intermedia: en producción (percent
    /// remoto en 0) y bajo uitest el recorrido es byte-idéntico al de hoy.
    private func handleNewBranch() {
        switch WelcomeNewBranchRouter.route(
            beacon: CloudBeacon(),
            cloudEntryAvailable: cloudEntryAvailable,
            options: visibleNewOptions
        ) {
        case .cloudSignIn(let provider):
            leaveWelcome(to: .cloudSignIn) { onBeaconRoutesToCloudSignIn(provider) }
        case .single(let option):
            handleNewOption(option)
        case .chooser:
            goTo(.newChooser)
        }
    }

    /// **Preguntar por el corpus del teléfono, pero SOLO cuando este camino se va a saltar el alert.**
    ///
    /// El predicado es el MISMO que decide el relanzamiento, y eso no es una coincidencia que convenga
    /// perder de vista — son las dos caras del hueco que este término cierra:
    ///
    ///  · **`shouldRelaunch == true`** (mount neutro): el portal sale por `onNeedsMirrorRelaunch` y
    ///    `onSelectPrivateAccount` **no corre**, así que el alert de datos existentes de
    ///    `startFreshPrivateOnboarding` no se levanta. Aquí hace falta este aviso, o no hay ninguno.
    ///  · **`shouldRelaunch == false`**: el portal llama a `proceed()`, corre `onSelectPrivateAccount` y
    ///    el alert de siempre hace su trabajo. Preguntar aquí sería enseñar DOS avisos del mismo hecho.
    ///
    /// **Y hay una segunda razón, más dura, que obliga a que sea este predicado y no otro**
    /// (`.claude/rules/swiftdata-cloudkit.md`, «ARCHIVOS, nunca FILAS»): el borrado que cuelga de este
    /// aviso quita FILAS. Con `NSPersistentCloudKitContainer` montado, los deletes se quedan en la History
    /// y el espejo los EXPORTA — vaciaría el iCloud de la persona en todos sus dispositivos. Un mount
    /// neutro es `cloudKitDatabase: .none` explícito: no hay espejo que pueda exportar nada, y es
    /// exactamente el caso en el que este término se enciende. El daño no es teórico: con la red caída la
    /// sonda devuelve `.failed`, el aviso saldría igual (es lo correcto: lo de aquí se cuenta sin red) y
    /// el espejo exportaría los deletes en cuanto volviera la conexión.
    private var deviceCorpusGate: WelcomePrivateICloudGateView.DeviceCorpus? {
        guard WelcomeMirrorRelaunchLogic.shouldRelaunch(
            destination: .privateOnboarding,
            mountedDecision: SwiftDataConfiguration.personalStoreMountedDecision) else { return nil }
        return .init(hasData: { hasLocalDataNow() },
                     wipe: { await performDeviceCorpusWipe() })
    }

    /// De dónde vino quien está en la puerta de iCloud, y por tanto a dónde lo devuelve su «volver».
    /// Es el MISMO término que `handleNewBranch` usa para decidir si enseña el sub-chooser: con bypass no
    /// hubo 2º nivel y el origen es el chooser de primer nivel. Se RE-DERIVA en el «volver» en vez de
    /// capturarse al entrar: así no hay un segundo sitio donde escribir la condición.
    private var newBranchOriginStep: WelcomeFlowStep {
        WelcomeAccountChoiceLogic.bypass(visibleNewOptions) == nil ? .newChooser : .chooser
    }

    private func handleNewOption(_ option: WelcomeAccountChoiceLogic.NewOption) {
        switch option {
        case .privateAccount:
            // **Paso 4 · esta rama ya no sale directa por el portal: pasa por la puerta.** Hasta el
            // 2026-09-10 iba a `leaveWelcome(.privateOnboarding)`, y con el mount neutro eso persiste el
            // destino y **NO llama a `onSelectPrivateAccount`** — el único callback que consultaba «¿hay
            // datos?». Resultado medido en device el 2026-09-09: instalación fresca + iCloud con meses de
            // histórico → pantalla de reinicio CIEGA, y al reabrir el onboarding completo montándose
            // encima mientras el espejo bajaba el corpus viejo por debajo.
            //
            // La puerta no sustituye al portal, va DELANTE: su `onProceed` es el mismo
            // `leaveWelcome(to: .privateOnboarding)` de siempre, con su relanzamiento. Lo que cambia es que
            // ya no se cruza sin haber preguntado a iCloud (ADR §9, punto 4).
            //
            // R2: es «Soy nuevo» sin nube, y el que paga el relanzamiento que el alta nube deja de pagar
            // — el reparto que la Opción C aprueba. **Dejó de ser el bypass de producción**: con el percent
            // de la elección nube EN 100 (medido el 2026-09-09) el sub-chooser SÍ se muestra en prod y esta
            // rama es una de sus dos salidas, no la única. Sigue siendo camino ÚNICO donde el percent no
            // llega: device sin snapshot fetcheado (fail-closed), bajo UITest, y si se vuelve el percent a 0.
            goTo(.privateICloudGate)
        case .cloudAccount:
            // A5: el alta born-cloud. El stub explícito de A4 (`showBornCloudPendingAlert`) queda
            // BORRADO en este mismo commit, no silenciado — era una promesa con fecha.
            // R2: pasa por el portal igual que los demás, y sale sin relanzar — que es el chip entero.
            leaveWelcome(to: .cloudAccount) { onSelectCloudAccount() }
        }
    }

    private func goTo(_ next: WelcomeFlowStep) {
        guard step != next else { return }
        let animation: Animation? = reduceMotion ? nil : .smooth(duration: 0.5, extraBounce: 0.1)
        withAnimation(animation) {
            step = next
        }
    }
}

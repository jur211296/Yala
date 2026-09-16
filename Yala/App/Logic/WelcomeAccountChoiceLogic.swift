//
//  WelcomeAccountChoiceLogic.swift
//  Yala
//
//  Pure-logic del Welcome Chooser de 2 niveles (decisión owner 2026-07-12):
//  qué opciones muestra cada sub-chooser y cuándo hacer bypass (una sola opción
//  visible → no se muestra pantalla intermedia).
//
//  El botón de nube se oculta con backend no configurado y bajo UITest (SIWA no funciona en sim;
//  determinismo de los XCUITests existentes). El «prod DARK hoy» que decía aquí caducó con D-R1 paso 1
//  (2026-07-30): `CloudBackendConfig.isConfigured` es `true` en los DOS schemes.
//
//  **La card de «Es mi primera vez» se oculta además sin App Attest** (2026-09-16, ticket
//  `cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest`): quien no puede conseguir token no subiría nada.
//  Las de «Ya tengo una cuenta» no llevan ese término a propósito: entrar con una cuenta que ya existe es otra decisión.
//  Lo que sí lo lleva son las dos salidas de esa pantalla que DAN DE ALTA —«Crear mi cuenta» tras «No encontramos una
//  cuenta» y «Crear cuenta con…» del mismatch—: leen esta misma puerta por `WelcomeNewOptionsGate.offersCloudSignUp`
//  (2026-09-16, ticket `cloud-sign-in-screen-offers-sign-up-to-a-phone-without-app-attest`).
//  El simulador no tiene App Attest, así que sin `YALA_DEV_SHARED_SECRET` tampoco ofrece la nube: la convención y el
//  seam de XCUITest están en `.claude/rules/gateway-attest.md`.
//
//  **A4 de D-A7 (2026-08-09): `visibleNewOptions` GANA SU CONSUMIDOR** — `WelcomeNewChooserView`
//  vía `WelcomeFlowContainer` — y `bornCloudEnabled` se cablea a la constante COMPILADA
//  `CloudSyncFlags.bornCloudChoiceEnabled`, hoy `true`. El plan de julio que decía «born-cloud
//  está DIFERIDO ⇒ `bornCloudEnabled` queda cableado a `false` en el callsite» queda OBSOLETO:
//  la palanca de release es el PERCENT remoto (`CLOUD_ONBOARDING_CHOICE_ROLLOUT_PERCENT`, fail-closed
//  mientras no haya snapshot), igual que con Grupos — así A5 puede ejercitar el alta en staging/DEV sin
//  recompilar. **En producción está EN 100**, medido con `curl` al `/config` el 2026-09-09: la card
//  born-cloud SÍ se ve. Esto decía «`"0"` en producción ⇒ prod sigue sin ver la card», que describía un
//  estado ya vencido — el `.toml` del gateway llevó ese 0 desfasado hasta el 2026-09-10.
//

import Foundation

nonisolated enum WelcomeAccountChoiceLogic {

    /// Sub-opciones de "Soy nuevo".
    enum NewOption: Equatable, CaseIterable {
        case privateAccount
        case cloudAccount
    }

    /// Sub-opciones de "Ya tengo cuenta". `cloudSignIn` = Apple; `googleSignIn` = Google
    /// (sesión 2 — mismo gate: ambas solo con backend configurado y fuera de uitest).
    enum ExistingOption: Equatable, CaseIterable {
        case restoreICloud
        case cloudSignIn
        case googleSignIn
    }

    /// `remoteCloudEnabled`/`remoteOnboardingChoiceEnabled` = flags remote-config (DIFERIDOS #34,
    /// §j.1): la card born-cloud exige AMBOS (el sub-flag de elección es un escalón POSTERIOR del
    /// rollout del flag padre). Kill-switch = corta la ENTRADA: sin flag remoto no hay alta nueva.
    ///
    /// `isAttestSupported` = este teléfono puede conseguir token (`AppAttestClient.canObtainSessionToken`). Sin él la card
    /// no sale (`AttestSyncGate.shouldOfferCloudOnly`, la decisión del owner de bloquear por adelantado): elegir la nube
    /// sería apuntar gastos que nunca llegan a la cuenta. Con la nube fuera queda una sola card y el container hace bypass
    /// a la rama privada —salvo «Crear otra cuenta», que enseña el chooser con esa card—: el mismo recorrido del
    /// kill-switch, sin copy nuevo.
    static func visibleNewOptions(
        isConfigured: Bool,
        isUITest: Bool,
        isAttestSupported: Bool,
        bornCloudEnabled: Bool,
        remoteCloudEnabled: Bool,
        remoteOnboardingChoiceEnabled: Bool
    ) -> [NewOption] {
        var options: [NewOption] = [.privateAccount]
        if isConfigured && !isUITest && bornCloudEnabled
            && remoteCloudEnabled && remoteOnboardingChoiceEnabled
            && AttestSyncGate.shouldOfferCloudOnly(isAttestSupported: isAttestSupported) {
            options.append(.cloudAccount)
        }
        return options
    }

    /// `remoteCloudEnabled` (DIFERIDOS #34): con el kill-switch OFF las cards de sign-in nube se
    /// ocultan (bypass a restore, = prod DARK de hoy).
    ///
    /// **Residual ratificado por el owner (2026-09-06) — y son DOS puertas, no una.** Bajo el kill,
    /// un usuario nube que REINSTALA no re-entra hasta el re-encendido, y eso ocurre por los dos
    /// caminos a la vez:
    ///  1. **La card del Welcome** — esta función: sin `remoteCloudEnabled` no se ofrece el sign-in.
    ///     Y con ella se va el encaminamiento por faro, porque `cloudEntryAvailable` se DERIVA de
    ///     aquí (`routeNewBranch`, y el callsite en `WelcomeFlowContainer`).
    ///  2. **La fila «Dónde viven tus datos» de Ajustes** — `StorageRowGateLogic.isVisible`, cuyo
    ///     gate es `remoteEnabled || isEngaged`: una reinstalación NO puede estar engaged (el estado
    ///     que lo prueba es local y se fue con la app), así que la fila tampoco aparece.
    ///
    /// Hasta el 2026-09-07 esta línea solo nombraba la primera, y describir media política es como
    /// se acaba «arreglando» la puerta equivocada. Las dos cerradas es lo DESEADO: el kill significa
    /// nube en pausa para todos, también para volver. Lo que sí se corrigió es el mensaje del único
    /// camino que queda abierto —«Restaurar desde iCloud»—, que le decía a un nacido-en-nube con sus
    /// datos intactos que no los encontrábamos: ver `WelcomeRestorePauseLogic`.
    static func visibleExistingOptions(
        isConfigured: Bool,
        isUITest: Bool,
        remoteCloudEnabled: Bool
    ) -> [ExistingOption] {
        var options: [ExistingOption] = [.restoreICloud]
        if isConfigured && !isUITest && remoteCloudEnabled {
            options += [.cloudSignIn, .googleSignIn]
        }
        return options
    }

    /// Bypass del sub-chooser: con una sola opción visible se navega directo a ella.
    static func bypass<Option>(_ options: [Option]) -> Option? {
        options.count == 1 ? options.first : nil
    }

    // MARK: - Rama "Soy nuevo": el faro ENCAMINA, y la elección queda a un toque (ADR 2026-09-09 §10)

    /// Destino de la rama "Soy nuevo". El faro se sigue consultando ANTES de ofrecer nada —encaminar es el
    /// default—, pero ya no decide por la persona: la pantalla de destino lleva «Crear otra cuenta», que
    /// devuelve al chooser ENTERO (ticket `beacon-routes-only-never-blocks`).
    enum NewBranchRoute: Equatable {
        /// El faro de iCloud-KV dice que este Apple ID YA tiene una cuenta en la nube ⇒ se encamina a entrar
        /// con ella (§k.4). `accountProvider` es el método con el que se creó SEGÚN EL FARO, sin fallback:
        /// `nil` = el faro no lo dice o trae un valor que esta versión no conoce, y quien pinta el origen
        /// necesita distinguir «Apple» de «no lo sé» para no afirmar lo que no sabe. Con qué método se firma
        /// lo decide `signInProvider(forBeaconAccount:)`.
        ///
        /// **Hasta el paso 6 esto era «JAMÁS la elección» (A26, 2026-08-09)**: un nacido en la nube que en su
        /// 2º móvil eligiera «iCloud privado» arrancaría un dataset que no se junta con nada. El ADR §10 pesa
        /// más —el faro solo encamina— y Jürgen aceptó esa consecuencia a sabiendas (2026-09-09): la elección
        /// entera, privado incluido, sin avisos que nadie pidió.
        case cloudSignIn(accountProvider: CloudSignInProvider?)
        /// Bypass: una sola opción visible ⇒ no se monta pantalla intermedia (el recorrido de hoy).
        case single(NewOption)
        /// Dos o más opciones ⇒ sub-chooser.
        case chooser
    }

    /// `cloudEntryAvailable` es la disponibilidad de la MISMA pantalla a la que encamina el faro —
    /// la card `.cloudSignIn` de `visibleExistingOptions`—, no un gate nuevo: sin backend
    /// configurado el sign-in no puede completar (callejón), bajo uitest rompería el determinismo,
    /// y con el kill-switch remoto puesto la política ya ratificada es que la re-entrada nube no se
    /// ofrece (residual del owner en `visibleExistingOptions`). El callsite lo DERIVA de
    /// `visibleExistingOptions` en vez de re-escribir los tres términos.
    ///
    /// Bajo el kill remoto el faro no encamina y la persona ve el chooser de siempre. Antes eso se
    /// declaraba como residual de A26 («el born-cloud vuelve a poder divergir»); desde el ADR §10 esa
    /// divergencia es una elección posible también CON el faro, así que ya no es residual de nada.
    static func routeNewBranch(
        beaconLinked: Bool,
        beaconProvider: String?,
        cloudEntryAvailable: Bool,
        options: [NewOption]
    ) -> NewBranchRoute {
        if beaconLinked && cloudEntryAvailable {
            return .cloudSignIn(accountProvider: beaconProvider.flatMap(CloudSignInProvider.init(rawValue:)))
        }
        if let single = bypass(options) { return .single(single) }
        return .chooser
    }

    /// Con qué método se firma cuando el faro encamina. Sin método conocido ⇒ `.apple`: es el fallback de
    /// siempre —vivía dentro de `routeNewBranch`— y no una elección silenciosa, porque si no casa, la
    /// pantalla de destino lo dice (`ProviderMismatchLogic`) y ofrece las dos salidas.
    static func signInProvider(forBeaconAccount accountProvider: CloudSignInProvider?) -> CloudSignInProvider {
        accountProvider ?? .apple
    }
}

/// El estado honesto del restore bajo el kill-switch (decisión owner 2026-09-06).
///
/// **El problema que cierra:** con las dos puertas de nube cerradas, el ÚNICO camino que le queda a
/// quien vuelve es «Restaurar desde iCloud», y esa pantalla busca en **CloudKit**. Un nacido-en-nube
/// jamás tuvo datos ahí —los suyos viven en el backend— así que su búsqueda termina siempre vacía y
/// leía «No encontramos tus datos» con sus datos perfectamente intactos. El hecho es el contrario:
/// los datos existen y lo que está en pausa es la nube.
///
/// **Por qué el faro es el detector correcto** y no un flag local: vive en el iCloud-KV
/// (`CloudBeacon`), así que es lo ÚNICO de la cuenta nube que sobrevive a una reinstalación — que es
/// exactamente el recorrido que este mensaje describe. Cualquier testigo local es `false` en un
/// móvil recién instalado, por construcción.
///
/// **Deliberadamente NO sustituye a `.found`**: solo se consulta cuando la búsqueda no encontró nada.
/// Un usuario de iCloud privado que además tenga el faro puesto (dos devices, dos modos) sigue viendo
/// sus datos de iCloud y su botón de restaurar; taparle eso con un aviso de la nube sería cambiar un
/// mensaje equivocado por otro.
nonisolated enum WelcomeRestorePauseLogic {

    /// ¿La búsqueda vacía se debe a que la nube está en pausa, y no a que no haya datos?
    ///
    /// - Parameters:
    ///   - beaconLinked: `CloudBeacon.isCloudAccountLinked` — este Apple ID YA tiene cuenta nube.
    ///   - remoteCloudEnabled: `CloudRemoteFlags.cloudModeEnabled` — el kill-switch remoto.
    ///
    static func isCloudPaused(
        beaconLinked: Bool,
        remoteCloudEnabled: Bool
    ) -> Bool {
        beaconLinked && !remoteCloudEnabled
    }
}

/// El gate de las cards de «Soy nuevo» leído con las flags VIVAS. Existe para que el Welcome y la activación
/// de Yala completo (paso 8, que reusa el MISMO chooser) lean el MISMO gate: el ticket pide «mismo gate de
/// visibilidad», y dos copias de estos cinco términos es exactamente como dos pantallas empiezan a divergir.
/// Por eso lo leen también las salidas al alta de la pantalla de entrar, por `offersCloudSignUp`.
///
/// `-uitest-cloud-chooser` (opt-in EXPLÍCITO) destapa la card nube bajo XCUITest SOLO para los tests del
/// chooser; el resto de uitest queda byte-idéntico. Los remotos son fail-closed sin snapshot.
///
/// **App Attest se lee VIVO, y bajo XCUITest vale la verdad del simulador: no lo tiene.** Por eso los tests que
/// necesitan ver la card de la nube piden además `-uitest-fake-attest-support`, que finge SOLO esta entrada y no toca
/// `AppAttestClient`. Sin ese arg, `-uitest-cloud-chooser` deja un único término escondiendo la card —el attest—, y es
/// lo que permite probar la condición con el predicado real (`.claude/rules/testing.md`: el test de la condición corre
/// sin el seam).
@MainActor
enum WelcomeNewOptionsGate {
    static var live: [WelcomeAccountChoiceLogic.NewOption] {
        WelcomeAccountChoiceLogic.visibleNewOptions(
            isConfigured: CloudBackendConfig.isConfigured,
            isUITest: SwiftDataConfiguration.isUITesting && !UITestHooks.forceCloudChooser,
            isAttestSupported: UITestHooks.fakeAttestSupport || AppAttestClient.canObtainSessionToken,
            bornCloudEnabled: CloudSyncFlags.bornCloudChoiceEnabled,
            remoteCloudEnabled: CloudRemoteFlags.cloudModeEnabled,
            remoteOnboardingChoiceEnabled: CloudRemoteFlags.cloudOnboardingChoiceEnabled)
    }

    /// **¿Se le ofrece a este teléfono darse de alta en la nube?** Es exactamente la card «Tu cuenta en la nube», y es la
    /// puerta de TODAS las entradas al alta: la card y las dos salidas de la pantalla de entrar que dan de alta —«Crear mi
    /// cuenta» tras «No encontramos una cuenta» y «Crear cuenta con…» del mismatch— (ticket
    /// `cloud-sign-in-screen-offers-sign-up-to-a-phone-without-app-attest`). Hasta el 2026-09-16 esas dos no miraban
    /// nada: un teléfono sin App Attest, al que la card ya no le ofrecía la nube, creaba la cuenta por ahí y nada de lo
    /// que apuntaba llegaba nunca a ella. Tampoco miraban el kill del alta.
    ///
    /// Se DERIVA de `live` y no repite sus términos: así la card y las salidas no pueden decir cosas distintas.
    static var offersCloudSignUp: Bool {
        live.contains(.cloudAccount)
    }
}

/// Adaptador de LECTURA del faro para la rama "Soy nuevo" (A4 de D-A7). Existe para que el callsite
/// no lea `CloudBeacon` a mano y para que el test pueda inyectar el store KV (`BeaconKeyValueStore`):
/// la decisión sigue siendo pura y vive arriba; esto solo la alimenta.
@MainActor
enum WelcomeNewBranchRouter {
    static func route(
        beacon: CloudBeacon,
        cloudEntryAvailable: Bool,
        options: [WelcomeAccountChoiceLogic.NewOption]
    ) -> WelcomeAccountChoiceLogic.NewBranchRoute {
        WelcomeAccountChoiceLogic.routeNewBranch(
            beaconLinked: beacon.isCloudAccountLinked,
            beaconProvider: beacon.linkedProvider,
            cloudEntryAvailable: cloudEntryAvailable,
            options: options)
    }
}

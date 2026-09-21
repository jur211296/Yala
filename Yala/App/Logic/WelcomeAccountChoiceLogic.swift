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
    /// datos intactos que no los encontrábamos: ver `WelcomeRestoreEmptyOutcome`.
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

/// **Qué se le dice a quien terminó la búsqueda de restore SIN datos.** Tres desenlaces, y son tres
/// afirmaciones distintas sobre el mundo — por eso la decisión es UNA, y no dos booleanos que puedan
/// contradecirse entre sí.
///
/// **El primer problema que cerró (decisión owner 2026-09-06).** Con las dos puertas de nube cerradas
/// por el kill, el ÚNICO camino que le queda a quien vuelve es «Restaurar desde iCloud», y esa
/// pantalla busca en **CloudKit**. Un nacido-en-nube jamás tuvo datos ahí —los suyos viven en el
/// backend— así que su búsqueda termina siempre vacía y leía «No encontramos tus datos» con sus datos
/// perfectamente intactos. El hecho es el contrario: los datos existen y lo que está en pausa es la
/// nube. **Por qué el faro es el detector correcto** y no un flag local: vive en el iCloud-KV
/// (`CloudBeacon`), así que es lo ÚNICO de la cuenta nube que sobrevive a una reinstalación — que es
/// justo el recorrido que ese mensaje describe. Cualquier testigo local es `false` en un móvil recién
/// instalado, por construcción.
///
/// **El segundo, y es el que añade `.cloudUnverified`** (ticket `reinstall-without-network-has-no-cloud-door`,
/// decisión de Jürgen del 2026-09-17, opción 2). El párrafo de arriba da por hecho que SABEMOS qué dice
/// el kill, y eso solo es cierto si el servidor llegó a contestar. Quien reinstala —o estrena móvil— y
/// abre sin red se queda sin las dos cosas: el snapshot de remote-config vive en el contenedor de la
/// app y se fue con ella, y el iCloud-KV de un móvil recién instalado tampoco ha sincronizado, así que
/// el faro también está en blanco. Resultado hasta hoy: `beaconLinked == false` ⇒ `.notFound` ⇒ «No hay
/// datos asociados a tu cuenta» dicho con los datos intactos en el servidor. Ahora ese caso dice lo
/// único que es verdad: no lo hemos podido comprobar.
///
/// **Y el faro gana a los dos, que es lo que lo cazó la review adversarial del mismo día.** El primer
/// intento mandaba a `.cloudUnverified` todo lo que llegara sin snapshot, faro incluido, y eso le
/// quitaba la frase que MÁS le importa —«tus datos siguen a salvo en tu cuenta de Yala»— justo a quien
/// sí podemos probar que tiene cuenta. **El faro no viaja por nuestro gateway**: vive en el iCloud-KV
/// (`CloudBeacon.isCloudAccountLinked` → `store.bool`), así que puede estar puesto con nuestro servidor
/// inalcanzable — una red que filtre `workers.dev`, un 5xx del gateway, una caída de Cloudflare. Con el
/// faro puesto ya sabemos el hecho que decide el mensaje (los datos EXISTEN); lo que no sabemos —si la
/// nube está en pausa por el kill o por otra cosa— no cambia lo que hay que decirle.
///
/// ⇒ **`.cloudUnverified` es el desenlace de quien NO tiene faro y tampoco config**, que es exactamente
/// el móvil recién instalado del ticket: ahí el iCloud-KV tampoco ha sincronizado y las dos señales
/// están en blanco. Con el kill REAL puesto sí hay snapshot (percent 0), así que el recorrido del
/// ticket hermano no cambia en nada.
///
/// **Lo que esto NO cierra, y es el gemelo de lo que cierra: reinstalar CON red.** El snapshot llega,
/// así que `cloudConfigKnown` es `true`; pero el faro se lee con un `store.bool` que no fuerza nada
/// (`CloudBeacon.isCloudAccountLinked`) y el iCloud-KV de un móvil recién instalado llega cuando iOS
/// quiere, por `didChangeExternallyNotification`. En esa ventana las dos señales dicen «no» por
/// motivos distintos y el desenlace vuelve a ser `.notFound` con los datos intactos en el servidor.
/// Es anterior a este ticket —el `.cloudPaused` del kill tenía el mismo hueco— y no se cierra aquí:
/// ticket `restore-beacon-may-not-have-synced-yet-on-a-fresh-install`.
///
/// **Deliberadamente NO sustituye a `.found`**: esto solo se consulta cuando la búsqueda no encontró
/// nada. Un usuario de iCloud privado que además tenga el faro puesto (dos devices, dos modos) sigue
/// viendo sus datos de iCloud y su botón de restaurar; taparle eso con un aviso de la nube sería
/// cambiar un mensaje equivocado por otro.
nonisolated enum WelcomeRestoreEmptyOutcome: Equatable {

    /// No hay datos, y lo sabemos: la búsqueda terminó y el servidor nos dijo que la nube está abierta
    /// (o este Apple ID no tiene cuenta en ella). El copy de siempre.
    case notFound
    /// Los datos EXISTEN y lo que falta es la nube: hay cuenta (faro) y el kill remoto está puesto.
    case cloudPaused
    /// No lo sabemos: nunca hemos conseguido que el servidor conteste en esta instalación. No se afirma
    /// que los datos existan ni que falten.
    case cloudUnverified

    /// - Parameters:
    ///   - beaconLinked: `CloudBeacon.isCloudAccountLinked` — este Apple ID YA tiene cuenta nube.
    ///   - cloudConfigKnown: `CloudRemoteFlags.cloudConfigKnown` — ¿llegó a contestar el servidor?
    ///   - remoteCloudEnabled: `CloudRemoteFlags.cloudModeEnabled` — el kill-switch remoto.
    static func resolve(
        beaconLinked: Bool,
        cloudConfigKnown: Bool,
        remoteCloudEnabled: Bool
    ) -> WelcomeRestoreEmptyOutcome {
        // El faro decide primero: con cuenta probada, el mensaje que afirma que los datos existen es el
        // correcto tanto bajo el kill como sin haber podido preguntar. La condición se escribe con sus
        // DOS términos y no se deja caer en que `remoteCloudEnabled` ya es `false` sin snapshot: eso es
        // cierto en producción por el `absentDefault` fail-closed y FALSO en DEV, donde vale `true`.
        if beaconLinked {
            return remoteCloudEnabled && cloudConfigKnown ? .notFound : .cloudPaused
        }
        guard cloudConfigKnown else { return .cloudUnverified }
        return .notFound
    }
}

/// **Qué sabemos del import de CloudKit cuando la búsqueda de restore terminó y el store quedó VACÍO.**
/// Va ANTES de `WelcomeRestoreEmptyOutcome` en el recorrido, y responde una pregunta distinta: aquél
/// decide qué se le dice a quien terminó sin datos; éste decide si «terminó sin datos» es siquiera
/// cierto.
///
/// **El bug que cierra** (`restore-says-no-data-when-the-icloud-import-never-settled`, 2026-09-17):
/// `RestoreProgressView` usaba el `settled` de `waitForImportQuiescence(timeout: 90)` solo para la fase
/// visual, y entregaba el resumen igual si el import había asentado que si se había agotado el tope. Con
/// un histórico grande, una conexión lenta o CloudKit entregando por lotes, 90 s no bastan — y la
/// pantalla contestaba «No hay datos asociados a tu cuenta de iCloud» con los datos ahí, ofreciendo
/// debajo un «Empezar desde cero» que no preguntaba nada.
///
/// **Por qué el tope no sirve de señal, y `hasObservedImportActivity` sí.** `waitForImportQuiescence`
/// devuelve `false` tanto para el histórico que tarda como para el usuario **realmente nuevo**: su store
/// vacío no dispara ningún `.importEvent`, así que `forceFetchAndWait` agota el mismo tope. Usar el tope
/// tal cual convertiría toda instalación nueva en un «no pudimos comprobar» tras 90 s de espera, que es
/// justo lo que `reinstall-without-network-has-no-cloud-door` descartó a propósito. El que separa las dos
/// poblaciones es el flag del propio import: `iCloudSyncService.apply` lo enciende en el `case
/// .importEvent` **antes** de mirar si trae error, así que lo pone cualquier import —en curso, terminado
/// o fallido— y un store vacío nunca llega a ese `case`.
///
/// **Y la actividad sola no basta, que fue el primer error de este ticket.** El flag se enciende en la
/// CABECERA del `case .importEvent`, antes del `if let error`, así que lo pone igual un import que trae
/// datos que uno que FALLA — y el primer intento leía eso como «los datos vienen». Lo cazaron las tres
/// lentes de la review a la vez, con dos poblaciones: quien tiene un error terminal (cuota, cuenta
/// gestionada, permisos) y —peor— **el usuario realmente nuevo con red inestable**, a quien un solo
/// `.importEvent` con `networkUnavailable` le encendía el flag con la cuenta vacía. Los dos leían
/// «seguimos trayendo tus datos» con un «Reintentar» que devolvía al mismo sitio para siempre: el
/// remedio que el ticket descarta, entrando por la puerta de atrás.
///
/// Por eso entra un segundo término, y es el mismo molde que ya usa la reversa
/// (`ICloudCutoverGateLogic.decide`, `ReverseUploadBlockerLogic`): **la palabra VIGENTE de CloudKit**.
/// `lastImportError` a secas no vale —es un latch que ningún import con éxito limpia, igual que su
/// gemelo del export—, así que se comparan las FECHAS: el error cuenta solo si es posterior al último
/// import con éxito. Un error sin fecha no cuenta, que es el lado seguro aquí: la ambigüedad nunca
/// convierte «los datos vienen» en un desenlace que los niegue.
///
/// Con el error vigente el desenlace es `.inconclusive`, y no un estado propio: los tres finales del
/// camino de siempre —`.cloudPaused`, `.cloudUnverified`, `.notFound`— o afirman que los datos existen
/// o no niegan nada, los tres ofrecen reintentar y los tres confirman antes de borrar. Un cuarto copy
/// no diría nada que esos tres no digan mejor.
nonisolated enum RestoreImportSettlement: Equatable {

    /// El import ASENTÓ dentro del tope. **Hoy ningún consumidor lo trata distinto de `.inconclusive`
    /// y sigue siendo un caso propio a propósito: viaja al log** (`RestoreBreadcrumb.settled`), que es
    /// la única ventana sobre este flujo — el bug reproduce en CloudKit Production, donde no hay dSYM
    /// ni simulador. Sin separarlos, Console.app no distingue «CloudKit contestó que no hay nada» de
    /// «CloudKit no contestó», que es justo la pregunta de este ticket.
    ///
    /// Un primer intento le colgó además el gesto destructivo de `.notFound` (`conclusive:`), y se
    /// midió que esa rama tenía una sola población y **era gente con datos**: `settled` exige
    /// `hasCompletedFirstImport`, o sea que CloudKit trajo algo, y si lo trajo y `hasAnyData` seguía en
    /// `false` era porque son presupuestos o grupos, que aquel predicado no contaba.
    ///
    /// **Ese hueco se cerró A MEDIAS el 2026-09-21** (`restore-treats-budgets-and-groups-as-no-data`):
    /// `hasAnyData` cuenta ya los presupuestos, **pero NO los grupos** —no vienen de iCloud, y contarlos
    /// haría inalcanzable este mismo caso para toda la población con grupos—. Así que la rama sigue
    /// teniendo población, solo que otra: ya no es «presupuestos o grupos», es «grupos» a secas, más el
    /// import a medias. El gesto de `.notFound` no cambia, y ahora lo sostienen las dos razones.
    case settledEmpty
    /// El tope se agotó **habiendo visto actividad de import**: hay datos bajando y lo que faltó fue
    /// tiempo. Negarlos aquí es el bug; lo honesto es decir que siguen llegando.
    case stillImporting
    /// El tope se agotó **sin ver un solo import**. Dos poblaciones que esta señal no separa: quien de
    /// verdad no tiene nada (su store vacío no dispara eventos) y aquel a quien CloudKit no le contestó.
    /// Se mantiene el copy de «no encontramos tus datos» —Jürgen descartó convertir al usuario nuevo en
    /// un «no pudimos comprobar»— y la red pasa a ser la confirmación del gesto destructivo.
    case inconclusive

    /// - Parameters:
    ///   - settled: lo que devolvió `iCloudSyncService.waitForImportQuiescence`.
    ///   - hasObservedImportActivity: `iCloudSyncService.hasObservedImportActivity` leído en el mismo
    ///     instante que `settled`, no más tarde.
    ///   - lastImportErrorAt: `iCloudSyncService.lastImportErrorAt` — cuándo se vio el último error de
    ///     import. `nil` = ninguno, o un evento sin fechas.
    ///   - lastSuccessfulImportAt: `iCloudSyncService.lastSuccessfulImportDate`. Las dos fechas se
    ///     reciben crudas y la vigencia se calcula AQUÍ: un booleano precocinado fuera dejaría la
    ///     comparación sin test, que es justo donde vive la decisión.
    static func resolve(settled: Bool,
                        hasObservedImportActivity: Bool,
                        lastImportErrorAt: Date?,
                        lastSuccessfulImportAt: Date?) -> RestoreImportSettlement {
        guard !settled else { return .settledEmpty }
        guard hasObservedImportActivity else { return .inconclusive }
        let errorIsCurrent: Bool = {
            guard let errorAt = lastImportErrorAt else { return false }
            guard let successAt = lastSuccessfulImportAt else { return true }
            return errorAt > successAt
        }()
        return errorIsCurrent ? .inconclusive : .stillImporting
    }

    /// ¿Se le puede preguntar al remote-config, o el desenlace ya está decidido? Con datos bajando por
    /// CloudKit la respuesta del backend propio no cambia nada —el kill-switch gobierna la nube de Yala,
    /// no el espejo de Apple— y preguntar le costaría otro fetch a quien ya esperó el tope entero.
    var consultsRemoteConfig: Bool { self != .stillImporting }
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

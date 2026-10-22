//
//  CloudIdentityDiscovery.swift
//  Yala
//
//  El **motor** del bloque [I]: le pregunta al backend qué hay detrás de la identidad que acaba de
//  firmar, y devuelve uno de los tres resultados del ADR §7 ya resuelto para la puerta que pregunta.
//
//  POR QUÉ ES UN MOTOR Y NO UNA VISTA COMPARTIDA. Decisión de Jürgen (2026-09-09): «`GroupsSignInView`
//  cambia de motor, no de aspecto». La puerta de Grupos se sigue viendo como hoy —su tono de mini-app— y
//  lo que se comparte es la secuencia: pedir el JWT, preguntar `GET /account/exists`, cachear el tipo y
//  traducir la respuesta a un resultado. Compartir la vista habría cambiado justo lo que no debe cambiar.
//
//  **Y compartido significa dos call-sites de verdad**: `WelcomeCloudSignInView.runSignInFlow` y
//  `GroupsSignInView.resolveDestination`. La primera versión de este fichero decía «compartido» con un
//  solo llamador, mientras el Welcome conservaba su copia de la secuencia — y las dos ya cacheaban
//  distinto: una pasaba por `AccountKindLogic.snapshotToPersist` (que NO pisa con un `kind` ausente) y la
//  otra escribía el snapshot a pelo. Lo cazó una lente adversarial leyendo el docblock contra el grep.
//
//  ## Qué NO hace, y cada «no» tiene su motivo
//
//  · **No firma.** Cada puerta ya tiene su sign-in con sus propios catches —la asimetría Apple/Google no
//    es cosmética— y su propio copy de error. Este motor arranca con la sesión ya viva.
//  · **No aplica el guard cross-cuenta.** `CrossAccountEntryGuardLogic` necesita inputs que solo conoce
//    cada puerta (`hasLocalDataNow`, el claim persistido, la señal de restore en curso), y en la puerta de
//    Grupos «hay datos locales» significa otra cosa que en el Welcome. Lo aplica quien pregunta.
//  · **No rutea.** La tabla es `CloudIdentityRoutingLogic`, y es pura.
//
//  ## Lo único que escribe además del tipo: el faro huérfano (paso 6)
//
//  Cuando el backend contesta «no existe» y eso PRUEBA que la cuenta del faro de iCloud-KV ya no existe,
//  el motor limpia el faro (`clearBeaconIfItsAccountIsGone`). Decisión de Jürgen del 2026-09-09: «se limpia
//  solo en cuanto [I] lo descubre». La prueba es `BeaconOrphanLogic`, y lo que no prueba no se toca.
//
//  ## El caso normal es que el servidor NO diga el tipo
//
//  Medido el 2026-09-10: ni staging ni producción sirven `kind` todavía. Por eso el motor **no** decide
//  qué asumir: le pasa la puerta a `CloudIdentityRoutingLogic.discovery(exists:kind:gate:)`, que degrada
//  al comportamiento de HOY de esa puerta. Y por eso mismo un `kind` ausente **jamás borra** lo cacheado
//  (`AccountKindLogic.snapshotToPersist`): un gateway viejo no es prueba de que la cuenta haya cambiado.
//
//  ADR 2026-09-09 «Sesiones — dos ejes» §7 · ticket `cloud-sign-in-discovers-account-kind`.
//

import Foundation

@MainActor
final class CloudIdentityDiscovery {

    /// Qué se pudo averiguar.
    enum Outcome: Equatable {
        /// El backend contestó. `discovery` viene ya resuelto para la puerta que preguntó. `migrationInProgress` es el
        /// `migration_in_progress` de `/account/exists` (`false` si no lo dijo): solo lo lee la puerta de «Migrar a la nube».
        case discovered(CloudIdentityRoutingLogic.Discovery, userID: String, migrationInProgress: Bool = false)
        /// No se pudo preguntar: sin sesión, sin JWT, o la red/el gateway no contestaron.
        ///
        /// **No es un resultado de la tabla y no debe tratarse como uno.** La matriz de escenarios lo dice
        /// en su fila «M · cualquier [I]»: error reintentable, sin crear ni borrar nada.
        case unavailable(retryable: Bool)
    }

    private let client: CloudAccountClient
    private let store: AccountKindStore
    private let jwtProvider: @MainActor () async -> String?
    private let userIDProvider: @MainActor () -> String?
    /// **Paso 6** · el faro de iCloud-KV, para limpiarlo cuando esta respuesta PRUEBA que su cuenta ya no
    /// existe. Inyectable: sin él, los tests leerían y BORRARÍAN el iCloud-KV real del simulador.
    private let beacon: CloudBeacon
    /// El método con el que firmó la sesión viva (`"apple"`/`"google"`), leído del Keychain. Solo lo usa la
    /// prueba de Apple de `BeaconOrphanLogic`.
    private let sessionProviderName: @MainActor () -> String?
    private let now: () -> Date

    /// `client` se construye SIN `attestProvider` a propósito: `/account/exists` lo sirve `requireUser`,
    /// que NO exige App Attest —es una ruta pre-sesión, anterior a `/attest/bind`— y cablear attest donde
    /// no se exige es lo que rompe el alta. Ver `.claude/rules/gateway-attest.md`.
    init(
        client: CloudAccountClient? = nil,
        store: AccountKindStore? = nil,
        jwtProvider: (@MainActor () async -> String?)? = nil,
        userIDProvider: (@MainActor () -> String?)? = nil,
        beacon: CloudBeacon? = nil,
        sessionProviderName: (@MainActor () -> String?)? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.client = client ?? CloudAccountClient()
        self.store = store ?? AccountKindStore.shared
        self.jwtProvider = jwtProvider ?? { await CloudAuthService.shared.accessToken() }
        self.userIDProvider = userIDProvider ?? { CloudAuthService.shared.currentUserID }
        self.beacon = beacon ?? CloudBeacon()
        self.sessionProviderName = sessionProviderName ?? { CloudAuthService.shared.storedProvider() }
        self.now = now
    }

    /// Pregunta por la identidad viva y devuelve el resultado que ve la tabla.
    ///
    /// - Parameter gate: la puerta que pregunta. Decide **solo** qué se asume cuando la cuenta existe y el
    ///   servidor no dijo de qué tipo es; con el dato presente, el dato manda.
    func discover(gate: CloudIdentityRoutingLogic.Gate) async -> Outcome {
        guard let userID = userIDProvider(), !userID.isEmpty else {
            // Sin sesión no hay a quién preguntar. NO es reintentable desde aquí: quien reintenta es la
            // puerta, volviendo a firmar.
            return .unavailable(retryable: false)
        }
        guard let jwt = await jwtProvider() else { return .unavailable(retryable: true) }

        // Paso 6 · el faro tal como estaba ANTES de preguntar. Si otro dispositivo del Apple ID lo reescribe
        // mientras la petición está en vuelo, esta respuesta ya no habla de él (ver `clearBeaconIfItsAccountIsGone`).
        let beaconBeforeAsking = BeaconReading(beacon)

        let outcome = await client.exists(jwt: jwt)

        // El userID se re-lee DESPUÉS del await: entre la petición y la respuesta puede haberse cerrado la
        // sesión o entrado otra cuenta, y atribuirle esta respuesta a quien está firmado AHORA sería
        // rutear a una persona con el tipo de cuenta de otra. Mismo guard que `AccountKindService.refresh`.
        guard let userIDVivo = userIDProvider(), userIDVivo == userID else {
            return .unavailable(retryable: false)
        }

        switch CloudWelcomeSignInFlow.route(outcome) {
        case .failed(let retryable):
            return .unavailable(retryable: retryable)

        case .accountMissing:
            clearBeaconIfItsAccountIsGone(sessionUserID: userIDVivo, readBeforeAsking: beaconBeforeAsking)
            return .discovered(.newAccount, userID: userIDVivo)

        case let .accountFound(kind, migrationInProgress):
            // El tipo se cachea aquí porque éste es el único punto de la app donde el backend lo dice
            // antes de que la sesión esté en marcha. `snapshotToPersist` es quien decide si se escribe:
            // un `kind` ausente devuelve `nil` y **no** borra lo que ya sabíamos.
            if let snapshot = AccountKindLogic.snapshotToPersist(
                remote: kind, sessionUserID: userIDVivo, cached: store.read(), now: now()
            ) {
                store.write(snapshot)
            }
            return .discovered(
                CloudIdentityRoutingLogic.discovery(exists: true, kind: kind, gate: gate),
                userID: userIDVivo,
                migrationInProgress: migrationInProgress)
        }
    }

    /// **El faro huérfano se limpia AQUÍ** (decisión de Jürgen 2026-09-09, ticket
    /// `beacon-routes-only-never-blocks`). Éste es el único punto de la app donde el backend dice «esta
    /// identidad no tiene cuenta», y por aquí pasan todas las puertas de [I]: el Welcome y Grupos.
    ///
    /// **Solo con PRUEBA** —la tabla es `BeaconOrphanLogic`—, porque el borrado viaja a todos los
    /// dispositivos del Apple ID y no se deshace. Lo que no se puede probar se queda, y ahí basta con que el
    /// faro no bloquee.
    ///
    /// Se evalúa con el `userID` releído DESPUÉS del `await`, el mismo al que se le atribuye la respuesta:
    /// probar con la identidad de antes limpiaría el faro por la cuenta de otra persona.
    ///
    /// **Y solo si el faro no cambió mientras se preguntaba** (lente B de la review): si otro dispositivo del
    /// mismo Apple ID reclamó una cuenta durante la petición, su faro nuevo no es el que esta respuesta
    /// describe. Lo que NO se puede cerrar desde aquí es el caso contrario —el faro nuevo del otro dispositivo
    /// todavía no ha llegado a éste—, porque el iCloud-KV no tiene compare-and-delete. Residual escrito en
    /// `.claude/rules/swiftdata-cloudkit.md`.
    ///
    /// Sesión secundaria: con el descriptor vivo el borrado lo bloquea `OwnerKeyValueStore`, y por eso el
    /// breadcrumb solo se escribe si el faro de verdad se apagó. En la ventana de ENTRADA, con el descriptor
    /// aún sin activar, las pruebas siguen valiendo: con Apple, SIWA firma con la identidad del DUEÑO del
    /// teléfono; con Google y otro hash no hay prueba.
    private func clearBeaconIfItsAccountIsGone(sessionUserID: String, readBeforeAsking before: BeaconReading) {
        let now = BeaconReading(beacon)
        guard now == before else { return }
        guard let proof = BeaconOrphanLogic.proof(
            accountExists: false,
            beaconLinked: now.linked,
            beaconAccountHash: now.accountHash,
            beaconProvider: now.provider,
            sessionSubHash: CloudBeacon.hash(sessionUserID),
            sessionProvider: sessionProviderName().flatMap(CloudSignInProvider.init(rawValue:))
        ) else { return }
        beacon.clearCloudAccountLinked()
        guard !beacon.isCloudAccountLinked else { return }
        CloudSyncBreadcrumb.beaconOrphanCleared(proof: proof.rawValue)
    }
}

/// Una lectura del faro, para comparar la de antes de preguntar con la de después.
private struct BeaconReading: Equatable {
    let linked: Bool
    let provider: String?
    let accountHash: String?

    @MainActor
    init(_ beacon: CloudBeacon) {
        linked = beacon.isCloudAccountLinked
        provider = beacon.linkedProvider
        accountHash = beacon.accountHash
    }
}

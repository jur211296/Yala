//
//  AccountEntryGroupsHold.swift
//  Yala
//
//  Ticket `adopt-lineage-block-shows-connecting-for-fifteen-minutes`. Al entrar desde el Welcome en una cuenta que ya tiene
//  grupos, el canal de Grupos bajaba ANTES del claim y el puente creaba en local la cuenta «Grupos PEN», sus categorías, el
//  gasto de grupo y su borrador, con identidades de ESTE teléfono. La cuenta ya tenía esas mismas filas, puenteadas por el
//  otro aparato con otras identidades, así que el adopt las veía como huérfanas sin linaje (`noSharedRows`) y la pantalla
//  se quedaba 15 minutos en «Conectando… 60 %». Le pasa a toda persona con grupos que entra desde un teléfono nuevo.
//
//  **El arreglo es el orden: el canal no arranca hasta que el adopt decide.** Mientras este candado esté puesto,
//  `GroupsSyncClient.startIfEligible` no arranca el canal (y sin arrancarlo no hay `context` para los tirones de la UI ni del
//  push). Cuando el adopt aterriza (`storageMode == .cloud` con el motor personal en marcha), Grupos corre detrás del pull
//  personal en el mismo ciclo (paso 5.6 de `CloudSyncRuntime`): el puente encuentra las patas y las filas de sistema que la
//  cuenta ya tenía y no acuña otras. Se descartó la otra opción, que el linaje reconozca las filas del puente como propias:
//  subirían, y la cuenta tendría dos «Grupos PEN» y el mismo gasto de grupo dos veces.
//
//  Ciclo de vida:
//  - **Se arma al firmar en el Welcome** (`WelcomeCloudSignInView.ensureSignedIn`), ANTES de abrir la sesión: no está medido
//    qué disparador arrancó el canal en el iPhone (primer plano, la pestaña montada, el arranque), y todos pasan por
//    `startIfEligible`. Sin sesión todavía se arma con el comodín: frena la sesión que va a abrirse, sea cual sea.
//  - **Frena mientras dure el plazo O haya una migración en vuelo** (`migrationInFlight`, del journal): el adopt puede
//    esperar al import mucho más de una hora, y vencer en medio dejaría pasar justo lo que este candado evita.
//  - **Se retira al aterrizar el adopt** (`landed`): ahí manda el ciclo personal. Y lo retira el Welcome cuando la cuenta
//    resulta ser solo de grupos (la persona viene a usarlos) o cuando la pantalla se cierra sin un adopt que proteger.
//  - **Distinto de `CompleteAccountAdoptPending`** (el del alta por invitación): aquel se suelta al EMPEZAR el adopt, porque
//    su trabajo es el guard cross-cuenta, que ya contó. Este tiene que aguantar hasta que la guarda de linaje del adopt haya
//    decidido, que es después.
//

import Foundation

@MainActor
enum AccountEntryGroupsHold {
    /// Cuánto frena sin una migración en vuelo: cubre leer «¿Cargamos tus datos y entramos?» y un relanzamiento. Un abandono
    /// a medias no puede dejar a la persona sin Grupos más de esto.
    nonisolated static let ttl: TimeInterval = 60 * 60

    /// Frena la sesión que vaya a abrirse, sea de quien sea (se arma antes de firmar).
    nonisolated static let anySession = "*"

    static let subKey = "groupsSync.accountEntryHoldSub"
    static let sinceKey = "groupsSync.accountEntryHoldSince"

    /// Almacén. Los tests lo sustituyen por uno aislado.
    static var defaults: UserDefaults = .standard

    /// Seams de las lecturas vivas. Los tests las sustituyen.
    static var journalConnectedProvider: () -> Bool = { MigrationPhaseStore.shared.isJournalConnected }
    static var migrationInFlightProvider: () -> Bool = { liveMigrationInFlight() }
    static var landedProvider: () -> Bool = { liveLanded() }
    static var storageModeIsCloudProvider: () -> Bool = { CloudSyncFlags.storageMode == .cloud }
    static var journalReadableProvider: () -> Bool = { MigrationPhaseStore.shared.currentJournalRead != .unreadable }

    /// Lo que decide el candado.
    nonisolated enum Decision: Equatable {
        /// El canal espera.
        case hold
        /// El canal puede arrancar; el candado sigue puesto (otra sesión, o ninguna).
        case release
        /// El canal puede arrancar y el candado ya no sirve: se retira.
        case releaseAndClear
    }

    /// Arma el candado. `sub` = la sesión que entra; `nil` (aún sin sesión) arma el comodín.
    static func arm(sub: String?, now: Date = .now) {
        let value: String
        if let sub, !sub.isEmpty { value = sub } else { value = anySession }
        defaults.set(value, forKey: subKey)
        defaults.set(now.timeIntervalSince1970, forKey: sinceKey)
    }

    static func clear() {
        defaults.removeObject(forKey: subKey)
        defaults.removeObject(forKey: sinceKey)
    }

    /// ¿Está puesto? Sin leer el plazo ni el journal.
    static var isArmed: Bool { defaults.string(forKey: subKey) != nil }

    /// ¿Frena el canal de Grupos para la sesión `sub`? Retira el candado si ya no sirve.
    static func blocksChannel(sub: String?, now: Date = .now) -> Bool {
        guard let armedSub = defaults.string(forKey: subKey) else { return false }
        let since = (defaults.object(forKey: sinceKey) as? Double).map(Date.init(timeIntervalSince1970:))
        // Sin journal no se lee nada más: antes de `configure` la fase es el relleno `.notStarted` y `canRunDomain` también la
        // lee (ticket `can-run-domain-reads-the-filler-phase-before-the-journal-connects`).
        let journalConnected = journalConnectedProvider()
        let landed = journalConnected && landedProvider()
        let decision = decide(armedSub: armedSub, armedSince: since, sessionSub: sub, now: now,
                              journalConnected: journalConnected,
                              migrationInFlight: journalConnected && migrationInFlightProvider(),
                              awaitingRemount: journalConnected && !landed && storageModeIsCloudProvider()
                                  && journalReadableProvider(),
                              landed: landed)
        switch decision {
        case .hold:
            return true
        case .release:
            return false
        case .releaseAndClear:
            clear()
            return false
        }
    }

    /// La pantalla del Welcome se cierra: si no queda un adopt que proteger, el candado sobra. Con una migración en vuelo, o
    /// con el modo ya en la nube sin haber aterrizado (el adopt terminó y falta remontar), se queda: lo retira `landed`.
    static func releaseIfNoAdoptPending() {
        guard isArmed, journalConnectedProvider(), !migrationInFlightProvider(), !storageModeIsCloudProvider() else { return }
        clear()
    }

    /// Pura. El orden es el contrato:
    /// 1. Sin candado, nada que frenar.
    /// 2. Sin journal conectado (arranque en frío, antes de `configure`) frena SIN retirar: la fase que se leería es el
    ///    relleno `.notStarted`, y retirarlo ahí soltaba el canal con un adopt pendiente (review adversarial). Quien llama
    ///    vuelve a preguntar cuando el journal conecta.
    /// 3. El adopt aterrizó: manda el ciclo personal y el candado se retira.
    /// 4. Sin sesión no hay canal; con OTRA cuenta que la armada, no es esta entrada.
    /// 5. Con una migración en vuelo, o con el modo ya en la nube esperando el remonte (el adopt terminó y falta reabrir),
    ///    frena venza o no el plazo: el canal levantaría su loop propio sobre el store que se va a remontar.
    /// 6. Dentro del plazo frena; vencido —o con un reloj que retrocede— se retira: un candado que no caduca dejaría a la
    ///    persona sin Grupos.
    nonisolated static func decide(armedSub: String?, armedSince: Date?, sessionSub: String?, now: Date,
                                   journalConnected: Bool = true, migrationInFlight: Bool,
                                   awaitingRemount: Bool = false, landed: Bool) -> Decision {
        guard let armedSub else { return .release }
        guard journalConnected else { return .hold }
        if landed { return .releaseAndClear }
        guard let sessionSub, !sessionSub.isEmpty else { return .release }
        guard armedSub == anySession || armedSub == sessionSub else { return .release }
        if migrationInFlight || awaitingRemount { return .hold }
        guard let armedSince else { return .releaseAndClear }
        let elapsed = now.timeIntervalSince(armedSince)
        return elapsed >= 0 && elapsed < ttl ? .hold : .releaseAndClear
    }

    /// ¿Hay una migración (o un adopt) en vuelo según el journal? Una fase que no es de reposo, o efectos pendientes (el par
    /// `notStarted` + `.adoptBackendAccount` del adopt que reintenta). Un journal ilegible NO cuenta como en vuelo: decide el
    /// plazo, para que una avería del journal no deje a nadie sin Grupos para siempre.
    nonisolated static func migrationInFlight(_ read: JournaledMigrationRead) -> Bool {
        switch read {
        case .unreadable:
            return false
        case .read(let phase, let hasPendingEffects):
            if hasPendingEffects { return true }
            switch phase {
            case .notStarted, .done, .failedRollback, .icloudActive, .reverseFailedRollback:
                return false
            case .dryRun, .consent, .authenticating, .waitingForLeader, .claimingMigration, .assigningIdentity,
                 .uploadingSnapshot, .verifying, .cutover, .reverseConfirm, .reverseClaimLeader, .reverseDrainAll,
                 .reverseVerify, .reverseFreezeBackend, .reverseMountMirror, .reverseReconcile, .reverseUpload:
                return true
            }
        }
    }

    private static func liveMigrationInFlight() -> Bool {
        migrationInFlight(MigrationPhaseStore.shared.currentJournalRead)
    }

    /// El adopt aterrizó: el teléfono ya está en la nube y el motor personal puede correr (store montado sin espejo, fase
    /// estable). Desde ahí Grupos va detrás del pull personal.
    private static func liveLanded() -> Bool {
        CloudSyncFlags.storageMode == .cloud && CloudSyncRuntime.canRunDomain()
    }
}

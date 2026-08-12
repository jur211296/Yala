//
//  GroupsConsentRegistrar.swift
//  Yala
//
//  El registro del consent de GRUPOS contra la CUENTA (chip C1). Una sola pieza para las tres mitades:
//  aceptar, retomar lo que no llegó, y traerse de la cuenta lo que este device todavía no sabe.
//
//  ## Lo que arregla
//
//  El consent de Grupos no llegaba a Yala para el grueso del parque, y no por un bug sino por la rama:
//  `storageMode` es `.icloud` por defecto y Grupos va al 100 % sin exigir Modo Nube ⇒ el epoch acababa en
//  el iCloud KV del Apple ID. Como responsables del tratamiento no podíamos demostrar el consentimiento
//  (RGPD Art. 7.1). **Esto no mueve un registro de canal: para casi todos lo CREA.**
//
//  ## Las cuatro invariantes que no se pueden romper
//
//  1. **El epoch es la hora de la ACEPTACIÓN**, jamás la del reintento que consiguió red. Por eso
//     `acceptedAt` viaja en el intent y en el payload del RPC, y `now` es inyectable en todo este fichero.
//  2. **Se arma ANTES de intentar y se desarma SOLO con 2xx.** `register` escribe el intent antes de tocar
//     la red y antes del `onAccept()` que cierra el sheet: un `throw`, un 403 del kill o un kill del
//     proceso quedan cubiertos por el mismo mecanismo.
//  3. **Append-only.** Aquí no hay ninguna operación de borrado remoto y no debe añadirse: el grant de
//     `groups_consents` no tiene `delete` ni `update`, así que el invariante lo sostiene el servidor.
//  4. **La caché lleva el `userID` dentro** y la lectura NO entra por el canal de prefs — la frontera M1
//     sigue cerrada. El molde entero es `AccountEntitlementService` + `AccountEntitlementStore`.
//
//  ## Por qué el `sub` que no casa ni intenta ni descarta
//
//  Un intent que sobrevive a un relevo de humano en el mismo device no puede registrarse contra la cuenta
//  que hay ahora: sería atribuirle a B la aceptación de A. Y descartarlo tampoco: es la prueba de una
//  aceptación REAL que solo esperaba a tener red. Se queda esperando a su dueño (R9 del spec).
//

import Foundation

@MainActor
final class GroupsConsentRegistrar {

    static let shared = GroupsConsentRegistrar()

    /// Cómo clasificó el registrar la última pasada. Devuelto para los tests y para los breadcrumbs; el
    /// producto no ramifica sobre esto (aceptar NUNCA falla de cara al usuario).
    enum Outcome: Equatable {
        /// No había intención armada.
        case idle
        /// Registrado: el servidor tiene la fila y el intent quedó desarmado.
        case registered
        /// Conservado a propósito (sin sesión, `sub` que no casa, backoff sin vencer, o fallo del servidor).
        case deferred(reason: String)
    }

    private let clientFactory: @MainActor () -> GroupsMembershipClient
    private let userIDProvider: @MainActor () -> String?

    /// Guard de reentrada: boot y post-sign-in pueden coincidir en el mismo instante.
    private var isWorking = false

    /// Dependencias `nil` = las de producción, resueltas DENTRO del init (los defaults de un parámetro se
    /// evalúan en contexto `nonisolated` y estos singletons son `@MainActor`).
    ///
    /// El `attestProvider` NO es opcional en la construcción de producción y su ausencia no la detecta el
    /// compilador: `POST /groups/rpc/{fn}` pasa por `requireUserAndAttest`, así que sin él el gateway
    /// responde 401 `yala_attest_required` bajo `enforce` y **pasa como si nada bajo `observe`, que es lo
    /// que corre staging**. Lo que impide que esta construcción nazca sin proveedor es
    /// `AttestWiringTests`, no el compilador.
    init(
        clientFactory: (@MainActor () -> GroupsMembershipClient)? = nil,
        userIDProvider: (@MainActor () -> String?)? = nil
    ) {
        self.clientFactory = clientFactory ?? {
            GroupsMembershipClient(attestProvider: AttestSessionProvider.live)
        }
        self.userIDProvider = userIDProvider ?? { CloudAuthService.shared.currentUserID }
    }

    // MARK: - Aceptar

    /// El usuario acaba de aceptar. Escribe la caché local, ARMA el intent y lanza el intento.
    ///
    /// El orden importa y es el de la regla de la casa: «recorre la función desde su primera línea y arma
    /// antes del primer `return` que no deje rastro». Aquí el `return` implícito es el `onAccept()` del
    /// caller, que cierra el sheet y sigue el flujo — armar después de él ya es tarde.
    ///
    /// Sin sesión NO se arma (no habría cuenta a la que atribuirlo) y aun así la caché local se escribe: el
    /// usuario aceptó de verdad y la puerta no puede depender de la red. En la práctica ese caso no ocurre
    /// —las tres tablas de routing ordenan sign-in ANTES que consent— y si ocurriera, `adoptLegacyIfNeeded`
    /// lo sella y lo registra en cuanto haya sesión.
    func register(path: String?, now: Date = .now) {
        let userID = userIDProvider()
        GroupsConsentState.write(GroupsConsentSnapshot(
            userID: userID, textVersion: GroupsConsentText.version, acceptedAt: now))
        guard let userID else { return }
        GroupsConsentPendingIntent.arm(
            userID: userID, textVersion: GroupsConsentText.version, acceptedAt: now, path: path, at: now)
        Task { @MainActor in await self.resumeIfNeeded(now: now) }
    }

    // MARK: - Retomar

    /// Retome del intent. Lo llaman el boot y el closure de éxito del sign-in de grupos.
    ///
    /// El canario se emite ANTES de cualquier early-return —molde `bridgedTxOrphanSweepDeferred`— porque si
    /// no, «hay intents frenados» y «no había intents» se leen igual en el dashboard.
    @discardableResult
    func resumeIfNeeded(now: Date = .now) async -> Outcome {
        guard let pending = GroupsConsentPendingIntent.pending else { return .idle }

        let ageHours = max(0, now.timeIntervalSince(pending.armedAt) / 3600)
        MetricsService.canary(
            .groupsConsentPending,
            detail: "attempts:\(pending.attempts)",
            value: ageHours)

        guard !isWorking else { return .deferred(reason: "in-flight") }

        guard let live = userIDProvider() else { return .deferred(reason: "no-session") }
        guard live == pending.userID else {
            // Ni se intenta ni se descarta: el intent espera a su dueño.
            return .deferred(reason: "sub-mismatch")
        }
        guard GroupsConsentRetryBackoffLogic.shouldAttempt(
            attempts: pending.attempts, lastAttemptAt: pending.lastAttemptAt, now: now) else {
            return .deferred(reason: "backoff")
        }

        isWorking = true
        defer { isWorking = false }

        do {
            let state = try await clientFactory().recordConsent(
                textVersion: pending.textVersion, acceptedAt: pending.acceptedAt, path: pending.path)
            // La sesión pudo cerrarse durante el await: confirmar contra otra cuenta desarmaría el intent
            // de alguien que no es quien está ahora (molde `AccountEntitlementService.persist`).
            guard userIDProvider() == pending.userID else {
                return .deferred(reason: "session-changed")
            }
            GroupsConsentPendingIntent.confirm(userID: pending.userID, textVersion: pending.textVersion)
            applyServerState(state, sessionUserID: pending.userID)
            return .registered
        } catch {
            return classifyFailure(error, at: now)
        }
    }

    /// Clasificación de errores. NUNCA un `try?`: cada rama significa algo distinto y el 400 es el que hay
    /// que poder ver desde fuera.
    private func classifyFailure(_ error: Error, at now: Date) -> Outcome {
        GroupsConsentPendingIntent.noteFailedAttempt(at: now)
        guard let rpcError = error as? GroupsRPCError else {
            #if DEBUG
            print("GroupsConsentRegistrar: Error registrando consent: \(error)")
            #endif
            return .deferred(reason: "unknown")
        }
        switch rpcError {
        case .channelDisabled:
            // Kill-switch: sin canal no hay grupos, pero el consent YA ocurrió. Transitorio: el canal se
            // levantará sin que el usuario haga nada.
            return .deferred(reason: "channel-disabled")
        case .sessionExpired, .transient, .decoding:
            return .deferred(reason: "transient")
        case .badInput, .notAuthorized, .permanentRejected, .invalidInvite, .groupExists,
             .invalidGroupID, .memberNotFound, .cannotRemoveOwner, .ownerCannotLeave:
            // Un rechazo permanente sobre un registro LEGAL es un bug nuestro, no una razón para tirar la
            // prueba: se CONSERVA y se hace ruido. El backoff impide que el bucle cueste batería.
            MetricsService.canary(.groupsConsentRegistrationRejected, detail: "\(rpcError)")
            #if DEBUG
            print("GroupsConsentRegistrar: registro RECHAZADO por el servidor: \(rpcError)")
            #endif
            return .deferred(reason: "rejected")
        }
    }

    // MARK: - Leer de la cuenta / adoptar el legacy

    /// Sesión nueva o arranque con sesión viva: adopta el consent LEGACY si lo hay, retoma el intent y
    /// trae el estado de la cuenta. Es lo que hace que el consent siga a la persona (entra en su iPad,
    /// hace login, y la app ya lo sabe) y lo que CREA el registro del parque que aceptó antes de C1.
    func handleSignIn() async {
        await adoptLegacyIfNeeded()
        await resumeIfNeeded()
        await refreshFromServer()
    }

    /// El consent que este device tiene en el formato anterior a C1 (o sin sellar) pasa a snapshot sellado
    /// con el `sub` vivo, y se ARMA su registro contra la cuenta. Idempotente y barato: sin sesión, sin
    /// consent local o con el snapshot ya sellado para esta cuenta, es un no-op.
    func adoptLegacyIfNeeded(now: Date = .now) async {
        guard let live = userIDProvider() else { return }
        guard let local = GroupsConsentState.readSnapshot() else { return }
        if local.userID == live, GroupsConsentPendingIntent.isArmed { return }
        guard local.userID == nil || local.userID == live else {
            // Snapshot de OTRA cuenta: no se adopta ni se borra. `GroupsConsentDecisionLogic` ya lo ignora
            // para esta sesión, y borrarlo perdería el consent del dueño si vuelve a entrar.
            return
        }
        if local.userID == nil {
            GroupsConsentState.write(GroupsConsentSnapshot(
                userID: live, textVersion: local.textVersion, acceptedAt: local.acceptedAt))
        }
        GroupsConsentPendingIntent.arm(
            userID: live, textVersion: local.textVersion, acceptedAt: local.acceptedAt,
            path: "adopt-legacy", at: now)
    }

    /// Trae el consent vigente de la CUENTA y sella la caché local con él. Un fallo de red NUNCA borra ni
    /// degrada la caché (molde `AccountEntitlementService`): lo que hay sigue valiendo offline.
    @discardableResult
    func refreshFromServer() async -> Bool {
        guard let live = userIDProvider() else { return false }
        do {
            let state = try await clientFactory().consentState()
            return applyServerState(state, sessionUserID: live)
        } catch {
            #if DEBUG
            print("GroupsConsentRegistrar: no se pudo leer el consent de la cuenta: \(error)")
            #endif
            return false
        }
    }

    /// Sella la caché con lo que dice el servidor, y solo cuando lo del servidor es igual o MÁS NUEVO. Un
    /// estado remoto más viejo que el local no lo pisa: el local puede ser una aceptación de hace un
    /// segundo cuyo registro aún viaja en el intent.
    @discardableResult
    private func applyServerState(_ state: GroupsConsentStateResult, sessionUserID: String) -> Bool {
        guard let version = state.textVersion, let acceptedAt = state.acceptedAt else { return false }
        let local = GroupsConsentState.readSnapshot()
        if let local, local.userID == sessionUserID, local.textVersion > version { return false }
        GroupsConsentState.write(GroupsConsentSnapshot(
            userID: sessionUserID, textVersion: version, acceptedAt: acceptedAt))
        return true
    }
}

//
//  GroupBackendInviteEntryHandler.swift
//  Yala
//
//  Sucesor DARK de `CKShareEntryHandler` para links de invitación BACKEND (contrato C1: `g`+`t`).
//  Flujo (§A1): desbloquea beta → persiste el join intent (regla inviolable: post-accept = intent
//  PERSISTENTE reconciliable) → decide el paso encadenado sign-in → consent → join (pure logic en
//  `GroupBackendInviteEntryLogic`). El reconciler (`GroupJoinReconciler`) completa el join en boot/
//  foreground y limpia el intent cuando el member local materializa por pull.
//
//  DARK: la rama C2 en `AppBootstrapper.handleInviteLink` solo lo invoca con `groupsBackendEnabled` ON.
//  Providers/joinProvider inyectables para tests. Logs fuera de #if DEBUG (excepción SplitSync
//  consciente, sin PII — el displayName JAMÁS se loguea).
//

import Foundation
import OSLog
import SwiftData

@MainActor
enum GroupBackendInviteEntryHandler {

    /// Origen de la invocación (telemetría/logs + discriminador de presentación).
    enum Source: String {
        case universalLink   // tap de un universal link (warm, initialized)
        case boot            // reconciler trigger boot
        case foreground      // reconciler trigger foreground
        /// CTA del propio GroupInviteOnboardingView (join tap / retry) — JAMÁS re-presenta onboarding.
        case userAction
        /// Continuación post sign-in/consent desde los sheets de ContentView (A2).
        case continuation
    }

    private static let logger = Logger(subsystem: "com.yala", category: "SplitSync")

    // MARK: - Señal «acaba de tapear un enlace» (memoria del PROCESO, jamás disco)

    /// Grupos cuyo enlace de invitación se tapeó EN ESTE ARRANQUE. Molde de
    /// `MetricsService.trackedOnceKeys`: `private static var` bajo el aislamiento del enum.
    ///
    /// **Que NO se persista es el mecanismo, no un detalle de implementación.** El join intent vive 7
    /// días en `PendingJoinStore`; si esta señal viajara con él, un arranque cualquiera —sin que nadie
    /// tapeara nada— re-solicitaría la entrada al grupo y al admin le llegaría una solicitud fantasma de
    /// alguien a quien ya rechazó. En memoria, «tapeó» solo puede ser verdad si tapeó.
    private static var tapArmedGroupIDs: Set<String> = []

    /// Marca que este arranque vio un tap de enlace para `groupID`. Lo llama `persistIntent`, que es el
    /// choke point de los DOS caminos de tap: el warm (`handle`) y el frío
    /// (`AppBootstrapper.persistBackendInviteIntent`, que cubre el cold launch y el flag OFF).
    static func armInviteTap(groupID: String) {
        tapArmedGroupIDs.insert(groupID)
    }

    /// PEEK — no consume. La DECISIÓN (`GroupJoinReconcileLogic.decideBackend`) puede correr varias veces
    /// en un arranque (boot y foreground); ninguna de ellas es el efecto, así que ninguna gasta el tap.
    static func isInviteTapArmed(groupID: String) -> Bool {
        tapArmedGroupIDs.contains(groupID)
    }

    /// Consume el tap. Lo gasta el ÚNICO sitio donde ocurre el efecto (`attemptJoin`, justo antes del
    /// RPC), de modo que un tap valga a lo sumo un `join_group` aunque boot y foreground corran en el
    /// mismo arranque.
    static func consumeInviteTapArm(groupID: String) {
        tapArmedGroupIDs.remove(groupID)
    }

    /// Fronteras de sesión y wipe (`AppRouter.resetAll`, `SecondarySessionBoundaryPurge`): un arm puesto
    /// por la persona A jamás debe gastarse con la sesión de la persona B.
    static func clearInviteTapArms() {
        tapArmedGroupIDs.removeAll()
    }

    // MARK: - Dependencias inyectables (default = cadena real de producción)

    static var hasSessionProvider: @MainActor () -> Bool = { CloudAuthService.shared.hasSession }
    static var isConsentedProvider: @MainActor () -> Bool = { GroupsConsentState.isAccepted }
    /// Señal de routing del invitado fresco (paso 6 §A1 / A2): sin onboarding → invite onboarding
    /// primero (captura el nombre antes del join).
    static var hasCompletedOnboardingProvider: @MainActor () -> Bool = {
        UserDefaults.standard.bool(forKey: AppPreferences.Keys.hasCompletedOnboarding)
    }
    static var profileNameProvider: @MainActor () -> String = {
        SessionDefaults.current.string(forKey: "userName") ?? ""
    }
    /// `join_group` RPC. Default = servicio real (gate `groupsBackendEnabled && hasSession`).
    static var joinProvider: @MainActor (_ token: String, _ displayName: String, _ legacyMemberKey: String?) async throws -> JoinGroupResult = {
        token, displayName, legacyMemberKey in
        try await GroupBackendMembershipService(
            client: GroupsMembershipClient(attestProvider: AttestSessionProvider.live))
            .join(token: token, displayName: displayName, legacyMemberKey: legacyMemberKey)
    }
    /// `update_member_display_name` RPC (corrección R1). Default = servicio real.
    static var updateDisplayNameProvider: @MainActor (_ groupID: String, _ displayName: String) async throws -> UpdateDisplayNameResult = {
        groupID, displayName in
        try await GroupBackendMembershipService(
            client: GroupsMembershipClient(attestProvider: AttestSessionProvider.live))
            .updateDisplayName(groupID: groupID, displayName: displayName)
    }

    // MARK: - Entry point (warm tap)

    /// Warm path: universal link backend tapeado con la app inicializada.
    static func handle(
        groupID: String,
        token: String,
        branded: InviteLinkService.BrandedMetadata = .empty,
        source: Source = .universalLink
    ) async {
        // 1. Adopta el dominio Grupos: aceptar una invitación ES el acto deliberado.
        UserDefaults.standard.set(true, forKey: AppPreferences.Keys.groupsBetaUnlocked)
        // 2. Persiste el intent ANTES de cualquier await.
        persistIntent(groupID: groupID, token: token)
        // `canaryOnce` con la MISMA clave que `AppBootstrapper.persistBackendInviteIntent`: el camino
        // del flag OFF persiste el intent allí y re-entra aquí, y con `canary` a secas un solo tap
        // emitía dos eventos. Las dos claves tienen que seguir siendo el `groupID`.
        MetricsService.canaryOnce(.groupJoinIntentPersisted, key: groupID)
        // 3-4. Decide y ejecuta.
        await drive(groupID: groupID, token: token, source: source)
    }

    /// Upsert del join intent backend (keying `zoneName == groupID`). Preserva displayName/currency ya
    /// capturados (silent-setup) en un re-tap. G6-2: captura el `legacyMemberKey` del device (member local del
    /// grupo migrado) para un RE-JOIN — `SplitSyncManager` da el grupo + su `ModelContext` (persistIntent no
    /// tiene contexto propio); si el grupo no está local aún, preserva el ya capturado en un re-tap.
    static func persistIntent(groupID: String, token: String) {
        // El tap se ARMA aquí y no en cada llamador porque este es el choke point: sus dos llamadores
        // (`handle`, warm; `AppBootstrapper.persistBackendInviteIntent`, frío) son ambos un tap de enlace.
        // Tapear ES la petición: sin esta señal el camino en frío de quien fue RECHAZADO se comía el
        // intent en `.correctAndClear` —el member residual `rejected` sigue local— y nunca llamaba a
        // `join_group`, así que el enlace nuevo no hacía nada con la app cerrada.
        armInviteTap(groupID: groupID)
        let existing = PendingJoinStore.entry(zoneName: groupID)
        var legacyMemberKey: String?
        if let group = GroupService.shared.group(for: groupID),
           let context = group.modelContext {
            legacyMemberKey = legacyMemberKeyForRejoin(group: group, context: context)
        }
        PendingJoinStore.save(PendingJoinEntry(
            zoneName: groupID,
            zoneOwnerName: "",
            displayName: existing?.displayName,
            regionFallbackCurrency: existing?.regionFallbackCurrency,
            backendGroupID: groupID,
            inviteToken: token,
            legacyMemberKey: legacyMemberKey ?? existing?.legacyMemberKey
        ))
    }

    /// FUENTE del legacy recordName de CloudKit para un RE-JOIN de grupo migrado (G6-2). La llave sale
    /// SIEMPRE de una FILA de la zona; el `cachedRecordName` no es una fuente, es un SELECTOR.
    ///
    /// **Por qué NO es el molde literal de 2.6.** Los otros cinco resolvedores de identidad preguntan
    /// «¿quién soy?» y por eso llevan el fallback por `sub`. Este pregunta «¿cuál era MI FICHA legacy?», que
    /// es otra cosa: en una zona migrada el `sub` resuelve al member born-backend, cuyo
    /// `cloudKitUserRecordID` está VACÍO por diseño (`GroupsSyncClient.applyMember` nunca lo escribe) ⇒
    /// añadir ese criterio al predicado devolvería vacío o basura. La cascada, en orden:
    ///
    ///  1. **`isCurrentUser` con recordName no vacío**, desempate por `joinedAt` más antiguo (criterio
    ///     CANÓNICO, el mismo de `GroupExpenseService.selectCurrentUserMemberID` y de
    ///     `GroupNotificationService.currentMemberID`). El `fetchLimit = 1` sin `sortBy` de antes era una
    ///     moneda al aire: una zona migrada puede tener DOS filas marcadas del mismo humano —la legacy y la
    ///     born-backend de un re-join que no rebindeó— y si ganaba la born-backend (recordName vacío) se
    ///     perdía la única llave del device.
    ///  2. **Identidad iCloud**: la fila cuyo `cloudKitUserRecordID == cachedRecordName`. Es el peldaño que
    ///     mantiene vivo el caso común (2º device / reinstalación / restore con el mismo Apple ID), donde el
    ///     flag llega apagado —`isCurrentUser` es device-local y no viaja: ni `CKRecordTranslator` ni
    ///     `GroupsSyncClient.applyMember` lo escriben nunca— y **ningún camino PASIVO lo enciende** mientras
    ///     la zona sea del canal backend. `refreshCurrentUserFlags` la deja fuera por DOS caminos, no uno:
    ///     sin sesión Yala su guard `memberIsInBackendChannel && !backendCanResolve` salta el member ENTERO,
    ///     y CON sesión la rama que resuelve por `sub` exige `SplitMember.userID`, que esta fila no tiene
    ///     —la llave CloudKit y la identidad backend viven en filas distintas por diseño: la born-remote deja
    ///     `cloudKitUserRecordID` vacío—, así que cae en la rama que CONSERVA el valor previo. ⇒ la fuente 1
    ///     no es «tardía» aquí: está ciega hasta que el re-join tenga éxito y el pull ADOPTE esta misma fila
    ///     (`GroupsSyncClient.fetchSplitMember` la casa por su fallback `cloudKitUserRecordID == member_key`
    ///     y le escribe `userID`), o sea justo DESPUÉS de que la llave hiciera falta.
    ///
    ///     Tres precisiones MEDIDAS el 2026-08-03, al auditar si esto seguía siendo cierto (lo es, y por
    ///     poco): (i) «nadie» es **nadie pasivo** — `GroupService.ensureCurrentUserMemberExists` sí enciende
    ///     el flag por record-name y NO lleva guard de canal propio; lo que lo mantiene lejos son sus
    ///     call-sites, los tres del camino CloudKit (`GroupJoinReconciler` lo prohíbe explícitamente en la
    ///     rama backend). (ii) La ceguera vale **módulo una fila por zona**: el `memberIsInBackendChannel`
    ///     del refresh sale de un `Dictionary(uniquingKeysWith: { first, _ in first })` sobre un fetch SIN
    ///     `sortBy`, así que en una zona con duplicado MIXTO puede resolver `false` y entonces el flag sí se
    ///     enciende — es el último «decide mirando UNA fila» de la familia del punto 11 de
    ///     `.claude/rules/swiftdata-cloudkit.md`. (iii) Que `refreshCurrentUserFlags` ganara una rama que
    ///     resuelve por `sub` **no alcanza a este peldaño**, y es el error fácil de cometer al leerlo: esa
    ///     rama solo cubre members born-backend o ya adoptados, y el filtro de la era CloudKit de esta
    ///     cascada (`!cloudKitUserRecordID.isEmpty`) los excluye por construcción.
    ///
    ///     **Sin números de línea a propósito.** Los que había (`GroupService:1119` y `:1145-1154`) eran
    ///     EXACTOS al escribirse y hoy el mismo código está +91 líneas más abajo; peor que morir, esas dos
    ///     posiciones aterrizan ahora en otro guard que también retorna temprano y en el comentario del
    ///     backfill, así que seguían PARECIENDO correctas y nada delataba la deriva. Cita símbolos.
    ///  3. **Cache a pelo, SOLO si la zona no tiene censo de la era CloudKit** (ninguna fila con
    ///     `cloudKitUserRecordID`). Con censo y sin match se devuelve `nil`: `migrate_group` construye los
    ///     placeholders desde ese mismo censo, así que una llave que ninguna fila respalda no puede ser MI
    ///     placeholder — y si casa alguno es el de OTRO humano, al que `join_group` le entregaría el
    ///     historial (rebindea por `member_key = X and user_id is null`, sin preguntar de quién es). Ese es
    ///     el daño que la revocación C-3 existe para impedir. `nil` = entrar como member NUEVO, el residual
    ///     §9.3b ya documentado.
    ///
    /// `#Predicate` CONCRETO por tipo (regla inviolable); el filtrado fino va en memoria — molde
    /// `GroupJoinReconciler.currentUserMemberExists`, y los members de una zona son pocos.
    static func legacyMemberKeyForRejoin(group: SplitGroup, context: ModelContext) -> String? {
        // C-3 (D1): si este device revocó las credenciales de re-join del grupo (cambio/cierre del Apple ID
        // con la fila RETENIDA), no hay legacy key que ofrecer. Corta las TRES vías de un golpe: las filas
        // `SplitMember` —hijas de un grupo retenido, o sea que SOBREVIVEN, y cuyo `cloudKitUserRecordID` es
        // el recordName del Apple ID que se fue— y el fallback del cache. El re-join entra entonces como
        // member NUEVO (residual §9.3b, ya documentado) en vez de rebindear server-side la membresía
        // CloudKit-era del humano anterior.
        guard group.rejoinRevokedAt == nil else { return nil }
        let zoneID = group.cloudKitZoneID
        let cached = GroupUserIdentityService.shared.cachedRecordName ?? ""
        let members: [SplitMember]
        do {
            members = try context.fetch(FetchDescriptor<SplitMember>(
                predicate: #Predicate { $0.groupZoneID == zoneID }))
        } catch {
            // Cero silencios. Sin censo legible no hay nada que pueda contradecir al cache, así que se
            // conserva el fallback de siempre en vez de convertir un fallo de lectura en pérdida del rebind.
            logger.error("BackendInvite: legacyMemberKeyForRejoin fetch failed for \(zoneID, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return cached.isEmpty ? nil : cached
        }
        // Solo las filas de la era CloudKit pueden aportar una llave legacy: las born-backend llevan el
        // `member_key` en `memberKey` y el campo CloudKit vacío (separación de canales, G3).
        let cloudKitEra = members.filter { !$0.cloudKitUserRecordID.isEmpty }
        if let flagged = cloudKitEra.filter({ $0.isCurrentUser }).min(by: { $0.joinedAt < $1.joinedAt }) {
            return flagged.cloudKitUserRecordID
        }
        if !cached.isEmpty,
           let byIdentity = cloudKitEra.filter({ $0.cloudKitUserRecordID == cached })
                                       .min(by: { $0.joinedAt < $1.joinedAt }) {
            return byIdentity.cloudKitUserRecordID
        }
        guard cloudKitEra.isEmpty, !cached.isEmpty else {
            if !cloudKitEra.isEmpty {
                // Sin PII (jamás el recordName): el rastro de campo es que la zona tenía censo y lo
                // contradijo. Sustituye al canario que sí se emite cuando la llave se manda y no matchea.
                logger.notice("BackendInvite: legacy key withheld for \(zoneID, privacy: .public) — cached identity backed by none of \(cloudKitEra.count, privacy: .public) CloudKit-era members")
            }
            return nil
        }
        return cached
    }

    // MARK: - Driver compartido (handler + reconciler)

    /// Decide el siguiente paso (sign-in / consent / invite-onboarding / join) re-evaluando condiciones
    /// VIVAS y lo ejecuta. Reusado por el reconciler backend (§A1 pasos 3-4) y por la continuación de
    /// los sheets de A2.
    static func drive(groupID: String, token: String, source: Source) async {
        switch GroupBackendInviteEntryLogic.nextStep(
            hasSession: hasSessionProvider(),
            isConsented: isConsentedProvider(),
            hasCompletedOnboarding: hasCompletedOnboardingProvider(),
            canPresentOnboarding: source != .userAction
        ) {
        case .presentSignIn:
            RouterEntryGate.shared.submit(.presentGroupsSignIn(pendingJoin: groupID))
            logger.notice("BackendInvite[\(source.rawValue, privacy: .public)]: no session → present sign-in for \(groupID, privacy: .public)")
        case .presentConsent:
            RouterEntryGate.shared.submit(.presentGroupsConsent(pendingJoin: groupID))
            logger.notice("BackendInvite[\(source.rawValue, privacy: .public)]: no consent → present consent for \(groupID, privacy: .public)")
        case .presentInviteOnboarding:
            RouterEntryGate.shared.submit(.presentGroupBackendInviteOnboarding(pendingJoin: groupID))
            logger.notice("BackendInvite[\(source.rawValue, privacy: .public)]: fresh user → present invite onboarding for \(groupID, privacy: .public)")
        case .join:
            await attemptJoin(groupID: groupID, token: token, source: source)
        }
    }

    /// Continuación del flujo encadenado desde los sheets de A2 (sign-in OK / consent aceptado) o desde
    /// el drain con condición viva stale: re-lee el intent persistido y re-evalúa el siguiente paso.
    static func continueFlow(zoneName: String) async {
        guard let entry = PendingJoinStore.entry(zoneName: zoneName),
              let groupID = entry.backendGroupID,
              let token = entry.inviteToken
        else {
            logger.notice("BackendInvite[continuation]: no live backend intent for \(zoneName, privacy: .public) — nothing to continue")
            return
        }
        await drive(groupID: groupID, token: token, source: .continuation)
    }

    /// Ejecuta el `join_group` RPC + clasifica el resultado. G6-2: el `legacyMemberKey` se LEE del intent
    /// persistido (lo capturó `persistIntent` con el member local del grupo migrado) — cubre el warm path y el
    /// reconciler de un golpe; `nil` en un join normal (token fresco). Presencia ⇒ RE-JOIN: el server rebindea
    /// la membresía CloudKit-era; el canario `groupLegacyRebindFailed` se dispara si se envió y no matcheó.
    static func attemptJoin(
        groupID: String,
        token: String,
        source: Source
    ) async {
        let intent = PendingJoinStore.entry(zoneName: groupID)
        let legacyMemberKey = intent?.legacyMemberKey
        // R1: displayName SIEMPRE no-vacío (btrim='' → yala_bad_input permanente).
        let displayName = GroupBackendInviteEntryLogic.resolveJoinDisplayName(
            intentName: intent?.displayName,
            profileName: profileNameProvider(),
            defaultName: L10n.Profile.defaultName
        )
        // CONSUMO del tap, justo antes del RPC: este es el único call-site de `join_group`, así que
        // gastarlo aquí garantiza a lo sumo un join por tap aunque boot y foreground corran en el mismo
        // arranque. Consumir ANTES del await obliga a la simetría de abajo: toda rama que CONSERVA el
        // intent RE-ARMA el tap, o un fallo de red se convertiría en pérdida silenciosa (arm gastado,
        // RPC fallido, reconciler que ya no reintenta nunca).
        consumeInviteTapArm(groupID: groupID)
        do {
            let result = try await joinProvider(token, displayName, legacyMemberKey)
            // C6: canario de rebind legacy (solo si se ENVIÓ legacyMemberKey y no matcheó).
            if legacyMemberKey != nil, !result.rebound {
                MetricsService.canary(.groupLegacyRebindFailed)
            }
            handleJoinSuccess(groupID: groupID, result: result, source: source)
        } catch let error as GroupsRPCError {
            handleJoinError(groupID: groupID, error: error, source: source)
        } catch {
            // No-GroupsRPCError → tratar como transient (conserva el intent, reintenta el reconciler).
            // Y si conserva el intent, re-arma el tap: misma simetría que las tres ramas retryables de
            // `handleJoinError`.
            armInviteTap(groupID: groupID)
            logger.error("BackendInvite[\(source.rawValue, privacy: .public)]: join threw non-RPC error for \(groupID, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Resultado

    private static func handleJoinSuccess(groupID: String, result: JoinGroupResult, source: Source) {
        // Tracker: fase desde el status del RPC (pendingApproval → espera-aprobación; active → éxito).
        GroupJoinIntentTracker.shared.rehydrate(zoneName: groupID)
        if let status = SplitMemberStatus(rawValue: result.status) {
            GroupJoinIntentTracker.shared.noteMemberResolved(zoneName: groupID, status: status)
        }
        MetricsService.canary(.groupJoinIntentReconciled, detail: "\(source.rawValue)|\(result.status)")
        logger.notice("BackendInvite[\(source.rawValue, privacy: .public)]: join OK for \(groupID, privacy: .public) status=\(result.status, privacy: .public) rebound=\(result.rebound, privacy: .public)")
        // Intent CONSERVADO: se limpia cuando el member local materialice (pull) vía el reconciler —
        // misma semántica actual (jamás "todo listo" sin member).
    }

    private static func handleJoinError(groupID: String, error: GroupsRPCError, source: Source) {
        let kind = GroupBackendAcceptErrorLogic.classify(error)
        switch kind {
        case .sessionRequired:
            // Sesión cayó a mitad → re-presentar sign-in; intent conservado, reconciler reintenta.
            // Intent conservado ⇒ tap RE-ARMADO (simetría exacta): sin esto el reintento volvería a
            // decidir `.correctAndClear` con el member residual y el join no saldría nunca.
            armInviteTap(groupID: groupID)
            RouterEntryGate.shared.submit(.presentGroupsSignIn(pendingJoin: groupID))
            logger.notice("BackendInvite[\(source.rawValue, privacy: .public)]: session required for \(groupID, privacy: .public) → present sign-in")
        case .transient:
            // Sin alerta; conserva intent (el reconciler reintenta) ⇒ tap RE-ARMADO.
            armInviteTap(groupID: groupID)
            logger.notice("BackendInvite[\(source.rawValue, privacy: .public)]: transient join error for \(groupID, privacy: .public) → retry later")
        case .channelDisabled:
            // El kill-switch server-side apagó el canal (el device tenía el percent viejo cacheado: hasta
            // 6 h de `RemoteFlagDecisionLogic.refreshMinInterval`). Es el MISMO estado del mundo que la
            // rama `.backendUnavailable` de `AppBootstrapper.handleInviteLink`, solo que descubierto por
            // el servidor en vez de por el snapshot local ⇒ MISMO canario con el MISMO detail (una serie,
            // no dos que hay que sumar en el dashboard) y MISMA copy. Intent CONSERVADO: el join se
            // completa solo cuando el canal vuelva. Y `.showGroupSyncError`, NUNCA `.showInviteError`,
            // cuyo título está hardcodeado a «Enlace no válido» y aquí sería FALSO — el enlace es
            // perfecto, lo que está apagado es el canal.
            // Intent CONSERVADO ⇒ tap RE-ARMADO, para que el join salga cuando el canal vuelva.
            armInviteTap(groupID: groupID)
            MetricsService.canary(.groupJoinIntentDeferred, detail: "backendChannelOff")
            RouterEntryGate.shared.submit(.showGroupSyncError(
                String(localized: "groups.invite.channelUnavailable")
            ))
            logger.error("BackendInvite[\(source.rawValue, privacy: .public)]: channel killed server-side for \(groupID, privacy: .public) → intent kept, informing user")
        case .invalidInvite, .groupDeleted, .notAuthorized, .generic:
            // PERMANENTE: canario + limpiar intent + alerta localizada (cero silencios).
            MetricsService.canary(.groupJoinFailed, detail: GroupBackendAcceptErrorLogic.slug(for: error))
            PendingJoinStore.clear(zoneName: groupID)
            // Señala el fallo a la vista de onboarding (failedStep) en vez de dejarla en
            // joining/takingLong con el alert retenido detrás del cover; recoverable: false
            // porque el intent ya se limpió (invalidInvite/permanente no se reintenta).
            GroupJoinIntentTracker.shared.noteAcceptFailed(zoneName: groupID, recoverable: false)
            if kind == .groupDeleted {
                // El enlace era REAL: lo que ya no está es el grupo. `linkInvalidDetail` termina en
                // «pídele al admin que regenere uno», y aquí eso manda a una acción IMPOSIBLE — no hay
                // grupo ni admin a quien pedírselo. Ése era el defecto entero del ticket.
                //
                // Se reutiliza el copy de `reconnect.deletedForAll`, que dice exactamente este hecho
                // («Este grupo fue eliminado por su creador») y ya está traducido a los 16 idiomas. Es
                // el MISMO hecho visto desde otro camino, no un préstamo por comodidad. **Aviso para
                // quien edite aquel copy: tiene un segundo consumidor, éste.**
                //
                // El título de `showInviteError` sigue siendo «Enlace no válido» y es honesto: ese
                // enlace ya no lleva a ninguna parte. Lo que cambia es que el cuerpo explica por qué en
                // vez de dar un consejo que no se puede seguir.
                RouterEntryGate.shared.submit(.showInviteError(String(localized: "groups.reconnect.deletedForAll.body")))
            } else if kind == .invalidInvite {
                RouterEntryGate.shared.submit(.showInviteError(String(localized: "groups.invite.linkInvalidDetail")))
            } else {
                RouterEntryGate.shared.submit(.showGroupSyncError(L10n.Groups.Errors.actionFailed))
            }
            logger.error("BackendInvite[\(source.rawValue, privacy: .public)]: PERMANENT join failure for \(groupID, privacy: .public) kind=\(String(describing: kind), privacy: .public)")
        }
    }

    // MARK: - Corrección R1 del displayName (llamada por el reconciler al materializar el member)

    /// Si el silent-setup capturó el nombre real y el member ya existe con el placeholder, corrige vía
    /// `update_member_display_name` UNA vez (guard anti-pisado en la pure logic).
    static func correctDisplayNameIfNeeded(
        groupID: String,
        intentName: String?,
        currentMemberDisplayName: String
    ) async {
        guard GroupBackendInviteEntryLogic.shouldCorrectMemberDisplayName(
            intentName: intentName,
            currentMemberDisplayName: currentMemberDisplayName,
            defaultName: L10n.Profile.defaultName
        ) else { return }
        let name = (intentName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            _ = try await updateDisplayNameProvider(groupID, name)
            logger.notice("BackendInvite: display name corrected for \(groupID, privacy: .public)")
        } catch {
            logger.error("BackendInvite: display name correction failed for \(groupID, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}

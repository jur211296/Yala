//
//  GroupMigrationUploader.swift
//  Yala
//
//  Migra los grupos vivos CloudKit del OWNER al backend (Grupos→backend G6-3, C3). Task del boot con el flag
//  `groupsBackendEnabled` ON. GATE COMPLETO (CRÍTICO 2): `groupsBackendEnabled && hasSession &&
//  GroupsConsentState.isAccepted` + QUIESCENCIA del import personal ANTES del primer save() (el uploader salva
//  al mainContext compartido en los pasos 3 y 6 — sin el gate reintroduce el crash-loop de restore).
//
//  CANDIDATOS/RESUME (CRÍTICO 3): `isOwner && movedToBackendAt == nil && ckSystemFieldsData != nil` — JAMÁS
//  `!isBackendGroup` (la adopción de G6-2 puede flipear isBackendGroup ANTES del paso 3 si el pull de
//  memberships llega primero tras migrate_group → con `!isBackendGroup` el grupo se PERDERÍA del resume). Todos
//  los pasos son idempotentes ⇒ resume = correr el pipeline COMPLETO desde 1. Secuencial por grupo. Un fallo
//  NO bloquea la app: el grupo reintenta en el próximo boot.
//
//  ORDEN CONGELADO por grupo (kill-safe, cada paso idempotente):
//   1. migrate_group RPC (meta histórica + members legacy). already:true → sigue.
//   2. create_group_invite RPC → token (one-shot, sin retry; re-corrida minta token NUEVO, el huérfano expira).
//   3. isBackendGroup=true + save — CloudKit congelado + drain backend ACTIVO (ediciones concurrentes → outbox).
//   4. seed del historial fila-completa (enqueueSnapshotRows, LECTURA VIVA) + drainOnce (captura incrementales).
//   5. pushPending hasta outbox VIVO del grupo = 0 (chunks de 50). blocked/transient → reintenta próximo boot.
//   6. movedToBackendAt + backendReInviteToken + markerEnqueuedFlag=false + save → enqueueMigrationMarker →
//      markerEnqueuedFlag=true + save (orden ajuste #7: encolar a engine.state es durable; kill entre saves →
//      el boot-reconciler C2 re-encola los `movedToBackendAt != nil && !markerEnqueuedFlag`).
//   7. Breadcrumbs + telemetría.
//

import Foundation
import OSLog
import SwiftData

@MainActor
final class GroupMigrationUploader {

    /// TTL del token de re-invite de la migración (1 año, tope del RPC): un member puede re-joinear semanas
    /// después de la migración.
    static let reInviteTTLSeconds = 365 * 24 * 60 * 60

    private let logger = Logger(subsystem: "com.yala.app", category: "GroupsMigration")

    // MARK: - Boundary ops inyectables (default = producción; los tests inyectan mocks)

    private let migrate: (String, [String: Any], [[String: Any]]) async throws -> MigrateGroupResult
    private let createInvite: (String) async throws -> String
    private let seedSnapshot: (SplitGroup) throws -> Void
    private let drain: () -> Void
    private let push: () async -> PushOutcome
    private let liveOutboxCount: (String) throws -> Int
    private let enqueueMarker: (SplitGroup) -> Void
    private let sessionCheck: @MainActor () -> Bool
    private let context: ModelContext
    private let now: () -> Date

    // MARK: - Gate C-4 (fetch de GRUPOS asentado)

    /// Tope de espera del gate y cadencia del sondeo. Espejan `AppBootstrapper.awaitPersonalImportForBootSave`
    /// (`totalPollCap = 120`, `pollInterval = 2`) porque el presupuesto es el mismo: un Task de boot que
    /// DIFIERE al vencer, jamás fuerza. Con 60s la cohorte cuya promoción a auto-sync llega tarde
    /// diferiría en cada boot y no migraría nunca.
    /// `nonisolated`: se usan como valor por DEFECTO de parámetros del `init`, y esos se evalúan en el
    /// contexto del CALLER — con el tipo aislado al MainActor sería un error en el modo Swift 6.
    nonisolated static let fetchGateCapSecondsDefault: TimeInterval = 120
    nonisolated static let fetchGatePollSecondsDefault: TimeInterval = 2

    /// Señal PASIVA del canal de fetch, acotada a las zonas que se van a congelar. Inyectable como el
    /// resto de boundary ops. El default LEE el singleton (un default inerte convertiría un olvido de
    /// cableado en un gate silenciosamente desactivado); los tests inyectan una señal determinista.
    private let fetchGateSignal: @MainActor (Set<String>) -> GroupFetchQuiescenceGate.Signal
    /// Sondeo del gate. `false` = cancelado ⇒ abortar la pasada. Inyectable para que los tests no
    /// duerman (regla: nunca `Task.sleep` largo en tests).
    private let gatePoll: (TimeInterval) async -> Bool
    private let fetchGateCapSeconds: TimeInterval
    private let fetchGatePollSeconds: TimeInterval

    init(
        context: ModelContext,
        now: @escaping () -> Date = { .now },
        sessionCheck: @escaping @MainActor () -> Bool = { CloudAuthService.shared.hasSession },
        fetchGateSignal: (@MainActor (Set<String>) -> GroupFetchQuiescenceGate.Signal)? = nil,
        gatePoll: ((TimeInterval) async -> Bool)? = nil,
        fetchGateCapSeconds: TimeInterval = GroupMigrationUploader.fetchGateCapSecondsDefault,
        fetchGatePollSeconds: TimeInterval = GroupMigrationUploader.fetchGatePollSecondsDefault,
        migrate: ((String, [String: Any], [[String: Any]]) async throws -> MigrateGroupResult)? = nil,
        createInvite: ((String) async throws -> String)? = nil,
        seedSnapshot: ((SplitGroup) throws -> Void)? = nil,
        drain: (() -> Void)? = nil,
        push: (() async -> PushOutcome)? = nil,
        liveOutboxCount: ((String) throws -> Int)? = nil,
        enqueueMarker: ((SplitGroup) -> Void)? = nil
    ) {
        self.context = context
        self.now = now
        self.sessionCheck = sessionCheck
        // Señal PASIVA: SOLO LEE los contadores del delegate. JAMÁS fuerza un fetch de CloudKit (no es
        // por zona: fetchearía la base privada entera y descartaría, con avance de token, lo de los
        // grupos ya congelados en ESTA misma pasada) ni evalúa la promoción (que dispararía un fetch
        // en un Task que nadie awaitea).
        self.fetchGateSignal = fetchGateSignal ?? { zones in
            SplitSyncManager.shared.privateFetchGateSignal(candidateZoneNames: zones)
        }
        self.gatePoll = gatePoll ?? { seconds in
            // Molde de `AppBootstrapper.awaitPersonalStoreReady`: un Task cancelado devuelve el valor
            // conservador (el caller difiere) en vez de busy-spinear. No es un `try?` que silencia.
            do { try await Task.sleep(for: .seconds(seconds)); return true }
            catch { return false }
        }
        self.fetchGateCapSeconds = fetchGateCapSeconds
        self.fetchGatePollSeconds = fetchGatePollSeconds
        self.migrate = migrate ?? { gid, meta, members in
            try await GroupBackendMembershipService(client: GroupsMembershipClient())
                .migrateGroup(groupID: gid, meta: meta, members: members)
        }
        self.createInvite = createInvite ?? { gid in
            try await GroupBackendMembershipService(client: GroupsMembershipClient())
                .createInvite(groupID: gid, ttlSeconds: Self.reInviteTTLSeconds, maxUses: nil)
        }
        self.seedSnapshot = seedSnapshot ?? { group in
            try GroupsSyncClient.shared.enqueueSnapshotRows(for: group, context: context)
        }
        self.drain = drain ?? { GroupsSyncClient.shared.drainOnce(context: context) }
        self.push = push ?? { await GroupsSyncClient.shared.pushPending(context: context) }
        self.liveOutboxCount = liveOutboxCount ?? { gid in
            try GroupsSyncClient.shared.liveGroupOutboxCount(groupID: gid, context: context)
        }
        self.enqueueMarker = enqueueMarker ?? { group in
            SplitSyncManager.shared.enqueueMigrationMarker(group: group)
        }
    }

    // MARK: - Boot entry point

    /// Corre la pasada de migración de TODOS los candidatos. GATE del caller (`AppBootstrapper`): quiescencia
    /// del import + flag + sesión + consent. Idempotente: un candidato que falla reintenta en el próximo boot.
    func run() async {
        // GATE COMPLETO (CRÍTICO 2): flag + sesión + consent. La QUIESCENCIA del import PERSONAL la
        // garantiza el caller (`AppBootstrapper` con `awaitPersonalStoreReady()`, que enruta por
        // `StorageModeSignalRouter`). Primero porque es barato: con el canal apagado no se espera nada.
        guard CloudSyncFlags.groupsBackendEnabled, sessionCheck(), GroupsConsentState.isAccepted else { return }

        // GATE C-4 (fetch de GRUPOS). Va aquí, de PASADA y ANTES de `fetchCandidates()`, por tres razones
        // concretas:
        //  1. El paso 1 (`buildPayload`) fotografía el roster de `SplitMember` al ARRANCAR `migrateOne`,
        //     y ese payload es la ÚNICA vía de los members al backend (`SplitMember` es PULL-ONLY y
        //     `enqueueSnapshotRows` no lo siembra). Un gate colocado más abajo no lo cubriría.
        //  2. No invalida el array de candidatos (aquí todavía no existe).
        //  3. Se espera UNA vez por boot, no N.
        // LO QUE NO CUBRE, dicho en voz alta: para los grupos 2..N el `buildPayload` ocurre minutos
        // después del gate (median k-1 migraciones con RPCs). Eso lo acota el re-chequeo de `migrateOne`;
        // lo que NADIE puede acotar es «existe un record en CloudKit que aún no hemos fetcheado» — ése es
        // el RESCATE, y va en su propio ticket.
        //
        // Las zonas se calculan ANTES del gate porque el gate las necesita (testigo por zona) y porque
        // así se evita esperar en balde cuando no hay nada que migrar. Se mapean a `String` y los
        // `@Model` se sueltan en el acto: nada que una espera pueda invalidar.
        let gateZones = candidateZoneNames()
        guard !gateZones.isEmpty else {
            GroupMigrationProgress.shared.finish()
            return
        }
        guard await awaitGroupFetchSettled(candidateZoneNames: gateZones) else { return }

        let candidates = fetchCandidates()
        guard !candidates.isEmpty else {
            GroupMigrationProgress.shared.finish()
            return
        }
        GroupMigrationProgress.shared.begin(total: candidates.count)

        var completed = 0
        for group in candidates {
            let outcome = await migrateOne(group)
            if outcome == .completed { completed += 1 }
            GroupMigrationProgress.shared.noteGroupFinished()
        }

        GroupMigrationProgress.shared.finish()
        if completed > 0 {
            GroupsSyncBreadcrumb.groupsMigrationCompleted(count: completed)
            MetricsService.canary(.groupMigrationCompleted, value: Double(completed))
        }
    }

    // MARK: - Candidatos

    /// `isOwner && movedToBackendAt == nil && ckSystemFieldsData != nil`. `#Predicate` CONCRETO por tipo.
    private func fetchCandidates() -> [SplitGroup] {
        let descriptor = FetchDescriptor<SplitGroup>(
            predicate: #Predicate { $0.isOwner == true && $0.movedToBackendAt == nil && $0.ckSystemFieldsData != nil })
        do {
            return try context.fetch(descriptor)
        } catch {
            #if DEBUG
            logger.error("GroupsMigration: fetchCandidates falló: \(error)")
            #endif
            return []
        }
    }

    /// Zonas de los candidatos, como `String` planos: alimenta el testigo POR ZONA del gate y sirve de
    /// conteo previo. No retiene ningún `@Model` (los suelta al mapear) ⇒ no hay nada que una espera
    /// pueda invalidar. `#Predicate` CONCRETO por tipo, igual que `fetchCandidates`.
    private func candidateZoneNames() -> Set<String> {
        let descriptor = FetchDescriptor<SplitGroup>(
            predicate: #Predicate { $0.isOwner == true && $0.movedToBackendAt == nil && $0.ckSystemFieldsData != nil })
        do {
            return Set(try context.fetch(descriptor).map(\.cloudKitZoneID))
        } catch {
            #if DEBUG
            logger.error("GroupsMigration: candidateZoneNames falló: \(error)")
            #endif
            return []
        }
    }

    /// Espera PASIVA a que el fetch de grupos se asiente. `false` ⇒ diferir la pasada al próximo boot
    /// (los 7 pasos son idempotentes: diferir jamás pierde trabajo).
    private func awaitGroupFetchSettled(
        candidateZoneNames: Set<String>, capSeconds: TimeInterval? = nil, isPass: Bool = true
    ) async -> Bool {
        let cap = capSeconds ?? fetchGateCapSeconds
        var waited: TimeInterval = 0
        while true {
            let signal = fetchGateSignal(candidateZoneNames)
            switch GroupFetchQuiescenceGate.decide(
                signal: signal,
                waitedSeconds: waited,
                capSeconds: cap,
                canWait: true
            ) {
            case .proceed:
                return true
            case .deferToNextBoot:
                noteFetchGateDeferral(
                    waited: waited,
                    reason: GroupFetchQuiescenceGate.deferReason(signal: signal),
                    isPass: isPass)
                return false
            case .wait:
                guard await gatePoll(fetchGatePollSeconds) else {
                    noteFetchGateDeferral(waited: waited, reason: "cancelled", isPass: isPass)
                    return false
                }
                waited += fetchGatePollSeconds
            }
        }
    }

    /// Rastro + telemetría del diferimiento. `canaryOnce`: como mucho UNA emisión por proceso y clave —
    /// un canario por boot envenenaría el gate de encendido «canarios en cero» del dashboard. Serie
    /// PROPIA (`groupMigrationDeferred`), NUNCA `groupMigrationFailed`: aquí no ha fallado nada. Las dos
    /// claves están SEPARADAS a propósito: con una sola, el diferimiento de PASADA (que gana casi
    /// siempre) silenciaría para todo el proceso al de GRUPO, que es la señal más accionable — significa
    /// que la migración arrancó y un grupo concreto se saltó.
    private func noteFetchGateDeferral(waited: TimeInterval, reason: String, isPass: Bool) {
        GroupsSyncBreadcrumb.groupsMigrationFetchGateDeferred(waited: Int(waited), reason: reason)
        MetricsService.canaryOnce(
            .groupMigrationDeferred, key: isPass ? "fetchGate" : "fetchGatePerGroup", detail: reason)
        if isPass { GroupMigrationProgress.shared.finish() }
    }

    enum StepOutcome: Equatable { case completed, transient }

    // MARK: - Pipeline por grupo

    private func migrateOne(_ group: SplitGroup) async -> StepOutcome {
        let groupID = group.cloudKitZoneID

        // Re-chequeo C-4 por grupo: el gate de pasada corrió ANTES de los grupos #1..#k-1, así que para el
        // #k pueden haber pasado minutos. Si mientras tanto se abrió un ciclo de fetch, llegaron batches al
        // búfer o el fetch de ESTA zona falló, se ESPERA (cap corto — la pasada ya gastó su presupuesto) en
        // vez de saltar el grupo: un ciclo de auto-sync en vuelo es un estado normal y frecuente a mitad de
        // pasada, y tratarlo como «diferir» repartiría una migración de N grupos entre N arranques.
        guard await awaitGroupFetchSettled(
            candidateZoneNames: [groupID], capSeconds: fetchGateCapSeconds / 4, isPass: false
        ) else { return .transient }
        // La espera abre ventana a los eventos del delegate, que pueden BORRAR este `@Model`
        // (`applyRemoteDeletion`, `deleteGroupCache`, `clearAllLocalGroupData`) o migrarlo por otra vía.
        // Re-validar antes de escribir sobre él: `context.save()` sobre un modelo borrado es corrupción.
        guard !group.isDeleted, group.movedToBackendAt == nil else { return .transient }

        // Paso 1: migrate_group (meta histórica + members). already:true sigue. Payload inválido → abortar
        // este boot y RE-EVALUAR en el próximo (H3 review: se retorna .transient a propósito — el caso real
        // [cloudKitUserRecordID vacío pre-backfill] es RESOLUBLE con el tiempo; sin spam de RPC porque el
        // guard retorna ANTES de llamar migrate()).
        guard let payload = buildPayload(for: group) else {
            logger.error("GroupsMigration: payload inválido para el grupo (skip) — sin owner válido / meta mala")
            GroupsSyncBreadcrumb.groupsMigrationFailed(step: "migrate:payload")
            MetricsService.canary(.groupMigrationFailed, detail: "migrate:payload")
            return .transient
        }
        do {
            _ = try await migrate(groupID, payload.meta, payload.members)
        } catch {
            logMigrationStepFailure(step: "migrate", error: error)
            return .transient
        }

        // Paso 2: create_group_invite → token (one-shot; re-corrida minta token nuevo).
        let token: String
        do {
            token = try await createInvite(groupID)
        } catch {
            logMigrationStepFailure(step: "invite", error: error)
            return .transient
        }

        // Paso 3: isBackendGroup=true + save. A PARTIR DE AQUÍ CloudKit congelado + drain backend ACTIVO.
        if !group.isBackendGroup {
            group.isBackendGroup = true
            do {
                try context.save()
            } catch {
                logMigrationStepFailure(step: "freeze", error: error)
                return .transient
            }
        }

        // Paso 4: seed del historial fila-completa (LECTURA VIVA) + drainOnce (captura incrementales concurrentes).
        do {
            try seedSnapshot(group)
        } catch {
            logMigrationStepFailure(step: "seed", error: error)
            return .transient
        }
        drain()

        // Paso 5: push hasta outbox VIVO del grupo = 0.
        guard await pushUntilGroupDrained(groupID: groupID) else {
            GroupsSyncBreadcrumb.groupsMigrationFailed(step: "push")
            MetricsService.canary(.groupMigrationFailed, detail: "push")
            return .transient
        }

        // Paso 6: estampar el marcador (orden ajuste #7).
        group.movedToBackendAt = now()
        group.backendReInviteToken = token
        group.markerEnqueuedFlag = false
        do {
            try context.save()
        } catch {
            logMigrationStepFailure(step: "marker", error: error)
            return .transient
        }
        enqueueMarker(group)   // encolar a engine.state (durable)
        group.markerEnqueuedFlag = true
        do {
            try context.save()
        } catch {
            // Kill entre este save y el previo → el boot-reconciler C2 lo re-encola (movedToBackendAt != nil
            // && !markerEnqueuedFlag). No es fatal: el marcador YA está encolado a engine.state.
            logMigrationStepFailure(step: "marker", error: error)
            return .transient
        }
        return .completed
    }

    /// Chunks de 50 los aplica `pushPending`; se repite hasta que el outbox VIVO del grupo llega a 0 o un
    /// outcome no-completed corta (blocked/transient → reintenta próximo boot). Un dead-letter NO es fila viva
    /// → el grupo puede quedar con rechazos permanentes; `liveOutboxCount` los excluye ⇒ avanza igual (el
    /// mismatch resultante en el Merkle degrada honesto, no hay cutover con pérdida silenciosa).
    private func pushUntilGroupDrained(groupID: String, maxRounds: Int = 40) async -> Bool {
        for _ in 0..<maxRounds {
            let live: Int
            do { live = try liveOutboxCount(groupID) } catch { return false }
            if live == 0 { return true }
            switch await push() {
            case .completed:
                continue
            case .sessionExpired, .accountUnavailable, .transient:
                return false
            }
        }
        return false
    }

    // MARK: - Payload

    private func buildPayload(for group: SplitGroup) -> (meta: [String: Any], members: [[String: Any]])? {
        let meta = GroupMigrationMetaSnapshot(
            name: group.name, currencyCode: group.currencyCode, iconName: group.iconName,
            colorHex: group.colorHex, defaultSplitType: group.defaultSplitType,
            simplifyDebts: group.simplifyDebts, showDebtsInSingleCurrency: group.showDebtsInSingleCurrency,
            membersCanInvite: group.membersCanInvite, createdAt: group.createdAt)

        let zoneID = group.cloudKitZoneID
        let memberModels: [SplitMember]
        do {
            memberModels = try context.fetch(FetchDescriptor<SplitMember>(
                predicate: #Predicate { $0.groupZoneID == zoneID }))
        } catch {
            #if DEBUG
            logger.error("GroupsMigration: fetch members falló: \(error)")
            #endif
            return nil
        }
        var skippedNoRecordName = 0
        let snapshots: [GroupMigrationMemberSnapshot] = memberModels.map { m in
            if m.cloudKitUserRecordID.isEmpty { skippedNoRecordName += 1 }
            return GroupMigrationMemberSnapshot(
                memberKey: m.cloudKitUserRecordID, displayName: m.displayName, role: m.role,
                status: m.status, isOwner: m.isGroupOwner, joinedAt: m.joinedAt)
        }
        if skippedNoRecordName > 0 {
            // Residual CloudKit-era (molde del skip del Merkle B1): un member sin recordName no se puede
            // migrar; se salta. Sin PII. (H1 review: fase PAYLOAD, no seed — etiqueta corregida.)
            GroupsSyncBreadcrumb.groupsMigrationFailed(step: "payload:memberNoRecordName")
        }
        return GroupMigrationPayloadBuilder.build(groupID: zoneID, meta: meta, members: snapshots)
    }

    // MARK: - Boot-reconciler (C2, ajuste #7)

    /// Re-encola el MARCADOR de los grupos `movedToBackendAt != nil && !markerEnqueuedFlag` (kill entre el
    /// save del marcador [paso 6a] y el flag [paso 6c]). Vacío en estado estable → sin write redundante del
    /// GroupMeta en cada boot. Gateado por quiescencia por el caller (salva el mainContext). `static`: no
    /// necesita el estado del uploader.
    @MainActor
    static func reconcileMarkers(context: ModelContext) {
        // C-3: acotado al OWNER. El marcador es del owner que migró (paso 6) y solo él puede subirlo a su
        // propia zona; una copia congelada de MIEMBRO casa el resto del predicado por construcción
        // (`markerEnqueuedFlag` es LOCAL-only y nace `false`) y hoy hace que el device del miembro encole un
        // GroupMeta contra una zona inexistente de su propia private DB. Con las filas RETENIDAS tras un
        // cambio de Apple ID (D1) eso pasaría a subir el GroupMeta del grupo bajo la identidad NUEVA.
        // `#Predicate` CONCRETO por tipo (regla inviolable).
        let descriptor = FetchDescriptor<SplitGroup>(
            predicate: #Predicate { $0.isOwner == true && $0.movedToBackendAt != nil && $0.markerEnqueuedFlag == false })
        let pending: [SplitGroup]
        do {
            pending = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("GroupsMigration: reconcileMarkers fetch falló: \(error)")
            #endif
            return
        }
        guard !pending.isEmpty else { return }
        for group in pending {
            SplitSyncManager.shared.enqueueMigrationMarker(group: group)
            group.markerEnqueuedFlag = true
        }
        do {
            try context.save()
        } catch {
            #if DEBUG
            print("GroupsMigration: reconcileMarkers save falló: \(error)")
            #endif
            return
        }
        GroupsSyncBreadcrumb.groupsMigrationMarkerReconciled(count: pending.count)
    }

    // MARK: - Helpers

    private func logMigrationStepFailure(step: String, error: Error) {
        #if DEBUG
        logger.error("GroupsMigration: paso \(step, privacy: .public) falló: \(error.localizedDescription, privacy: .public)")
        #endif
        GroupsSyncBreadcrumb.groupsMigrationFailed(step: step)
        MetricsService.canary(.groupMigrationFailed, detail: step)
    }
}

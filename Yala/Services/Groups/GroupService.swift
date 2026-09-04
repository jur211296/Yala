//
//  GroupService.swift
//  Yala
//
//  CRUD for groups and members.
//  Persistencia local del dominio Grupos. Las operaciones de MEMBRESÍA que viajan lo hacen por el canal
//  backend (RPC); la Fase 3 se llevó el encolado a CKSyncEngine y la creación de zonas de CloudKit.
//

import Foundation
import SwiftData
import os.log

@MainActor
@Observable
final class GroupService {

    // MARK: - Singleton

    static let shared = GroupService()

    // MARK: - Properties

    private var modelContext: ModelContext?
    private let logger = Logger(subsystem: "com.yala", category: "GroupService")

    /// `sub` de la sesión Yala para la resolución de identidad del canal backend en
    /// `refreshCurrentUserFlags`. Inyectable para tests — mismo molde que
    /// `GroupJoinReconciler.backendUserIDProvider`, que ya existía por la misma razón.
    ///
    /// Sin este seam la pieza más delicada de 2.6 no es testeable: su rama por `sub` decide quién ve qué
    /// balance y sus tres guards (no estampar el record-name en zona backend, no apagar `isCurrentUser`
    /// sin iCloud, no inferir `isGroupOwner` en el canal nuevo) no tienen otra vía de alcanzarse desde
    /// una suite. NO hace falta tocar `CloudAuthService`: el default lee de él y los tests lo sustituyen.
    static var backendUserIDProvider: @MainActor () -> String? = { CloudAuthService.shared.currentUserID }

    // MARK: - Init

    private init() {}

    // MARK: - Context Injection

    func setContext(_ context: ModelContext?) {
        self.modelContext = context
    }

    private func requireContext() throws -> ModelContext {
        guard let context = modelContext else {
            throw GroupServiceError.noContext
        }
        return context
    }

    #if DEBUG
    /// Resetea el contexto inyectado — tests que setean un contexto propio deben limpiarlo
    /// al salir para no contaminar otras suites (mismo patrón que GroupExpenseService).
    func _testResetContext() {
        self.modelContext = nil
    }
    #endif

    // MARK: - Backend channel routing (G5-A / C5)

    /// `true` si esta op de membership debe ir por el canal BACKEND (RPC) en vez de CKSyncEngine:
    /// flag `groupsBackendEnabled` ON Y la ZONA es del canal backend. Con el flag OFF SIEMPRE `false`
    /// → camino CloudKit byte-idéntico.
    ///
    /// **La unidad es la ZONA, no la fila del parámetro** (`GroupBackendIdentityLogic.membershipRoutesToBackend`,
    /// criterio ANY-row — mismo molde que `GroupZoneCacheGate.belongsToBackendChannel`). Decidía
    /// `flag && group.isBackendGroup`, y con un `SplitGroup` DUPLICADO **mixto** en la zona el MISMO grupo se
    /// enrutaba por un canal u otro según qué fila tuviera el caller en la mano: los siete call-sites de esta
    /// función eligen entre «RPC server-first» y «CloudKit», y equivocarse hacia CloudKit produce un ÉXITO
    /// LOCAL FALSO —`leaveGroup` no llama a `leave_group`, `approveMember`/`removeMember` no llaman a su RPC,
    /// los dos guards defensivos de `rejectMember`/`changeRole` dejan de lanzar— con el usuario intacto
    /// server-side (y, en el caso del leave, todavía `is_group_writer`).
    ///
    /// El fetch degrada a la fila en mano si no hay contexto o si lanza: nunca peor que el criterio anterior.
    ///
    /// **Fase 3 — lo que este docblock declaraba como red de seguridad ya no existe, y por eso este
    /// predicado se quedó solo.** El choke-point C2 de aguas abajo era `SplitSyncManager.enqueueSave`, que
    /// con `GroupFreezeLogic.zoneBlocksCloudKitWrites` volvía no-op el encolado de `removeMember`,
    /// `removeMemberLocal` y `approveMember` cuando este predicado se hubiera equivocado. Borrado el
    /// transporte no hay segunda barrera: **equivocarse aquí hacia `false` ya no produce una escritura a un
    /// canal muerto, produce que la op no viaje a ninguna parte**, que es un fallo más visible pero también
    /// más silencioso en local. El criterio ANY-row por zona es lo único que lo sostiene.
    private func routesMembershipToBackend(_ group: SplitGroup) -> Bool {
        let flagEnabled = CloudSyncFlags.groupsBackendEnabled
        // Con el flag OFF no se enumera la zona: el resultado ya es `false` y el camino CloudKit tiene que
        // quedar byte-idéntico —también en trabajo— para la cohorte que no tiene el canal encendido.
        let rowsInZone = flagEnabled ? backendFlagsInZone(group.cloudKitZoneID) : []
        return GroupBackendIdentityLogic.membershipRoutesToBackend(
            flagEnabled: flagEnabled,
            inHandIsBackendGroup: group.isBackendGroup,
            rowsInZone: rowsInZone)
    }

    /// `isBackendGroup` de TODAS las filas de la zona. Devuelve **vacío** sin contexto o si el fetch lanza —
    /// el caller cae entonces a la fila en mano, que es exactamente el comportamiento anterior a este fix.
    private func backendFlagsInZone(_ zoneID: String) -> [Bool] {
        guard let context = modelContext else { return [] }
        do {
            return try context
                .fetch(FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.cloudKitZoneID == zoneID }))
                .map(\.isBackendGroup)
        } catch {
            #if DEBUG
            logger.error("routesMembershipToBackend: fetch de la zona \(zoneID, privacy: .public) falló: \(error.localizedDescription, privacy: .public)")
            #endif
            return []
        }
    }

    /// Servicio de membership del canal backend (RPC tipado). Inyectable para tests (`.shared` es singleton).
    /// `attestProvider` OBLIGATORIO: todo lo que sale de aquí va a `POST /groups/rpc/{fn}`, que exige App
    /// Attest bajo `enforce` (guard `requireUserAndAttest`, `gateway/src/groups/rpc.ts:87-89`; `:81-83` es
    /// la validación del JWT de Supabase, otra cosa).
    var backendMembershipFactory: @MainActor () -> GroupBackendMembershipService = {
        GroupBackendMembershipService(
            client: GroupsMembershipClient(attestProvider: AttestSessionProvider.live))
    }

    // MARK: - Group CRUD

    // C4 · `createGroup` FUE BORRADA aquí, y no por dead-code: **era la fábrica de zombis.** Acuñaba un
    // `SplitGroup` con `isBackendGroup == false` (el default del modelo), y eso es irrecuperable —
    // `fetchCandidates` tiene cero ocurrencias en el repo, `migrate_group` no tiene endpoint en
    // `gateway/src/`, `movedToBackendAt` no tiene escritor que lo ponga y `createShareLink` devuelve
    // `Groups.Errors.inviteFailed` para todo grupo no-backend ⇒ grupo de una persona, no invitable, para
    // siempre. Su único call-site de producción era la rama `.cloudKit` de `GroupFormView.saveAsync`, que
    // murió con ella; dejarla viva y sin llamador sería la familia de `AppAttestClient.ensureRegistered()`.
    // **La creación de grupos vive HOY en `GroupBackendMembershipService.createGroup` (RPC server-first),
    // y es el único camino.** No la resucites: para reabrir la creación local haría falta antes un
    // productor de migración que hoy no existe en ninguna capa.

    /// Update group metadata.
    /// G6-3 (C4, FREEZE — RED de correctness): un grupo migrado y congelado (`movedToBackendAt != nil &&
    /// !isBackendGroup`, con la mitigación #9 del owner reinstall) NO acepta escrituras — sus records irían a
    /// la zona CloudKit congelada y se perderían. Lanza `.movedToBackend`. `leaveGroup` NUNCA se congela (salir
    /// de la copia muerta es lo deseado).
    func validateGroupIsWritable(_ group: SplitGroup) throws {
        if group.isMigratedFrozen { throw GroupServiceError.movedToBackend }
    }

    func updateGroup(
        _ group: SplitGroup,
        name: String,
        iconName: String,
        colorHex: String,
        currencyCode: String,
        simplifyDebts: Bool,
        showDebtsInSingleCurrency: Bool,
        defaultSplitType: String,
        membersCanInvite: Bool
    ) throws {
        let context = try requireContext()
        try validateGroupIsWritable(group)
        try requireCurrentUserAdmin(in: group, context: context)

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw GroupServiceError.emptyName }

        group.name = trimmedName
        group.iconName = iconName
        group.colorHex = colorHex
        group.currencyCode = currencyCode
        group.simplifyDebts = simplifyDebts
        group.showDebtsInSingleCurrency = showDebtsInSingleCurrency
        group.defaultSplitType = defaultSplitType
        group.membersCanInvite = membersCanInvite

        do {
            try context.save()
        } catch {
            throw GroupServiceError.saveFailed(error)
        }

        SessionState.shared.incrementDataVersion()
    }

    /// Update the group options that ANY active member may change (not admin-only).
    /// `simplifyDebts` y `defaultSplitType` afectan cómo se presentan las deudas a todos, pero no
    /// son decisiones estructurales del owner (la moneda única sí lo es y se queda en `updateGroup`).
    func updateMemberEditableOptions(
        _ group: SplitGroup,
        simplifyDebts: Bool,
        defaultSplitType: String
    ) throws {
        let context = try requireContext()
        try validateGroupIsWritable(group)
        try requireCurrentUserActiveMember(in: group, context: context)

        group.simplifyDebts = simplifyDebts
        group.defaultSplitType = defaultSplitType

        do {
            try context.save()
        } catch {
            throw GroupServiceError.saveFailed(error)
        }

        SessionState.shared.incrementDataVersion()
    }

    /// Archive or unarchive a group.
    func setArchived(_ group: SplitGroup, isArchived: Bool) throws {
        let context = try requireContext()
        try validateGroupIsWritable(group)
        try requireCurrentUserAdmin(in: group, context: context)
        group.isArchived = isArchived

        do {
            try context.save()
        } catch {
            throw GroupServiceError.saveFailed(error)
        }

        SessionState.shared.incrementDataVersion()
    }

    /// Soft-delete del grupo. Owner-only. Bloquea si cualquier miembro tiene balance pendiente.
    /// Propaga `isHiddenForAll` por dos canales (idem setArchived): SplitGroup record sync +
    /// CKShare custom key. Invisible para todos los miembros al próximo sync; el CKShare custom
    /// key gateá retap link al modo `.deletedForAll` para devices sin SplitGroup local.
    /// Irreversible desde la app — recovery solo vía CloudKit Dashboard (ver apuntes-grupos.md).
    /// Adicional: dispara `freezeForSoftDelete` para limpiar TX/drafts personales bridgeadas.
    func softDelete(_ group: SplitGroup) throws {
        let context = try requireContext()
        guard group.isOwner else { throw GroupServiceError.notOwner }

        // Recalcular balances internamente (defensa en profundidad — no confía en UI).
        let expenses = try GroupExpenseService.shared.fetchExpenses(for: group)
        let shares = try GroupExpenseService.shared.fetchAllShares(for: group)
        let members = try fetchMembers(for: group)
        let settlements = try GroupExpenseService.shared.fetchSettlements(for: group)

        let balances = GroupBalanceService.calculateBalances(
            expenses: expenses,
            shares: shares,
            members: members,
            settlements: settlements
        )
        guard balances.allSatisfy({ abs($0.netBalance) <= 0.01 }) else {
            throw GroupServiceError.outstandingBalance
        }

        group.isHiddenForAll = true

        do {
            try context.save()
        } catch {
            throw GroupServiceError.saveFailed(error)
        }

        SessionState.shared.incrementDataVersion()

        // Sube el SplitGroup record con isHiddenForAll=true para que el sync lo propague
        // a los devices de los invitados (el CKShare custom key abajo es solo race-tolerant
        // fallback para el flow de retap link).

        // Libera TX cuenta real (preserva rastro financiero) + convierte drafts a manual.
        // No-bloqueante: el observer del sync y la red de seguridad boot-time cubren
        // con idempotency si esta llamada falla.
        if GroupTransactionBridge.shared.isReady {
            do {
                try GroupTransactionBridge.shared.freezeForSoftDelete(group: group)
            } catch {
                #if DEBUG
                logger.error("softDelete: freezeForSoftDelete failed: \(error.localizedDescription, privacy: .public)")
                #endif
            }
        }

        let zoneID = group.cloudKitZoneID

        // Cleanup override del bridge para este zone — el SplitGroup queda visible
        // pero `isHiddenForAll==true` lo trata como zona inactiva; el override ya no
        // tiene callsite vivo.
        do {
            try BridgeModeResolver.shared.clearOverride(forZoneID: zoneID, in: context)
        } catch {
            #if DEBUG
            logger.error("softDelete: clearOverride failed: \(error.localizedDescription, privacy: .public)")
            #endif
        }
    }

    // MARK: - Member Management

    /// Add a member to a group.
    @discardableResult
    func addMember(
        to group: SplitGroup,
        displayName: String,
        role: String = "member"
    ) throws -> SplitMember {
        let context = try requireContext()
        try requireCurrentUserAdmin(in: group, context: context)

        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw GroupServiceError.emptyMemberName }
        guard role == "admin" || role == "member" else { throw GroupServiceError.invalidRole }

        let member = SplitMember(
            groupZoneID: group.cloudKitZoneID,
            displayName: trimmedName,
            role: role
        )
        context.insert(member)

        do {
            try context.save()
        } catch {
            throw GroupServiceError.saveFailed(error)
        }

        SessionState.shared.incrementDataVersion()

        return member
    }

    /// Remove a member from a group.
    ///
    /// C5: grupo backend + flag ON → RPC `remove_member` SERVER-FIRST; a éxito, la mutación local optimista
    /// corre por `removeMemberLocal` (su `enqueueSave` queda no-op por C2). RPC falla → throw, local INTACTO.
    /// Flag OFF → camino CloudKit byte-idéntico.
    func removeMember(_ member: SplitMember, from group: SplitGroup) async throws {
        if routesMembershipToBackend(group) {
            guard let memberKey = member.memberKey else { throw GroupServiceError.missingMemberKey }
            _ = try await backendMembershipFactory().remove(
                groupID: group.cloudKitZoneID, memberKey: memberKey)
        }
        try removeMemberLocal(member, from: group)
    }

    /// Cuerpo local (síncrono) de `removeMember`: validación + `.removed` + save + enqueue. Extraído para
    /// que la rama backend de C5 lo reuse tras el RPC (el `enqueueSave` queda no-op por el guard C2).
    private func removeMemberLocal(_ member: SplitMember, from group: SplitGroup) throws {
        let context = try requireContext()
        // C-10: red service-level. El detalle de un grupo congelado pasó a ser alcanzable, y estas
        // escrituras irían a una zona CloudKit muerta: se perderían en silencio.
        try validateGroupIsWritable(group)
        try requireCurrentUserAdmin(in: group, context: context)

        guard member.groupZoneID == group.cloudKitZoneID else { throw GroupServiceError.memberNotInGroup }
        guard !member.isCurrentUser else { throw GroupServiceError.cannotRemoveSelf }
        guard !member.isGroupOwner else { throw GroupServiceError.ownerMemberImmutable }
        guard member.isActive else { return }

        // Cannot remove the last admin
        if member.role == "admin" {
            let adminCount = try activeAdminCount(in: group, context: context)
            guard adminCount > 1 else { throw GroupServiceError.lastAdmin }
        }

        member.memberStatus = .removed
        // NOTE: `isCurrentUser` no se setea aquí — es device-local, no se sincroniza vía
        // CKRecord. `refreshCurrentUserFlags` lo reescribe en cada device basándose en el
        // matching de `cloudKitUserRecordID` con el current iCloud user.

        do {
            try context.save()
        } catch {
            throw GroupServiceError.saveFailed(error)
        }

        SessionState.shared.incrementDataVersion()
    }

    /// members awaiting admin approval (status `.pendingApproval`).
    func pendingMembers(in group: SplitGroup) throws -> [SplitMember] {
        try fetchMembers(for: group).filter { $0.isPendingApproval }
    }

    /// admin approves a pending member, marking them as active and enqueuing sync.
    ///
    /// C5: grupo backend + flag ON → RPC `approve_member` SERVER-FIRST (RLS lo autoriza); a éxito, la
    /// mutación local optimista corre por el MISMO `transitionPendingMember` (su `enqueueSave` queda no-op
    /// por el guard C2 — el pull confirma). RPC falla → throw ANTES de tocar el contexto → alert del
    /// call-site, local INTACTO. Flag OFF → camino CloudKit byte-idéntico.
    func approveMember(_ member: SplitMember, in group: SplitGroup) async throws {
        if routesMembershipToBackend(group) {
            // El RPC espera `member.memberKey` (String?) + `group.cloudKitZoneID` — JAMÁS `member.id`.
            guard let memberKey = member.memberKey else { throw GroupServiceError.missingMemberKey }
            _ = try await backendMembershipFactory().approve(
                groupID: group.cloudKitZoneID, memberKey: memberKey)
        }
        try transitionPendingMember(member, to: .active, in: group)
    }

    /// admin rejects a pending member's request, marking them as rejected and enqueuing sync.
    func rejectMember(_ member: SplitMember, in group: SplitGroup) throws {
        // Guard defensivo (review G5-A): sin routing backend para reject — evitar falso éxito local.
        guard !routesMembershipToBackend(group) else { throw GroupServiceError.backendActionUnavailable }
        try transitionPendingMember(member, to: .rejected, in: group)
    }

    private func transitionPendingMember(
        _ member: SplitMember,
        to newStatus: SplitMemberStatus,
        in group: SplitGroup
    ) throws {
        let context = try requireContext()
        // C-10: red service-level. El detalle de un grupo congelado pasó a ser alcanzable, y estas
        // escrituras irían a una zona CloudKit muerta: se perderían en silencio.
        try validateGroupIsWritable(group)
        try requireCurrentUserAdmin(in: group, context: context)

        guard member.groupZoneID == group.cloudKitZoneID else { throw GroupServiceError.memberNotInGroup }
        guard member.isPendingApproval else { throw GroupServiceError.notPendingApproval }

        member.memberStatus = newStatus

        do {
            try context.save()
        } catch {
            throw GroupServiceError.saveFailed(error)
        }

        SessionState.shared.incrementDataVersion()
    }

    /// Change a member's role.
    func changeRole(_ member: SplitMember, to newRole: String, in group: SplitGroup) throws {
        // Guard defensivo (review G5-A): no existe RPC de cambio de rol — evitar falso éxito local.
        guard !routesMembershipToBackend(group) else { throw GroupServiceError.backendActionUnavailable }
        let context = try requireContext()
        // C-10: red service-level. El detalle de un grupo congelado pasó a ser alcanzable, y estas
        // escrituras irían a una zona CloudKit muerta: se perderían en silencio.
        try validateGroupIsWritable(group)
        try requireCurrentUserAdmin(in: group, context: context)

        guard member.groupZoneID == group.cloudKitZoneID else { throw GroupServiceError.memberNotInGroup }
        guard newRole == "admin" || newRole == "member" else { throw GroupServiceError.invalidRole }
        guard member.isActive else { throw GroupServiceError.inactiveMember }
        guard !member.isGroupOwner || newRole == "admin" else { throw GroupServiceError.ownerMemberImmutable }

        // Cannot demote the last admin
        if member.role == "admin" && newRole == "member" {
            let adminCount = try activeAdminCount(in: group, context: context)
            guard adminCount > 1 else { throw GroupServiceError.lastAdmin }
        }

        member.role = newRole

        do {
            try context.save()
        } catch {
            throw GroupServiceError.saveFailed(error)
        }

        SessionState.shared.incrementDataVersion()
    }

    /// Current user leaves a group they were invited to (non-owner).
    func leaveGroup(_ group: SplitGroup) async throws {
        let context = try requireContext()

        guard !group.isOwner else { throw GroupServiceError.ownerCannotLeave }

        // C5: zona backend + flag ON → RPC `leave_group` (server-first, deja la fila `status='left'`) +
        // limpieza local existente. SIN `leaveShare`/`PendingLeaveShareTracker` y SIN
        // `ensureCurrentUserMemberExists` (PROHIBIDO para backend — regla A1: encolaría a CKSyncEngine). Los
        // tombstones del cascade de `performLocalCleanupAndDelete` NO se emiten (C2-bis: la zona sale del set
        // backend al borrar el SplitGroup — y sale SIEMPRE desde 2026-08-03, porque la primitiva barre TODAS
        // las filas de la zona; con una sola, un duplicado dejaba la zona dentro del set y esta frase era
        // falsa). RPC falla → throw ANTES de tocar el contexto → local INTACTO.
        //
        // **El residual del CKShare que esta rama declaraba se EXTINGUIÓ con la Fase 3**, no se arregló:
        // decía que en una zona MIXTA el usuario salía server-side pero se quedaba dentro del share, y que
        // cerrarlo pedía antes darle TTL al tracker. Borrado el transporte no hay `leaveShare` que llamar
        // ni tracker donde encolar, y el share huérfano que pueda quedar en CloudKit no lo ve ya ninguna
        // superficie de la app.
        if routesMembershipToBackend(group) {
            do {
                _ = try await backendMembershipFactory().leave(groupID: group.cloudKitZoneID)
            } catch GroupsRPCError.memberNotFound {
                // Ya no soy miembro server-side → sigo al cleanup local. Mismo criterio y mismo
                // motivo que `batchLeave`, que lo tolera desde su origen.
                //
                // El caso que lo hacía falta aquí es el RECHAZADO: su fila server-side no es una
                // membresía viva, así que el RPC responde `member_not_found` y la única salida que
                // se le ofrece —la confirmación de salir de la tarjeta— terminaba en un alert de
                // error, dejándole el grupo pegado en la lista para siempre. Sin este `catch`, la
                // salida existe en la UI y no funciona.
            }
            try performLocalCleanupAndDelete(group: group, context: context)
            do {
                try context.save()
            } catch {
                throw GroupServiceError.saveFailed(error)
            }
            SessionState.shared.incrementDataVersion()
            return
        }

        // Zona SIN canal (legacy que nunca migró): la salida es puramente LOCAL y eso es todo lo que
        // puede ser — el transporte que la habría propagado ya no existe, y ningún otro miembro va a
        // enterarse por ninguna vía. Se marca el member como `.left` igual que antes para que el estado
        // local quede coherente si la fila sobrevive a la limpieza de abajo por cualquier camino.
        //
        // El usuario puede salir aunque tenga saldo pendiente. La UI muestra warning
        // explícito en el confirmation dialog antes de invocar este método.
        let currentMember = try await ensureCurrentUserMemberExists(in: group, reactivateInactive: false)

        if currentMember.isActive {
            currentMember.memberStatus = .left
            currentMember.isCurrentUser = true
            do {
                try context.save()
            } catch {
                throw GroupServiceError.saveFailed(error)
            }
        }

        try performLocalCleanupAndDelete(group: group, context: context)

        do {
            try context.save()
        } catch {
            throw GroupServiceError.saveFailed(error)
        }

        SessionState.shared.incrementDataVersion()
    }

    /// Flow simétrico a `leaveGroup` disparado por observer cuando el admin remoto saca al current user del
    /// grupo. Idempotente: si el SplitGroup local ya fue borrado (e.g. leaveGroup previo en otro device del
    /// mismo user), no-op.
    ///
    /// **Le quedaba UN disparador tras la Fase 3.** Eran dos, uno por canal; el de CloudKit
    /// (`SplitSyncManager.applyMember`, que veía al member propio pasar de `.active` a `.removed`) se fue
    /// con el transporte. Hoy solo la llama `GroupsSyncClient.reconcileLostMemberships`, que ve desaparecer
    /// la zona del `memberships` del pull — ahí NO hay fila de member que observar (la RLS deja de
    /// entregarla en cuanto el status es `removed`), así que la señal es la ausencia.
    ///
    /// Y con él se fue la mitad CloudKit del cuerpo: el `leaveShareByZone` y su retry persistido. Lo que
    /// queda es la limpieza LOCAL, que era su otra mitad y la única que sigue teniendo a quién servir.
    func performRemovedSelfCleanup(zoneName: String, context providedContext: ModelContext? = nil) async {
        guard let context = providedContext ?? modelContext else { return }
        // `createdAt` ASC = la fila CANÓNICA de la zona, mismo criterio que `group(for:)`. El barrido es
        // por zona desde 2026-08-03, así que la elegida no cambia QUÉ se borra; el `sortBy` se conserva
        // para que la elección no la haga SQLite.
        let descriptor = FetchDescriptor<SplitGroup>(
            predicate: #Predicate { $0.cloudKitZoneID == zoneName },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        let rows: [SplitGroup]
        do {
            rows = try context.fetch(descriptor)
        } catch {
            logger.error("performRemovedSelfCleanup: fetch failed for \(zoneName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return
        }
        guard let group = rows.first else { return }  // already deleted — idempotent

        do {
            try performLocalCleanupAndDelete(group: group, context: context)
            try context.save()
        } catch {
            #if DEBUG
            logger.error("performRemovedSelfCleanup: local cleanup failed: \(error.localizedDescription, privacy: .public)")
            #endif
        }
        SessionState.shared.incrementDataVersion()
    }

    /// Bloque común de cleanup local al salir o ser removido de un grupo: libera TX cuenta
    /// real (preserva rastro financiero), convierte drafts a manual, borra expenses/shares/
    /// settlements/members de la zone, limpia prefs personales del grupo y elimina los
    /// SplitGroup locales. NO hace save() — caller controla cuándo flushear.
    ///
    /// **La unidad es la ZONA y el `group` solo es su portador.** Las cinco limpiezas de abajo ya iban por
    /// `cloudKitZoneID`; la única que iba por FILA era el `context.delete(group)` final, y esa asimetría es
    /// la que rompía la seguridad que el comentario de `leaveGroup` (:553) declara por escrito: con un
    /// `SplitGroup` DUPLICADO en la zona —estado documentado, con servicio propio
    /// (`SplitGroupDeduplicationService`)— la fila superviviente mantiene la zona dentro de
    /// `GroupsSyncClient.backendGroupZoneIDs`, que es un fetch de filas VIVAS, ⇒ el `save()` del caller (con
    /// el autor por DEFECTO, el que captura el drain) traducía el cascade a tombstones de
    /// `split_expenses`/`split_shares`/`split_settlements` con HLC fresco. El `guard !updateOnly` de
    /// `translateChange` NO cubre esto y no puede: el tombstone de un gasto SÍ tiene que viajar. Hermano
    /// exacto del defecto que `GroupZoneCacheGate` cerró en el transporte (2026-08-03).
    ///
    /// **Y el borrado del grupo va PRIMERO**, molde de `GroupZoneCacheGate.deleteCache` y
    /// `GroupsIdentityPurgeGate.deleteRows`. No es orden estético: `BridgeModeResolver.clearOverride` hace
    /// su propio `context.save()` (`BridgeModeResolver.swift:170`) ⇒ con el grupo al final se COMITEA un
    /// estado intermedio de «hijas muertas + fila del grupo viva», que es exactamente lo que el drain
    /// traduce. Hoy no lo alcanza (todo esto es `@MainActor` síncrono y no hay `await` entre la primitiva y
    /// el `save()` del caller, así que ningún drain se cuela en medio), pero sí queda PERSISTIDO si el
    /// `save()` final lanza —ningún call-site hace `rollback()`— y ahí el drain de la vuelta siguiente lo ve.
    /// Con el grupo primero, cualquier commit parcial deja huérfanas invisibles, jamás un emisor vivo.
    ///
    /// **Sin guard de canal, a propósito.** El de `GroupZoneCacheGate` es fail-CLOSED («zona backend ⇒
    /// intocable») y aquí bloquearía el 100 % del camino: la rama backend de `leaveGroup` se toma justo
    /// cuando `isBackendGroup == true`. Y el usuario ya salió server-side —`leave_group` no es idempotente
    /// puro (lo dice el docblock de `batchLeave`) y el pull deja de listar el grupo— así que negarse a
    /// limpiar deja un fantasma
    /// IMBORRABLE. La protección correcta aquí es que la zona salga del set backend SIEMPRE, que es lo que
    /// hace el barrido por zona.
    private func performLocalCleanupAndDelete(group: SplitGroup, context: ModelContext) throws {
        let zoneID = group.cloudKitZoneID
        if GroupTransactionBridge.shared.isReady {
            do {
                // Por ZONA: la fila del grupo se va justo debajo y este freeze solo necesita el zoneID.
                try GroupTransactionBridge.shared.freezeForSoftDelete(zoneID: zoneID)
            } catch {
                #if DEBUG
                logger.error("freezeForSoftDelete failed: \(error.localizedDescription, privacy: .public)")
                #endif
            }
        }
        // TODAS las filas de la zona, no solo la del parámetro. `#Predicate` CONCRETO por tipo.
        let rows: [SplitGroup]
        do {
            rows = try context.fetch(
                FetchDescriptor<SplitGroup>(predicate: #Predicate { $0.cloudKitZoneID == zoneID }))
        } catch {
            // Degradar al comportamiento anterior (la fila en mano) y NO abortar: el usuario ya salió
            // server-side y bloquear aquí le deja el grupo fantasma. Nunca es peor que antes de este fix.
            #if DEBUG
            logger.error("performLocalCleanupAndDelete: fetch de la zona falló: \(error.localizedDescription, privacy: .public)")
            #endif
            rows = [group]
        }
        for row in rows { context.delete(row) }
        try cascadeDeleteGroupData(zoneName: zoneID, context: context)
        GroupPersonalPreferences.removeAll(for: zoneID)
        // Un join intent vivo para una zona que deja de existir localmente es
        // obsoleto (reconciliarlo re-crearía el member recién borrado).
        PendingJoinStore.clear(zoneName: zoneID)
        do {
            try BridgeModeResolver.shared.clearOverride(forZoneID: zoneID, in: context)
        } catch {
            #if DEBUG
            logger.error("clearOverride failed: \(error.localizedDescription, privacy: .public)")
            #endif
        }
    }

    // MARK: - Batch "salir de todos mis grupos" (D10)

    /// Clasifica TODOS los grupos activos (`!isHiddenForAll` — INCLUYE archivados, mismo set que
    /// `accountDeletionGroupsSummary`) en entries del batch. Los `.skipHasDebt` se EXCLUYEN (fuera del batch —
    /// la fila 👥 los muestra). Los `.needsDecision` se arman YA terminales (no requieren ejecución). READ-ONLY
    /// (sin saves — invariante de quiescencia (b)).
    func batchClassifyAllGroups() throws -> [BatchLeaveEntry] {
        let groups = try fetchAllGroups().filter { !$0.isHiddenForAll }
        var entries: [BatchLeaveEntry] = []
        for group in groups {
            let facts = try batchFacts(group)
            let action = GroupBatchLeaveLogic.classify(facts)
            switch action {
            case .skipHasDebt:
                continue
            case .needsDecision:
                entries.append(BatchLeaveEntry(
                    groupZoneID: group.cloudKitZoneID, groupName: group.name,
                    phase: .needsDecision, plannedAction: .needsDecision,
                    needsDecisionReason: GroupBatchLeaveLogic.needsDecisionReason(facts)))
            default:
                entries.append(BatchLeaveEntry(
                    groupZoneID: group.cloudKitZoneID, groupName: group.name,
                    phase: .pending, plannedAction: action))
            }
        }
        return entries
    }

    /// Ejecuta UN paso del batch para un grupo. Idempotente (grupo ya borrado → `.done`; RPCs tolerantes a
    /// "ya salí"). El caller (orquestador) hace el gate de quiescencia y el write-ahead de fase. Un
    /// transitorio (red/sesión/sin contexto/**fetch que lanza**) → `.deferred` (el resume lo retoma); un fallo
    /// permanente → `.failed`; la deuda sobrevenida → `.needsDecision(.debtAppeared)`.
    ///
    /// La fila que se toma es la CANÓNICA de la zona (`createdAt` ASC, igual que `group(for:)`) y ya no una
    /// arbitraria: de ella salen `isOwner` y la deuda, y el CANAL lo decide `routesMembershipToBackend`, que
    /// mira la zona ENTERA.
    func executeBatchStep(_ entry: BatchLeaveEntry) async -> GroupBatchLeaveLogic.StepResult {
        guard let context = modelContext else { return .deferred }
        let zoneID = entry.groupZoneID
        let rows: [SplitGroup]
        do {
            rows = try context.fetch(FetchDescriptor<SplitGroup>(
                predicate: #Predicate { $0.cloudKitZoneID == zoneID },
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]))
        } catch {
            // Un fallo de LECTURA no es «ya no existe local»: `.done` es TERMINAL para el orquestador
            // (`GroupBatchLeaveLogic.isTerminal`) ⇒ marcaría el grupo como salido y no lo reintentaría
            // JAMÁS. `.deferred` deja la entry `.inProgress` y el resume la retoma — el mismo trato que la
            // ausencia de contexto, dos líneas arriba.
            logger.error("executeBatchStep: fetch de la zona \(zoneID, privacy: .public) falló: \(error.localizedDescription, privacy: .public)")
            return .deferred
        }
        guard let group = rows.first else {
            return .done  // ya no existe local (salido/removido en otro device) → idempotente
        }
        if rows.count > 1 {
            MetricsService.cloudkitDuplicateDetected(
                model: "SplitGroup", count: rows.count, context: .runtimeFetch, keySuffix: zoneID)
        }

        let facts: GroupBatchLeaveLogic.GroupFacts
        do { facts = try batchFacts(group) } catch { return .deferred }
        // Re-chequeo de deuda JUSTO ANTES de mutar (carrera deuda-sobrevenida).
        if facts.hasOutstandingDebt { return .needsDecision(.debtAppeared) }

        // `.pending` re-clasifica con facts frescos; `.inProgress` re-ejecuta la acción CONGELADA.
        let action = entry.phase == .pending ? GroupBatchLeaveLogic.classify(facts) : entry.plannedAction
        switch action {
        case .skipHasDebt:
            return .needsDecision(.debtAppeared)
        case .needsDecision:
            return .needsDecision(GroupBatchLeaveLogic.needsDecisionReason(facts))
        case .leave:
            do { try await batchLeave(group); return .done }
            catch let e as GroupsRPCError { return Self.isTransientRPC(e) ? .deferred : .failed("\(e)") }
            catch { return .failed("\(error.localizedDescription)") }
        case .deleteSolo:
            do { try softDelete(group); return .done }
            catch GroupServiceError.outstandingBalance { return .needsDecision(.debtAppeared) }
            catch { return .failed("\(error.localizedDescription)") }
        case .transferThenLeave:
            do {
                switch try await transferOwnershipThenLeave(group) {
                case .left: return .done
                case .needsDecision(let r): return .needsDecision(r)
                }
            }
            catch let e as GroupsRPCError { return Self.isTransientRPC(e) ? .deferred : .failed("\(e)") }
            catch { return .failed("\(error.localizedDescription)") }
        }
    }

    /// Salir de un grupo para el batch, tolerante a `member_not_found` en el resume (RPC `leave_group` NO es
    /// idempotente puro: 2º call → `yala_member_not_found`; tras un kill entre el RPC OK y el cleanup local, el
    /// resume lo re-llama → se trata como ÉXITO → fuerza el cleanup local). El canal CloudKit reusa el
    /// `leaveGroup` existente (ya resume-safe: member ya `.left` → salta el enqueue/save y va a leaveShare+cleanup).
    func batchLeave(_ group: SplitGroup) async throws {
        guard routesMembershipToBackend(group) else {
            try await leaveGroup(group)   // CloudKit path (resume-safe)
            return
        }
        let context = try requireContext()
        do {
            _ = try await backendMembershipFactory().leave(groupID: group.cloudKitZoneID)
        } catch GroupsRPCError.memberNotFound {
            // Ya salí server-side (resume tras parcial) → sigo al cleanup local.
        }
        try performLocalCleanupAndDelete(group: group, context: context)
        do { try context.save() } catch { throw GroupServiceError.saveFailed(error) }
        SessionState.shared.incrementDataVersion()
    }

    /// Transfiere el ownership al co-member elegible (server elige el heredero) y sale. El fix del hazard
    /// transfer→leave: NO pasa por `leaveGroup` (cuyo guard `!isOwner` bloquearía porque el `isOwner` LOCAL no
    /// se voltea hasta que llegue el pull) — hace el backend-leave inline. Idempotente: transfer → `already` en
    /// resume; leave → `member_not_found` tolerado. `no_eligible_owner` (carrera: el heredero salió) →
    /// `.needsDecision` (JAMÁS tombstonea — el server tampoco).
    func transferOwnershipThenLeave(_ group: SplitGroup) async throws -> GroupBatchLeaveLogic.TransferLeaveOutcome {
        let context = try requireContext()
        let service = backendMembershipFactory()
        let transfer = try await service.transferOwnership(groupID: group.cloudKitZoneID)
        if transfer.reason == "no_eligible_owner" {
            return .needsDecision(.backendNoEligibleHeir)
        }
        // transferred || already → server ya no me ve como owner → puedo salir.
        do {
            _ = try await service.leave(groupID: group.cloudKitZoneID)
        } catch GroupsRPCError.memberNotFound {
            // Ya salí (resume tras parcial) → sigo al cleanup local.
        }
        try performLocalCleanupAndDelete(group: group, context: context)
        do { try context.save() } catch { throw GroupServiceError.saveFailed(error) }
        SessionState.shared.incrementDataVersion()
        return .left
    }

    /// Facts read-only del grupo (derivados EN MEMORIA — nunca `#Predicate` sobre `userID` opcional).
    private func batchFacts(_ group: SplitGroup) throws -> GroupBatchLeaveLogic.GroupFacts {
        let context = try requireContext()
        let members = try fetchMembers(for: group, context: context)
        let activeCoMembers = members.filter { $0.isActive && !$0.isCurrentUser }
        let eligibleHeirs = activeCoMembers.filter { $0.userID != nil }
        return GroupBatchLeaveLogic.GroupFacts(
            isOwner: group.isOwner,
            isBackendChannel: routesMembershipToBackend(group),
            activeCoMemberCount: activeCoMembers.count,
            eligibleHeirCount: eligibleHeirs.count,
            hasOutstandingDebt: try batchHasOutstandingDebt(group, members: members, context: context))
    }

    /// `true` si el usuario tiene saldo pendiente (`abs(netBalance) > 0.01`) en el grupo. Molde
    /// `accountDeletionGroupsSummary`/`recomputeOutstandingDebt`: early-exit sin gastos; member no resuelto →
    /// `false` (sub-conteo, jamás sobre-aviso). READ-ONLY.
    private func batchHasOutstandingDebt(_ group: SplitGroup, members: [SplitMember], context: ModelContext) throws -> Bool {
        let zoneID = group.cloudKitZoneID
        let expenseCount = try context.fetchCount(
            FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.groupZoneID == zoneID }))
        guard expenseCount > 0 else { return false }
        guard let me = members.first(where: { $0.isCurrentUser }) else { return false }
        let expenses = try GroupExpenseService.shared.fetchExpenses(for: group)
        let shares = try GroupExpenseService.shared.fetchAllShares(for: group)
        let settlements = try GroupExpenseService.shared.fetchSettlements(for: group)
        let balances = GroupBalanceService.calculateBalances(
            expenses: expenses, shares: shares, members: members, settlements: settlements)
        let meID = me.id.uuidString
        return balances.contains { $0.memberID == meID && abs($0.netBalance) > 0.01 }
    }

    /// REINTENTABLE por el resume (`.deferred`) vs permanente (`.failed`, estado TERMINAL del batch).
    /// `member_not_found` NUNCA llega aquí (lo atrapan `batchLeave`/`transferOwnershipThenLeave`).
    ///
    /// `.channelDisabled` (403 del kill-switch server-side de Grupos) va en la rama reintentable, y es
    /// EXPLÍCITO y no por el `default` a propósito: antes de que ese caso existiera, el 403 llegaba aquí
    /// como `.transient(status: 403)` ⇒ `.deferred`, y dejarlo caer en el `default: false` habría
    /// convertido en FALLO TERMINAL —para cada grupo del batch— lo que antes era un diferido que el resume
    /// recogía. El canal se levanta con un deploy y sin que el usuario haga nada, así que marcar `.failed`
    /// le obligaría a rehacer a mano un batch que iba a funcionar solo. Es la misma decisión que
    /// `GroupBackendAcceptErrorLogic.isPermanent(.channelDisabled) == false`.
    ///
    /// ⚠️ Este `default` es el único catch-all sobre `GroupsRPCError` en todo `Yala/`: al añadir un caso al
    /// enum, clasifícalo AQUÍ a mano — el compilador no avisa, y el silencio cae del lado de `.failed`.
    private static func isTransientRPC(_ error: GroupsRPCError) -> Bool {
        switch error {
        case .transient, .sessionExpired, .channelDisabled: return true
        default: return false
        }
    }

    // MARK: - Current User Identity / Membership

    /// Ensures there is a SplitMember for the current iCloud user in the given group.
    /// Returns the member representing the current user.
    func ensureCurrentUserMemberExists(in group: SplitGroup, reactivateInactive: Bool = true, context providedContext: ModelContext? = nil) async throws -> SplitMember {
        let context = try providedContext ?? requireContext()
        let recordName = try await GroupUserIdentityService.shared.currentUserRecordName()

        let members = try fetchMembers(for: group, context: context)
        if let existing = members.first(where: { !$0.cloudKitUserRecordID.isEmpty && $0.cloudKitUserRecordID == recordName }) {
            var changed = false
            if !existing.isCurrentUser {
                existing.isCurrentUser = true
                changed = true
            }
            if reactivateInactive && !existing.isActive {
                if existing.memberStatus == .pendingApproval {
                    // No-op: solo el admin puede sacar a un member de pending.
                } else if group.isOwner {
                    existing.memberStatus = .active
                    changed = true
                } else if existing.memberStatus == .rejected || existing.memberStatus == .removed {
                    existing.memberStatus = .pendingApproval
                    changed = true
                } else {
                    // Legacy left → active (preserva semántica previa para users que se fueron voluntariamente).
                    existing.memberStatus = .active
                    changed = true
                }
            }
            if group.isOwner && !existing.isGroupOwner {
                existing.isGroupOwner = true
                existing.role = "admin"
                changed = true
            }
            if changed {
                do {
                    try context.save()
                } catch {
                    throw GroupServiceError.saveFailed(error)
                }
            }
            return existing
        }

        // Legacy fallback: if a local member is marked as current user but missing a record ID, backfill it.
        if let legacy = members.first(where: { $0.isCurrentUser }) {
            guard reactivateInactive || legacy.isActive else { return legacy }
            if legacy.cloudKitUserRecordID.isEmpty {
                legacy.cloudKitUserRecordID = recordName
                if reactivateInactive {
                    legacy.memberStatus = .active
                }
                if group.isOwner {
                    legacy.isGroupOwner = true
                    legacy.role = "admin"
                }
                do {
                    try context.save()
                } catch {
                    throw GroupServiceError.saveFailed(error)
                }
            }
            return legacy
        }

        // A9: NO heuristic fallbacks (nameMatch / admin-único). If the current user
        // doesn't match any existing SplitMember by `cloudKitUserRecordID` and no
        // legacy member is flagged with `isCurrentUser=true`, we create a new
        // SplitMember below. Identity must be authoritative — assuming by name or
        // role can mis-assign `isCurrentUser` in groups with two members of the
        // same name or with unrelated admins.

        guard reactivateInactive else { throw GroupServiceError.currentUserMemberNotFound }

        // Create a new member record for the current user.
        // invitados entran como pendingApproval; owner siempre active.
        let zoneID = group.cloudKitZoneID
        let initialStatus: SplitMemberStatus = group.isOwner ? .active : .pendingApproval
        let member = SplitMember(
            groupZoneID: zoneID,
            displayName: currentUserDisplayName(),
            cloudKitUserRecordID: recordName,
            role: "member",
            status: initialStatus,
            isCurrentUser: true
        )
        member.id = GroupUserIdentityService.deterministicUUID(
            namespace: "SplitMember",
            name: "\(zoneID):\(recordName)"
        )

        context.insert(member)
        try context.save()
        SessionState.shared.incrementDataVersion()
        return member
    }

    /// A13: Updates the current user's `displayName` across all groups they belong to,
    /// and enqueues sync for each updated SplitMember. Called after the user finishes
    /// their initial onboarding (e.g. `GroupInviteOnboardingView.performSilentSetup`)
    /// or as part of boot-time reconciliation if a previous attempt was interrupted.
    /// - Parameter newName: the user's chosen display name (will be trimmed).
    /// - Note: Idempotent — when no member needs update, returns without saving.
    func updateCurrentUserDisplayName(_ newName: String) async throws {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let context = try requireContext()

        let memberDescriptor = FetchDescriptor<SplitMember>(
            predicate: #Predicate { $0.isCurrentUser == true }
        )
        let myMembers = try context.fetch(memberDescriptor)
        let pending = myMembers.filter { $0.displayName != trimmed }
        guard !pending.isEmpty else { return }

        // Cache groups by zoneID — typical user has 1-3 groups, fetch once.
        // `uniquingKeysWith` evita crash si CloudKit sync trae duplicados con el
        // mismo zoneID (no hay @Attribute(.unique) por compat CloudKit). Cualquier
        // duplicado sirve igual para enqueueSave — todos apuntan al mismo zone.
        let allGroups = try fetchAllGroups()
        let groupByZoneID = Dictionary(allGroups.map { ($0.cloudKitZoneID, $0) },
                                       uniquingKeysWith: { first, _ in first })
        if groupByZoneID.count < allGroups.count {
            let conflictCount = allGroups.count - groupByZoneID.count
            #if DEBUG
            print("GroupService: \(conflictCount) duplicate SplitGroups detected during updateCurrentUserDisplayName")
            #endif
            MetricsService.cloudkitDuplicateDetected(
                model: "SplitGroup",
                count: conflictCount,
                context: .uniquingFallback,
                keySuffix: "updateDisplayName:\(conflictCount)"
            )
        }

        for member in pending {
            let group = groupByZoneID[member.groupZoneID]
            // G6-3 (C4): SALTAR los grupos congelados (member-reachable, cross-group) — escribir el displayName
            // a la zona CloudKit congelada se perdería. El displayName de la copia backend lo corrige el
            // re-join (update_member_display_name). Guard per-grupo (NO throw global: la acción es multi-grupo).
            if let group, group.isMigratedFrozen { continue }
            member.displayName = trimmed
        }

        do {
            try context.save()
        } catch {
            throw GroupServiceError.saveFailed(error)
        }
    }

    /// Recomputes `SplitMember.isCurrentUser` across all groups from `cloudKitUserRecordID`.
    /// `context` override opcional (default mainContext). Todos los callers actuales (delegate del
    /// sync, UI, boot) resuelven al mainContext; la protección contra `save()` durante un restore
    /// vive en el gate de QUIESCENCIA del sync (export-only + `deferMainContextWork`), no en aislar
    /// el contexto.
    func refreshCurrentUserFlags(context providedContext: ModelContext? = nil) async {
        guard let context = providedContext ?? modelContext else { return }

        // 2.6: la identidad del canal Grupos → backend es el `sub` de la cuenta Yala, así que se resuelve
        // ANTES que la de CloudKit y sin depender de ella. Con el flag OFF (SIEMPRE en producción hoy)
        // `currentUserID` es nil, `backendCanResolve` es false y todo lo de abajo es BYTE-IDÉNTICO al
        // camino de siempre — incluido el `return` temprano cuando iCloud no resuelve.
        let backendEnabled = CloudSyncFlags.groupsBackendEnabled
        let currentUserID: String? = backendEnabled ? Self.backendUserIDProvider() : nil
        let backendCanResolve = !(currentUserID ?? "").isEmpty

        // El recordName de CloudKit pasa a ser BEST-EFFORT: sin él el path CloudKit queda inerte por sí
        // solo (`cloudKitMatch` ya exige no-vacío) pero el canal backend sigue sabiendo quién soy. Antes
        // un iCloud no resoluble abortaba la función ENTERA, así que en un device del canal nuevo sin
        // iCloud disponible ningún `SplitMember` recibía `isCurrentUser` — o sea, el usuario se quedaba
        // sin su propio balance en sus propios grupos.
        var recordName = ""
        if let cached = GroupUserIdentityService.shared.cachedRecordName, !cached.isEmpty {
            recordName = cached
        } else {
            do {
                recordName = try await GroupUserIdentityService.shared.currentUserRecordName()
            } catch {
                logger.error("refreshCurrentUserFlags: currentUserRecordName failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        guard !recordName.isEmpty || backendCanResolve else { return }

        do {
            let allGroups = try context.fetch(FetchDescriptor<SplitGroup>())
            let groupsByZone = Dictionary(allGroups.map { ($0.cloudKitZoneID, $0) }, uniquingKeysWith: { first, _ in first })
            if groupsByZone.count < allGroups.count {
                let conflictCount = allGroups.count - groupsByZone.count
                #if DEBUG
                print("GroupService: \(conflictCount) duplicate SplitGroups detected during refreshCurrentUserFlags")
                #endif
                MetricsService.cloudkitDuplicateDetected(
                    model: "SplitGroup",
                    count: conflictCount,
                    context: .uniquingFallback,
                    keySuffix: "refreshFlags:\(conflictCount)"
                )
            }

            // El predicado de CANAL va por ZONA con TODAS sus filas (ANY-row), NO por la fila que gane el
            // uniquing de arriba. `groupsByZone` se queda como está a propósito: sus otros dos usos —el
            // `group` que se pasa a `enqueueSave` y el `group.isOwner` de la inferencia de rol— no son
            // preguntas sobre el canal, y `isOwner` es una credencial que HABILITA, que el criterio del
            // punto 11 de `.claude/rules/swiftdata-cloudkit.md` dice NO fusionar.
            //
            // Lo que arreglaba decidir esto con una fila arbitraria (`fetch` sin `sortBy` + `uniquingKeysWith:
            // { first, _ in first }`): en una zona con duplicado MIXTO podía resolver `false` y entonces las
            // CUATRO decisiones de abajo se tomaban como si el grupo fuera de CloudKit — encendiendo o
            // apagando `isCurrentUser` donde el diseño dice CONSERVARLO. Último miembro de la familia
            // «decidir sobre una ZONA mirando UNA sola fila»; molde de `GroupFreezeLogic.zoneBlocksCloudKitWrites`
            // y `GroupService.backendFlagsInZone`.
            let backendZones: Set<String> = Set(
                Dictionary(grouping: allGroups, by: \.cloudKitZoneID)
                    .filter { _, rows in
                        GroupZoneCacheGate.belongsToBackendChannel(
                            rowsInZone: rows.map { ($0.isBackendGroup, $0.movedToBackendAt) })
                    }
                    .keys)

            let members = try context.fetch(FetchDescriptor<SplitMember>())
            let membersByZone = Dictionary(grouping: members, by: \.groupZoneID)
            var changed = false

            // Canal Grupos → backend (G3, DARK): con el flag ON, la identidad AUTORITATIVA de "soy yo" es
            // el auth `uid` (`SplitMember.userID` vs `CloudAuthService.currentUserID`). Resuelto arriba,
            // antes que el recordName de CloudKit (2.6).

            // Migration: older builds could create current-user members without `cloudKitUserRecordID`.
            // Try to infer and backfill once per group, so other devices can identify the same user.
            let localDisplayName = currentUserDisplayName()
            // 2.6: el backfill es del path CloudKit — sin recordName resuelto no hay identidad que
            // estampar, y con el canal backend resolviendo por `sub` este bloque no aporta nada.
            let backfillCandidates: [SplitGroup] = recordName.isEmpty ? [] : allGroups
            for group in backfillCandidates {
                guard let zoneMembers = membersByZone[group.cloudKitZoneID] else { continue }
                // C-3: la fila del canal backend RETENIDA tras un cambio de Apple ID (D1) no se re-ancla al
                // recordName NUEVO — su identidad la resuelve el `sub` de la cuenta Yala. Sin esto, el
                // backfill estampa el recordName del humano nuevo sobre un member ajeno del grupo anterior.
                //
                // Por ZONA, no por la fila del iterador: `backfillCandidates` son TODAS las filas, así que
                // con un duplicado MIXTO este bucle visitaba las dos y la gemela NO-backend pasaba el guard
                // ⇒ el estampado ocurría igual. Preguntándolo por fila, el guard **no protegía nunca** en una
                // zona mixta — no «la mitad de las veces», que es lo que sugiere la forma del código.
                guard !backendZones.contains(group.cloudKitZoneID) else { continue }
                guard !zoneMembers.contains(where: { $0.cloudKitUserRecordID == recordName }) else { continue }

                // A1 (G3): EXCLUIR los members del canal Grupos → backend (born-backend tienen
                // `cloudKitUserRecordID == ""` por diseño, pero `memberKey`/`userID` seteados). Sin este
                // filtro, con el flag ON un member backend recibiría un record-name de CloudKit Y se
                // encolaría a CKSyncEngine (fuga cross-canal). Flag-OFF es seguro: todos los members reales
                // de hoy tienen `memberKey == nil && userID == nil`.
                let candidates = zoneMembers.filter {
                    $0.cloudKitUserRecordID.isEmpty && $0.memberKey == nil && $0.userID == nil
                }
                guard !candidates.isEmpty else { continue }

                // Safe heuristic for any group: unique displayName match.
                let nameMatches = candidates.filter { $0.displayName == localDisplayName }
                if nameMatches.count == 1, let candidate = nameMatches.first {
                    candidate.cloudKitUserRecordID = recordName
                    changed = true
                    continue
                }

                // Owner groups: prefer the single admin, else earliest join.
                guard group.isOwner else { continue }
                let admins = candidates.filter { $0.role == "admin" }
                let candidate = (admins.count == 1 ? admins.first : candidates.min(by: { $0.joinedAt < $1.joinedAt }))
                if let candidate {
                    candidate.cloudKitUserRecordID = recordName
                    changed = true
                }
            }

            for member in members {
                // ANY-row por ZONA (ver `backendZones`). El nombre conserva «member» porque es la zona DE
                // ESE member; lo que cambió es el CUANTIFICADOR, no el predicado — la distinción entre los
                // tres predicados de la familia (`isBackendGroup` estrecho para membresía,
                // `isBackendGroup || isMigratedFrozen` ancho para escribir a CloudKit, `belongsToBackendChannel`
                // para retención e identidad) se conserva intacta.
                let memberIsInBackendChannel = backendZones.contains(member.groupZoneID)

                // C-3: par del guard de arriba. Un member de un grupo del canal backend RETENIDO lleva el
                // `cloudKitUserRecordID` del Apple ID que se FUE, así que el match por record-name daría
                // `false` y APAGARÍA su `isCurrentUser` — dejando el grupo retenido sin «quién soy»
                // (balances, participación) justo en el grupo que este fix existe para conservar.
                //
                // 2.6: el salto pasa a ser CONDICIONAL. Su motivo era que la única señal disponible —el
                // record-name— es la equivocada para estos grupos; con la sesión Yala viva hay una señal
                // AUTORITATIVA, el `sub`, y saltarse el member deja abierto el hueco contrario, que es el
                // que 2.6 cierra: `GroupsSyncClient.applyMember` NUNCA setea `isCurrentUser` y
                // `GroupBackendMembershipService` solo lo pone en el member del CREADOR, así que quien se
                // UNE a un grupo —y cualquiera en un 2º device o tras un reinstall— recibe su propio
                // member por el PULL sin el flag, y sin él la UI no le da balance propio, ni FAB, ni
                // liquidar (`GroupDetailViewModel.currentUserMember` lee SOLO ese flag). Sin `sub` que
                // consultar (flag OFF, o sin sesión) se conserva el salto exacto de antes.
                if memberIsInBackendChannel, !backendCanResolve { continue }

                // Backfill legacy "current user" members that were created without a CloudKit identity.
                // A1 (G3): EXCLUIR los members del canal backend (`memberKey`/`userID` seteados) — su
                // `cloudKitUserRecordID == ""` es intencional; backfillearlo + encolarlo sería fuga cross-canal.
                // 2.6: y tampoco en una ZONA del canal backend (ahora alcanzable al condicionar el salto de
                // arriba) ni sin recordName resuelto — es el estampado del humano nuevo sobre un member
                // ajeno que C-3 documenta, y escribir "" sobre "" marcaría `changed` y encolaría un save
                // a CKSyncEngine sin haber cambiado nada.
                if !recordName.isEmpty && !memberIsInBackendChannel
                    && member.isCurrentUser && member.cloudKitUserRecordID.isEmpty
                    && member.memberKey == nil && member.userID == nil {
                    member.cloudKitUserRecordID = recordName
                    changed = true
                }

                // Path CloudKit (fallback y único camino con flag OFF): match por record-name.
                let cloudKitMatch = !recordName.isEmpty && member.cloudKitUserRecordID == recordName
                let shouldBeCurrent: Bool
                if backendEnabled, let uid = member.userID, !uid.isEmpty {
                    // Canal backend: identidad autoritativa = auth uid del member vs sesión actual.
                    shouldBeCurrent = GroupBackendIdentityLogic.isCurrentUser(
                        memberUserID: uid, currentUserID: currentUserID)
                } else if memberIsInBackendChannel || recordName.isEmpty {
                    // 2.6, los dos casos en que el record-name NO es señal y el member se DEJA COMO ESTÁ:
                    //  · zona del canal backend con un member SIN identidad backend (legacy CloudKit de un
                    //    grupo migrado): es exactamente el match que C-3 documenta como falso tras un cambio
                    //    de Apple ID, y apagarlo dejaría el grupo retenido sin «quién soy».
                    //  · sin recordName resuelto no hay nada que afirmar de NINGÚN member del canal viejo.
                    //    Antes era inalcanzable —la función abortaba entera—; ahora que sigue viva para el
                    //    canal backend, caer a `cloudKitMatch` (false para todos) apagaría el `isCurrentUser`
                    //    de todos los grupos CloudKit del device por una ausencia transitoria de iCloud.
                    shouldBeCurrent = member.isCurrentUser
                } else {
                    // Sin `userID` backend (legacy/mixto) o flag OFF → path CloudKit. Con flag OFF, ESTA es
                    // la única rama y `shouldBeCurrent == cloudKitMatch` (comportamiento sin cambios).
                    shouldBeCurrent = cloudKitMatch
                }
                if member.isCurrentUser != shouldBeCurrent {
                    member.isCurrentUser = shouldBeCurrent
                    changed = true
                }

                // 2.6: fuera del canal backend. Ahí el rol lo dicta el server vía `applyMember` y esta
                // inferencia local (soy dueño del grupo ⇒ mi member es admin) solo podría pisarlo hasta el
                // próximo delta; además el `enqueueSave` ya no tiene a dónde subirlo. Con flag OFF el
                // `continue` de arriba hace este guard inalcanzable ⇒ comportamiento sin cambios.
                if shouldBeCurrent,
                   !memberIsInBackendChannel,
                   let group = groupsByZone[member.groupZoneID],
                   group.isOwner,
                   !member.isGroupOwner
                {
                    member.isGroupOwner = true
                    member.role = "admin"
                    changed = true
                }
            }
            if changed {
                try context.save()
                SessionState.shared.incrementDataVersion()
            }
        } catch {
            #if DEBUG
            logger.error("refreshCurrentUserFlags: Failed: \(error)")
            #endif
        }
    }

    private func requireCurrentUserAdmin(in group: SplitGroup, context: ModelContext) throws {
        let members = try fetchMembers(for: group)
        // Identidad resuelta: espeja a `GroupDetailViewModel.isCurrentUserAdmin`, que es quien
        // decide si se PINTAN aprobar/rechazar/invitar. Divergir aquí deja botones que fallan.
        if let current = GroupExpenseService.resolveCurrentUserMember(from: members) {
            guard current.isActive else { throw GroupServiceError.inactiveMember }
            guard current.role == "admin" else { throw GroupServiceError.adminRequired }
            return
        }
        guard group.isOwner else { throw GroupServiceError.adminRequired }
    }

    /// Cualquier miembro activo puede escribir (no requiere admin). Espejo de
    /// `GroupExpenseService.validateCurrentUserCanWrite`: bloquea pending/inactive; el owner
    /// pasa aunque su SplitMember aún no exista localmente.
    private func requireCurrentUserActiveMember(in group: SplitGroup, context: ModelContext) throws {
        let members = try fetchMembers(for: group)
        // Identidad resuelta, por el mismo motivo que su hermano de arriba y que
        // `GroupExpenseService.validateCurrentUserCanWrite`, del que este método es espejo.
        if let current = GroupExpenseService.resolveCurrentUserMember(from: members) {
            guard current.isActive else { throw GroupServiceError.inactiveMember }
            return
        }
        guard group.isOwner else { throw GroupServiceError.inactiveMember }
    }

    private func activeAdminCount(in group: SplitGroup, context: ModelContext) throws -> Int {
        let zoneName = group.cloudKitZoneID
        let adminDesc = FetchDescriptor<SplitMember>(
            predicate: #Predicate { $0.groupZoneID == zoneName && $0.role == "admin" }
        )
        return try context.fetch(adminDesc).filter(\.isActive).count
    }

    // MARK: - Cascade Delete

    /// Delete all local models for a group zone (members, expenses, shares, settlements).
    /// Does NOT delete the group itself or save the context.
    private func cascadeDeleteGroupData(zoneName: String, context: ModelContext) throws {
        let memberDesc = FetchDescriptor<SplitMember>(predicate: #Predicate { $0.groupZoneID == zoneName })
        for member in try context.fetch(memberDesc) { context.delete(member) }

        let shareDesc = FetchDescriptor<SplitShare>(predicate: #Predicate { $0.groupZoneID == zoneName })
        for share in try context.fetch(shareDesc) { context.delete(share) }

        let expenseDesc = FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.groupZoneID == zoneName })
        for expense in try context.fetch(expenseDesc) { context.delete(expense) }

        let settlementDesc = FetchDescriptor<SplitSettlement>(predicate: #Predicate { $0.groupZoneID == zoneName })
        for settlement in try context.fetch(settlementDesc) { context.delete(settlement) }
    }

    // MARK: - Fetch Helpers

    /// Fetch all non-archived groups.
    func fetchActiveGroups() throws -> [SplitGroup] {
        let context = try requireContext()
        let descriptor = FetchDescriptor<SplitGroup>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }

    /// Fetch all groups (including archived).
    func fetchAllGroups() throws -> [SplitGroup] {
        let context = try requireContext()
        let descriptor = FetchDescriptor<SplitGroup>(
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }

    /// Fetch members for a group.
    func fetchMembers(for group: SplitGroup, context providedContext: ModelContext? = nil) throws -> [SplitMember] {
        let context = try providedContext ?? requireContext()
        let zoneID = group.cloudKitZoneID
        let descriptor = FetchDescriptor<SplitMember>(
            predicate: #Predicate { $0.groupZoneID == zoneID },
            sortBy: [SortDescriptor(\.displayName)]
        )
        return try context.fetch(descriptor).sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive { return lhs.isActive && !rhs.isActive }
            if lhs.memberStatus != rhs.memberStatus {
                return statusSortOrder(lhs.memberStatus) < statusSortOrder(rhs.memberStatus)
            }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    /// Grupos donde el current user puede crear un gasto USABLE (activo + miembro `.active`
    /// presente). Espeja `GroupsViewModel.eligibleGroupsForExpense` (que filtra sus caches del
    /// tab) pero hace los fetches directos, para callers FUERA del tab Grupos — ej. convertir un
    /// draft del Inbox. El filtro pure-logic (`GroupExpenseEligibilityLogic.canCreateExpense`) es
    /// el SSOT compartido; solo difiere la fuente de datos (fetch aquí vs cache en el VM).
    func eligibleGroupsForExpense(context providedContext: ModelContext? = nil) throws -> [SplitGroup] {
        let context = try providedContext ?? requireContext()
        let groups = try context.fetch(FetchDescriptor<SplitGroup>(sortBy: [SortDescriptor(\.name)]))
        return try groups.filter { group in
            let members = try fetchMembers(for: group, context: context)
            let status = members.first(where: { $0.isCurrentUser })?.memberStatus
            return GroupExpenseEligibilityLogic.canCreateExpense(
                currentMemberStatus: status,
                isArchived: group.isArchived,
                isHiddenForAll: group.isHiddenForAll,
                isMigratedFrozen: group.isMigratedFrozen
            )
        }
    }

    // MARK: - User Display Name

    private func currentUserDisplayName() -> String {
        let name = SessionDefaults.current.string(forKey: "userName") ?? ""
        return name.isEmpty ? L10n.Profile.defaultName : name
    }

    private func statusSortOrder(_ status: SplitMemberStatus) -> Int {
        switch status {
        case .active: 0
        case .pendingApproval: 1
        case .left: 2
        case .removed: 3
        case .rejected: 4
        }
    }

    // MARK: - Consultas del store de Grupos (Fase 2 · 2.4)
    //
    // Vienen de `SplitSyncManager`, que la Fase 3 borra entero. Son lecturas del store de Grupos, no del
    // transporte: nada aquí sabe de CloudKit. Los `#Predicate` son CONCRETOS por tipo y deben seguir
    // siéndolo — uno genérico-protocolo compila y CRASHEA al ejecutar el fetch (fix `c74349fc`, regla de
    // `.claude/rules/swiftdata-cloudkit.md`).

    /// El `SplitGroup` local de una zona. Ordenado por `createdAt asc` para que gane siempre el canónico
    /// (el más antiguo) si una carrera de sync dejó duplicados con el mismo `cloudKitZoneID`.
    func group(for zoneID: String) -> SplitGroup? {
        guard let context = modelContext else { return nil }
        let descriptor = FetchDescriptor<SplitGroup>(
            predicate: #Predicate { $0.cloudKitZoneID == zoneID },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        let results: [SplitGroup]
        do {
            results = try context.fetch(descriptor)
        } catch {
            logger.error("group(for:) fetch failed for zone \(zoneID, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
        if results.count > 1 {
            #if DEBUG
            logger.error("GroupService.group(for:): \(results.count) duplicate SplitGroups for zone \(zoneID)")
            #endif
            MetricsService.cloudkitDuplicateDetected(
                model: "SplitGroup",
                count: results.count,
                context: .runtimeFetch,
                keySuffix: zoneID
            )
        }
        return results.first
    }

    /// `SplitMember` del usuario actual en una zona (canónico: el de `joinedAt` más antiguo si hubiera
    /// duplicados). Reusado por `currentMemberStatus(zoneName:)` y por callsites del bridge.
    func currentUserMember(zoneID: String) -> SplitMember? {
        guard let context = modelContext else { return nil }
        var descriptor = FetchDescriptor<SplitMember>(
            predicate: #Predicate { $0.groupZoneID == zoneID && $0.isCurrentUser == true },
            sortBy: [SortDescriptor(\.joinedAt, order: .forward)]
        )
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            logger.error("currentUserMember(zoneID:) fetch failed for \(zoneID, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Estado local del usuario actual en una zona. Nil si no es miembro local.
    func currentMemberStatus(zoneName: String) -> SplitMemberStatus? {
        currentUserMember(zoneID: zoneName)?.memberStatus
    }

    /// D5 (§3.3.4, aviso de «Eliminar mi cuenta»): resumen READ-ONLY de los grupos del usuario. Recorre los
    /// grupos NO soft-deleted (`isHiddenForAll == false`) y devuelve, sin escribir NADA (fetches + cálculo
    /// puro — invariante de quiescencia (b) intacto):
    ///  - `outstandingDebtGroupCount`: cuántos tienen un saldo pendiente para el usuario actual
    ///    (`|net| > 0.01` en alguna moneda; molde `GroupSettingsView.recomputeOutstandingDebt`, agregado y
    ///    filtrado al member del usuario). Un grupo cuyo `isCurrentUser` aún no resolvió se SALTA → posible
    ///    sub-conteo, JAMÁS sobre-aviso (dirección segura: el aviso solo informa, nunca bloquea).
    ///  - `hasLegacyCloudKitFootprint`: si algún grupo tiene zona CloudKit viva (`ckSystemFieldsData != nil`),
    ///    donde el nombre persiste tras el GDPR delete (`groups_forget_user` anonimiza SOLO el backend). Se
    ///    evalúa en memoria (evita el gotcha de `#Predicate` sobre opcionales) y **sobre TODOS los grupos,
    ///    ocultos incluidos** — a diferencia de la deuda, ver el porqué en el cuerpo.
    /// Degrada a `.empty` si el contexto no está montado o un fetch lanza. La composición del copy vive en
    /// `AccountDeletionMessageLogic`; el conteo se delega a `AccountDeletionDebtLogic` (ambos puros/testeados).
    ///
    /// `context` inyectable (default `nil` → `self.modelContext`, producción intacta): permite testear la
    /// glue SwiftData→resumen sin mutar el singleton `.shared`. La resolución del member del usuario se hace
    /// INLINE contra ese `context` (mismo predicado que `currentUserMember(zoneID:)`) — así el método es
    /// determinista respecto al contexto pasado y no lee estado del singleton.
    func accountDeletionGroupsSummary(context: ModelContext? = nil) -> AccountDeletionGroupsSummary {
        guard let context = context ?? modelContext else { return .empty }
        do {
            // La huella CloudKit se evalúa sobre TODOS los grupos, OCULTOS INCLUIDOS: es un hecho del
            // servidor de Apple, no de la vista. C3 retira los grupos de la era CloudKit ocultándolos
            // (`LegacyGroupsRetirement`), y con el filtro puesto esa retirada APAGABA el caveat
            // `.legacyFootprint` del diálogo de borrado de cuenta (`AccountDeletionDebtLogic:98`) sin borrar
            // ni una de las zonas cuyo nombre sigue visible. Ocultar el grupo no retira la huella.
            let allGroups = try context.fetch(FetchDescriptor<SplitGroup>())
            let hasLegacy = allGroups.contains { $0.ckSystemFieldsData != nil }
            // La deuda y `hasGroups` sí son de los grupos VIVOS: un grupo oculto no admite gastos ni sale en
            // ninguna lista, así que avisar de su saldo sería avisar de algo que el usuario ya no puede ver.
            let groups = allGroups.filter { !$0.isHiddenForAll }

            var perGroupNets: [[Double]] = []
            for group in groups {
                let zoneID = group.cloudKitZoneID

                // Member del usuario actual en esta zona (canonical: oldest joinedAt), INLINE contra el
                // `context` pasado. No resuelto (isCurrentUser aún sin asentar) ⇒ salta → sub-conteo, jamás
                // sobre-aviso.
                var meDesc = FetchDescriptor<SplitMember>(
                    predicate: #Predicate { $0.groupZoneID == zoneID && $0.isCurrentUser == true },
                    sortBy: [SortDescriptor(\.joinedAt, order: .forward)])
                meDesc.fetchLimit = 1
                guard let me = try context.fetch(meDesc).first else { continue }
                let myMemberID = me.id.uuidString

                // Early exit O(1): grupo sin gastos ⇒ sin deuda posible (delega a SQL COUNT).
                let expensesCount = try context.fetchCount(FetchDescriptor<SplitExpense>(
                    predicate: #Predicate { $0.groupZoneID == zoneID }))
                guard expensesCount > 0 else { continue }

                let expenses = try context.fetch(FetchDescriptor<SplitExpense>(
                    predicate: #Predicate { $0.groupZoneID == zoneID }))
                let shares = try context.fetch(FetchDescriptor<SplitShare>(
                    predicate: #Predicate { $0.groupZoneID == zoneID }))
                let settlements = try context.fetch(FetchDescriptor<SplitSettlement>(
                    predicate: #Predicate { $0.groupZoneID == zoneID }))
                let members = try context.fetch(FetchDescriptor<SplitMember>(
                    predicate: #Predicate { $0.groupZoneID == zoneID }))

                let balances = GroupBalanceService.calculateBalances(
                    expenses: expenses, shares: shares, members: members, settlements: settlements)
                perGroupNets.append(balances.filter { $0.memberID == myMemberID }.map(\.netBalance))
            }

            return AccountDeletionGroupsSummary(
                outstandingDebtGroupCount: AccountDeletionDebtLogic.groupsWithOutstandingBalance(
                    perGroupUserNetBalances: perGroupNets),
                hasLegacyCloudKitFootprint: hasLegacy,
                hasGroups: !groups.isEmpty)
        } catch {
            logger.error("accountDeletionGroupsSummary fetch failed: \(error.localizedDescription, privacy: .public)")
            return .empty
        }
    }

    /// El grupo sincronizado más recientemente (útil tras aceptar un share).
    func mostRecentGroup() -> SplitGroup? {
        guard let context = modelContext else { return nil }
        var descriptor = FetchDescriptor<SplitGroup>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        do {
            return try context.fetch(descriptor).first
        } catch {
            logger.error("mostRecentGroup() fetch failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

// MARK: - Errors

enum GroupServiceError: LocalizedError {
    case noContext
    case emptyName
    case emptyMemberName
    case invalidRole
    case notOwner
    case adminRequired
    case ownerCannotLeave
    case lastAdmin
    case inactiveMember
    case memberNotInGroup
    case cannotRemoveSelf
    case ownerMemberImmutable
    case currentUserMemberNotFound
    case notPendingApproval
    case currentUserPendingApproval
    case outstandingBalance
    case missingMemberKey
    case backendActionUnavailable
    /// G6-3: el grupo se migró a la nube de Yala y está congelado en este device — hay que volver a entrar.
    case movedToBackend
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noContext:
            return "GroupService: No ModelContext available"
        case .emptyName:
            return "GroupService: Group name cannot be empty"
        case .emptyMemberName:
            return "GroupService: Member name cannot be empty"
        case .invalidRole:
            return "GroupService: Role must be 'admin' or 'member'"
        case .notOwner:
            return "GroupService: Only the group owner can perform this action"
        case .adminRequired:
            return "GroupService: Only group admins can perform this action"
        case .ownerCannotLeave:
            return "GroupService: Owner cannot leave their own group"
        case .lastAdmin:
            return "GroupService: Cannot remove or demote the last admin"
        case .inactiveMember:
            return "GroupService: Inactive members cannot perform this action"
        case .memberNotInGroup:
            return "GroupService: Member does not belong to this group"
        case .cannotRemoveSelf:
            return "GroupService: Use leave group instead of removing yourself"
        case .ownerMemberImmutable:
            return "GroupService: The group owner cannot be removed or demoted"
        case .currentUserMemberNotFound:
            return "GroupService: Current user member was not found in this group"
        case .notPendingApproval:
            return "GroupService: Member is not awaiting approval"
        case .currentUserPendingApproval:
            return "GroupService: Your membership is pending admin approval"
        case .outstandingBalance:
            return "GroupService: Cannot proceed while members have outstanding balances"
        case .missingMemberKey:
            // C5 defensive: un member del canal backend sin `member_key` (no debería ocurrir en born-backend
            // — el materializador siempre lo setea). Reusa la copy genérica de acción fallida.
            return L10n.Groups.Errors.actionFailed
        case .backendActionUnavailable:
            // Guard defensivo (review G5-A, lente CloudKit #3): reject/changeRole NO están ruteados al
            // backend (no existe RPC de cambio de rol; el reject se ruteará junto al resto en G6) — sin
            // este guard mutarían local sin sync, dando falsa sensación de éxito hasta que el pull revierta.
            return L10n.Groups.Errors.actionFailed
        case .movedToBackend:
            return L10n.Groups.Errors.movedToBackend
        case .saveFailed(let error):
            return "GroupService: Save failed - \(error.localizedDescription)"
        }
    }
}

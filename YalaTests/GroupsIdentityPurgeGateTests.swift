//
//  GroupsIdentityPurgeGateTests.swift
//  YalaTests
//
//  C-3: cambio de identidad de iCloud (sign-out / switch de Apple ID) con el canal Grupos→backend.
//
//  Aislamiento: NINGÚN test depende del valor de `CloudSyncFlags.groupsBackendEnabled` — el gate es
//  deliberadamente independiente del flag. Aun así se llama `_testResetGroupsBackendEnabledOverride()`
//  al construir el contexto, porque el override es ESTÁTICO y otra suite pudo dejarlo puesto (no basta
//  con «no lo tocamos»); jamás un `defer { flag = prev }`. Fixtures al molde de
//  `HandoverGroupsDomainTests`: la zona de los hijos SALE de `group.cloudKitZoneID` y no se pisa, salvo
//  en los dos tests donde pisarla ES el sujeto (zona ajena del pull backend y duplicado por zona).
//  `PendingJoinStore.defaults` se inyecta y se restaura (molde `GroupBackendInviteEntryHandlerJoinTests`).
//

import CloudKit
import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite(.serialized)
struct GroupsIdentityPurgeGateTests {

    private let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: - Fixtures

    private func makeContext() throws -> ModelContext {
        CloudSyncFlags._testResetGroupsBackendEnabledOverride()
        return try makeTestContext()
    }

    /// Siembra un grupo con UN hijo de cada tipo en su zona REAL.
    @discardableResult
    private func seedZone(
        in context: ModelContext,
        name: String,
        isOwner: Bool = false,
        isBackendGroup: Bool = false,
        movedToBackendAt: Date? = nil,
        token: String? = nil,
        markerEnqueuedFlag: Bool = false
    ) throws -> SplitGroup {
        let group = SplitGroup(name: name, isOwner: isOwner)
        group.isBackendGroup = isBackendGroup
        group.movedToBackendAt = movedToBackendAt
        group.backendReInviteToken = token
        group.markerEnqueuedFlag = markerEnqueuedFlag
        context.insert(group)
        let zone = group.cloudKitZoneID
        context.insert(SplitMember(groupZoneID: zone, displayName: "Ana"))
        context.insert(SplitExpense(groupZoneID: zone, amount: 300, expenseDescription: "Cena"))
        context.insert(SplitShare(memberID: "m1", amount: 100, groupZoneID: zone))
        context.insert(SplitSettlement(
            groupZoneID: zone, fromMemberID: "m1", toMemberID: "m2", amount: 100))
        try context.save()
        return group
    }

    private func childCounts(
        _ context: ModelContext, zone: String
    ) throws -> (members: Int, expenses: Int, shares: Int, settlements: Int) {
        (
            try context.fetchCount(FetchDescriptor<SplitMember>(predicate: #Predicate { $0.groupZoneID == zone })),
            try context.fetchCount(FetchDescriptor<SplitExpense>(predicate: #Predicate { $0.groupZoneID == zone })),
            try context.fetchCount(FetchDescriptor<SplitShare>(predicate: #Predicate { $0.groupZoneID == zone })),
            try context.fetchCount(FetchDescriptor<SplitSettlement>(predicate: #Predicate { $0.groupZoneID == zone }))
        )
    }

    /// `apply` con los tres seams cerrados (sin sesión real, sin UserDefaults).
    @discardableResult
    private func runGate(
        _ context: ModelContext,
        hasCloudSession: Bool = true,
        revoked: ((String) -> Void)? = nil
    ) throws -> GroupsIdentityPurgeGate.Result {
        try GroupsIdentityPurgeGate.apply(
            in: context,
            now: { fixedNow },
            hasCloudSession: { hasCloudSession },
            revokePendingJoinCredential: { zone in revoked?(zone); return 0 })
    }

    // MARK: - El fix

    /// EL test que pide el ticket: tras un cambio de identidad simulado el HISTORIAL sigue disponible.
    /// El mecanismo ya no es el cursor sino la RETENCIÓN de filas — y esta prueba pinnea las dos mitades
    /// del par: las filas siguen ahí Y el cursor del pull backend sigue INTACTO. Resetear el cursor
    /// («que el server lo re-mande») no es una alternativa: el server solo manda `server_seq > cursor`.
    @Test func apply_retainsBackendZoneWithItsHistory_whenCloudSessionAlive() throws {
        let context = try makeContext()
        let backend = try seedZone(in: context, name: "Depa", isBackendGroup: true, token: "tok-1")
        let zone = backend.cloudKitZoneID
        let cursorJSON = "{\"\(zone)\":42}"
        let cursor = GroupSyncCursor(groupCursorsJSON: cursorJSON)
        context.insert(cursor)
        try context.save()

        let result = try runGate(context)
        try context.save()

        #expect(result.retainedOwnedZones == 1)
        #expect(result.retainedFrozenZones == 0)
        #expect(result.deletedZones == 0)
        #expect(try context.fetchCount(FetchDescriptor<SplitGroup>()) == 1)
        let counts = try childCounts(context, zone: zone)
        #expect(counts.members == 1)
        #expect(counts.expenses == 1)
        #expect(counts.shares == 1)
        #expect(counts.settlements == 1)
        #expect(cursor.groupCursorsJSON == cursorJSON)

        // `GroupSyncCursor` no está en `wipeAllModels`: sin esto la fila sobrevive al resto del fichero.
        context.delete(cursor)
        try context.save()
    }

    /// D1 completo: se retienen LAS DOS formas (dueño backend y copia CONGELADA) y a ambas se les revoca
    /// TODA credencial de re-join — el token y la marca durable que impide su re-hidratación.
    @Test func apply_retainsFrozenMemberCopy_andRevokesEveryRejoinCredential() throws {
        let context = try makeContext()
        try seedZone(in: context, name: "Depa", isBackendGroup: true, token: "tok-owner")
        let frozen = try seedZone(in: context, name: "Viaje", movedToBackendAt: .now, token: "tok-frozen")
        var revokedZones: [String] = []

        let result = try runGate(context, revoked: { revokedZones.append($0) })
        try context.save()

        #expect(result.retainedOwnedZones == 1)
        #expect(result.retainedFrozenZones == 1)
        #expect(result.deletedZones == 0)
        #expect(result.credentialsRevoked == 2)

        let groups = try context.fetch(FetchDescriptor<SplitGroup>())
        #expect(groups.count == 2)
        #expect(groups.allSatisfy { $0.backendReInviteToken == nil })
        #expect(groups.allSatisfy { $0.rejoinRevokedAt == fixedNow })
        // Los discriminadores de canal NO se tocan: borrarlos volvería la fila indistinguible de un
        // grupo CloudKit y re-elegible para el borrado del próximo evento.
        #expect(groups.contains { $0.isBackendGroup })
        #expect(groups.contains { $0.movedToBackendAt != nil })
        // El intent de join pendiente de cada zona retenida pierde su legacyMemberKey.
        #expect(Set(revokedZones) == Set(groups.map(\.cloudKitZoneID)))
        #expect(revokedZones.contains(frozen.cloudKitZoneID))
    }

    /// C1: zona con duplicado de canal MIXTO (fenómeno documentado en `SplitGroupDeduplicationService`).
    /// Decidir por FILA borraría los hijos de la zona al procesar el duplicado sin marcar y dejaría el
    /// grupo backend RETENIDO como cascarón vacío con el cursor vivo = pérdida permanente causada por el
    /// propio fix. De una zona retenida no se borra NADA; el duplicado lo resuelve el dedup del boot.
    @Test func apply_mixedChannelDuplicateZone_keepsChildrenAndBothRows() throws {
        let context = try makeContext()
        let backend = try seedZone(in: context, name: "Depa", isBackendGroup: true)
        let zone = backend.cloudKitZoneID
        // Duplicado del accept-share: `id` nuevo, MISMA zona, sin marca de canal (el flip solo tocó una
        // fila — `fetchSplitGroup` usa `fetchLimit = 1`).
        let twin = SplitGroup(name: "Depa")
        twin.cloudKitZoneID = zone
        context.insert(twin)
        try context.save()

        let result = try runGate(context)
        try context.save()

        #expect(result.retainedOwnedZones == 1)
        #expect(result.deletedZones == 0)
        #expect(try context.fetchCount(FetchDescriptor<SplitGroup>()) == 2)
        let counts = try childCounts(context, zone: zone)
        #expect(counts.members == 1)
        #expect(counts.expenses == 1)
        #expect(counts.shares == 1)
        #expect(counts.settlements == 1)
    }

    /// Pin anti-regresión del commit 31dded30: el usuario nuevo NO hereda los grupos CloudKit del
    /// anterior. El gate solo exceptúa el canal backend; el canal CloudKit se sigue yendo entero.
    @Test func apply_stillDeletesPlainCloudKitZoneWithItsRows() throws {
        let context = try makeContext()
        let cloudKitGroup = try seedZone(in: context, name: "Cusco", isOwner: true)
        let zone = cloudKitGroup.cloudKitZoneID

        let result = try runGate(context)
        try context.save()

        #expect(result.deletedZones == 1)
        #expect(result.failedZones == 0)
        #expect(result.retainedOwnedZones == 0)
        #expect(result.retainedFrozenZones == 0)
        #expect(try context.fetchCount(FetchDescriptor<SplitGroup>()) == 0)
        let counts = try childCounts(context, zone: zone)
        #expect(counts.members == 0)
        #expect(counts.expenses == 0)
        #expect(counts.shares == 0)
        #expect(counts.settlements == 0)
    }

    /// D4: la retención se ata a la SESIÓN DE NUBE. Sin identidad Yala viva no hay `sub` que reclame
    /// esas filas, ni refresco, ni camino de vuelta ⇒ el device borra como hoy, también el canal backend.
    @Test func apply_withoutCloudSession_deletesBackendZonesToo() throws {
        let context = try makeContext()
        try seedZone(in: context, name: "Depa", isBackendGroup: true, token: "tok-owner")
        try seedZone(in: context, name: "Viaje", movedToBackendAt: .now)
        var revokedZones: [String] = []

        let result = try runGate(context, hasCloudSession: false, revoked: { revokedZones.append($0) })
        try context.save()

        #expect(result.deletedZones == 2)
        #expect(result.retainedOwnedZones == 0)
        #expect(result.retainedFrozenZones == 0)
        #expect(try context.fetchCount(FetchDescriptor<SplitGroup>()) == 0)
        // Sin sesión el camino es «como hoy»: el store de intents no se toca.
        #expect(revokedZones.isEmpty)
    }

    /// Contrato del barrido: borra por la zona REAL de la fila. La derivación `SplitGroupZone.zoneName(for: id)` solo
    /// vale para los grupos nacidos en CloudKit; un born-remote del pull backend nace con id nuevo y la
    /// zona del server encima (`applyGroupMeta`). Depender de la invariante es lo que dejaba huérfanos.
    @Test func apply_deletesChildrenByTheRowsRealZone_notByTheIDDerivation() throws {
        let context = try makeContext()
        let group = SplitGroup(name: "Zona ajena")
        group.cloudKitZoneID = "\(SplitGroupZone.zonePrefix)\(UUID().uuidString)"  // molde applyGroupMeta
        context.insert(group)
        let zone = group.cloudKitZoneID
        context.insert(SplitMember(groupZoneID: zone, displayName: "Ana"))
        context.insert(SplitExpense(groupZoneID: zone, amount: 10, expenseDescription: "Café"))
        try context.save()
        #expect(zone != SplitGroupZone.zoneName(for: group.id), "fixture inválido: la zona debe diferir")

        let result = try runGate(context)
        try context.save()

        #expect(result.deletedZones == 1)
        #expect(try context.fetchCount(FetchDescriptor<SplitGroup>()) == 0)
        let counts = try childCounts(context, zone: zone)
        #expect(counts.members == 0)
        #expect(counts.expenses == 0)
    }

    /// C5: el marcador del OWNER migrado se RE-ARMA. D2 recrea los engines con `state: nil`, así que el
    /// pending change del marcador se va con el estado viejo; dejar el flag en `true` afirmaría «ya está
    /// encolado» sobre una cola que ya no existe y los members NUNCA congelarían. La copia de MIEMBRO no
    /// se toca (su flag ya es `false` y el reconciler, ahora acotado a `isOwner`, la excluye).
    @Test func apply_reQueuesOnlyTheOwnerMigrationMarker() throws {
        let context = try makeContext()
        let owner = try seedZone(
            in: context, name: "Depa", isOwner: true, isBackendGroup: true,
            movedToBackendAt: .now, token: "tok", markerEnqueuedFlag: true)
        let frozen = try seedZone(in: context, name: "Viaje", movedToBackendAt: .now)

        let result = try runGate(context)
        try context.save()

        #expect(result.markersReQueued == 1)
        #expect(owner.markerEnqueuedFlag == false)
        #expect(frozen.markerEnqueuedFlag == false)
    }

    /// Tabla de la decisión pura: D1 exige AMBAS formas del canal backend, y D4 las corta a las dos
    /// cuando no hay sesión de nube. Es el contrato que impide «optimizar» la retención a solo
    /// `isBackendGroup` (la mitad que deja fuera las copias congeladas).
    @Test func decide_table_bothBackendShapes_andTheSessionGate() {
        #expect(GroupsIdentityPurgeGate.decide(isBackendGroup: true, movedToBackendAt: nil, hasCloudSession: true)
            == .retainRevokingRejoinCredentials)
        #expect(GroupsIdentityPurgeGate.decide(isBackendGroup: false, movedToBackendAt: .now, hasCloudSession: true)
            == .retainRevokingRejoinCredentials)
        #expect(GroupsIdentityPurgeGate.decide(isBackendGroup: true, movedToBackendAt: .now, hasCloudSession: true)
            == .retainRevokingRejoinCredentials)
        #expect(GroupsIdentityPurgeGate.decide(isBackendGroup: false, movedToBackendAt: nil, hasCloudSession: true)
            == .deleteLocalRows)
        #expect(GroupsIdentityPurgeGate.decide(isBackendGroup: true, movedToBackendAt: nil, hasCloudSession: false)
            == .deleteLocalRows)
        #expect(GroupsIdentityPurgeGate.decide(isBackendGroup: false, movedToBackendAt: .now, hasCloudSession: false)
            == .deleteLocalRows)
        #expect(GroupsIdentityPurgeGate.decide(isBackendGroup: true, movedToBackendAt: .now, hasCloudSession: false)
            == .deleteLocalRows)
        #expect(GroupsIdentityPurgeGate.decide(isBackendGroup: false, movedToBackendAt: nil, hasCloudSession: false)
            == .deleteLocalRows)
        // Zona con duplicado MIXTO: basta UNA fila del canal backend para retener la zona entera.
        #expect(GroupsIdentityPurgeGate.decideForZone(
            rowsInZone: [
                (isBackendGroup: false, movedToBackendAt: nil),
                (isBackendGroup: true, movedToBackendAt: nil),
            ],
            hasCloudSession: true) == .retainRevokingRejoinCredentials)
    }

    // MARK: - Durabilidad de la revocación (C2 / C3)

    /// C2: la revocación sobrevive al PULL. Sin la marca local, `CKRecordTranslator.update` re-hidrata el
    /// token en el siguiente fetch del GroupMeta — y D2 (reset de los change tokens) garantiza ese fetch.
    @Test func ckRecordTranslatorUpdate_doesNotRehydrateTheTokenOnARevokedGroup() throws {
        let context = try makeContext()
        let group = try seedZone(in: context, name: "Depa", isBackendGroup: true, token: "tok-1")
        try runGate(context)
        try context.save()
        #expect(group.backendReInviteToken == nil)

        let record = CKRecord(
            recordType: "GroupMeta",
            recordID: CKRecord.ID(
                recordName: group.id.uuidString,
                zoneID: CKRecordZone.ID(zoneName: group.cloudKitZoneID, ownerName: CKCurrentUserDefaultName)))
        record.encryptedValues["name"] = "Depa" as CKRecordValue
        record["movedToBackendAt"] = fixedNow as CKRecordValue
        record.encryptedValues["backendReInviteToken"] = "tok-1" as CKRecordValue

        CKRecordTranslator.update(group, from: record)

        #expect(group.backendReInviteToken == nil)
        // El resto del marcador SÍ se aplica: solo la credencial queda revocada.
        #expect(group.movedToBackendAt == fixedNow)
    }

    /// C3: el token no era la única credencial. `legacyMemberKeyForRejoin` lee el `SplitMember` con
    /// `isCurrentUser` de la zona — hijo de un grupo RETENIDO, o sea que sobrevive — y lo manda a
    /// `join_group` como `p_legacy_member_key` (rebind server-side de la membresía del Apple ID que se
    /// fue). Con la marca devuelve nil y el re-join entra como member NUEVO.
    @Test func legacyMemberKeyForRejoin_returnsNil_afterTheGateRevokedTheZone() throws {
        let context = try makeContext()
        let group = try seedZone(in: context, name: "Viaje", movedToBackendAt: .now, token: "tok")
        let me = SplitMember(groupZoneID: group.cloudKitZoneID, displayName: "Jür")
        me.isCurrentUser = true
        me.cloudKitUserRecordID = "_appleIDviejo"
        context.insert(me)
        try context.save()
        #expect(GroupBackendInviteEntryHandler.legacyMemberKeyForRejoin(group: group, context: context)
            == "_appleIDviejo")

        try runGate(context)
        try context.save()

        #expect(GroupBackendInviteEntryHandler.legacyMemberKeyForRejoin(group: group, context: context) == nil)
    }

    /// La revocación del intent pendiente es QUIRÚRGICA: se va el `legacyMemberKey` (rebind) y se queda
    /// el `inviteToken`, para que un join en vuelo se complete igual, como member nuevo.
    @Test func pendingJoinStore_revokeLegacyMemberKey_dropsTheKeyAndKeepsTheToken() throws {
        let previous = PendingJoinStore.defaults
        PendingJoinStore.defaults = makeIsolatedDefaults(prefix: "purgegate")
        defer { PendingJoinStore.defaults = previous }

        PendingJoinStore.save(PendingJoinEntry(
            zoneName: "SplitGroup-Z", zoneOwnerName: "",
            backendGroupID: "SplitGroup-Z", inviteToken: "tok", legacyMemberKey: "_appleIDviejo"))

        #expect(PendingJoinStore.revokeLegacyMemberKey(zoneName: "SplitGroup-Z") == 1)

        let entry = PendingJoinStore.entry(zoneName: "SplitGroup-Z")
        #expect(entry?.legacyMemberKey == nil)
        #expect(entry?.inviteToken == "tok")
        // Idempotente: una segunda pasada no cuenta nada.
        #expect(PendingJoinStore.revokeLegacyMemberKey(zoneName: "SplitGroup-Z") == 0)
        #expect(PendingJoinStore.revokeLegacyMemberKey(zoneName: "SplitGroup-otra") == 0)
    }
}

/// Cableado de producción (source-scan). El gate es puro y testeable, pero `clearAllLocalGroupData` es
/// `private` sobre un singleton con CKSyncEngine vivo: sin estos scans, revertir el hunk que lo cablea
/// deja la suite ENTERA en verde con el bug de vuelta. Mismo patrón y misma razón que
/// `HandoverGroupsWiringTests` / `SignOutNotificationWiringTests`.
@Suite("C-3 · cableado de producción (source-scan)")
struct GroupsIdentityPurgeWiringTests {

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // repo root
    }

    private static func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(path), encoding: .utf8)
    }

    /// La primitiva de purga por identidad pasa por el gate y NUNCA vuelve a borrar el dominio entero.
    @Test func clearAllLocalGroupData_goesThroughTheGate() throws {
        let src = try Self.source("Yala/Services/Groups/SplitSyncManager.swift")
        #expect(src.contains("GroupsIdentityPurgeGate.apply(in: modelContext)"))
        // La negativa ancla en el PRIMITIVO, no en una forma de llamada concreta. La versión anterior
        // escaneaba `deleteGroupCache(groupID: group.id, context: modelContext)`, una firma que NUNCA
        // existió (los call-sites siempre pasaron `groupID: groupID`) ⇒ estaba verde midiendo el vacío, la
        // familia de `AppAttestClient.ensureRegistered()`. Con el `#require` de abajo, si alguien renombra
        // el primitivo esta prueba se cae en vez de dejar de medir en silencio.
        try #require(src.contains("private func deleteGroupCache(zoneName: String, context: ModelContext)"),
                     "el primitivo cambió de nombre o de firma: este scan dejó de medir nada")
        let afterPurge = try #require(src.components(separatedBy: "private func applyIdentityPurge() {").last)
        let purgeBody = afterPurge.components(separatedBy: "\n    #if DEBUG").first ?? afterPurge
        #expect(!purgeBody.contains("deleteGroupCache("),
                Comment(rawValue: "la purga por identidad tiene su propio barrido (RETIENE las zonas "
                        + "backend); reusar el primitivo del transporte, que borra la zona entera, se "
                        + "llevaría por delante justo lo que el gate acaba de conservar"))
    }

    /// D2: la rama `.signOut` resetea el estado del engine, no solo borra filas. Es la trampa (1) de
    /// `.claude/rules/swiftdata-cloudkit.md` y el anti-patrón que nombra `resetLocalGroupsSyncState`.
    @Test func signOutBranch_alsoResetsEngineState() throws {
        let src = try Self.source("Yala/Services/Groups/SplitSyncManager.swift")
        let branch = src.components(separatedBy: "case .signOut:")
        #expect(branch.count == 2)
        let body = branch[1].components(separatedBy: "case .switchAccounts:").first ?? ""
        // Positiva a secas: una negativa sobre `clearAllLocalGroupData()` se rompería en cuanto alguien
        // mencionara el nombre CON paréntesis en el comentario del propio hunk. Lo que importa es que la
        // rama enruta por la limpieza completa, y eso lo dice esta línea.
        #expect(body.contains("performAccountSwitchCleanup()"))
    }

    /// D2 de verdad: `clearState` solo borra el fichero; sin recrear los engines, el delegate re-escribe
    /// la `stateSerialization` que sigue en memoria en el siguiente `.stateUpdate`.
    @Test func identityCleanup_recreatesBothEngines() throws {
        let src = try Self.source("Yala/Services/Groups/SplitSyncManager.swift")
        #expect(src.contains("recreateEnginesAfterIdentityChange()"))
        #expect(src.contains("private func recreateEnginesAfterIdentityChange()"))
    }

    /// Los 4 sitios que la RETENCIÓN vuelve alcanzables ya no miran `isBackendGroup` a secas: una copia
    /// CONGELADA retenida no puede re-encolarse a la private DB del Apple ID NUEVO.
    ///
    /// **El 2026-08-03 el predicado se mudó de sitio y este test se actualizó con él.** Los cuatro guards
    /// pasaron a preguntar por la ZONA (`zoneBlocksCloudKitWrites`, ANY-row) porque con un `SplitGroup`
    /// duplicado MIXTO el mismo grupo pasaba o no según qué fila trajera el caller. **El predicado por FILA
    /// no cambió** —sigue siendo la disyunción del freeze, que es lo que este test defiende— pero ahora vive
    /// UNA sola vez, dentro del helper, en vez de repetido en los cuatro guards. Las anclas siguen siendo de
    /// CÓDIGO y el conteo nombra al sitio exacto que alguien quite.
    @Test func theFourCloudKitWriteSites_useTheFreezePredicate() throws {
        let src = try Self.source("Yala/Services/Groups/SplitSyncManager.swift")
        // Los 4 guards, cada uno con su forma: enqueueSave / enqueueDeletion (guard), zoneRecovery (guard
        // sobre `$0` dentro del filtro) y recordRecovery (`if … continue`).
        #expect(src.components(separatedBy: "guard !zoneBlocksCloudKitWrites(group) else {")
            .count - 1 == 2)                                                  // enqueueSave + enqueueDeletion
        #expect(src.contains("guard !zoneBlocksCloudKitWrites($0) else {"))    // zoneRecovery
        #expect(src.contains("if zoneBlocksCloudKitWrites(group) {"))          // recordRecovery
        // Y el predicado por fila que este test defiende sigue siendo el ANCHO, no `isBackendGroup` a secas.
        #expect(src.contains("group.isBackendGroup || group.isMigratedFrozen"),
                "el helper de zona dejó de usar la disyunción del freeze")
        #expect(src.contains("$0.isBackendGroup || $0.isMigratedFrozen"),
                "el mapeo de las filas de la zona dejó de usar la disyunción del freeze")
    }

    /// D4: la retención se ata a la SESIÓN DE NUBE REAL y al store de intents REAL, no a un seam de test.
    /// Sin esto, un default `{ true }` deja los 11 tests de arriba en verde y la privacidad rota en
    /// producción — los tests inyectan los tres seams, así que el default es justo lo que no cubren.
    @Test func theGateDefaultsToTheRealSessionAndTheRealJoinStore() throws {
        let src = try Self.source("Yala/App/Logic/GroupsIdentityPurgeGate.swift")
        #expect(src.contains("hasCloudSession: @MainActor () -> Bool = { CloudAuthService.shared.hasSession }"))
        #expect(src.contains("PendingJoinStore.revokeLegacyMemberKey(zoneName: $0)"))
    }
}


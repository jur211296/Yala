//
//  GroupBackendInviteEntryHandlerLegacyKeyTests.swift
//  YalaTests
//
//  `legacyMemberKeyForRejoin` — el SEXTO resolvedor de identidad de Grupos, el que 2.6 no enumeró.
//  Produce la llave con la que un re-join RECLAMA la membresía de la era CloudKit en un grupo ya migrado
//  (`join_group(p_legacy_member_key)` → rebind de la fila placeholder que `migrate_group` dejó con
//  `user_id NULL`). Llave equivocada = historial atribuido a una fila fantasma, o —peor— a OTRO humano.
//
//  Lo que estas celdas pinnean, y por qué NO es el molde literal de 2.6: la pregunta aquí no es «quién
//  soy» sino «cuál era MI FICHA legacy». Un fallback por `sub` (el que 2.6 añadió en los otros cinco)
//  elegiría el member born-backend, cuyo `cloudKitUserRecordID` está VACÍO por diseño
//  (`GroupsSyncClient.applyMember`) ⇒ devolvería vacío o basura. Por eso la cascada resuelve FILAS de la
//  zona, y el `cachedRecordName` deja de ser una FUENTE para pasar a ser un SELECTOR.
//
//  El guard C-3 (`rejoinRevokedAt`) ya está cubierto por `GroupsIdentityPurgeGateTests:319-337` — aquí no
//  se duplica. Se reusa su molde de siembra.
//
//  Serializado: toca el singleton `GroupUserIdentityService.shared` (cache in-memory) y ≥2
//  `makeTestContext()`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("legacyMemberKeyForRejoin · la llave sale de una FILA, no de la identidad suelta", .serialized)
struct GroupBackendInviteEntryHandlerLegacyKeyTests {

    // MARK: - Fixtures

    private func makeContext() throws -> ModelContext {
        CloudSyncFlags._testResetGroupsBackendEnabledOverride()
        return try makeTestContext()
    }

    /// Copia CONGELADA de un grupo migrado (`movedToBackendAt != nil`), sin credencial revocada: es el
    /// estado exacto en el que un miembro tapea el re-invite. Molde `GroupsIdentityPurgeGateTests`.
    @discardableResult
    private func seedMigratedZone(in context: ModelContext, name: String = "Viaje") throws -> SplitGroup {
        let group = SplitGroup(name: name)
        group.movedToBackendAt = Date(timeIntervalSince1970: 1_800_000_000)
        group.backendReInviteToken = "tok"
        context.insert(group)
        try context.save()
        return group
    }

    @discardableResult
    private func seedMember(
        in context: ModelContext,
        zone: String,
        displayName: String,
        recordID: String = "",
        isCurrentUser: Bool = false,
        memberKey: String? = nil,
        userID: String? = nil,
        joinedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) throws -> SplitMember {
        let member = SplitMember(groupZoneID: zone, displayName: displayName)
        member.cloudKitUserRecordID = recordID
        member.isCurrentUser = isCurrentUser
        member.memberKey = memberKey
        member.userID = userID
        member.joinedAt = joinedAt
        context.insert(member)
        try context.save()
        return member
    }

    /// Fija la identidad iCloud cacheada del device y la restaura. NUNCA `UserDefaults.standard`: el
    /// `_testSetCachedRecordName` solo toca el cache in-memory, que es lo que la función lee.
    private func withCachedIdentity(_ recordName: String?, _ body: () throws -> Void) rethrows {
        let previous = GroupUserIdentityService.shared.cachedRecordName
        GroupUserIdentityService.shared._testSetCachedRecordName(recordName)
        defer { GroupUserIdentityService.shared._testSetCachedRecordName(previous) }
        try body()
    }

    // MARK: - El defecto (A): el censo de la zona CONTRADICE al cache

    /// EL rojo. Estado alcanzable y medido (2026-07-30): `performAccountSwitchCleanup` llama
    /// `clearAllLocalGroupData()` —que se AUTO-DIFIERE en la ventana export-only y por tanto NO corre
    /// `GroupsIdentityPurgeGate`, o sea NO escribe `rejoinRevokedAt`— y acto seguido
    /// `resetLocalGroupsSyncState()`, que SÍ corre y borra la identidad iCloud. El diferido vive solo en
    /// memoria: si el proceso muere antes de la promoción, la purga no ocurre JAMÁS. El siguiente arranque
    /// re-siembra el cache con el recordName del Apple ID NUEVO y `refreshCurrentUserFlags` apaga el
    /// `isCurrentUser` de la fila (el grupo aún no está marcado como migrado ⇒ `cloudKitMatch == false`);
    /// cuando el marcador aterriza, esa rama CONGELA el `false` para siempre.
    ///
    /// Resultado hoy: la fuente 2 devuelve el recordName NUEVO, que no es el `member_key` de ningún
    /// placeholder MÍO — y si casa con alguno, es el de OTRO humano de ese mismo grupo (el `join_group`
    /// rebindea con `member_key = X and user_id is null`, sin preguntar de quién es). Eso es exactamente
    /// lo que la revocación C-3 existe para impedir, reabierto por el diferido.
    @Test("Cache que ningún member de la zona respalda ⇒ NO se ofrece como llave legacy")
    func legacyKey_isRefused_whenTheZoneCensusContradictsTheCache() throws {
        let context = try makeContext()
        let group = try seedMigratedZone(in: context)
        // Mi ficha legacy, con el recordName del Apple ID que se fue y el flag ya apagado.
        try seedMember(in: context, zone: group.cloudKitZoneID, displayName: "Jür", recordID: "_appleIDviejo")
        // Y la de otro humano del grupo, para que el censo CloudKit-era no sea trivial.
        try seedMember(in: context, zone: group.cloudKitZoneID, displayName: "Ana", recordID: "_ana")

        try withCachedIdentity("_appleIDnuevo") {
            #expect(GroupBackendInviteEntryHandler.legacyMemberKeyForRejoin(group: group, context: context) == nil,
                    """
                    Devolvió una llave que NINGUNA fila de la zona respalda. `migrate_group` construye los \
                    placeholders desde ese mismo censo, así que esa llave o no casa nada (fallo silencioso \
                    con datos plausibles) o casa el placeholder de OTRO miembro y le entrega su historial.
                    """)
        }
    }

    // MARK: - Lo que NO puede cambiar (el cache sigue salvando el caso común)

    /// 2º device / reinstalación / restore con el MISMO Apple ID: la fila legacy baja por CloudKit con el
    /// flag apagado —`isCurrentUser` es device-local y no viaja en el CKRecord— y ahí `refreshCurrentUserFlags`
    /// tampoco lo enciende NUNCA (en una zona del canal backend deja el flag como está: `GroupService:1119`
    /// y `:1145-1154`). La llave la da la propia fila, que es lo que el server tiene.
    @Test("Fila legacy con el recordName del device: la llave sale de la fila aunque el flag esté apagado")
    func legacyKey_comesFromTheRow_whenTheFlagIsOffButTheIdentityMatches() throws {
        let context = try makeContext()
        let group = try seedMigratedZone(in: context)
        try seedMember(in: context, zone: group.cloudKitZoneID, displayName: "Ana", recordID: "_ana")
        try seedMember(in: context, zone: group.cloudKitZoneID, displayName: "Jür", recordID: "_appleIDdelDevice")

        try withCachedIdentity("_appleIDdelDevice") {
            #expect(GroupBackendInviteEntryHandler.legacyMemberKeyForRejoin(group: group, context: context)
                == "_appleIDdelDevice")
        }
    }

    /// Sin censo CloudKit-era en la zona no hay nada que pueda contradecir al cache (el grupo puede estar
    /// local antes que sus members). Ahí se conserva el fallback de hoy: cerrarlo también aquí convertiría
    /// una ventana de sync en una pérdida del rebind.
    @Test("Zona sin ninguna fila de la era CloudKit: el cache sigue siendo el fallback")
    func legacyKey_fallsBackToTheCache_whenTheZoneHasNoCloudKitEraCensus() throws {
        let context = try makeContext()
        let group = try seedMigratedZone(in: context)
        // Members born-backend: `cloudKitUserRecordID` vacío por diseño (`applyMember` nunca lo escribe).
        try seedMember(in: context, zone: group.cloudKitZoneID, displayName: "Ana",
                       memberKey: "11111111-1111-1111-1111-111111111111",
                       userID: "11111111-1111-1111-1111-111111111111")

        try withCachedIdentity("_appleIDdelDevice") {
            #expect(GroupBackendInviteEntryHandler.legacyMemberKeyForRejoin(group: group, context: context)
                == "_appleIDdelDevice")
        }
        // Y sin identidad iCloud tampoco se inventa nada: residual §9.3b (entra como member NUEVO).
        try withCachedIdentity(nil) {
            #expect(GroupBackendInviteEntryHandler.legacyMemberKeyForRejoin(group: group, context: context) == nil)
        }
    }

    // MARK: - La moneda al aire del `fetchLimit = 1` sin sort

    /// Una zona migrada puede tener DOS filas `isCurrentUser` del mismo humano: la legacy CloudKit (con
    /// recordName) y la born-backend de un re-join que no rebindeó (`cloudKitUserRecordID` vacío, encendida
    /// por `refreshCurrentUserFlags` vía `sub`). Con `fetchLimit = 1` y sin `sortBy`, cuál gana lo decidía
    /// el orden del store: si ganaba la born-backend, la llave BUENA que estaba en la otra fila se perdía.
    @Test("Entre dos filas marcadas gana la que tiene recordName, no la born-backend")
    func legacyKey_prefersTheRowThatCarriesARecordName_overAFlaggedBackendBornMember() throws {
        let context = try makeContext()
        let group = try seedMigratedZone(in: context)
        let sub = "22222222-2222-2222-2222-222222222222"
        // Insertada PRIMERO a propósito: es la que ganaba el fetch sin sort.
        try seedMember(in: context, zone: group.cloudKitZoneID, displayName: "Jür",
                       isCurrentUser: true, memberKey: sub, userID: sub,
                       joinedAt: Date(timeIntervalSince1970: 1_750_000_000))
        try seedMember(in: context, zone: group.cloudKitZoneID, displayName: "Jür",
                       recordID: "_appleIDdelDevice", isCurrentUser: true)

        try withCachedIdentity(nil) {
            #expect(GroupBackendInviteEntryHandler.legacyMemberKeyForRejoin(group: group, context: context)
                == "_appleIDdelDevice",
                    "La fila born-backend tapó a la legacy y se perdió la única llave de rebind del device.")
        }
    }

    /// Tie-break canónico entre filas marcadas con recordName: `joinedAt` más antiguo — el MISMO criterio
    /// que `GroupExpenseService.selectCurrentUserMemberID` y `GroupNotificationService.currentMemberID`.
    /// Divergir aquí haría que el rebind reclamara un placeholder distinto del que el resto de la app
    /// considera «yo».
    @Test("Con duplicados marcados, el desempate es el `joinedAt` más antiguo (criterio canónico)")
    func legacyKey_tieBreaksOnOldestJoinedAt() throws {
        let context = try makeContext()
        let group = try seedMigratedZone(in: context)
        try seedMember(in: context, zone: group.cloudKitZoneID, displayName: "Jür",
                       recordID: "_reciente", isCurrentUser: true,
                       joinedAt: Date(timeIntervalSince1970: 1_760_000_000))
        try seedMember(in: context, zone: group.cloudKitZoneID, displayName: "Jür",
                       recordID: "_antiguo", isCurrentUser: true,
                       joinedAt: Date(timeIntervalSince1970: 1_600_000_000))

        try withCachedIdentity(nil) {
            #expect(GroupBackendInviteEntryHandler.legacyMemberKeyForRejoin(group: group, context: context)
                == "_antiguo")
        }
    }
}

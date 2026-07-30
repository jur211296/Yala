//
//  GroupServiceCurrentUserFlagsTests.swift
//  YalaTests
//
//  Tests de `GroupService.refreshCurrentUserFlags` — la pieza de 2.6 que decide QUIÉN VE QUÉ BALANCE.
//
//  Por qué existe esta suite: `isCurrentUser` es un flag del canal CloudKit y en el BACKEND nace APAGADO
//  para casi todo el mundo (solo `GroupBackendMembershipService.createGroup` lo enciende, y solo sobre el
//  member del CREADOR; `GroupsSyncClient.applyMember` NUNCA lo setea). Quien se UNE a un grupo, y
//  cualquiera en un 2º device o tras un reinstall, recibe su propio `SplitMember` por el PULL sin el flag
//  ⇒ `GroupDetailViewModel.currentUserMember` lee SOLO ese flag ⇒ sin banda de balance, sin FAB, sin
//  liquidar. El re-cableo de 2.6 lo arregla resolviendo por el `sub` de la cuenta Yala, y ninguna de sus
//  cuatro decisiones fallaba al compilar: un apagón silencioso necesita un test, no un build verde.
//
//  Cubre las CUATRO decisiones, cada una con su contra-caso:
//    1. el fix        — member backend sin flag + `sub` que casa ⇒ se enciende
//    2. la autoridad  — `sub` que NO casa ⇒ se apaga (es otro humano)
//    3. regla C-3     — grupo RETENIDO con member legacy ⇒ NO se apaga (`.claude/rules/swiftdata-cloudkit.md`)
//    4. los 3 guards  — no estampar record-name en zona backend · no apagar sin iCloud · no inferir
//                       `isGroupOwner` donde el rol lo dicta el server
//  y la INERCIA con el canal APAGADO (kill remoto, o binario sin canal compilado).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("GroupService.refreshCurrentUserFlags · identidad del miembro (2.6)", .serialized)
struct GroupServiceCurrentUserFlagsTests {

    private static let sub = "11111111-1111-1111-1111-111111111111"
    private static let otherSub = "22222222-2222-2222-2222-222222222222"
    /// Identidad iCloud vigente en el device.
    private static let recordNameNow = "_recordNameActual"
    /// La que quedó en las filas retenidas cuando el Apple ID cambió (D1 / C-3).
    private static let recordNameGone = "_recordNameDelAppleIDQueSeFue"

    // MARK: - Entorno

    /// Fija flag + `sub` + identidad iCloud cacheada, y los RESTAURA. Los tres son estado GLOBAL
    /// (`CloudSyncFlags`, el provider estático, el singleton de identidad) ⇒ la suite es `.serialized`,
    /// como manda la regla de tests para todo lo que toca `.shared`.
    ///
    /// `cachedRecordName` no-nil evita que `refreshCurrentUserFlags` caiga al fetch de CKContainer: con el
    /// cache poblado la función lo lee y no sale a la red.
    private func withIdentity(
        backendEnabled: Bool,
        sub: String?,
        cachedRecordName: String?,
        _ body: () async throws -> Void
    ) async throws {
        let previousProvider = GroupService.backendUserIDProvider
        let previousRecordName = GroupUserIdentityService.shared.cachedRecordName
        GroupService.backendUserIDProvider = { sub }
        GroupUserIdentityService.shared._testSetCachedRecordName(cachedRecordName)
        CloudSyncFlags.groupsBackendEnabled = backendEnabled
        defer {
            // El restore es el RESET del override, no `= false`. La versión anterior se apoyaba en que
            // «el compilado es `false`, así que restaurar es `= false`», premisa que el flip de D-R1
            // paso 2 destruyó: bajo `Yala Dev` el default pasa a `true`, así que ese `= false` dejaba un
            // override pegajoso divergente para todo test posterior del proceso.
            CloudSyncFlags._testResetGroupsBackendEnabledOverride()
            GroupService.backendUserIDProvider = previousProvider
            GroupUserIdentityService.shared._testSetCachedRecordName(previousRecordName)
        }
        try await body()
    }

    /// Grupo + su member, insertados y guardados. `backend` cubre las DOS formas de pertenencia que D1
    /// nombra: `isBackendGroup` (dueño backend) y `movedToBackendAt` (copia congelada).
    private func seed(
        in context: ModelContext,
        backend: Bool,
        movedToBackend: Bool = false,
        isOwner: Bool = false,
        memberUserID: String? = nil,
        memberRecordName: String = "",
        isCurrentUser: Bool = false,
        isGroupOwner: Bool = false
    ) throws -> (group: SplitGroup, member: SplitMember) {
        let group = SplitGroup(name: "Viaje", isOwner: isOwner)
        group.isBackendGroup = backend
        group.movedToBackendAt = movedToBackend ? .now : nil
        let member = SplitMember(
            groupZoneID: group.cloudKitZoneID,
            displayName: "Yo",
            cloudKitUserRecordID: memberRecordName,
            isGroupOwner: isGroupOwner,
            isCurrentUser: isCurrentUser
        )
        member.userID = memberUserID
        context.insert(group)
        context.insert(member)
        try context.save()
        return (group, member)
    }

    // MARK: - 1 · El fix: el member del canal backend se reconoce por su `sub`

    @Test("Member backend sin isCurrentUser: el sub que casa lo ENCIENDE (el bug de 2.6)")
    func backendMemberWithoutFlag_isTurnedOn_whenSubMatches() async throws {
        let context = try makeTestContext()
        let seeded = try seed(
            in: context, backend: true, memberUserID: Self.sub, isCurrentUser: false)

        try await withIdentity(backendEnabled: true, sub: Self.sub, cachedRecordName: Self.recordNameNow) {
            await GroupService.shared.refreshCurrentUserFlags(context: context)
        }

        #expect(seeded.member.isCurrentUser,
                "Quien se UNE recibe su member por el pull sin el flag; sin esto se queda sin balance ni FAB.")
    }

    @Test("La copia CONGELADA (movedToBackendAt) también resuelve por sub, no solo isBackendGroup")
    func frozenCopy_alsoResolvesBySub() async throws {
        let context = try makeTestContext()
        let seeded = try seed(
            in: context, backend: false, movedToBackend: true,
            memberUserID: Self.sub, isCurrentUser: false)

        try await withIdentity(backendEnabled: true, sub: Self.sub, cachedRecordName: Self.recordNameNow) {
            await GroupService.shared.refreshCurrentUserFlags(context: context)
        }

        #expect(seeded.member.isCurrentUser, "D1 nombra AMBAS formas de pertenencia al canal backend.")
    }

    // MARK: - 2 · La autoridad: un sub que no casa es OTRO humano

    @Test("Sub que NO casa: se APAGA — en el canal nuevo el sub es la identidad autoritativa")
    func backendMember_isTurnedOff_whenSubMismatches() async throws {
        let context = try makeTestContext()
        let seeded = try seed(
            in: context, backend: true, memberUserID: Self.otherSub, isCurrentUser: true)

        try await withIdentity(backendEnabled: true, sub: Self.sub, cachedRecordName: Self.recordNameNow) {
            await GroupService.shared.refreshCurrentUserFlags(context: context)
        }

        #expect(!seeded.member.isCurrentUser,
                "El member de otra cuenta Yala no puede quedarse marcado como «yo».")
    }

    // MARK: - 3 · Regla C-3: el grupo RETENIDO conserva su «quién soy»

    @Test("Grupo retenido tras cambio de Apple ID: el member legacy CONSERVA isCurrentUser")
    func retainedBackendGroup_legacyMemberKeepsCurrentUser() async throws {
        let context = try makeTestContext()
        // Member sin identidad backend (`userID` nil) y con el record-name del Apple ID que se FUE:
        // el match por record-name da false, y apagarlo dejaría el grupo retenido sin «quién soy».
        let seeded = try seed(
            in: context, backend: true, memberUserID: nil,
            memberRecordName: Self.recordNameGone, isCurrentUser: true)

        try await withIdentity(backendEnabled: true, sub: Self.sub, cachedRecordName: Self.recordNameNow) {
            await GroupService.shared.refreshCurrentUserFlags(context: context)
        }

        #expect(seeded.member.isCurrentUser,
                "C-3: es justo el grupo que el fix de retención existe para conservar.")
    }

    // MARK: - 4 · Los tres guards que hacen seguro condicionar el salto C-3

    @Test("Zona backend: NO se estampa el record-name sobre un member ajeno")
    func backendZone_recordNameNeverStamped() async throws {
        let context = try makeTestContext()
        // `isCurrentUser` + `cloudKitUserRecordID` vacío es el candidato del backfill legacy.
        let seeded = try seed(
            in: context, backend: true, memberUserID: nil,
            memberRecordName: "", isCurrentUser: true)

        try await withIdentity(backendEnabled: true, sub: Self.sub, cachedRecordName: Self.recordNameNow) {
            await GroupService.shared.refreshCurrentUserFlags(context: context)
        }

        #expect(seeded.member.cloudKitUserRecordID.isEmpty,
                "Estampar aquí es el humano nuevo escribiéndose sobre un member ajeno (C-3).")
    }

    @Test("Zona backend: isGroupOwner NO se infiere localmente — el rol lo dicta el server")
    func backendZone_groupOwnerNotInferredLocally() async throws {
        let context = try makeTestContext()
        let seeded = try seed(
            in: context, backend: true, isOwner: true,
            memberUserID: Self.sub, isCurrentUser: false, isGroupOwner: false)

        try await withIdentity(backendEnabled: true, sub: Self.sub, cachedRecordName: Self.recordNameNow) {
            await GroupService.shared.refreshCurrentUserFlags(context: context)
        }

        #expect(seeded.member.isCurrentUser, "El sub sí debe resolver la identidad…")
        #expect(!seeded.member.isGroupOwner,
                "…pero el rol viene por applyMember: pisarlo local solo dura hasta el próximo delta.")
        #expect(seeded.member.role == "member")
    }

    // MARK: - 5 · Inercia con el canal apagado (kill remoto / binario sin canal)

    @Test("Flag OFF: el member de un grupo backend queda INTACTO (el salto de siempre)")
    func flagOff_backendGroupMemberUntouched() async throws {
        let context = try makeTestContext()
        let seeded = try seed(
            in: context, backend: true, memberUserID: Self.sub, isCurrentUser: false)

        // Sub presente a propósito: con el flag OFF no debe leerse.
        try await withIdentity(backendEnabled: false, sub: Self.sub, cachedRecordName: Self.recordNameNow) {
            await GroupService.shared.refreshCurrentUserFlags(context: context)
        }

        #expect(!seeded.member.isCurrentUser,
                "Con el flag OFF la rama por sub no existe: comportamiento previo a 2.6, byte a byte.")
    }

    @Test("Flag OFF: el path CloudKit sigue resolviendo por record-name")
    func flagOff_cloudKitPathStillResolvesByRecordName() async throws {
        let context = try makeTestContext()
        let seeded = try seed(
            in: context, backend: false, memberUserID: nil,
            memberRecordName: Self.recordNameNow, isCurrentUser: false)

        try await withIdentity(backendEnabled: false, sub: nil, cachedRecordName: Self.recordNameNow) {
            await GroupService.shared.refreshCurrentUserFlags(context: context)
        }

        #expect(seeded.member.isCurrentUser, "2.6 no debe haber tocado el canal viejo.")
    }

    @Test("Grupo CloudKit cuyo record-name ya no es el mío: se APAGA (comportamiento de siempre)")
    func cloudKitGroup_staleRecordName_isTurnedOff() async throws {
        let context = try makeTestContext()
        let seeded = try seed(
            in: context, backend: false, memberUserID: nil,
            memberRecordName: Self.recordNameGone, isCurrentUser: true)

        try await withIdentity(backendEnabled: false, sub: nil, cachedRecordName: Self.recordNameNow) {
            await GroupService.shared.refreshCurrentUserFlags(context: context)
        }

        #expect(!seeded.member.isCurrentUser,
                "Fuera del canal backend el record-name SÍ es la señal: este apagado es el correcto.")
    }
}

//
//  GroupBackendMembershipService.swift
//  Yala
//
//  Materializador de membresía del canal Grupos → backend (incremento G3, DARK). @MainActor final class que
//  compone `GroupsMembershipClient` (RPCs) + `ModelContext` (store de Grupos). NADIE lo llama en producción:
//  es PARALELO al camino CloudKit vigente (`GroupService`/`InviteLinkService` + CKSyncEngine) y NO añade
//  call-sites de UI — el cableado a la UI real llega en G4+, tras encender `groupsBackendEnabled`.
//
//  Gate en CADA método público: `groupsBackendEnabled && hasSession`. Con el flag OFF (SIEMPRE hoy) todo
//  método lanza `sessionExpired` ANTES de tocar la red o el contexto (no-op verificable en tests).
//
//  DECISIÓN DE DISEÑO — `createGroup` es SERVER-FIRST: el RPC `create_group` crea el grupo Y su fila owner
//  server-side; SOLO a éxito se materializa el `SplitGroup` + `SplitMember` locales. Garantiza que el grupo
//  existe server-side ANTES de cualquier delta de meta del drain (cierra por diseño el residual de b86dbf1c:
//  la purga del noop `group_not_found` en `applyResults` SE MANTIENE — protege del retry-storm de meta de
//  grupos CloudKit legacy no migrados cuando el flag encienda). El save local va bajo
//  `GroupsSyncClient.outboxSaveAuthor` (echo-suppression: el server YA tiene meta+member vía el RPC → el
//  drain NO re-emite la meta inicial; el próximo pull reconcilia PATCH idempotente).
//

import Foundation
import OSLog
import SwiftData

@MainActor
final class GroupBackendMembershipService {

    private let client: GroupsMembershipClient
    private let sessionCheck: @MainActor () -> Bool
    private let logger = Logger(subsystem: "com.yala.app", category: "GroupsMembership")

    init(
        client: GroupsMembershipClient,
        sessionCheck: @escaping @MainActor () -> Bool = { CloudAuthService.shared.hasSession }
    ) {
        self.client = client
        self.sessionCheck = sessionCheck
    }

    /// Gate DARK compartido: sin el flag O sin sesión → `sessionExpired` sin request ni mutación.
    private func ensureEligible() throws {
        guard CloudSyncFlags.groupsBackendEnabled, sessionCheck() else {
            throw GroupsRPCError.sessionExpired
        }
    }

    // MARK: - create_group (SERVER-FIRST)

    /// Crea el grupo server-side vía RPC y, SOLO a éxito, materializa el `SplitGroup` (isOwner) + su
    /// `SplitMember` owner localmente. RPC falla → throw SIN tocar el contexto (cero inserts). El save va bajo
    /// `outboxSaveAuthor` (el server ya tiene el grupo+owner; el drain no debe re-emitir la meta inicial).
    func createGroup(
        name: String,
        iconName: String = "person.2.fill",
        colorHex: String = "#8B5CF6",
        currencyCode: String,
        displayName: String,
        defaultSplitType: String = "equal",
        simplifyDebts: Bool = false,
        showDebtsInSingleCurrency: Bool = false,
        membersCanInvite: Bool = false,
        context: ModelContext
    ) async throws -> SplitGroup {
        try ensureEligible()

        // Grupo local CONSTRUIDO pero NO insertado: su `init` genera `cloudKitZoneID` ("SplitGroup-{uuid}")
        // = la identidad server-side (`p_group_id`).
        let group = SplitGroup(
            name: name,
            iconName: iconName,
            colorHex: colorHex,
            currencyCode: currencyCode,
            simplifyDebts: simplifyDebts,
            isOwner: true,
            showDebtsInSingleCurrency: showDebtsInSingleCurrency,
            defaultSplitType: defaultSplitType,
            membersCanInvite: membersCanInvite
        )
        let zoneID = group.cloudKitZoneID

        // RPC PRIMERO. Un throw aquí NO ha tocado el contexto todavía.
        let result = try await client.createGroup(
            groupID: zoneID,
            name: name,
            currencyCode: currencyCode,
            iconName: iconName,
            colorHex: colorHex,
            displayName: displayName,
            defaultSplitType: defaultSplitType,
            simplifyDebts: simplifyDebts,
            showDebtsInSingleCurrency: showDebtsInSingleCurrency,
            membersCanInvite: membersCanInvite
        )

        // Owner member: identidad del namespace BACKEND; `memberKey`/`userID` = el `member_key` del server
        // (= sub); `cloudKitUserRecordID` se queda "" (separación de canales — el sub jamás contamina CloudKit).
        let owner = SplitMember(
            groupZoneID: zoneID,
            displayName: displayName,
            cloudKitUserRecordID: "",
            role: "admin",
            status: .active,
            isGroupOwner: true,
            isCurrentUser: true
        )
        owner.id = GroupBackendIdentityLogic.deterministicMemberID(
            groupID: zoneID, memberKey: result.memberKey)
        owner.memberKey = result.memberKey
        owner.userID = result.memberKey

        try saveUnderOutboxAuthor(context) {
            context.insert(group)
            context.insert(owner)
        }
        return group
    }

    // MARK: - RPC passthrough (no materializan localmente — el pull reconcilia)

    /// RPC only: el pull trae grupo + members (join síncrono server-side); NO materializa nada local.
    func join(token: String, displayName: String, legacyMemberKey: String?) async throws -> JoinGroupResult {
        try ensureEligible()
        return try await client.joinGroup(
            token: token, displayName: displayName, legacyMemberKey: legacyMemberKey)
    }

    func approve(groupID: String, memberKey: String) async throws -> MemberActionResult {
        try ensureEligible()
        return try await client.approveMember(groupID: groupID, memberKey: memberKey)
    }

    func remove(groupID: String, memberKey: String) async throws -> MemberActionResult {
        try ensureEligible()
        return try await client.removeMember(groupID: groupID, memberKey: memberKey)
    }

    func leave(groupID: String) async throws -> MemberActionResult {
        try ensureEligible()
        return try await client.leaveGroup(groupID: groupID)
    }

    func createInvite(groupID: String, ttlSeconds: Int, maxUses: Int?) async throws -> String {
        try ensureEligible()
        return try await client.createInvite(groupID: groupID, ttlSeconds: ttlSeconds, maxUses: maxUses)
    }

    func revokeInvite(token: String) async throws {
        try ensureEligible()
        try await client.revokeInvite(token: token)
    }

    func updateDisplayName(groupID: String, displayName: String) async throws -> UpdateDisplayNameResult {
        try ensureEligible()
        return try await client.updateMemberDisplayName(groupID: groupID, displayName: displayName)
    }

    func forgetUser() async throws -> ForgetResult {
        try ensureEligible()
        return try await client.forgetUser()
    }

    // MARK: - Save helper

    /// Ejecuta `body` y hace `context.save()` bajo `GroupsSyncClient.outboxSaveAuthor`, restaurando el autor
    /// previo (echo-suppression: el drain descarta las transacciones con este autor).
    private func saveUnderOutboxAuthor(_ context: ModelContext, _ body: () throws -> Void) throws {
        let previous = context.author
        context.author = GroupsSyncClient.outboxSaveAuthor
        defer { context.author = previous }
        try body()
        try context.save()
    }
}

//
//  GroupBackendInviteService.swift
//  Yala
//
//  Arma un invite LINK backend (contrato C1): pide el token al RPC `create_group_invite` (vía
//  `GroupBackendMembershipService`) y construye el URL branded con `InviteLinkService.buildBackendInviteURL`.
//  DARK (G4): sin call-sites de UI — el "compartir enlace" backend lo cablea G5. Gate heredado del service
//  (`groupsBackendEnabled && hasSession`): con el flag OFF, `createInvite` lanza `sessionExpired`.
//

import Foundation
import OSLog

@MainActor
final class GroupBackendInviteService {

    /// TTL por defecto del invite backend (7 días — paridad con el TTL de `PendingJoinStore`). G5 lo
    /// parametriza desde la UI de "compartir enlace". `nonisolated` para usarse como valor por defecto
    /// de argumento (contexto nonisolated).
    nonisolated static let defaultTTLSeconds = 7 * 24 * 60 * 60

    private let membership: GroupBackendMembershipService
    private let logger = Logger(subsystem: "com.yala.app", category: "GroupsInvite")

    init(membership: GroupBackendMembershipService) {
        self.membership = membership
    }

    /// Crea un invite backend y devuelve el LINK C1 listo para compartir. Lanza si el RPC falla
    /// (`GroupsRPCError`) o si el builder no puede formar el URL (`.decoding`).
    func createInviteLink(
        for group: SplitGroup,
        inviterName: String,
        members: [SplitMember],
        ttlSeconds: Int = defaultTTLSeconds,
        maxUses: Int? = nil
    ) async throws -> URL {
        let groupID = group.cloudKitZoneID
        let token = try await membership.createInvite(
            groupID: groupID, ttlSeconds: ttlSeconds, maxUses: maxUses)
        guard let url = InviteLinkService.buildBackendInviteURL(
            groupID: groupID,
            token: token,
            group: group,
            members: members,
            inviterName: inviterName
        ) else {
            #if DEBUG
            logger.error("GroupsInvite: buildBackendInviteURL devolvió nil para group \(groupID, privacy: .public)")
            #endif
            throw GroupsRPCError.decoding
        }
        return url
    }
}

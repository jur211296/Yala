//
//  GroupInviteLinkMaker.swift
//  Yala
//
//  Acuña el enlace de invitación de un grupo. Vivía dentro de `GroupMembersView.createShareLink`; desde la auditoría UX
//  2.2 (L12-10) lo usa también la hoja «está listo» que sale al crear un grupo, y dos copias del guard del canal y de la
//  clasificación del error divergirían.
//

import Foundation

@MainActor
enum GroupInviteLinkMaker {

    enum Outcome: Equatable {
        case link(URL)
        /// Texto para el usuario: por qué no hay enlace y qué puede hacer.
        case failed(String)
    }

    /// Fase 3: el canal CloudKit de invitaciones ya no existe. El guard se conserva ENTERO —flag + zona backend— y su
    /// rama negativa informa: un grupo legacy no se puede invitar por ninguna vía, y dejar el botón mudo sería el
    /// apagón silencioso que la re-medición marca como peor modo de fallo (§S5.2). Qué dice esa rama lo decide
    /// `GroupInviteLinkCreationLogic`: las DOS causas (grupo legacy, permanente · canal apagado, transitorio) piden
    /// consejos opuestos, y ninguna de las dos es la conexión del admin.
    static func make(for group: SplitGroup, members: [SplitMember]) async -> Outcome {
        do {
            if CloudSyncFlags.groupsBackendEnabled && group.isBackendGroup {
                // C4: grupo backend → invite por TOKEN RPC (link ya branded). Nota A1: el flag cubre «no emitir hasta
                // que el parser esté desplegado».
                let name = UserDefaults.standard.string(forKey: "userName") ?? ""
                let inviterName = name.isEmpty ? L10n.Profile.defaultName : name
                let url = try await GroupBackendInviteService(
                    membership: GroupBackendMembershipService(
                        client: GroupsMembershipClient(attestProvider: AttestSessionProvider.live))
                ).createInviteLink(for: group, inviterName: inviterName, members: members)
                return .link(url)
            } else {
                let message = switch GroupInviteLinkCreationLogic.blocker(
                    backendEnabled: CloudSyncFlags.groupsBackendEnabled,
                    isBackendGroup: group.isBackendGroup
                ) {
                case .legacyGroup: L10n.Groups.Errors.inviteLegacyGroup
                case .channelOff: L10n.Groups.Errors.inviteChannelOff
                // No alcanzable: este `else` es la negación exacta del guard que la logic evalúa.
                // El copy de red es el fallback correcto si algún día dejan de ser el mismo predicado.
                case nil: L10n.Groups.Errors.inviteFailed
                }
                return .failed(message)
            }
        } catch {
            #if DEBUG
            print("GroupInviteLinkMaker: Error: \(error)")
            #endif
            // Por causa: «revisa tu conexión» solo cuando la petición no salió del teléfono.
            return .failed(GroupActionErrorLogic.inviteMessage(for: error))
        }
    }
}

//
//  GroupMemberRejectLogic.swift
//  Yala
//
//  Rechazar una solicitud de unión en un grupo de la nube (card 840m del QA guiado del TF19, 2026-10-20).
//
//  El servidor rechaza con `remove_member`: a quien está `pendingApproval` lo deja `rejected`, y a quien ya está
//  `active` lo deja `removed` (`supabase-groups-staging.ddl`, §5). Por eso `GroupService.rejectMember` exige la
//  solicitud pendiente en local antes de llamar, y por eso aquí solo se marca `.rejected` en local cuando el servidor
//  contesta eso mismo: si contesta otra cosa, el estado local era viejo y el pull trae el de verdad.
//

import Foundation

enum GroupMemberRejectLogic {
    /// ¿El servidor confirmó el rechazo? Solo entonces se escribe `.rejected` en local.
    static func marksRejectedLocally(serverStatus: String) -> Bool {
        serverStatus == SplitMemberStatus.rejected.rawValue
    }
}

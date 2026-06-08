//
//  MemberChangeNotificationLogic.swift
//  Yala
//
//  Pure-logic para clasificar un SplitMember NUEVO (insert recibido por sync)
//  en el tipo de notificación que corresponde. Extraído de SplitSyncManager
//  para test sin SwiftData/CloudKit (regla R8: makeTestContext flakea en local).
//
//  Antes, un member nuevo `pendingApproval` recibido por un NO-admin caía al
//  branch `else` → notif "X se unió al grupo" (cuando aún está pendiente de
//  aprobación). Ahora pending solo notifica al admin ("X quiere unirse"); los
//  estados terminales (rejected/left/removed) no notifican; `active` y los
//  records con status ausente/desconocido (que el modelo trata como activos)
//  disparan "se unió".
//

import Foundation

enum MemberChangeNotificationKind: Equatable {
    /// Solicitud de ingreso pendiente → notif "X quiere unirse", SOLO al admin.
    case pendingRequestForAdmin
    /// Miembro activo nuevo → notif "X se unió al grupo".
    case joined
    /// Sin notificación: pending para no-admin, o estado terminal/desconocido.
    case ignore
}

enum MemberChangeNotificationLogic {
    /// Clasifica un SplitMember **nuevo** (insert remoto) según su estado y si el
    /// current user es admin del grupo.
    /// - pending + admin → `.pendingRequestForAdmin`
    /// - active / status ausente o desconocido → `.joined` (el modelo los
    ///   materializa como `.active`; notificar es coherente con la UI)
    /// - pending + no-admin / rejected / left / removed → `.ignore`
    static func classifyNewMember(rawStatus: String?, isCurrentUserAdmin: Bool) -> MemberChangeNotificationKind {
        switch SplitMemberStatus(rawValue: rawStatus ?? "") {
        case .pendingApproval:
            return isCurrentUserAdmin ? .pendingRequestForAdmin : .ignore
        case .rejected, .left, .removed:
            return .ignore
        case .active, .none:
            // `.none` cubre status ausente o rawValue desconocido. El resto del
            // sistema (CKRecordTranslator, SplitMember.memberStatus) materializa
            // ese record como `.active` → notificamos "se unió" para no divergir
            // de lo que el usuario ve en la lista, y porque un re-fetch del mismo
            // record no re-clasifica (`existingMemberIDs` ya lo contiene).
            return .joined
        }
    }
}

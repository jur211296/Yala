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
//  2026-07-11 (bug "Jür se unió al grupo"): en el PRIMER import de una zona
//  recién unida, `existingMemberIDs` está vacío → todos los members
//  preexistentes (incluido el owner) clasificaban como "nuevos" y el invitado
//  recibía notifs espurias. Se añaden dos guards previos: autoexclusión por
//  identidad (jamás notificar al usuario sobre sí mismo) y baseline de zona
//  (durante el import inicial se suprime TODO — joined Y pending; los pending
//  históricos son ruido de import y el estado accionable sigue en la UI).
//

import Foundation

enum MemberChangeNotificationKind: Equatable {
    /// Solicitud de ingreso pendiente → notif "X quiere unirse", SOLO al admin.
    case pendingRequestForAdmin
    /// Miembro activo nuevo → notif "X se unió al grupo".
    case joined
    /// Sin notificación: pending para no-admin, estado terminal/desconocido,
    /// member del propio usuario, o import inicial de la zona.
    case ignore
}

enum MemberChangeNotificationLogic {

    /// Baseline de una zona respecto a notificaciones de membership.
    enum ZoneBaseline: Equatable {
        /// Zona asentada → clasificar normal.
        case established
        /// Import inicial en curso (o zona aún sin SplitGroup local) → suprimir.
        case initialImport
    }

    /// Ventana máxima de supresión tras el insert del SplitGroup. Auto-sana un
    /// `initialMemberImportStartedAt` colgado (didFetch perdido por kill
    /// mid-cycle): pasados 15 min las notifs se reanudan solas.
    static let initialImportWindow: TimeInterval = 15 * 60

    /// Deriva el baseline de la zona para este batch.
    /// - `groupExistsLocally == false`: red intra-batch — el member llegó ANTES
    ///   que el GroupMeta en el mismo batch ⇒ es import inicial por definición.
    /// - `importStartedAt` vigente (< window): el SplitGroup se insertó por
    ///   fetch hace poco y su primer ciclo aún no se marcó completo.
    static func zoneBaseline(
        groupExistsLocally: Bool,
        importStartedAt: Date?,
        now: Date,
        window: TimeInterval = initialImportWindow
    ) -> ZoneBaseline {
        guard groupExistsLocally else { return .initialImport }
        guard let importStartedAt else { return .established }
        return now.timeIntervalSince(importStartedAt) < window ? .initialImport : .established
    }

    /// Clasifica un SplitMember **nuevo** (insert remoto).
    /// Orden de guards:
    /// 1. Autoexclusión: el member es el propio usuario (recordIDs no vacíos e
    ///    iguales) → `.ignore` SIEMPRE. Si la identidad local no se resolvió
    ///    (cache nil/vacío) NO se excluye — el baseline cubre el caso grande.
    /// 2. Import inicial de la zona → `.ignore` para joined Y pending.
    /// 3. Clasificación por status (lógica original intacta):
    ///    - pending + admin → `.pendingRequestForAdmin`
    ///    - active / status ausente o desconocido → `.joined` (el modelo los
    ///      materializa como `.active`; notificar es coherente con la UI)
    ///    - pending + no-admin / rejected / left / removed → `.ignore`
    static func classifyNewMember(
        rawStatus: String?,
        isCurrentUserAdmin: Bool,
        memberUserRecordID: String? = nil,
        currentUserRecordID: String? = nil,
        zoneBaseline: ZoneBaseline = .established
    ) -> MemberChangeNotificationKind {
        if let memberUserRecordID, let currentUserRecordID,
           !memberUserRecordID.isEmpty, !currentUserRecordID.isEmpty,
           memberUserRecordID == currentUserRecordID
        {
            return .ignore
        }

        if zoneBaseline == .initialImport {
            return .ignore
        }

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

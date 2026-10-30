//
//  GroupServerNoticeReplacementLogic.swift
//  Yala
//
//  ¿Qué aviso genérico del servidor sustituye el aviso rico de actividad de un grupo? Ticket
//  `notices-come-out-one-after-another-by-priority`.
//
//  El gateway manda un push con alerta y `content-available` (`gateway/src/groups/routes.ts`, `fanOutGroupPush`): si iOS
//  despierta a la app, el aviso local con quién, qué y cuánto «reemplaza» el texto genérico. Hasta hoy solo se retiraba el
//  de membresía (`GroupApprovalNoticeLogic`); los de actividad y de solicitud de entrada se quedaban, y la persona veía dos
//  avisos del mismo gasto.
//
//  Solo se retira el genérico del MISMO grupo: su `deepLink` es `groups/<group_id del servidor>`, que en local es
//  `SplitGroup.cloudKitZoneID` (`SplitGroup-<uuid>`). El de varios grupos (`deepLink` = `groups`) no se toca: el aviso rico
//  habla de uno, y quitarlo dejaría a los demás sin aviso.
//
//  **Y solo el RECIENTE** (`freshWindow`, review adversarial del 2026-10-30): el aviso rico cuenta los cambios de ESTA tanda,
//  y el del grupo está limitado a uno cada 5 min. Un genérico que llegó durante ese límite —o cuyo cambio descartó el filtro
//  de participación— no tuvo su aviso rico, y retirarlo con el siguiente lo borraba sin que nadie lo sustituyera. El
//  genérico que esta tanda sustituye es el push que despertó a la app para bajarla: llegó segundos antes. Con un pull lento
//  se queda alguno de más; se prefiere avisar de más que de menos.
//

import Foundation

enum GroupServerNoticeReplacementLogic {

    /// Las `loc-key` de los dos genéricos que el aviso rico de actividad cubre: gastos/liquidaciones/miembros y solicitudes.
    static let replacedLocKeys: Set<String> = [
        "notifications.groups.remoteActivity",
        "notifications.groups.remotePendingRequest",
    ]

    /// Los `deepLink` con que el servidor y la app nombran a un grupo. El servidor usa el `group_id` tal cual
    /// (`SplitGroup-<uuid>`); se acepta también el `id` local por si un grupo de la era CloudKit los tiene iguales.
    static func groupLinks(groupID: UUID, zoneID: String?) -> Set<String> {
        var links: Set<String> = ["groups/\(groupID.uuidString)"]
        if let zoneID, !zoneID.isEmpty { links.insert("groups/\(zoneID)") }
        return links
    }

    /// Cuánto puede llevar entregado un genérico para contar como el de esta tanda.
    static let freshWindow: TimeInterval = 120

    /// ¿Es este aviso entregado un genérico del servidor sobre uno de esos grupos, y de esta tanda?
    static func isReplacedServerNotice(
        _ userInfo: [AnyHashable: Any], deliveredAt: Date, now: Date, groupLinks: Set<String>
    ) -> Bool {
        guard now.timeIntervalSince(deliveredAt) <= freshWindow else { return false }
        return isServerNotice(userInfo, groupLinks: groupLinks)
    }

    /// ¿Es un genérico del servidor (actividad o solicitud) sobre uno de esos grupos, sin mirar cuándo llegó?
    static func isServerNotice(_ userInfo: [AnyHashable: Any], groupLinks: Set<String>) -> Bool {
        guard let aps = userInfo["aps"] as? [String: Any],
              let alert = aps["alert"] as? [String: Any],
              let locKey = alert["loc-key"] as? String,
              replacedLocKeys.contains(locKey),
              let deepLink = userInfo["deepLink"] as? String else { return false }
        return groupLinks.contains(deepLink)
    }
}

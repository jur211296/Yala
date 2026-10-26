//
//  GroupsPushKind.swift
//  Yala
//
//  Qué hace la app con un push del gateway (`userInfo["yala"]["kind"]`). Card `x6p9`, ticket
//  `push-client-ignores-yala-kind`: hasta el 2026-10-25 cualquier push con la clave `yala` disparaba un ciclo de
//  sync de Grupos, también el de depuración (`g0-spike`) o uno que una versión futura del gateway invente.
//
//  **Contrato con el gateway**: los casos son los de `GROUP_PUSH_KINDS` (`gateway/src/groups/routes.ts`), y
//  `GroupsPushKindContractTests` lee ese bloque. Uno nuevo se añade en los dos lados el mismo día.
//

import Foundation

nonisolated enum GroupsPushKind: String, CaseIterable, Sendable {
    /// Actividad en un grupo: gastos, liquidaciones, cambios del grupo.
    case groupsSync = "groups-sync"
    /// Alguien pide entrar en un grupo tuyo, o te respondieron. El pendiente o el alta llegan por el pull.
    case groupsMembership = "groups-membership"

    /// Si el push pide bajar los cambios de Grupos. Los dos kinds conocidos, sí; uno desconocido (el de
    /// depuración, o uno nuevo que esta versión no entiende) no: un ciclo de sync que nadie pidió.
    static func triggersGroupsSync(kind: String?) -> Bool {
        guard let kind, let known = GroupsPushKind(rawValue: kind) else { return false }
        switch known {
        case .groupsSync, .groupsMembership: return true
        }
    }
}

/// Resuelve el destino de un enlace a un grupo (`groups/<id>`). Llegan dos formas, y las dos son buenas:
/// - el `id` local del grupo (`uuidString`): los avisos que compone la app y las ventanas nuevas;
/// - el `group_id` del servidor (`SplitGroup-<uuid>`): el push del gateway (card `x6p9`) y el atajo del puente de
///   gastos. En un grupo que llegó por el canal backend el `id` local NO coincide con ese uuid
///   (`SplitGroupZone.zoneName`), así que se busca por `cloudKitZoneID`, nunca pelando el prefijo.
nonisolated enum GroupDeepLinkMatch {
    static func matches(pendingID: String, groupID: UUID, zoneID: String) -> Bool {
        if let uuid = UUID(uuidString: pendingID) { return uuid == groupID }
        return !zoneID.isEmpty && zoneID == pendingID
    }
}

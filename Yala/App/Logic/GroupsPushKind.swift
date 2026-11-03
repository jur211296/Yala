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

/// Card th4n: un grupo abierto desde su aviso, para el detalle de esa ventana (`SceneNavigation.groupOpenedFromNotification`).
nonisolated struct GroupNotificationEntry: Equatable, Sendable {
    let groupID: UUID
    let token = UUID()
}

/// Card th4n: el aviso de grupo que se acaba de tocar. `NotificationService.routeTap` lo apunta antes de navegar y
/// `GroupsContainerView` lo consume al abrir el grupo: así distingue una apertura desde el aviso de las otras que pasan por
/// el mismo `.navigate(.groupDetail)` (crear un gasto de grupo desde Nuevo registro), que no deben esperar a la red.
@MainActor
final class GroupNotificationOpening {
    static let shared = GroupNotificationOpening()

    /// Lo que dura la marca: si el grupo no llega a abrirse en ese rato (el toque se perdió, el grupo no está), una
    /// apertura posterior del mismo grupo por otro camino no se toma por la del aviso.
    static let lifetime: TimeInterval = 60

    private var pending: (id: String, at: Date)?

    func request(_ pendingID: String, now: Date = .now) { pending = (pendingID, now) }

    /// `true` (y lo olvida) si el `pendingGroupID` que se consume es el del aviso tocado y la marca sigue viva.
    func consume(matching pendingID: String, now: Date = .now) -> Bool {
        guard let pending, pending.id == pendingID else { return false }
        self.pending = nil
        return now.timeIntervalSince(pending.at) <= Self.lifetime
    }
}

//
//  GroupBackendIdentityLogic.swift
//  Yala
//
//  Lógica PURA de identidad del canal de sync de GRUPOS → backend (incremento G3, DARK). Sin estado,
//  sin `ModelContext`, sin CloudKit → testeable en aislamiento total. `nonisolated`: se consume tanto
//  desde el apply `@MainActor` de `GroupsSyncClient` como desde `refreshCurrentUserFlags` (main actor),
//  pero no toca estado del actor.
//
//  Provee dos primitivas del canal backend, PARALELAS a la identidad CloudKit vigente (no la reemplazan;
//  el path CloudKit por `cloudKitUserRecordID`/record-name sigue vivo como fallback para members mixtos):
//
//   1. `deterministicMemberID(groupID:memberKey:)` — id LOCAL estable de un `SplitMember` nacido del
//      backend, derivado del `group_id` + `member_key` del wire. Usa un NAMESPACE PROPIO
//      (`memberIDNamespace`), DISTINTO del namespace `"SplitMember"` del path CloudKit
//      (`GroupUserIdentityService.deterministicMemberID`) → para los MISMOS inputs produce un UUID
//      distinto, por diseño: el canal backend no reusa la identidad CloudKit, la re-deriva de su propia
//      autoridad (el `member_key` del server).
//
//   2. `isCurrentUser(memberUserID:currentUserID:)` — ¿este member soy yo? Comparación del auth `uid`
//      (`SplitMember.userID` local vs `CloudAuthService.currentUserID`), lowercase y nil-safe: un lado
//      `nil`/vacío NUNCA matchea (un member sin `userID` cae al path CloudKit, no a un falso match).
//

import Foundation

nonisolated enum GroupBackendIdentityLogic {

    /// Namespace del id determinista de member del canal BACKEND. Distinto de `"SplitMember"` (namespace
    /// del path CloudKit) a propósito — garantiza que el UUID derivado JAMÁS colisione con el CloudKit
    /// para los mismos inputs (el canal re-deriva su identidad de la autoridad del server, no la reusa).
    static let memberIDNamespace = "SplitMemberBackend"

    /// UUID LOCAL estable de un `SplitMember` nacido del backend. `= SHA256("SplitMemberBackend:{groupID}:
    /// {memberKey}")` truncado a 16 bytes. Determinista: el mismo par `(groupID, memberKey)` → el mismo
    /// UUID en todos los devices → dedup del member sin depender de la identidad CloudKit.
    static func deterministicMemberID(groupID: String, memberKey: String) -> UUID {
        GroupUserIdentityService.deterministicUUID(
            namespace: memberIDNamespace, name: "\(groupID):\(memberKey)")
    }

    /// ¿El member (por su auth `uid` del backend) es el usuario de la sesión actual? Lowercase + nil-safe:
    /// cualquier lado `nil` o vacío ⇒ `false` (jamás un falso positivo por ausencia de identidad).
    static func isCurrentUser(memberUserID: String?, currentUserID: String?) -> Bool {
        guard let memberUserID, let currentUserID,
              !memberUserID.isEmpty, !currentUserID.isEmpty else { return false }
        return memberUserID.lowercased() == currentUserID.lowercased()
    }

    /// Pertenencia de un GRUPO al canal BACKEND en sentido AMPLIO: `isBackendGroup` (dueño backend,
    /// born-remote o adoptado) **o** `movedToBackendAt != nil` (copia CONGELADA — el marcador viajó por
    /// CloudKit y el miembro aún no re-joineó). D1 nombra AMBAS formas.
    ///
    /// Vivía en `GroupsIdentityPurgeGate` (su primer consumidor). Se mudó aquí porque la Fase 3 borra ese
    /// fichero entero con el transporte CloudKit y el predicado es del canal NUEVO: lo consultan tanto la
    /// purga por cambio de identidad como la resolución de identidad de `refreshCurrentUserFlags`.
    ///
    /// OJO: este predicado es el de RETENCIÓN/PERTENENCIA. NO es el predicado correcto para decidir si un
    /// grupo puede escribir a CKSyncEngine: ahí hay que usar `isBackendGroup || isMigratedFrozen`
    /// (`GroupFreezeLogic.isFrozen`), porque su mitigación #9 trata a propósito como NO congelado al owner
    /// tras un reinstall (`movedToBackendAt != nil && ckSystemFieldsData != nil`) y ampliar el predicado
    /// crudo le quitaría su último camino de subida.
    static func belongsToBackendChannel(isBackendGroup: Bool, movedToBackendAt: Date?) -> Bool {
        isBackendGroup || movedToBackendAt != nil
    }

    /// ¿Una op de MEMBRESÍA de esta ZONA va por el canal BACKEND (RPC) en vez de CKSyncEngine?
    ///
    /// **La unidad es la ZONA y no la fila**, por la misma razón que en `GroupZoneCacheGate` y
    /// `GroupsIdentityPurgeGate`: existen `SplitGroup` distintos con el mismo `cloudKitZoneID`
    /// (`SplitGroupDeduplicationService`) y el duplicado puede ser MIXTO —la adopción de
    /// `GroupsSyncClient.fetchSplitGroup` voltea una fila arbitraria, `fetchLimit = 1` SIN `sortBy`—, así que
    /// decidir por fila enruta el MISMO grupo por un canal u otro según cuál se tenga en la mano. Criterio
    /// ANY-row: si alguna fila de la zona es del canal backend, la zona lo es.
    ///
    /// `inHandIsBackendGroup` va SEPARADO de `rowsInZone` y cuenta SIEMPRE, a propósito: es lo que hace que el
    /// caller degrade al comportamiento ANTERIOR —la fila en mano— cuando no pudo enumerar la zona (el fetch
    /// lanzó, o el objeto aún no está persistido). Nunca peor que decidir por fila; con una sola fila,
    /// byte-idéntico.
    ///
    /// **El predicado por fila es `isBackendGroup` a secas y NO `belongsToBackendChannel`**, que es el de
    /// RETENCIÓN. Una copia CONGELADA (`movedToBackendAt != nil`, `isBackendGroup == false`) es un grupo cuyo
    /// miembro **aún no re-joineó** ⇒ no tiene membresía server-side ⇒ `leave_group` respondería
    /// `member_not_found`, que `GroupService.batchLeave` trata como ÉXITO y salta el `leaveShare` de CloudKit:
    /// ampliar el predicado dejaría al usuario dentro del CKShare del que creía haber salido.
    static func membershipRoutesToBackend(
        flagEnabled: Bool, inHandIsBackendGroup: Bool, rowsInZone: [Bool]
    ) -> Bool {
        flagEnabled && (inHandIsBackendGroup || rowsInZone.contains(true))
    }

    /// R10 (G6-2): ¿este `member_key` es de un member LEGACY del mundo CloudKit (grupo migrado) en vez de un
    /// `sub` nacido del backend? El `sub` del auth SIEMPRE parsea como UUID (`v_uid::text`, lowercase-hyphenated);
    /// un recordName de CloudKit (`"_…"`) JAMÁS parsea. El discriminador decide en qué NAMESPACE derivar el id
    /// LOCAL del `SplitMember` born-remote: legacy → namespace CloudKit-era `"SplitMember"` (byte-idéntico al id
    /// del owner en `GroupService`, preserva la identidad del mundo CloudKit); backend → namespace propio del
    /// canal (`deterministicMemberID`).
    static func isLegacyMemberKey(_ key: String) -> Bool {
        // Guard del sentinel = DEFENSIVO (verificado en DDL: `groups_forget_user` anonimiza `display_name`,
        // JAMÁS `member_key` — el sentinel no llega por este campo). Vacío y sentinel NUNCA son legacy.
        guard !key.isEmpty, key != SplitMember.deletedUserSentinel else { return false }
        return UUID(uuidString: key) == nil
    }
}

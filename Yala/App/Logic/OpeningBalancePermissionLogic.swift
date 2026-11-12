//
//  OpeningBalancePermissionLogic.swift
//  Yala
//
//  Card yd2w (2026-10-31) · quién gestiona los saldos iniciales de un grupo: el dueño, o cualquier admin activo.
//
//  Hasta ese día solo el dueño (`group.isOwner`), en la UI y en `GroupExpenseService`: en el grupo Matri Jürgen es admin
//  y la opción ni aparecía. El servidor nunca lo exigió (las políticas de `split_expenses`/`split_shares` piden un miembro
//  activo; medido en staging y producción ese día).
//
//  Una sola decisión para los dos lados a propósito: si la UI pinta el botón y el servicio lo rechaza, la persona ve algo
//  que no funciona. El dueño conserva el permiso aunque su fila no resuelva o no diga «admin», así nadie pierde lo que
//  tenía. «Admin» es `SplitMember.isAdmin` del miembro propio RESUELTO (`resolveCurrentUserMember`), el mismo criterio que
//  `GroupDetailViewModel.isCurrentUserAdmin` usa para el resto de acciones de admin.
//

//  Card hfhs (2026-11-02) · en un grupo del BACKEND la app decide como el servidor. El trigger `opening_balance_guard`
//  (g27_01) deja pasar al dueño o a quien `is_group_admin` reconoce: CUALQUIER fila de `group_members` con su `user_id`,
//  activa y con `role = 'admin'`. La fila canónica de la app puede ser otra: en un grupo migrado, la fila heredada de la
//  era CloudKit lleva `isCurrentUser` encendido y es la que `resolveCurrentUserMember` elige primero, pero en el servidor
//  sigue sin reclamar (`user_id` NULL) si la persona entró por un enlace en vez de reclamarla. Medido en staging el
//  2026-11-02 (`qa/cloud/g29_01-staging-probe.sh`, casos 9 y 10): con la heredada admin sin reclamar y la suya `member`,
//  el servidor rechaza su saldo con `yala_opening_balance_not_admin`; reclamándola, lo aplica. La app le enseñaba el
//  botón igual en los dos casos.
//

nonisolated enum OpeningBalancePermissionLogic {
    static func canManage(groupIsOwner: Bool, currentMemberIsActive: Bool, currentMemberIsAdmin: Bool) -> Bool {
        groupIsOwner || (currentMemberIsActive && currentMemberIsAdmin)
    }

    /// Una fila de miembro tal como la mira el servidor.
    struct MemberRow: Equatable {
        let userID: String?
        let isActive: Bool
        let role: String
    }

    /// La decisión completa (card hfhs). En un grupo del backend con sesión, la de `is_group_admin`: alguna fila con mi
    /// `user_id`, activa y `admin` (el `role` tal cual: `SplitMember.isAdmin` suma `isGroupOwner`, que el servidor no mira;
    /// el dueño ya entra por `groupIsOwner`, que viene de `owner_user_id`). Sin sesión, o en un grupo que no es del
    /// backend, la de siempre con la fila canónica: ahí no hay servidor que contradiga.
    static func canManage(
        groupIsOwner: Bool,
        isBackendGroup: Bool,
        currentUserID: String?,
        members: [MemberRow],
        canonicalIsActive: Bool,
        canonicalIsAdmin: Bool
    ) -> Bool {
        if groupIsOwner { return true }
        if isBackendGroup, let me = currentUserID?.lowercased(), !me.isEmpty {
            return members.contains { $0.userID?.lowercased() == me && $0.isActive && $0.role == "admin" }
        }
        return canManage(groupIsOwner: false, currentMemberIsActive: canonicalIsActive, currentMemberIsAdmin: canonicalIsAdmin)
    }

    /// La misma decisión, con los modelos y la sesión del proceso. La comparten el detalle del grupo (el botón) y
    /// `GroupExpenseService` (el guardado): si divergieran, la UI enseñaría algo que el guardado rechaza.
    @MainActor
    static func canManage(group: SplitGroup, members: [SplitMember]) -> Bool {
        let canonical = GroupExpenseService.resolveCurrentUserMember(from: members)
        return canManage(
            groupIsOwner: group.isOwner,
            isBackendGroup: group.isBackendGroup,
            currentUserID: CloudSyncFlags.groupsBackendEnabled ? CloudAuthService.shared.currentUserID : nil,
            members: members.map { MemberRow(userID: $0.userID, isActive: $0.isActive, role: $0.role) },
            canonicalIsActive: canonical?.isActive ?? false,
            canonicalIsAdmin: canonical?.isAdmin ?? false)
    }
}

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

nonisolated enum OpeningBalancePermissionLogic {
    static func canManage(groupIsOwner: Bool, currentMemberIsActive: Bool, currentMemberIsAdmin: Bool) -> Bool {
        groupIsOwner || (currentMemberIsActive && currentMemberIsAdmin)
    }
}

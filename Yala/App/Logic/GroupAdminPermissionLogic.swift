//
//  GroupAdminPermissionLogic.swift
//  Yala
//
//  Card 0vbn (2026-11-03) · ¿soy admin de este grupo? La misma respuesta para el menú de un miembro, los ajustes del
//  grupo y el guardado (`GroupService.requireCurrentUserAdmin`).
//
//  En un grupo del BACKEND todas las acciones de admin las decide el servidor con `is_group_admin`: CUALQUIER fila de
//  `group_members` con mi `user_id`, activa y con `role = 'admin'` (`approve_member`, `remove_member`, `set_member_role`,
//  `revoke_invite`, la política de UPDATE de `split_groups`). Hasta esta card la app miraba solo la fila CANÓNICA
//  (`resolveCurrentUserMember`), y en un grupo migrado esa puede ser la heredada de la era CloudKit, sin reclamar en el
//  servidor (`user_id` NULL). Con la heredada `member` y mi fila reclamada `admin`, el servidor aceptaba quitar a alguien,
//  cambiarle el rol o editar su saldo y el menú no lo ofrecía; al revés (la heredada `admin`, la mía `member`), el menú
//  ofrecía lo que el servidor rechaza. Es la decisión que la card hfhs ya llevó a los saldos iniciales
//  (`OpeningBalancePermissionLogic`), aplicada al resto.
//
//  Fuera del backend, o sin sesión, no hay servidor que contradiga: la de siempre, con la fila canónica, y el dueño sin
//  fila propia conserva lo suyo (el respaldo que ya tenía el guardado).
//

nonisolated enum GroupAdminPermissionLogic {
    typealias MemberRow = OpeningBalancePermissionLogic.MemberRow

    /// - Parameters:
    ///   - canonical: la fila canónica (`isActive`, `isAdmin` de `SplitMember`, que suma `isGroupOwner`), o `nil` si no
    ///     resuelve ninguna.
    static func isAdmin(
        groupIsOwner: Bool,
        isBackendGroup: Bool,
        currentUserID: String?,
        members: [MemberRow],
        canonical: (isActive: Bool, isAdmin: Bool)?
    ) -> Bool {
        if isBackendGroup, let me = currentUserID?.lowercased(), !me.isEmpty {
            let mine = members.filter { $0.userID?.lowercased() == me }
            // Ninguna fila mía bajó todavía (el grupo recién creado antes del primer pull): el dueño conserva el admin,
            // como en el guardado de siempre. Con alguna fila mía, mandan ellas.
            if mine.isEmpty { return groupIsOwner }
            // `role` tal cual: `SplitMember.isAdmin` suma `isGroupOwner`, que el servidor no mira.
            return mine.contains { $0.isActive && $0.role == "admin" }
        }
        guard let canonical else { return groupIsOwner }
        return canonical.isActive && canonical.isAdmin
    }

    /// La misma decisión, con los modelos y la sesión del proceso.
    @MainActor
    static func isAdmin(group: SplitGroup, members: [SplitMember]) -> Bool {
        let canonical = GroupExpenseService.resolveCurrentUserMember(from: members)
        return isAdmin(
            groupIsOwner: group.isOwner,
            isBackendGroup: group.isBackendGroup,
            currentUserID: CloudSyncFlags.groupsBackendEnabled ? CloudAuthService.shared.currentUserID : nil,
            members: members.map { MemberRow(userID: $0.userID, isActive: $0.isActive, role: $0.role) },
            canonical: canonical.map { (isActive: $0.isActive, isAdmin: $0.isAdmin) })
    }
}

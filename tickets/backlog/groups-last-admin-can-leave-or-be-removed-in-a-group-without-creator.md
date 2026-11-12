---
id: groups-last-admin-can-leave-or-be-removed-in-a-group-without-creator
status: backlog
priority: medium
area: "groups, backend"
created: 2026-10-28
updated: 2026-10-28
source: "hallazgo de la card y1cd (2026-10-28), medido en supabase-groups-staging.ddl"
---

# En un grupo sin creador, el último admin puede irse o ser expulsado y el grupo se queda sin admin

`leave_group` solo impide salir al dueño (`yala_owner_cannot_leave`) y `remove_member` solo protege al dueño. En un grupo
«sin creador» (`owner_user_id` null: migrados, o cuyo dueño se borró de auth sin pasar por `groups_forget_user`), el último
admin activo con cuenta puede irse, o un admin expulsar al otro, y nadie queda para aprobar ni invitar. Mismo molde que
g25_01: promover al heredero (o rechazar con `yala_last_admin`, como `set_member_role`). Decidir cuál.

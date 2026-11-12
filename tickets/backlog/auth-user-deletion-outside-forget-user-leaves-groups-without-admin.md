---
id: auth-user-deletion-outside-forget-user-leaves-groups-without-admin
status: backlog
priority: medium
area: "groups, backend"
created: 2026-10-28
updated: 2026-10-28
source: "hallazgo de la card y1cd (2026-10-28), medido en supabase-groups-staging.ddl"
---

# Borrar un usuario de auth sin `groups_forget_user` deja admins sin cuenta y grupos sin creador

`split_groups.owner_user_id` y `group_members.user_id` referencian `auth.users` con `on delete set null`. Un borrado en auth
que no pase por `groups_forget_user` (consola, un fallo a medias del borrado de cuenta) vacía los dos sin tocar rol ni
estado ni HLC: quedan admins «activos» sin cuenta, grupos sin creador y ningún heredero promovido. Es el camino que fabrica
los grupos sin creador de los que habla el ticket hermano. Opciones: trigger `before delete` en auth que llame a la misma
lógica, o un barrido.

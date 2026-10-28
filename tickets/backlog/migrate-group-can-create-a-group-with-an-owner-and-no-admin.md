---
id: migrate-group-can-create-a-group-with-an-owner-and-no-admin
status: backlog
priority: low
area: "groups, backend"
created: 2026-10-28
updated: 2026-10-28
source: "hallazgo de la card y1cd (2026-10-28), medido en supabase-groups-staging.ddl"
---

# `migrate_group` puede crear un grupo con dueño y sin ningún admin con cuenta

`migrate_group` pone al migrador como dueño (`owner_user_id = v_uid`) pero toma el `role` de cada miembro del payload: no
comprueba que la fila del dueño sea admin. Un grupo migrado desde CloudKit puede nacer sin admin usable. Solo afecta a
grupos de la era CloudKit que aún no migraron.

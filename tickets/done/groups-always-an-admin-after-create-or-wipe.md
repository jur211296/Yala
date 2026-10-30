---
id: groups-always-an-admin-after-create-or-wipe
status: done
priority: high
area: "groups, backend, gateway"
created: 2026-10-28
updated: 2026-10-28
owner: jurgen
source: "card tablero-grupos-siempre-un-admin-tras-crear-o-wip-y1cd (Jürgen 2026-10-27: Matri en el teléfono de Pia)"
---

# Grupos: siempre un admin, y quien hereda un grupo puede invitar

## Qué pasaba

El 2026-10-27 Pia veía «Matri» y no podía invitar a Jürgen. En el servidor ella ya era dueña y admin: al borrarse la cuenta
de Jürgen, `groups_forget_user` le pasó la propiedad y la hizo admin, y dejó el miembro de Jürgen anonimizado (`removed`,
`user_id` null). El fallo estaba en el teléfono: «Invitar» exige `group.isOwner`, un dato LOCAL que el pull no traía
(`owner_user_id` no está en el manifest), así que la heredera nunca se enteraba de que era dueña.

## Qué cambia

1. **El pull de Grupos dice de qué grupos eres dueño** (`owned_groups`, `gateway/src/groups/routes.ts`) y la app corrige con
   eso `isOwner` del grupo e `isGroupOwner` del miembro propio en cada página (`GroupsSyncClient.reconcileOwnership`). Vale
   en los dos sentidos: quien hereda pasa a dueño y quien cede deja de serlo. Un Worker que aún no manda el campo no cambia
   nada. Con eso, tras un borrado de cuenta o un «Empezar de cero», el dueño que queda puede invitar sin fricción y quien
   vuelve entra por el enlace (`join_group` ya re-admite al que salió, como pendiente de aprobación).
2. **`groups_forget_user` ya no deja un grupo vivo sin admin con cuenta** (`qa/cloud/g25_01_forget_user_keeps_an_admin.sql`):
   antes de anonimizar, en cada grupo donde quien se borra era el último admin activo con cuenta, promueve a admin al
   heredero con el criterio de siempre. La respuesta gana `admins_promoted`.
3. **Crear un grupo** ya dejaba al creador como admin activo con cuenta (servidor) y dueño (cliente); ahora el pull lo
   reafirma en cada página.

## Qué hay que desplegar, y en qué orden (Jürgen)

1. **Staging** (`fostjbbwstyuunmmefuk`): pega `qa/cloud/g25_01_forget_user_keeps_an_admin.sql` en el *SQL Editor*. Lleva
   guarda por md5 del cuerpo de partida (`4cd0a3cb…`): si no casa, para sin tocar nada. Marcha atrás:
   `qa/cloud/g25_01_rollback.sql`.
2. **Worker de staging**: `cd gateway && npm ci && npm run deploy:staging` desde `2.2` con este PR mergeado (trae
   `owned_groups` en el pull y `groupsManifestVersion` en `/config`).
3. **Producción** (`kefvaiymtgytemwbltlz`): lo mismo que el paso 1.
4. **Worker de producción**: `npm run deploy:production`.

El orden entre el SQL y el Worker da igual: son independientes. La app tolera el Worker viejo.

## Guion de QA (Yala Dev contra staging, dos teléfonos o teléfono + simulador)

1. Con la cuenta A crea un grupo «QA dueño» e invita a la cuenta B; apruébala.
2. Con A, en Ajustes › Tu cuenta, **elimina la cuenta** de la nube.
3. En el teléfono de B, abre Grupos y espera a que sincronice (o tira para refrescar). En «QA dueño» → Miembros tiene que
   salir **«Invitar»**: B ya es dueña. Antes de este cambio no salía.
4. Con B, genera el enlace e invita a una cuenta nueva (o a A recreada); al aceptarlo, B la aprueba.

## Probado antes de desplegar

- `bash qa/cloud/g25_01-local-test.sh`: Postgres desechable con el DDL real, 63 comprobaciones en 13 bloques y 5 mutantes
  muertos (el caso del grupo sin creador cae sin el paso nuevo).
- `gateway/test/groups.ownedGroups.test.ts` (4 casos) y `YalaTests/CloudSync/GroupsOwnershipFromPullTests` (6 casos:
  propiedad heredada, cedida, Worker viejo, grupo fuera de memberships, página ociosa y decodificación).

Review adversarial (2026-10-28): con sesión, el miembro propio se casa SOLO por su `sub` (la fila de otra cuenta que estuvo
antes en el teléfono puede conservar `isCurrentUser`). Residual de g25_01: el paso nuevo lee sin candado, como el loop1; un
admin que se quita el rol a la vez puede dejar el grupo sin ninguno (anotado en la cabecera de la migración).

Cerrado en el barrido de QA 2026-10-30: criterio estricto (filtro doble); motivo y evidencia en docs/qa/tanda-qa-jurgen-2.2-barrido-2026-10-30.md.

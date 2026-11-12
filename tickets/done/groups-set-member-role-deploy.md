---
id: groups-set-member-role-deploy
status: done
priority: high
area: "groups, backend, gateway"
created: 2026-10-21
updated: 2026-10-22
owner: jurgen
source: "lote decidido UX 2.2 · grupos administrar (L19-3, D2), encargo 2026-10-21-lote-decidido-2-2-12-grupos-administrar"
---

# Aplicar `g22_01` (cambiar el rol de un miembro) en staging y producción y desplegar el Worker

## Qué gana el usuario

En un grupo de la nube, un administrador puede hacer administrador a otro miembro o quitárselo. Hasta este cambio la app
no lo ofrecía en esos grupos: el servidor no tenía cómo cambiar un rol.

## Qué hay que desplegar, y en qué orden

1. **El DDL** `qa/cloud/g22_01_set_member_role.sql`: una función nueva, `set_member_role`, y `remove_member` /
   `leave_group` redefinidas para que quien sale del grupo deje de ser admin (y no lo vuelva a ser al re-entrar). No
   toca tablas. Lleva una guarda por md5 sobre esos dos cuerpos: el paso 1 del runbook los mide antes, y si no son los
   esperados se para.
2. **El Worker** con `set_member_role` en la allowlist (`gateway/src/groups/rpc.ts`).
3. **La app** que lo llama (la build 2.2 con este PR).

Al revés no se rompe nada ni se escribe a medias, pero el botón falla: con la app nueva y el Worker viejo, hacer o
quitar administrador da el error genérico («no se pudo, vuelve a intentarlo»), porque el Worker contesta 404
`unknown rpc`.

## Los pasos

Están, con los comandos, en `docs/RUNBOOK-staging-ddl.md`, sección «`g22_01_set_member_role.sql`». En corto:

1. **Staging** (`fostjbbwstyuunmmefuk`): comprobar que la función no existe → pegar el fichero en el *SQL Editor* →
   tiene que salir `g22_01 OK · set_member_role(text, text, text) creada, solo authenticated la ejecuta`.
2. **Worker de staging**: `cd gateway && npm ci && npm run deploy:staging` desde `2.2` con el PR mergeado.
3. **Producción** (`kefvaiymtgytemwbltlz`): lo mismo que el paso 1.
4. **Worker de producción**: `npm run deploy:production`. Apuntar el `Current Version ID` y el anterior.

## Qué verificar después

- En los dos entornos, la consulta del runbook devuelve `set_member_role` con `prosecdef = true` y
  `search_path=public`, y `has_function_privilege('anon', …)` da `false`.
- Con un build de `Yala Dev` contra staging, en un grupo de la nube con dos personas: hacer administrador al otro, y
  quitárselo después. En el otro teléfono, tras sincronizar, la insignia cambia.
- Que el creador no pierde el admin: desde el teléfono del otro administrador, quitarle el admin al creador
  sale «Quien creó el grupo siempre es administrador: no se le puede quitar el rol.» y el creador sigue siéndolo. Es el residual de abajo.
- Que salir deja de ser admin: un administrador que sale del grupo y vuelve a entrar por el enlace queda, al aprobarlo,
  como miembro.
- `npx wrangler tail` (con `--env production` en producción) no enseña `[groups-rpc] set_member_role upstream 404`:
  si sale, el Worker está desplegado y el DDL no.

## Probado antes de desplegar

- Banco local `bash qa/cloud/g22_01-local-test.sh`, Postgres 17 desechable con el DDL real de Grupos: 80
  comprobaciones (cada regla con su control, la guarda por md5, idempotencia, grants, las dos carreras, expulsar / salir /
  re-entrar y aprobar con `join_group` y `approve_member` reales, y la marcha atrás). Y ocho mutantes, cada uno cazado
  por su propio caso: sin la regla del creador, sin la del hueco, sin la del último admin, la del último admin contando
  huecos, sin cada uno de los dos candados y sin cada uno de los dos resets de rol.
- Gateway: `npm test` entero en verde (los goldens contra staging se saltan sin credenciales).

## Residuales conocidos

- En un grupo de la nube, el teléfono de un administrador que no es el creador no sabe quién lo creó (`isGroupOwner`
  solo lo pone el teléfono del creador; el pull no lo trae), así que le ofrece «Quitar como administrador» también al
  creador. El servidor lo rechaza (`yala_cannot_change_owner_role`) y no cambia nada; la app lo explica con su texto propio.
- Carrera con `transfer_group_ownership` / `groups_forget_user`: eligen al heredero («admin primero») leyendo sin
  candado y solo le escriben `role = 'admin'` si al leer no lo era. Si a la vez alguien le quita el admin a ese
  heredero, el grupo puede quedar con un creador que no es admin.
- Quien salió de un grupo siendo admin ANTES de esta migración conserva `role = 'admin'` en su fila; si re-entra y lo
  aprueban, vuelve a ser admin. No hay backfill: reescribir esas filas movería el HLC de filas ajenas.
- `leave_group` no mira si quedan admins: un admin que sale mientras otro se quita el admin puede dejar el grupo sin
  admins (pasaba ya antes).

## Marcha atrás

`qa/cloud/g22_01_rollback.sql` borra la función y devuelve `remove_member` / `leave_group` a su cuerpo anterior
(idempotente, con guarda). Antes, volver al Worker anterior
(`npx wrangler rollback <id>`): con el Worker nuevo y sin la función, el botón da el error genérico.

## Desplegado (2026-10-22, Frank)

- `g22_01` aplicada en staging y producción por la API de gestión (`/database/query`, en una transacción). Medido antes
  y después en los dos: la función no existía y los md5 eran los de partida; ahora existe con `prosecdef`,
  `search_path=public`, sin `anon` y con `authenticated`, y los md5 son los nuevos.
- Worker de staging `043cdff6` → `2574d9e8`; de producción `2e2c05c4` → `9769f3fd`. Marcha atrás:
  `npx wrangler rollback 043cdff6-499b-4fb2-89b0-67476bc06c18` (staging) y
  `npx wrangler rollback 2e2c05c4-293e-43f1-92e0-baa1bf6eaed2 --env production`, y después `g22_01_rollback.sql`.
- Sonda en staging por el Worker con el usuario A: `set_member_role` → `yala_not_authorized` (llega al RPC); control con
  un RPC inventado → 404 `unknown rpc`.

## Guion para el iPhone (Jürgen)

1. Dos teléfonos con la build 2.2 (TestFlight), los dos en el mismo grupo de la nube; tú administrador.
2. En el tuyo: el grupo → Miembros → la otra persona → «Hacer administrador». En el otro teléfono, tras sincronizar, sale
   como administrador.
3. Quítaselo («Quitar como administrador»). En el otro teléfono vuelve a miembro.
4. Desde el otro teléfono (siendo admin), intenta quitarte el rol a ti, que creaste el grupo: sale «Quien creó el grupo
   siempre es administrador: no se le puede quitar el rol.» y sigues siéndolo.

Cerrado en el barrido de QA 2026-10-30: criterio estricto (filtro doble); motivo y evidencia en docs/qa/tanda-qa-jurgen-2.2-barrido-2026-10-30.md.

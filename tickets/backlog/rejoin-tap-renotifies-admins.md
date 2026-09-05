---
id: rejoin-tap-renotifies-admins
status: backlog
priority: medium
area: groups-backend
created: 2026-09-04
source: medido al diseñar el arreglo de rejected-member-cold-tap-does-nothing (2026-09-04)
---

# Volver a tocar tu propio enlace, estando ya pendiente, vuelve a avisar al admin — cada vez

## Qué pasa

Pedí entrar a un grupo y estoy esperando aprobación. Toco otra vez el enlace que me pasaron —porque
no sé si se envió, o porque me lo reenvían— y el admin del grupo **recibe otra notificación de
solicitud pendiente**. Tantas como veces toque. Para él parece que insisto; en realidad no ha pasado
nada nuevo.

Del lado de la persona que toca, todo se ve normal: no hay error, no hay aviso, no cambia nada.

## Dónde está, medido el 2026-09-04

El guardián del fan-out está escrito para evitar exactamente esto, y **su comentario promete algo que
el código no cumple**:

`gateway/src/groups/rpc.ts:242-247`

```ts
// `join_group` → avisa a QUIEN PUEDE APROBAR, y sólo si de verdad quedó pendiente. Un `rebound` o
// un re-tap del enlace de alguien ya activo no es noticia para nadie.
if (fn === "join_group") {
  if (status !== "pendingApproval") return;
  waitUntil(fanOutGroupPush(...))
```

El filtro tapa el caso `active` y **deja pasar el caso `pendingApproval`**, que es justo el del
re-tap. La causa está en qué devuelve el RPC: en su rama «ya-member»
(`docs/modo-nube/briefs/prod-promo-sql/20260903221500_g13_03_join_group_distinguishes_deleted.sql:123-126`)

```sql
if v_row.deleted = false and v_row.status in ('active', 'pendingApproval') then
  return jsonb_build_object(..., 'status', v_row.status, 'rebound', false);
```

devuelve el estado **que ya tenía**, sin cambiar nada. El gateway no puede distinguir «acaba de
quedar pendiente» de «ya estaba pendiente y no ha cambiado nada», porque el RPC no se lo dice.

## Por qué importa

Es ruido dirigido a un tercero —el admin— por una acción inocente de otra persona, y el propio
código declara por escrito que no debe ocurrir. Ese guardián existe precisamente para no ser un
grifo de push.

Alcance: **vivo en producción**, con `GROUPS_BACKEND` al 100 %.

## El arreglo

El RPC tiene que decir si hubo **transición real**, y el fan-out gatearse con eso — no con el estado
final, que es ambiguo. Dos formas:

1. Devolver un campo nuevo (`changed: true/false`, o el `previous_status`) desde las ramas del RPC, y
   en `rpc.ts` exigir `changed === true` además de `status === "pendingApproval"`.
2. Que la rama no-op devuelva un estado distinguible.

La (1) es la que no toca la semántica de `status`, que ya tiene consumidores en el cliente.

Lleva migración SQL + despliegue del Worker + promoción a producción con su verificación, por eso no
se hizo dentro del arreglo de cliente donde se descubrió.

## Relación con `rejected-member-cold-tap-does-nothing`

Es el **mismo daño por otra puerta**. Aquel se arregló en el cliente haciendo que un tap produzca
como mucho una solicitud. Éste es la defensa en profundidad del lado del servidor, y cubre además a
cualquier otro cliente (la web, o una versión antigua de la app).

**No los mezcles en un commit:** uno es cliente puro y sin despliegue; éste toca base de datos y
Worker, y necesita staging antes de producción.

## Lo que no se midió

No se ha comprobado en un dispositivo cuántos push llegan de verdad —la cadena está leída en el
código y en el SQL promovido, no observada—. Antes de arreglarlo conviene verlo una vez: dos cuentas,
solicitud pendiente, re-tocar el enlace y contar las notificaciones que le llegan al admin.

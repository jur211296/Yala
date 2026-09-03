---
id: guest-decline-has-no-screen
status: in-progress
created: 2026-08-12
updated: 2026-08-26
source: YalaWiki/Bugs/grupos-invitado-el-no-no-tiene-pantalla.md
---


# La sala de espera del invitado: el «no» no tiene pantalla y el «sí» casi no se alcanza

## El síntoma, en lenguaje de usuario

Me invitan a un grupo, toco el enlace, entro y veo **«Solicitud enviada — el admin del grupo debe
aprobarte antes de que puedas participar»**. A partir de ahí:

- **Si me rechazan**: el grupo simplemente **desaparece de mi lista**. Sin aviso, sin banner, sin
  explicación. Parece un fallo de la app.
- **Mientras espero**: veo el grupo y veo quién está dentro, pero **ni un solo gasto**. Nadie me dice que
  eso es normal — el copy habla de «participar», no de «ver».
- **Si me aprueban**: la pantalla de «¡Todo listo!» prácticamente no la ve nadie.

## Lo medido

### 1 · El rechazo existe en el servidor y no tiene superficie en el cliente

`remove_member` (`supabase-groups-staging.ddl:566`) hace, en `:596`:

```sql
v_new := case when v_target.status = 'pendingApproval' then 'rejected' else 'removed' end
```

⇒ **rechazar y remover son el MISMO RPC**, y el servidor llama `rejected` al resultado cuando el objetivo
estaba pendiente (documentado en el encabezado de la función, `:564`).

Lo que rompe es la **lectura**: `is_group_member` (`:71-75`) solo admite `active`/`pendingApproval`, y el
pull filtra igual (`gateway/src/groups/routes.ts:388`). El rechazado deja de poder leer el grupo, su
`group_id` desaparece de `page.memberships` y `reconcileLostMemberships`
(`GroupsSyncClient.swift:1994-2026`) le borra las filas locales **deduciendo la baja por AUSENCIA**.

Resultado: **el «no» se manifiesta como una desaparición**. Y hay copy traducido a 16 locales que hoy no
tiene camino: `groups.invite.rejected.title`, `groups.invite.rejected.body`, `groups.card.rejectedChip` y
la rama `.rejected` de `PendingApprovalBanner`.

### 2 · En la sala de espera no puede ver ni un gasto, y ninguna pantalla lo dice

Un endurecimiento explícito del DDL cambió las policies SELECT de
`split_expenses`/`split_shares`/`split_settlements` de `is_group_member` (que incluye `pendingApproval`) a
`is_group_writer` (solo `active`), dejando `split_groups` y `group_members` en la primera
(`supabase-groups-staging.ddl:810-821`).

⇒ mientras espera, el invitado recibe por el pull **el grupo y el roster, y cero contenido financiero**.
El copy de la sala de espera habla de **participar**; el hecho es que tampoco **ve**. Ni el banner del
grupo ni el chip de la tarjeta lo aclaran.

### 3 · «¡Todo listo!» es prácticamente inalcanzable en el primer join

`join_group` devuelve `pendingApproval` en las **tres** ramas que puede tomar (rebind `:484`, revive
`:510`, insert `:524`) y **no existe ninguna rama de auto-aprobación**.
`GroupInviteOnboardingLogic.step` solo devuelve `.active` con `phase == .active`, y esa fase solo llega
por `noteMemberResolved(.active)`.

⇒ el final feliz exige que el admin apruebe **mientras el cover sigue abierto** y que un ciclo de pull
republique la fase. En el flujo real el invitado sale por «Continuar» desde «Solicitud enviada» y no la
ve nunca. El único camino natural a esa pantalla es **re-tapear el enlace siendo ya miembro activo**.

## Lo que la primera pasada dijo mal (y por qué queda escrito)

La derivación inicial afirmó que **«el status `rejected` ni siquiera existe server-side»**, apoyándose en
`ddl:1308`. Es **FALSO**: esa línea existe y dice lo que citaba, pero pertenece a `migrate_group`
(`:1214`) y valida el array de members de un payload de **migración** — no es el dominio de
`group_members.status`, columna que **no lleva CHECK** (tabla en `:131-147`).

Queda escrito porque la conclusión de usuario sobrevivió intacta con una causa distinta, y ese es
exactamente el modo en que un documento envejece mal: la conclusión correcta apoyada en la medición
equivocada. **La causa buena es la de LECTURA, no la de existencia.**

## Huecos (medir antes de diseñar el fix)

- **¿Emite el gateway un push de «te aprobaron»?** Medido: `get_group_push_tokens`
  (`ddl:1613`) excluye a los `pendingApproval`, así que el invitado no recibe pushes del grupo mientras
  espera. NO medido: si hay una notificación específica al aprobar (leer `gateway/src/push/`). **El copy
  «Te avisamos cuando esté listo» depende de esa respuesta** — si no hay push, el copy miente.
- Qué pinta exactamente `GroupDetailView` para un `pendingApproval`: empty state de la lista de gastos, y
  si el FAB de crear gasto está oculto o deshabilitado.

## El fix, en tres piezas independientes

1. **Dar pantalla al rechazo.** El copy ya existe en 16 locales. Hace falta que el cliente distinga
   «desapareció porque me rechazaron» de «desapareció porque el grupo se borró»: hoy `reconcileLostMemberships`
   deduce por ausencia y no puede. Necesita señal — que el pull devuelva el `rejected` una vez, o un
   tombstone.
2. **Decir la verdad en la sala de espera.** Copy que nombre lo que NO se ve todavía. Barato y sin
   servidor.
3. **Decidir qué se promete al salir.** Si no hay push de aprobación, «Te avisamos cuando esté listo» no
   se sostiene.

## Relacionados

- [[grupos-enlace-de-invitacion-cinco-causas-un-solo-mensaje]]
- [[grupos-recorrido-del-invitado-codigo-muerto-y-docblock-caducado]]
- [[qa_groups-aprobacion-no-retira-banner]] — el otro lado de la misma aprobación
- [[qa_groups-join-intent-reconciler]]

## Implementación · pieza 2 (2026-08-12, `0342564c`)

**Copy honesto de la sala de espera**, 16 locales. El anterior decía «El admin del grupo debe aprobarte
antes de que puedas participar. **Te avisamos cuando esté listo.**» y las dos mitades eran falsas.

## El hueco del push: MEDIDO, y la respuesta es NO

El ticket lo dejaba abierto («NO medido: si hay una notificación específica al aprobar — leer
`gateway/src/push/`»). Medido en `gateway/src/`, y de ahí sale el copy nuevo:

| Qué | Medición |
|---|---|
| El ÚNICO push del gateway | Un *silent* `content-available:1` de fan-out, `groups/routes.ts:159-215` |
| Quién lo dispara | **Solo** el handler de `POST /groups/push` (deltas de sync). `groups/rpc.ts` —donde vive `approve_member`— no importa `sendPush` ni hace fan-out |
| El payload | `defaultPayload()` en `push/apns.ts:72`: siempre `kind: "g0-spike"`. **Nunca una alerta visible** |
| A quién llega | `get_group_push_tokens`, que EXCLUYE a los `pendingApproval` (ya estaba medido en el ticket) |

⇒ **no hay ninguna notificación de «te aprobaron», ni la habría aunque el fan-out cubriera los RPC.**
La pieza 3 («decidir qué se promete al salir») queda resuelta: no se promete nada, y el copy nuevo da
la acción que sí existe — volver a abrir la app.

## El cliente ya está listo: la tesis del ticket necesita una corrección

El ticket dice que el copy del rechazo «hoy no tiene camino» y lista
`groups.invite.rejected.title`/`.body`, `groups.card.rejectedChip` y la rama `.rejected` de
`PendingApprovalBanner`. **Medido: el camino de CLIENTE existe entero y está cableado.**

`GroupDetailView.swift:112` hace `else if viewModel.currentUserMember?.isRejected == true` y presenta
`PendingApprovalBanner(state: .rejected, ...)` con su título, su cuerpo y su botón de salir
(`:624-660`). `SplitMember.isRejected` (`:67`) lee `memberStatus == .rejected`, y `applyMember`
escribe `model.status` con lo que venga del wire (`GroupsSyncClient.swift:2629`).

Lo que falta es **la señal, no la pantalla**: el delta con `status = 'rejected'` no le llega al
rechazado porque la RLS deja de entregarle el grupo, y `reconcileLostMemberships` deduce la baja por
ausencia y le borra las filas. ⇒ el fix de la pieza 1 **no incluye escribir UI**: es hacer que el
servidor entregue esa transición una vez (o un tombstone), y el cliente la pinta solo.

Eso hace la pieza 1 **más barata de lo que el ticket sugiere**, pero sigue siendo servidor.

## Pieza 1 · lo que hay que decidir en el servidor (no tocado, autorización del owner)

El diseño mínimo que se sostiene con lo medido:

1. Que el pull entregue **una vez** la membresía en estado `rejected` (hoy `gateway/src/groups/routes.ts:388`
   filtra a `active`/`pendingApproval`, y `is_group_member` en el DDL hace lo mismo).
2. Que `reconcileLostMemberships` distinga «me rechazaron» (señal recibida) de «el grupo desapareció»
   (ausencia) — hoy no puede, y por eso borra en los dos casos.

La decisión de seguridad que hay detrás: entregar `rejected` **es** dar un oráculo, aunque sea sobre
una membresía propia. Habría que ratificar que es aceptable (lo es, en mi lectura: el rechazado ya
sabía que existía el grupo, porque tocó su enlace), y acotarlo a la propia fila del solicitante.

migrated from YalaWiki Bugs/grupos-invitado-el-no-no-tiene-pantalla.md @ 1934e8ad

---

## DECISIÓN DEL OWNER · 2026-09-03 — sí al aviso de rechazo, acotado a la propia fila

**Aprobado**: el pull entrega UNA vez al solicitante su propia membresía en estado `rejected`, y
`reconcileLostMemberships` distingue rechazo de desaparición.

**Sobre el oráculo, que era el reparo.** Sí es dar información que hoy no se da, pero solo sobre la
propia fila de quien pregunta: alguien que pidió entrar a un grupo ya sabe que ese grupo existe y que
pidió entrar. Lo que se le añade es el desenlace de su propia solicitud. **Acotarlo a su fila es parte
de la decisión, no un detalle de implementación**: entregar el estado de OTROS sí sería un oráculo de
verdad.

**Lo que abarata la pieza:** el copy ya existe en los 16 idiomas (`groups.invite.rejected.title`,
`groups.invite.rejected.body`, `groups.card.rejectedChip`) y el cliente ya sabe pintar el banner — el
propio ticket corrige su tesis inicial: **no hay que escribir UI**. Y rechazar y expulsar son el mismo
RPC, que ya llama `rejected` al resultado cuando el objetivo estaba `pendingApproval`.

**Desbloquea también** la pieza 1 de `invite-link-five-causes-one-message`, que esperaba esta misma
autorización de servidor. Las dos se hacen juntas o la segunda se queda a medias.

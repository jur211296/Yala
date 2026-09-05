---
id: rejoin-tap-renotifies-admins
status: qa
priority: medium
area: groups-backend
created: 2026-09-04
updated: 2026-09-04
source: medido al diseñar el arreglo de rejected-member-cold-tap-does-nothing (2026-09-04)
---

# Volver a tocar tu propio enlace, estando ya pendiente, vuelve a avisar al admin — cada vez

## Qué pasaba

Pedí entrar a un grupo y estoy esperando aprobación. Toco otra vez el enlace que me pasaron —porque
no sé si se envió, o porque me lo reenvían— y el admin del grupo **recibe otra notificación de
solicitud pendiente**. Tantas como veces toque. Para él parece que insisto; en realidad no ha pasado
nada nuevo.

Del lado de la persona que toca, todo se ve normal: no hay error, no hay aviso, no cambia nada.

## Dónde estaba

El guardián del fan-out (`gateway/src/groups/rpc.ts::notifyMembershipChange`) estaba escrito para
evitar exactamente esto, y **su comentario prometía algo que el código no cumplía**: filtraba por
`status !== "pendingApproval"`, lo que tapa el caso del miembro `active` que reabre el enlace y deja
pasar justo el del re-tap de quien ya estaba pendiente.

La causa de fondo estaba un piso más abajo: **el `status` que devuelve el RPC es ambiguo.** Su rama
«ya eras miembro» devuelve `v_row.status` —el estado que la persona YA tenía—, que vale
`pendingApproval` igual que el de un alta nueva. El Worker no podía distinguirlos porque el RPC no se
lo decía.

> **Coordenada corregida:** el ticket original citaba el SQL en
> `docs/modo-nube/briefs/prod-promo-sql/…`. **Ese directorio no existe en el árbol.** La migración
> viva es `qa/cloud/g13_03_join_group_distinguishes_deleted.sql`, y su rama no-op está en las
> líneas 102-104.

## Lo que NO servía, y por qué conviene que quede escrito

`rebound` parece el discriminante obvio y **es falso**. De las cuatro ramas que retornan, sólo el
rebind legacy lo trae `true`; la re-activación de un rechazado y el alta nueva devuelven
`rebound:false` y **sí** son transiciones reales. Gatear por `rebound` habría apagado avisos legítimos
—entre ellos el que arregló `rejected-member-cold-tap-does-nothing`—.

## El arreglo

`qa/cloud/g13_04_join_group_reports_transition.sql`: `join_group` devuelve un campo **`changed`** en
sus cuatro ramas, `false` sólo en la no-op. El guardián del Worker añade `if (body.changed === false)
return;`. Nada más cambia: ni una condición, ni una escritura, ni `status`/`rebound`/`group_id`/
`member_key`.

**Cero cambios de cliente**, medido antes de escribirlo: `JoinGroupResult`
(`GroupsMembershipClient.swift:79-90`) es `Decodable` con `CodingKeys` explícitas y `JSONDecoder`
ignora las claves que no conoce.

**La ausencia de `changed` se trata como «avisa», a propósito.** El despliegue no es atómico; exigir
`changed === true` habría dejado a los admins sin **ninguna** solicitud si el Worker saliera antes que
la migración — un fallo peor y más silencioso que el ruido que arregla. Con el fail-open, ningún orden
de despliegue pierde un aviso legítimo. Hay un test que pinnea esa elección.

## Lo MEDIDO (2026-09-04)

El ticket original decía: «no se ha comprobado cuántos push llegan de verdad». La parte de servidor ya
está medida; la de device sigue pendiente (ver abajo).

**El bug, contra el motor de producción** (transacción revertida, función vieja, sin tocar nada): el
re-tap devuelve un jsonb **idéntico byte a byte** al del alta nueva —

```
{"status":"pendingApproval","rebound":false,"group_id":"…","member_key":"…"}
```

— lo que prueba que el Worker recibía lo mismo en ambos casos y disparaba el push las dos veces.

**El fix, mismo método, 6 escenarios sobre las 4 ramas:**

| # | Escenario | `status` | `changed` | Efecto |
|---|---|---|---|---|
| 1 | Primer tap (alta nueva) | pendingApproval | `true` | avisa |
| 2 | **Re-tap estando pendiente** | pendingApproval | `false` | **silencio** |
| 3 | Rechazado que vuelve a entrar | pendingApproval | `true` | avisa |
| 4 | Ese mismo re-toca otra vez | pendingApproval | `false` | silencio |
| 5 | Miembro activo reabre el enlace | active | `false` | silencio |
| 6 | Rebind legacy | pendingApproval | `true` | avisa |

Los pasos 2 y 3 son la clave: **idénticos en `status` y `rebound`**, siendo uno un no-op y el otro una
transición real. Y 3→4 es el criterio de éxito literal: una solicitud, un aviso.

## Verificación

- **Gate del Worker, por mutación**: quitar `if (body.changed === false) return;` pone rojo
  **exactamente** el test del re-tap y ninguno más. Un test que pasa con y sin el fix no prueba nada.
- **`gateway/test/push.fanout.unit.test.ts`: 21 verdes** (18 + 3 nuevos — `changed:false` calla,
  el rechazado que reentra avisa, campo ausente avisa).
- **Batería del gateway con las tres credenciales cargadas: 331 tests, 1 rojo**, que es
  `account-goldens-freeze-read-test-times-out` — **preexistente demostrado** (falla idéntico contra
  `HEAD` limpio, sin estos cambios).
- **Los 25 goldens de Grupos, verdes contra staging** con el Worker nuevo y la BD de staging **sin**
  la migración: es exactamente el escenario «Worker nuevo + servidor sin migrar», y no rompe nada.
- Typecheck: 3 errores, **todos preexistentes** (`groups.consent.test.ts`,
  `wrangler.forceupdate.test.ts`), idénticos contra `HEAD` limpio. Este cambio añade cero.

## Producción · aplicada y verificada el 2026-09-04

Aplicada como migración `g13_04_join_group_reports_transition`. A diferencia de g13_03 —que parcheó el
cuerpo vivo con un `do` block— aquí se pegó el cuerpo completo, y eso es defendible **porque el drift
se midió antes**: el `prosrc` de producción era idéntico al fichero de g13_03 salvo los comentarios
explicativos. El cuerpo aplicado conserva sólo los de estructura, así que repo y producción vuelven a
coincidir.

- Cuerpo: **4078 → 4321 caracteres** (+243: las cuatro claves `changed` y dos líneas de comentario).
- Post-checks: `'changed', true` ×3 · `'changed', false` ×1 · `yala_group_deleted` ×1 ·
  `yala_invalid_invite` ×1 (el no-oráculo de g13_03, intacto) · grant a `authenticated`, intacto.
- Comportamiento re-verificado **contra la función ya aplicada**: primer tap `changed:true`, re-tap
  `changed:false`.
- Worker `yala-gateway-production` desplegado — versión `89823cc3-39d4-4a44-8135-a245c9e7e878`, 100 %.
  `healthz` responde `{"ok":true,"environment":"production","enforce":"enforce"}`.

**Producción era el único delta seguro:** su último deploy (2026-09-03T21:35Z) es posterior al último
commit ajeno de `gateway/src`, así que este despliegue sólo añade este cambio.

## Lo que falta

1. **Staging no lleva la migración.** No hay credencial de DDL de staging accesible: el conector MCP
   sólo ve el proyecto de producción, y `~/Secrets/yala-supabase-test/` únicamente tiene JWTs de
   usuario. Queda **drift staging↔producción** en `join_group`. No rompe nada —los goldens no miran
   `changed` y se verificó que pasan sin él— pero hay que cerrarlo cuando haya acceso, aplicando el
   mismo fichero.
2. **El Worker de staging tampoco se desplegó, y a propósito**: su último deploy es del 2026-08-12 y
   arrastra **dos commits que no son de esta sesión** (`eb6593ce`, `6bf0f588`). Desplegarlo habría
   subido trabajo ajeno; además, sin la migración en su BD no verificaría nada (fail-open).
3. **El conteo real de push en device lo hace el owner.** `.claude/rules/gateway-attest.md` lo dice
   explícitamente: un build de Xcode no puede validar contra producción (el AAGUID de desarrollo da
   401 por diseño), así que **quien escribe el fix no puede ejercitarlo**. Son cinco minutos con dos
   cuentas: pedir entrada, dejar la solicitud pendiente, tocar el enlace **tres veces más** y comprobar
   que al admin le llega **una sola** notificación.

## Relación con `rejected-member-cold-tap-does-nothing`

Es el **mismo daño por otra puerta**, y ahora están los dos lados: aquél hizo que un tap valga como
mucho una solicitud desde el cliente; éste es la defensa del servidor, y cubre a cualquier otro cliente
(la web, o una versión antigua de la app). El escenario 3 de la tabla de arriba comprueba que este
arreglo **no apaga** aquél.

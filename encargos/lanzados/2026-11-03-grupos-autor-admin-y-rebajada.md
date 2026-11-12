# Grupos: autor del gasto desde 2.1, menú de admin en grupos migrados y avisos falsos tras cortar la re-bajada

Cierre: **cierra-sola**. Al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `grupos-autor-admin-y-rebajada` · Encargo 07 de la cola Yala (lote de 3 tareas chicas, un PR, un cierre) · al cerrar → encargo 08. Esfuerzo: high.

## Cards y criterio de hecho
- `tablero-grupos-la-edicion-de-un-telefono-con-2-1-vx6f` — Grupos: la edición de un teléfono con 2.1 deja en el servidor el autor anterior del gasto
  - Hecha cuando: Una edición de un cliente v2 deja el autor a NULL (el aviso cae al pagador, como antes), con sonda en staging; o la decisión de aceptarlo escrita en la regla del canal.
  - Contexto: Opción conservadora: trigger en split_expenses solo en staging con sonda; producción solo si queda documentado en el PR.
- `tablero-grupos-migrados-el-menu-de-un-miembro-of-0vbn` — Grupos migrados: el menú de un miembro ofrece las acciones de admin según la fila canónica, no la que ve el servidor
  - Hecha cuando: En un grupo migrado, el menú de miembro ofrece exactamente las acciones que el servidor acepta; test con la fila heredada sin reclamar y reclamada.
- `tablero-grupos-si-la-app-se-cierra-a-mitad-de-la-vj61` — Grupos: si la app se cierra a mitad de la re-bajada de una subida de versión, los gastos que ya estaban avisan de «modificado»
  - Hecha cuando: Un kill a mitad de la re-bajada no produce avisos de «gasto modificado» de gastos que no cambiaron; test que lo fija.

## Contexto
Las tres salieron de la review de grupos-autor-del-gasto (PR #750). Son residuales del despliegue de 2.2 en Grupos y conviene cerrarlas antes del barrido QA.

## Qué se pide
0. Lee cada card con `tablero ver <id>` (contexto y siguiente paso) antes de tocar código.
1. Resuelve las cards del lote en este orden, con su test o su vídeo según pida cada «Hecha cuando».
2. Si una card resulta no reproducible, descártala con la evidencia (vídeo o test) escrita en la card y en el PR.

## Qué NO hay que tocar
Precios o paywall, marketing/, Web/, migraciones de producción sin pasar antes por staging.

## Pie fijo (lanzar-sesion)
- Proyecto Yala, repo `jur211296/Yala`. Versión **2.2**. Base `origin/2.2`; el PR va a `2.2` con auto-merge.
- Una sesión Yala a la vez: no lances otras sesiones Yala ni trabajes en paralelo con otra. Un solo PR para todo este encargo y un solo cierre.
- Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.
- Pipeline serial de la Mini: limpiar sims muertos, DerivedData y cachés de XcodeBuildMCP de worktrees cerrados (nunca las de un worktree vivo); build con `xcodebuild -jobs 2` sin sim booteado; bootear 1 sim; tests; apagar y borrar el sim. `limpiar-mac --apply` al cerrar.
- Pasa cada card a «in qa» (o «done» si no necesita ojos de Jürgen) al abrir el PR, con `--agente` de la sesión.
- Si sale algo que no cabe aquí, crea cards en 2.2, «ready to launch», `cierra-sola`, prioridad alta, asignadas a frank (nada a backlog), y lista sus títulos en el PR y en el cierre.
- Cierre autónomo: se lanza con `--permission-mode bypassPermissions`. Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue. Lo que de verdad necesite a Jürgen, no lo hagas: crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.
- Al cerrar, Frank publica el digest y lanza el siguiente encargo de `~/Claude/flota/cola-yala/`.

Termina con /cerrar-total.

## Card extra (Jürgen 2026-11-03): Cuentas · las cuentas de sistema de Grupos se juntan en una sola cuenta «Grupos» con una línea por grupo
- Hecha cuando: en la zona de cuentas Grupos ocupa un solo espacio; adentro (o en su tarjeta) se ve una línea por grupo con su saldo; los saldos totales no cambian. Video en el PR.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **vx6f · autor desde un 2.1 → trigger en el servidor, no aceptarlo.** `BEFORE UPDATE` en `split_expenses` (g30_01): si
   un UPDATE avanza el `field_hlcs` de alguna unidad del formulario sin avanzar la del autor, el autor pasa a NULL (el
   aviso cae al pagador, como antes de xi74). Compara `field_hlcs`, no valores: los escritores del servidor que reescriben
   columnas no lo disparan. Banco local + sonda en STAGING. **Producción:** se aplica solo si el banco y la sonda salen
   verdes, documentado en el PR con su rollback (lo permite el contexto del encargo); si algo no cuadra, se queda en
   staging y la aplicación a producción va a una card de Jürgen.
2. **0vbn · admin de grupo migrado → una sola decisión, la del servidor.** `GroupAdminPermissionLogic.isAdmin`: en un
   grupo del backend con sesión, como `is_group_admin` (cualquier fila mía activa con `role = admin`); sin ninguna fila
   mía bajada, el dueño conserva el admin; fuera del backend, la fila canónica de siempre. La usan
   `GroupDetailViewModel.isCurrentUserAdmin` (menú, ajustes) y `GroupService.requireCurrentUserAdmin` (guardado). Todas
   las acciones de admin del servidor (aprobar, quitar, rol, invitaciones, ajustes del grupo) usan `is_group_admin`:
   medido en el DDL. Fuera: el aviso de solicitud pendiente del sync (no es una acción).
3. **vj61 · re-bajada cortada → silenciar por `server_seq`, durable.** Un gasto que vuelve a bajar con `server_seq` ≤ el
   más alto que este teléfono ya aplicó de ese grupo no es una edición nueva: no avisa. El máximo visto vive en
   `GroupSyncCursor` (campo nuevo, migración ligera del store sync-meta, sin CloudKit), en el MISMO save que el cursor,
   y sube con cada escritura del cursor (incluidos los resets, que guardan antes el valor viejo). Sustituye al conjunto
   en memoria `capabilityRepullZones` (una sola forma de decidirlo) y cubre también el re-pull del remedio del Merkle.
   Una edición real durante la re-bajada (seq mayor) sí avisa, que antes se silenciaba.
4. **Card extra · cuentas de Grupos en una tarjeta.** Las cuentas de sistema son por MONEDA («Grupos PEN»), no por grupo.
   En el carrusel del Panel (y sus chips de filtro) se juntan en una sola tarjeta «Grupos» que lista una línea por grupo
   con lo que ese grupo aporta (suma de los registros de las cuentas de sistema con ese grupo), y el total en la moneda
   preferida como la tarjeta de varias divisas. Los saldos totales no cambian (mismas cuentas, misma suma). Tocar la
   tarjeta abre la ficha de siempre de la primera cuenta de Grupos si hay una sola moneda; con varias, la lista de
   Ajustes no cambia. Detalle exacto tras medir el código del carrusel; la decisión de UI que no esté aquí se toma por
   el molde de la tarjeta de varias divisas.
5. **Orden y PR:** un PR, un cierre. Cards a «in qa» las que piden ojos (la extra, 0vbn) y «done» las que fija un test o
   una sonda.

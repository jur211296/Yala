# Estabilidad: cuelgue y caída de la app de desarrollo (Sentry), widget con movimientos en el futuro y test inestable de pagos planificados

Cierre: **cierra-sola**. Al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `estabilidad-sentry-widget-y-test` · Encargo 09 de la cola Yala (lote de 4 tareas chicas, un PR, un cierre) · al cerrar → encargo 10. Esfuerzo: medium.

## Cards y criterio de hecho
- `tablero-el-sistema-mata-la-app-de-desarrollo-por-mei0` — El sistema mata la app de desarrollo por bloquear el hilo principal más de 2 s (Sentry YALA-IOS-4)
  - Hecha cuando: Causa encontrada, arreglo con test y el issue resuelto en Sentry (o marcado como duplicado del que corresponda).
  - Contexto: https://yala-is.sentry.io/issues/YALA-IOS-4
- `tablero-la-app-de-desarrollo-se-cae-con-no-eligi-65wb` — La app de desarrollo se cae con «No eligible connection available» al abrir (Sentry YALA-IOS-3)
  - Hecha cuando: Causa encontrada, arreglo con test que lo reproduce y el issue resuelto en Sentry.
  - Contexto: https://yala-is.sentry.io/issues/YALA-IOS-3
- `tablero-el-widget-revienta-si-todos-tus-movimien-ba87` — El widget revienta si todos tus movimientos están en el futuro
  - Hecha cuando: Un libro cuyo primer movimiento es de mañana actualiza el widget sin cerrarse; test en rojo sin el arreglo.
  - Contexto: WidgetDataCache.buildTrendData: acotar daysOfData a 0.
- `tablero-test-de-borrados-de-pagos-planificados-f-vrs1` — Test de borrados de pagos planificados falla a veces en la suite completa: espera 300 ms a un plazo de 60 ms
  - Hecha cuando: El caso no depende de cuánto tarde el hilo principal y pasa en la suite completa varias veces seguidas.

## Contexto
Dos caídas del build de desarrollo vistas en Sentry, una caída real del widget y un test inestable. Si el token de Sentry no deja resolver el issue, déjalo escrito en la card (hay una decisión aparte de Jürgen sobre ese token) y sigue.

## Qué se pide
0. Lee cada card con `tablero ver <id>` (contexto y siguiente paso) antes de tocar código.
1. Resuelve las cards del lote en este orden, con su test o su vídeo según pida cada «Hecha cuando».
2. Si una card resulta no reproducible, descártala con la evidencia (vídeo o test) escrita en la card y en el PR.

## Qué NO hay que tocar
Precios o paywall, marketing/, Web/, la decisión del token de Sentry.

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

## Paso 0 (decidido por la sesión, 2026-11-03)

- **Ficheros:** `WidgetDataCache.swift` (tope a 0), `ScheduledPaymentPendingDeletion.swift` y su gemelo `RecordPendingDeletion.swift` (seam `batchSleep`), `ErrorReportingService.swift` (guarda de previews), tests y `qa/coverage-index.json`.
- **vrs1 — señal o reloj inyectado:** reloj inyectado (`ManualBatchTimer`). Esperar a «committed tiene 2» habría dejado en pie los casos que miden que el plazo se alarga, igual de frágiles. El patrón estaba también en los tests de registros: se arregla en los dos (regla «todas las instancias»).
- **YALA-IOS-3/4 — dónde estaba la caída:** en las previews de «Tu parte» de otra sesión (arregladas en #738), no en la app. El arreglo de este lote es que una preview no vuelva a informar a Sentry. IOS-4 se trata como duplicado de IOS-3: la causa es inferida (mismo simulador, mismo build, eventos intercalados) porque la pila no se puede simbolizar.
- **Resolver en Sentry:** el token de la Mini es de solo lectura y el del Llavero no existe. Queda anotado en las cards; la decisión del token no se toca.
- **Captura del widget:** no hay cambio visible (antes la app se cerraba; ahora la curva empieza hoy, como un libro vacío). Sin capturas.

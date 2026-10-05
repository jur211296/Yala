# Grupos: los Ajustes del grupo recalculan sin freno ni cancelación con cada cambio remoto (punto 2 del ticket groups-tab-missing-panel-perf)

## Contexto
El ticket `tickets/backlog/groups-tab-missing-panel-perf.md` (priority high) mide el coste de la pestaña Grupos. El punto 1 (la lista rehacía las cuentas en cada tecla) ya se cerró el 2026-09-06. Siguen abiertos:
- **Punto 2:** `GroupSettingsView` recalcula en el acto con cada `dataVersion` (el `.onChange(of: dataVersion)` y el recálculo de `GroupSettingsView.swift`, coordenadas aprox. `:103-105` y `:204-210`; vuelve a medirlas, derivan). No tiene el freno/coalescing ni la cancelación que ya tienen el Panel y el detalle del grupo.
- **Punto 3:** la validación cruzada del coalescing con dos aparatos nunca se pudo hacer, y no hay test de coalescing. El barrido de QA del 16-sep anotó además que el freno depende de `applicationState == .active`.
Lee el ticket entero antes de empezar: trae medidas, riesgos, criterios de aceptación y una review adversarial previa.

Jürgen quiere en Yala siempre lo más robusto y la mejor práctica aunque tarde más. Sin apuro. No te inclines a lo más chico.

## Qué se pide
1. Darle a `GroupSettingsView` el mismo freno y la misma cancelación que ya usan las otras superficies de Grupos (reutiliza el mecanismo existente; no inventes uno paralelo). Las ráfagas de cambios remotos deben coalescer en un solo recálculo y un recálculo viejo no debe pisar a uno nuevo.
2. Cerrar con tests lo que hoy no tiene red: un test de coalescing (ráfaga de N cambios → un recálculo) que sea determinista y no dependa de `applicationState == .active` del simulador, y un test de que el recálculo cancelado no publica. Primero en rojo contra el código actual, después en verde.
3. Si al medir aparece otra superficie de Grupos que recalcula sin freno, arréglala solo si es el mismo patrón y el mismo riesgo; si no, ticket nuevo en `tickets/backlog/`.
4. Lo que solo se puede verificar con dos aparatos (punto 3) queda como guion de device-QA en `tickets/qa/` con pasos concretos para Jürgen. Actualiza el ticket con lo hecho y lo que queda.
5. Pasa la tarjeta del tablero `tablero` del proyecto Yala que corresponda a este encargo por los estados (in progress al empezar, in qa al cerrar si queda device-QA). Ojo: `tablero editar --nota` sustituye la nota entera; añade sin borrar lo que había.

## Qué NO hay que tocar
- Nada de copy ni diseño nuevo. Si aparece una decisión de UI/UX, deja propuestas en el ticket y no la decidas.
- No toques los flujos de cerrar sesión / drain / desasociar de Grupos (están en el PR #362, en cola de auto-merge a 2.1).
- No cambies el comportamiento visible de Ajustes del grupo más allá de cuándo recalcula.

## Cómo se sabe que está bien
- Test(s) de coalescing y cancelación en rojo antes y en verde después.
- Gate completo: builds de Yala y Yala Dev sin warnings nuevos, unit tests verdes, XCUITest de Grupos verdes (los rojos conocidos de iOS 27 como `EdgeCasesUITests.test_extremeMinimumAmountSaves` se citan con su ticket, no se arreglan aquí).
- PR a `2.1` con el parte en el cuerpo, en cola de auto-merge.
- Cierra con `/cerrar-total` autónomo, sin esperar a Jürgen salvo que haya una decisión de diseño real.

## Gate después del CI del PR anterior
La sesión arranca ya, sobre `origin/2.1`. No se espera a que el PR anterior (#362) entre, y no se parte de su rama. Justo antes del gate, mira si #362 sigue en CI. Si sigue, espera a que entre y rebasa una sola vez, con el simulador apagado. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.

## Pipeline serial en la Mini y limpieza
Cola fija, sin solapar: limpiar → build con `xcodebuild -jobs 2` sin sim booteado → boot de 1 solo sim → tests → apagar y vaciar ese sim. Prohibido solapar swift-frontend + SpringBoard + app + UITests.
Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen (no las de worktrees vivos). Si el borrado falla, dilo en el cierre.
Al cerrar: apagar y vaciar el sim que usaste, quitar el worktree si ya no hace falta, no dejar Devices apagados ni basura de build. Si creas cualquier secreto en el Llavero, dilo en el cierre.
Capturas: solo si hay cambio visible (no debería); si las hay, `capturas/antes.png` y `capturas/despues.png` con rutas en el resumen.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hechos medidos antes de decidir** (árbol `a7b37a5f2`):
- El recálculo de Ajustes cuelga de `.onChange(of: sessionState.dataVersion)` en `GroupSettingsView.swift:204-210`
  y llama a `recomputeOwnerExit()` (→ `recomputeOutstandingDebt()`, `:1003-1042`: un `fetchCount` + cuatro fetch +
  `calculateBalances`) y a `recomputeShareableSummary()` (`:723-747`).
- `GroupSettingsView` tiene **un solo** sitio que lo presenta: la hoja `.settings` de `GroupDetailView.swift:306`.
  El detalle sigue montado debajo y su `.onChange(of: dataVersion)` (`:280-298`) ya agenda
  `viewModel.reloadAndRecalculate()` con freno de 150 ms, tras su dismiss-first.
- **Desfase que hoy existe:** `recomputeShareableSummary()` lee `viewModel.members/expenses/shares/settlements`
  en el acto del `dataVersion`, 150 ms ANTES de que el VM recargue. Calcula sobre los datos del cambio anterior y
  nadie lo repite cuando el VM se pone al día.
- La maquinaria del freno está **duplicada letra a letra** en `GroupsViewModel.swift:254-286` y
  `GroupDetailViewModel.swift:164-196`, y las dos copias leen `UIApplication.shared.applicationState` sin costura.
- En `Yala/App/Views/Groups` hay tres `.onChange(of: sessionState.dataVersion)`: lista y detalle con freno,
  Ajustes sin él. No hay otra superficie de Grupos con el mismo patrón.
- `GroupsViewModel`/`GroupDetailViewModel` no están entre los ficheros del PR #362.

**D1 · Cómo frena Ajustes** → recalcula cuando el **detalle termina su recálculo con freno**: `GroupDetailViewModel`
expone un contador que sube una vez por recálculo con freno publicado, y Ajustes cuelga de él en vez de `dataVersion`.
Por qué: es el mecanismo existente entero (freno, cancelación, pausa en segundo plano) sin una línea paralela, y de
paso Ajustes lee los datos del VM ya recargados, lo que cierra el desfase de arriba.
Alternativa descartada: que Ajustes llame también a `reloadAndRecalculate()` — agendaría un recálculo justo cuando el
detalle decide cerrarse sin hacerlo, que es lo que su dismiss-first evita a propósito. Y un `Task` propio en la vista
sería el freno paralelo que el encargo prohíbe.

**D2 · Qué sigue instantáneo** → el `.onAppear`, el pre-tap de archivar y de eliminar, el `needsDecision` de
transferir y la vuelta de un error de salir: todos llaman a `recomputeOwnerExit()` directo, como hoy. Y el
`transferRefusedByServer = false` se queda en el `.onChange(of: dataVersion)`, sin recálculo detrás.
Por qué: ese reset significa «llegó un dato DESPUÉS del rechazo»; si se moviera detrás del freno, un `dataVersion`
anterior a la respuesta del servidor lo borraría 150 ms después y «Transferir y salir» volvería a aparecer.

**D3 · La costura para testear sin `applicationState`** → se extrae la maquinaria duplicada a un tipo único
(`RecalculationDebouncer`) con la espera y el «¿está activa la app?» inyectables, y las dos VMs de Grupos lo usan.
Por qué: un test determinista necesita controlar la espera y el estado de la app, y con una sola copia el test cubre
las dos superficies. Alternativa descartada: meter la costura dos veces — dos copias que divergen y un test que cubre
una. Los frenos del Panel, Estadísticas, Registros y Pagos programados **no** se migran: no son de Grupos.

**D4 · Cuándo sube el contador** → solo cuando el recálculo con freno llega a publicar; no en el `loadData()` directo
de los gestos locales. Por qué: así Ajustes recalcula como mucho tantas veces como antes; sus propios gestos ya pasan
por `GroupService`, que sube `dataVersion`, y llegan por el mismo camino.

**D5 · Rojo antes, verde después** → el freno de las VMs **ya coalescía**: sus tests nacen verdes con la costura y se
validan con mutantes (sin cancelar el anterior, sin el `guard` de cancelación, sin la puerta de segundo plano). El rojo
real contra el código de hoy es el de Ajustes: un test que fija que el recálculo pesado no cuelga de `dataVersion`
sale rojo antes del cambio y verde después.
Por qué: decir que los tests de coalescing «salían rojos» sería falso; lo que faltaba era la red, no el freno.

**D6 · `[weak self]` en la acción del freno** → la tarea deja de retener la VM 150 ms. Por qué: tras cerrar el detalle
no hay nadie que lea el resultado; la cancelación del `.onDisappear` ya lo cubría, esto lo cubre aunque falle.

**D7 · El punto 3 (dos aparatos)** → el ticket pasa a `tickets/qa/` con un guion para Jürgen sobre el canal de hoy
(`GroupsSyncClient`, modo nube), y el doble-load al entrar —pendiente de volver a decidirse y sin relación con el
freno— sale a un ticket propio en `tickets/backlog/` para que el de QA se pueda cerrar mirando.

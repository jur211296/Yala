---
id: groups-tab-missing-panel-perf
status: backlog
priority: high
area: "groups, performance, cloudkit"
created: 2026-04-17
updated: 2026-09-02
source: YalaWiki/Bugs/qa_groups-tab-no-perf-patterns.md
---

# Grupos — el freno del Panel ya está puesto; lo que quema ahora es la lista

## Léeme primero (2026-09-02)

**El grueso de lo que este ticket pedía está implementado desde el 3 de julio y re-medido hoy
contra `553b91c9`.** El cuerpo anterior lo describía como pendiente: si lo retomas leyéndolo tal
cual, rehaces tres commits que ya existen.

Sigue abierto por tres cosas, y **dos de ellas no estaban en el ticket**:

1. La lista de grupos no es perezosa y recalcula deudas de todos los grupos a la vez — y otra vez
   con cada tecla del buscador. **Es el sitio más caro que queda y nunca se miró.**
2. Los Ajustes del grupo recalculan la deuda en cada cambio de datos sin freno ni cancelación:
   exactamente el patrón que este ticket vino a quitar, en una vista que su tabla no lista.
3. La validación cruzada del coalescing (dos dispositivos) nunca se pudo hacer.

**Todas las coordenadas de abajo están re-medidas hoy.** Las del cuerpo viejo eran de julio y
agosto; las que derivaron lo hicieron entre 1 y 340 líneas, y las sustituí (tabla al final). Y media sección
razonaba sobre `SplitSyncManager.swift`, **un fichero que ya no existe**.

## Lo que le pasa hoy a quien usa la app

- **Al buscar un grupo, escribir se siente pesado.** Cada letra que teclea rehace las cuentas de
  quién le debe a quién en todos los grupos que quedan en pantalla, incluidos los que no ha
  llegado a ver porque están más abajo. Con pocos grupos no se nota; con muchos, sí. *(Cuánto se
  nota no está medido — no hay perfilado, ver Riesgos.)*
- **Al abrir los ajustes de un grupo y quedarse ahí**, cada cambio que llega de otro miembro
  vuelve a leer todo el historial del grupo del disco y a rehacer los balances, sin agrupar
  ráfagas y sin parar cuando cierras la pantalla.
- Lo que **ya no** le pasa: la tab de Grupos y el detalle de un grupo ya no se recalculan una vez
  por cada cambio recibido. Cinco cambios seguidos se juntan en un solo recálculo.

## Ya está hecho (re-medido contra `553b91c9`)

| Lo que pedía el ticket | Dónde está hoy | Medido |
|---|---|---|
| Freno de 150 ms al sync remoto en la lista | `GroupsContainerView.swift:234-237` → `.onChange(of: sessionState.dataVersion) { viewModel.reloadAndRecalculate() }` | igual a la pista |
| Freno de 150 ms en el detalle | `GroupDetailView.swift:239-255`, con el **dismiss-first** delante (decide cerrar leyendo `group` directo, antes de programar nada) | la pista vieja decía `:211-221` |
| Maquinaria del freno en los VMs | `GroupsViewModel.swift:235-250` y `GroupDetailViewModel.swift:167-182` — `scheduleRecalculation(reload:)`, `Task.sleep(150ms)`, guards `isInBackground` + `applicationState`; props en `GroupsViewModel.swift:23-27` | — |
| Cancelar al salir, en las dos vistas | `GroupsContainerView.swift:218-221` y `GroupDetailView.swift:223-226` — `showNudgeBanner = false` **y** `viewModel.cancelRecalculation()`, conviviendo | igual a la pista |
| Suspender en segundo plano | `@Environment(\.scenePhase)` en `GroupsContainerView.swift:20` y `GroupDetailView.swift:49`; los `.onChange(of: scenePhase)` en `:222-233` y `:227-238` respectivamente | — |
| Estadísticas del grupo con freno | `GroupStatsView.swift:54-58` (período) y `:59-62` (moneda) llaman `viewModel.scheduleRecalculate()`, la versión **con** freno (`GroupStatsViewModel.swift:207-214`, 150 ms calc-only); `:53` cancela al salir | igual a la pista |
| No repintar si el número no cambió | `GroupsViewModel.swift:117` (`groups`), `:181` (`balancesByGroup`), `:195` (`globalSummary`); `GroupDetailViewModel.swift:267-268` (`balances`, `debts`) | derivaron +1, +1, +3 y +1 |
| Separar leer-del-disco de calcular | `GroupsViewModel`: `loadData()` :106-109 = `fetchData()` :112-142 + `recalculate()` :146-196. `GroupDetailViewModel`: `loadData()` :189-192 = `fetchData()` :196-227 + `recalculate()` :231-269 | — |
| Skeleton en el detalle | `GroupDetailViewModel.swift:41` (`isReady`, puesto en el `defer` de `:201`) consumido en `GroupDetailView.swift:119` (`.yalaSkeleton(!viewModel.isReady)`) | — |
| Las acciones del propio usuario siguen instantáneas | `GroupDetailViewModel`: `deleteExpense` :333, `removeOpeningBalance` :357, `confirmSettlement` :381, `rejectSettlement` :394, `deleteConfirmedSettlement` :414 — todas con `loadData()` directo, sin freno. Igual `GroupsViewModel.archiveGroup` :470 | la pista vieja decía `:221,245,271,285` |
| Spinner de primera carga en la lista | ya existía: `GroupsViewModel.swift:38` (`hasLoadedOnce`, puesto en `:123`) gatea el `ProgressView` de `GroupsContainerView.swift:53-58` | derivó de `:28`/`:103`/`:42-46` |

## Lo que sigue vivo

### 1. La lista rehace las cuentas de todos los grupos, y otra vez con cada tecla — NUEVO

**Medido:**

- `GroupsContainerView.swift:69-70` — la lista es `ScrollView { VStack(spacing: DS.Spacing.lg) { … } }`.
  **`VStack`, no `LazyVStack`**: SwiftUI construye todas las tarjetas, se vean o no.
- `:98-99` — `ForEach(viewModel.filteredGroups, id: \.id) { group in groupCardRow(group: group) }`.
- `:390` — dentro de `groupCardRow` (`:385`), el argumento `debts: viewModel.currentUserDebts(for: group)`.
  `GroupCardView.swift:19` lo recibe como `let debts: [GroupsViewModel.DebtRow]` — array llano, así
  que **se evalúa entero cada vez que se construye la fila**, no perezosamente.
- `GroupsViewModel.currentUserDebts` `:270-285` → `computeCurrentUserDebts` `:296` →
  `GroupBalanceService.calculateDebts` `:126-140`, que arma las deudas crudas recorriendo
  gastos × repartos y, **solo si el grupo tiene el toggle puesto**, llama la simplificación.
- `:73` — `searchText` es una propiedad de un VM `@Observable`, enlazada en `GroupsContainerView.swift:111-115`
  (`.searchable(text: $viewModel.searchText)`). `filteredGroups` (`GroupsViewModel.swift:85-90`) la lee.
- `:555-560` — `archivedGroupsSection` repite el mismo `groupCardRow` por cada grupo archivado
  cuando el usuario despliega «Ver archivados».

**Consecuencia (INFERIDA de esa estructura, no perfilada):** tocar una tecla del buscador cambia
`searchText` → invalida el body → el `VStack` no perezoso reconstruye **todas** las filas
supervivientes al filtro → `currentUserDebts` corre una vez por fila. Con el buscador vacío, el
conjunto es *todos* los grupos activos. Y como el `VStack` no es perezoso, también corre para las
filas que quedan fuera de la pantalla.

**Sobre el algoritmo cuadrático — dos correcciones medidas:**

- `DebtSimplificationService.swift:41` sigue autodocumentándose `O(n^2)` (greedy minimum cash
  flow), y `:42` es la función.
- **`SplitGroup.swift:25` → `var simplifyDebts: Bool = false`.** El cuerpo viejo decía que `true`
  «es el default»: **es falso**. Por defecto la tarjeta NO entra al cuadrático; entra al camino
  `consolidateDebts`. El cuadrático por tarjeta solo aparece en grupos donde el usuario encendió
  el toggle.
- Donde sí corre **siempre** es en el resumen global: `GroupBalanceService.swift:239-246`
  (`globalSummary`) llama `DebtSimplificationService.simplify(debts:)` **incondicionalmente**,
  cruzando todos los grupos, sin mirar el toggle de ninguno. Se invoca desde
  `GroupsViewModel.swift:186`, una vez por `recalculate()`.

**Sobre `fetchLimit` — medido, no hay ninguno en el camino de Grupos:**

- `GroupService.fetchAllGroups()` `:1244-1250` — sin predicate y **sin `fetchLimit`**. Su hermana
  `fetchActiveGroups()` `:1234-1241` sí filtra `!isArchived`, pero el VM usa la primera a
  propósito (necesita activos y archivados: son propiedades derivadas del mismo array).
- `GroupExpenseService`: `fetchExpenses` `:516`, `fetchAllShares` `:536`, `fetchSettlements`
  `:552` — predicate por zona, sin `fetchLimit`. Traen el historial completo del grupo, que es lo
  que el cálculo de balances necesita, pero sin techo.
- Los únicos `fetchLimit` de la zona son de búsqueda de una sola fila
  (`GroupService.swift:1350`, `:1406`, `:1446`; `GroupNotificationService.swift:237`).
- Atenuante medido: `GroupsViewModel.swift:130` tiene `guard !group.isArchived else { continue }`,
  así que gastos/repartos/liquidaciones solo se traen de los grupos activos. Los **miembros**
  (`:126`) sí se traen de todos, archivados incluidos.

**Camino más corto (sin plan cerrado):** `LazyVStack` en `:70` corta el trabajo de las filas que
no se ven. Cachear el resultado de `currentUserDebts` por grupo en el VM (que ya guarda
`expensesByGroup`/`sharesByGroup`/`settlementsByGroup` en `:46-48`) corta la repetición por tecla.
Las dos son independientes; la primera es de una línea y merece medirse antes que la segunda.

### 2. Los Ajustes del grupo recalculan sin freno ni cancelación — NUEVO

**Medido, `GroupSettingsView.swift`:**

- `:103-105` — `.onChange(of: sessionState.dataVersion) { _, _ in recomputeOutstandingDebt() }`.
  **Llamada directa, sin freno.** Es el mismo patrón que este ticket quitó de la lista y del
  detalle, en una vista que la tabla de archivos nunca listó.
- `:102` — `.onAppear { recomputeOutstandingDebt() }`.
- `:101` — el `.onDisappear` solo hace `saveIdentity()`: **no cancela nada**, porque no hay nada
  cancelable. Y no hay `scenePhase` en el fichero.
- `:626-665` — `recomputeOutstandingDebt()` hace un `fetchCount` de gastos y, si hay alguno,
  **cuatro fetch más** (gastos, repartos, liquidaciones, miembros) y un
  `GroupBalanceService.calculateBalances` completo. Es síncrono y en el hilo principal.

La hoja de ajustes se abre desde el detalle y **se queda montada** mientras el usuario cambia
nombre, moneda o tipo de reparto: durante ese rato, cada ráfaga de cambios remotos dispara la
cadena entera una vez por cambio. El comentario de `:620-625` explica por qué el resultado se
cachea en `hasOutstandingDebt` (para no refetchar en cada evaluación del body) — el hueco no es
ese cache, es que el *disparador* no tiene freno.

Aplicarle el mismo tratamiento que a las otras dos vistas es pequeño y encaja con lo ya hecho.

### 3. La validación cruzada del coalescing sigue sin hacerse

Era el único criterio de aceptación abierto hasta hoy (ver más abajo). Necesita dos aparatos con
el mismo grupo y ráfagas reales.

**Ojo con el motivo que el ticket daba para no hacerlo** («CKShare bloqueado en simulador»): ese
transporte murió. Medido — `AppBootstrapper.swift:1975-1986` responde a un enlace de CKShare que
«ese canal ya no existe» (Fase 3), y el commit `2f96ad84` (2026-08-06) borró el transporte CloudKit de
Grupos entero (su propio mensaje: «4.742 líneas en 14 ficheros: los 13 del transporte»). El canal de hoy es `GroupsSyncClient`. **Si el escenario es
reproducible ahora por otra vía, es cosa por decidir, no medida aquí.**

## Correcciones al cuerpo anterior

**`SplitSyncManager` ya no existe.** Borrado en `2f96ad84` (2026-08-06, «el transporte CloudKit se
lleva, al morir, la última forma de atrapar dinero») junto con `SplitSyncStartGate`,
`CKShareEntryHandler` y sus tests. `find` no encuentra el fichero; lo único que queda son
menciones en comentarios de otros ficheros. Todo lo que el cuerpo viejo razonaba sobre él —el
doble-load del `.onAppear`, la decisión técnica del Inc.1, el «`syncNow` no bumpea `dataVersion`
(`:857-860`)»— **queda sin sujeto y no debe reusarse como premisa.**

Lo que ocupa su lugar, medido: `refreshFromCloud(force:)` en `GroupsViewModel.swift:203-207` y
`GroupDetailViewModel.swift:135-139` llama `GroupsSyncClient.shared.syncNowFromUI()`
(`GroupsSyncClient.swift:487-489`) y después `loadData()`. **Y el cliente de hoy sí bumpea
`dataVersion`**: `GroupsSyncClient.swift:88-98` documenta un bump *por ciclo* cuando el pull
aplicó deltas que cambian contenido, con `SessionState.shared.incrementDataVersion()` por
defecto — y el propio comentario se apoya en este ticket («los VMs de Grupos ya debouncan
150 ms»). **⇒ la premisa que difirió D1 ya no se sostiene; quien retome esto debe volver a
decidir, no heredar.**

**El default de `simplifyDebts` es `false`, no `true`** (`SplitGroup.swift:25`). Ver el punto 1.

**El índice de cobertura sí se tocó.** El criterio de aceptación de abajo decía que
`lastVerified` no se bumpeó a propósito. Eso fue cierto el 3 de julio; hoy **ya no describe el
fichero**. Medido recorriendo el historial de `qa/coverage-index.json`:

- `groups-crud-balances-settlements` (deterministic): estaba en `2026-06-25` cuando se
  escribieron los tres incrementos; hoy marca **`2026-08-18`**, tras catorce cambios de valor
  intermedios de otros trabajos.
- `groups-stats-multicurrency` (agentic): estaba en `2026-06-25`; el commit `298c0a31`
  (2026-07-18) lo subió a **`2026-07-18`**, donde sigue.

Lo que **sí** sigue siendo verdad: ninguno de esos dos bumps verificó el coalescing de este
ticket, así que el criterio abierto lo sigue estando. Y el ratchet sigue sin backlog: el `_meta`
del índice declara `backlogBaseline: 0` y `deterministicSinXCUITest: 0` *(leído del fichero; no
corrí `qa/validate-coverage.sh`)*.

## Riesgos

- **Nada de esto está perfilado.** No hay una sola medida de tiempo en el ticket, ni antes ni
  ahora: lo que hay son hechos estructurales (no hay `LazyVStack`, no hay `fetchLimit`, no hay
  freno en Ajustes) y su consecuencia inferida. **`LazyVStack` es barato y seguro; cachear deudas
  por grupo no lo es** — merece una medida con Instruments antes, con un grupo de prueba grande.
- **Un cache de deudas por grupo puede quedarse viejo.** Si la clave de invalidación fuera solo
  el número de gastos/repartos/liquidaciones, una edición en sitio (mismo número, otro importe o
  el pagador cambiado) devolvería un resultado obsoleto en la tarjeta. La clave tiene que ser
  sensible a ediciones, o no hay cache. Los guards de igualdad ya puestos absorben el repintado,
  no el cálculo.
- **El freno en Ajustes debe respetar el mismo corte que el resto**: solo el disparador remoto
  (`dataVersion`) pasa por el freno; lo que el propio usuario toca sigue instantáneo. El
  `recomputeOutstandingDebt()` de `:102` (al abrir) y el pre-tap de archivar/borrar que describe
  `:620-625` **no** deben quedar detrás de 150 ms: el diálogo de deudas pendientes depende de ese
  valor en el momento del tap.
- **La lógica de cierre del detalle es lo más frágil de lo ya hecho.** `GroupDetailView.swift:244-252`
  decide cerrar leyendo `group` directo *antes* de programar el recálculo
  (`GroupDetailDismissDecision.shouldDismiss`, con `wasArchivedOnAppear` sembrado en el `.onAppear`
  de `:210`). Cualquier retoque del freno en esa vista tiene que preservar ese orden.
- **`GroupStatsViewModel` es un caso aparte y ya se resolvió como tal**: su freno
  (`:207-215`) es calc-only y no lleva los guards de `applicationState`/background, porque
  recibe los datos ya cargados del padre y no hace fetch propio. Está documentado en su propio
  comentario; no «le falta» el patrón completo.

## Acceptance Criteria

- [x] `loadData()` separado en leer-del-disco + calcular en los dos VMs, con la misma salida.
      _(Inc.1 — `6982383b`; re-medido: `GroupsViewModel.swift:106-109`/`:112-142`/`:146-196` y `GroupDetailViewModel.swift:189-192`/`:196-227`/`:231-269`)_
- [x] Los dos VMs tienen `scheduleRecalculation(reload:)` con freno de 150 ms y `Task` cancelable.
      _(Inc.2 — `55e17488`; re-medido: `GroupsViewModel.swift:235-250`, `GroupDetailViewModel.swift:167-182`)_
- [x] El `.onChange(of: sessionState.dataVersion)` de las dos vistas usa `reloadAndRecalculate()`,
      y el cierre del detalle sigue funcionando (orden dismiss-first).
      _(Inc.3 — `063f6aff`; re-medido: `GroupsContainerView.swift:234-237`, `GroupDetailView.swift:239-255`)_
- [x] El `.onDisappear` de las dos vistas cancela el recálculo **además** de resetear el banner.
      _(Inc.2 — `55e17488`; re-medido: `:218-221` y `:223-226`)_
- [x] Las dos vistas tienen `scenePhase` cableado a `setBackground(_:)`.
      _(Inc.2 — `55e17488`; re-medido: `GroupsContainerView.swift:222-233`, `GroupDetailView.swift:227-238`)_
- [x] Las acciones del propio usuario siguen instantáneas (no pasan por el freno).
      _(re-medido: los cinco `loadData()` directos de `GroupDetailViewModel` :336 :360 :385 :398 :418)_
- [x] `GroupDetailView` tiene skeleton de primera carga.
      _(Inc.1 — `6982383b`; re-medido: `isReady` en `GroupDetailViewModel.swift:41`/`:201`, consumido en `GroupDetailView.swift:119`)_
- [x] Build verde y unit tests verdes antes de cada commit incremental. _(consta en los tres commits de julio)_
- [~] El doble-load al entrar (leer del disco al fijar el contexto **y** otra vez tras el refresh
      remoto) sigue ahí, por decisión conservadora del owner.
      _(re-medido: `GroupsContainerView.swift:186` + `:206`; `GroupDetailView.swift:211` + `:214`)_
      **⚠️ La razón que lo difirió era una propiedad de `SplitSyncManager`, que ya no existe, y el
      transporte de hoy sí bumpea `dataVersion` — hay que volver a decidirlo, no heredarlo.**
- [ ] **La lista de grupos no rehace las deudas de las filas que no se ven, ni una vez por tecla
      del buscador.** _(NUEVO 2026-09-02 — ver «Lo que sigue vivo» punto 1)_
- [ ] **El `.onChange(of: dataVersion)` de `GroupSettingsView` (`:103-105`) tiene freno y
      cancelación, sin retrasar el valor que lee el diálogo de archivar/borrar.**
      _(NUEVO 2026-09-02 — ver punto 2)_
- [ ] Escenario cruzado: dos aparatos con el mismo grupo, 3-5 gastos rápidos en uno; el otro
      junta esos cambios en un solo recálculo. _(PENDIENTE — el motivo del bloqueo, «CKShare en
      simulador», caducó con el transporte; hay que replantear cómo se prueba.)_
- [~] `qa/coverage-index.json`: `groups-crud-balances-settlements` (deterministic, XCUITest) y
      `groups-stats-multicurrency` (agentic, device-qa) son las áreas afectadas. **Sus
      `lastVerified` ya no están donde los dejó este ticket** — hoy `2026-08-18` y `2026-07-18`,
      movidos por otros trabajos — pero ninguno cubre el coalescing, que sigue sin verificar.

## Historial de implementación (3 incrementos, julio 2026)

El patrón replicado es el de `PanelViewModel` / `PanelView`. **Las coordenadas de Panel que citaba
el cuerpo viejo derivaron todas** (por ejemplo, `scheduleRecalculation` no está en `:2322` sino en
`PanelViewModel.swift:2459`), así que las quité: hoy la referencia viva es el propio código de
Grupos, que ya lo implementa.

**Inc.3/3 — `063f6aff` — `perf(groups): debounce del sync remoto + dismiss-first + debounce en GroupStats`**
Las ráfagas de cambios remotos coalescen en un solo recálculo. En el detalle, reorden
**dismiss-first**. Pull-to-refresh y mutaciones locales siguen síncronos. `GroupStatsView` gana
freno calc-only. `/code-review high` cazó tres cosas que se arreglaron: fetch atómico en
`GroupDetailViewModel.fetchData` (no dejar miembros nuevos con gastos viejos), `defer { isReady = true }`
tras el intento (no dejar skeleton eterno si un fetch falla) y `syncCarouselPage()` movido a un
`onChange` reactivo sobre los códigos de moneda. Verificación: `/verify-ios` verde, 82 tests verdes.

**Inc.2/3 — `55e17488` — `refactor(groups): infra de debounce + lifecycle scenePhase`**
Maquinaria del freno en los dos VMs, más `scenePhase` y cancelación al salir en las dos vistas.
Sin cablear todavía el `onChange(dataVersion)`.

**Inc.1/3 — `6982383b` — `refactor(groups): separa loadData en fetch/calc + equality guards + skeleton en detalle`**
Refactor puro: separación leer/calcular, guards de igualdad, `isReady` en el detalle, y una
regresión de `isReady` en `YalaTests/GroupDetailViewModelTests.swift`. El cache por hash de
entradas se difirió: se confía en el freno más los guards de salida. Verificación: `/verify-ios`
verde, 40 casos verdes.

## QA Visual

### 2026-08-14 — simulador · **avance, NO cierra el ticket**

**Qué se verificó (verde):** que el freno de 150 ms no rompió el cierre del detalle, en **las dos
direcciones**. Es lo único que este escenario puede probar.

**Setup:** Yala Dev · Debug-Dev · iPhone 17 Pro · `-uitest -uitest-reset -uitest-skip-onboarding -uitest-pro
-uitest-seed grupos -uitest-deeplink groups`.

1. **El skeleton se levanta**: al abrir «Viaje a Cusco» aparecen `group_detail_fab_new_expense` y las filas
   de gastos; no se queda en gris. (`isReady` flipa.)
2. **Archivar → la app sale sola.** Ajustes del grupo → «Archivar grupo» → sale el diálogo de deudas
   («Hay deudas pendientes entre miembros. Si archivas, las deudas siguen vivas. ¿Continuar?») → confirmar.
   Se aterriza en la **LISTA**: existen `groups_fab_new` y la tarjeta «Viaje a Lima», **no** existe
   `group_detail_fab_new_expense`, aparece «Ver archivados (1)» y el total baja a «Te deben S/ 140,00».
   Esa aserción es la que importa: `GroupSettingsView.performArchiveToggle` llama a su propio `dismiss()`,
   que solo cerraría la sheet — ver «se cerró algo» no habría probado nada.
   ![[qa-groups-archivar-vuelve-a-lista-20260814-134428.png]]
3. **Desarchivar → NO expulsa.** Entrando al grupo archivado y tocando «Desarchivar grupo», la app **se
   queda dentro**: la sheet sigue abierta con el botón ya cambiado a «Archivar grupo» y detrás sigue el
   detalle (`group_detail_fab_new_expense`). Este paso es el que distingue la implementación correcta
   (`GroupDetailDismissDecision.shouldDismiss` cierra solo si se archivó DURANTE la sesión) de una que
   reaccione a «cambió el archivado» a secas.

**Lo que este QA NO prueba, y por qué el ticket sigue abierto:**

- **El criterio del coalescing sigue pendiente**: necesita 2 aparatos con el mismo grupo y ráfagas reales.
  **Cerrar el ticket con esto sería cerrar un criterio vivo.**
- El archivado de aquí es una mutación **LOCAL** con el objeto `SplitGroup` vivo en memoria. El caso que
  el `qa-notes` pide —**grupo archivado o eliminado REMOTAMENTE con el detalle abierto**— llega por merge
  y puede traer el modelo refaulteado: no queda cubierto.
- **El paso extra de scenePhase (background→foreground) no se pudo hacer con esta herramienta**, y conviene
  saberlo: `launch_app_sim` **no** trae la app al frente, la **mata y relanza** — y sin `launchArgs` arranca
  sin `-uitest`, así que apareció el Welcome Hero en vez del detalle. Para ejercitar
  `scenePhase .background → .active` hace falta otro mecanismo (o hacerlo a mano).
- El freno es de 150 ms: ninguna impresión de fluidez cuenta como evidencia en ninguna dirección.
- **Nada de este QA tocó los dos huecos nuevos** (la lista no perezosa y el `GroupSettingsView`): son
  del 2026-09-02 y no estaban identificados en agosto.

## Apéndice — coordenadas re-medidas (2026-09-02, `553b91c9`)

Lo que decía el cuerpo viejo → lo que hay hoy. **Sustituidas todas en el texto de arriba.**

| Cuerpo viejo | Medido hoy |
|---|---|
| `GroupsContainerView:193-195` (onChange dataVersion) | `:234-237` |
| `GroupsContainerView:190-192` (onDisappear) | `:218-221` |
| `GroupsContainerView:175-182` (onAppear) | `:185-207` |
| `GroupsContainerView:270` (currentUserDebts en la card) | `:390` |
| `GroupsContainerView:42-46` (gate del ProgressView) | `:53-58` |
| `GroupDetailView:211-221` (onChange dataVersion) | `:239-255` |
| `GroupDetailView:208-210` (onDisappear) | `:223-226` |
| `GroupDetailView:194-207` (onAppear) | `:209-222` |
| `GroupStatsView:53-57` / `:58-62` | `:54-58` / `:59-62` |
| `GroupsViewModel:28` (`hasLoadedOnce`) / `:103` | `:38` / `:123` |
| `GroupsViewModel:86-89` (`setContext`) | `:96-99` |
| `GroupsViewModel:93-160` (`loadData` monolítico) | ya partido: `:106-109` + `:112-142` + `:146-196` |
| `GroupsViewModel:97` / `:146` / `:153` (asignaciones) | `:117` / `:181` / `:195` |
| `GroupsViewModel:116` (guard archivados) | `:130` |
| `GroupsViewModel:36-38` (dicts por grupo) | `:40-41` y `:46-48` |
| `GroupDetailViewModel:100-103` (`setContext`) | `:124-127` |
| `GroupDetailViewModel:153-154` (`balances`/`debts`) | `:267-268` |
| `GroupDetailViewModel:135` (`calculateDebts`) | `:241-246` |
| `GroupDetailViewModel:221,245,271,285` (acciones locales) | `:336, :360, :385, :398, :418` |
| `GroupService:894-901` / `:904-910` | `:1234-1241` / `:1244-1250` |
| `GroupBalanceService:237-244` (`globalSummary`) | `:239-246` |
| `SplitSyncManager:857-860` | **el fichero no existe** (borrado en `2f96ad84`) |
| `PanelViewModel:2322-2337` y demás coordenadas de Panel | derivadas todas; retiradas del texto |

Iguales a la pista y confirmadas sin cambio: `GroupBalanceService.swift:12` (`MemberBalance:
Equatable`), `:22` (`GroupGlobalSummary: Equatable`), `DebtSimplificationService.swift:12`
(`Debt: Equatable`) y `:41` (el comentario `O(n^2)`).

migrated from YalaWiki Bugs/qa_groups-tab-no-perf-patterns.md @ 1934e8ad

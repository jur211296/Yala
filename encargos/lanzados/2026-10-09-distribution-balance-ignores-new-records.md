---
esfuerzo: high
---
# Estadísticas → Distribución actualiza el saldo al registrar o editar un movimiento, sin tener que cambiar de pestaña

## Contexto
Card del tablero `tablero-el-saldo-de-estadisticas-distribucion-no-ydrd` (lista para lanzar, vence 2026-10-10). Ticket: `tickets/backlog/el-saldo-de-distribucion-no-se-entera-de-un-registro-nuevo.md` (hallazgo de la review adversarial de `distribution-balance-kpi-skips-fx`). El triage de Frank del 2026-10-07 lo confirmó vivo en el código de 2.1.

Lo que ve el usuario: está en Estadísticas → Distribución con la métrica Balance, registra un ingreso de 500 y vuelve. El Panel ya dice 6.500; Distribución sigue diciendo 6.000 hasta que cambia de pestaña o de filtro. Al editar el importe de un movimiento existente es peor: ni el observador que hay salta.

Según el ticket (son pistas, verifícalas en este árbol antes de tocar nada):
- `CategoriesTabView` (`Yala/App/Views/Statistics/CategoriesTabView.swift`) recalcula en `calculateData()`, y sus disparadores son todos de filtro. El único que mira los datos es `.onChange(of: allTransactions.count)` (hacia la L227 en 2.1 de hoy) y solo llama a `recomputeSankey()`, no a `calculateData()`.
- Desde 2026-09-06 el hero muestra un saldo, que cambia con cualquier movimiento de cualquier fecha y cuenta; la dependencia se ensanchó y los disparadores no. `totalAmount` (el flujo) tiene el mismo agujero, preexistente.
- `DetailContainerView` ya tiene un `.onChange(of: sessionState.dataVersion)` que recarga el array, y un debounce de 150 ms del que `calculateData()` no cuelga. Atarlo a `dataVersion` sin más puede recalcular de más: medir antes (el cálculo cuesta ~15 ms con 5.475 movimientos).
- Relacionado, no se arregla aquí pero no se empeora: `tickets/backlog/distribucion-recalcula-dos-veces-por-toque-y-sin-debounce.md`.

CADENA tras cerrar `budget-interval-midnight-and-days-left` (PR #416 en cola de auto-merge a 2.1; card w7ai en done). No depende de ella: trabaja sin esperarla. Las cards high que quedan necesitan backend/deploy o están en manos de Jürgen; esta es la mejor medium sin decisión pendiente, sin deploy, sin secretos y sin gasto de API.

Para orientarte: `CLAUDE.md`, `.claude/rules/swiftui-ds.md` (precalcular en el ViewModel corta el live-binding), `.claude/rules/session-filters.md`, `.claude/rules/testing.md` y el ticket.

Antes de tocar UI, mira `~/Claude/referencias-ui/README.md` (referencias de patrones de la flota: inspiración, no copiar pantallas ni marcas) y respeta `.claude/rules/swiftui-ds.md`.

## Que se pide
1. Reproducir en el simulador: registrar un movimiento estando en Distribución con Balance, y editar el importe de uno existente → el hero no cambia.
2. Arreglar con la opción más robusta: que todo mutador de movimientos llegue al recálculo de la pestaña (hero, flujo y lo que dependa), colgado del debounce que ya existe en el contenedor, sin recalcular más veces por gesto que hoy. Mide las veces por gesto antes y después.
3. Si Tendencias u otra pestaña de Estadísticas tiene el mismo agujero al editar un importe, anótalo en un ticket aparte en `tickets/backlog/` con lo medido y no lo arregles aquí.
4. Test: el disparador del recálculo salta al registrar y al editar el importe (lógica pura o el test que ya cubra la pestaña), con un control rojo con el código viejo.
5. Si el cambio se ve en el simulador, deja `capturas/antes.png` y `capturas/despues.png` en el worktree, con rutas absolutas en el cierre. Si no se puede ver sin inventar datos, no hagas capturas y deja un guion de device-QA en `tickets/qa/`. Aquí: antes, el hero viejo tras registrar; después, el hero al día.
6. Anota lo medido en el ticket y muévelo según las convenciones del repo.
7. Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, limpieza). Al cerrar, mueve la card `tablero-el-saldo-de-estadisticas-distribucion-no-ydrd` a «in qa» asignada a jurgen si queda device-QA, o a «done» asignada a frank si no queda nada para él, con `tablero mover <id> --a "<estado>" --agente frank` y `tablero asignar <id> --a <quien> --agente frank`.

## Que NO hay que tocar
- El cálculo del saldo y del flujo en sí: solo cambia cuándo se recalcula.
- El doble recálculo por toque del ticket relacionado, más allá de no empeorarlo.
- El código muerto de OCR local `Yala/App/Services/ImageOCR/`.
- `qa.yml`, `nocturna-vigilante.yml`, `ping-avisador.yml` ni `avisar-grok-push-principal.yml`.
- Nada de marketing/ ni Web/.

Regla día/noche (hora de Lima): entre las 06:00 y las 21:00, si aparece una decisión de producto o de riesgo, pregúntala con AskUserQuestion. Entre las 21:00 y las 06:00, decide tú la opción recomendada y sigue, o difiere lo de alto riesgo dejándolo propuesto en el ticket (A/B/C con recomendación); en ese horario no uses AskUserQuestion.

## Pipeline de la Mini (serial, obligatorio)
1. Limpiar sims muertos, DerivedData de sesiones cerradas y cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar. El disco anda justo (~29 GB libres el 2026-10-09, por debajo del umbral de 32; si baja de ~20 GB, para, limpia y sigue).
2. Build con `xcodebuild -jobs 2` sin simulador booteado.
3. Boot de 1 solo simulador.
4. Tests.
5. Apagar y borrar ese simulador.
Prohibido solapar swift-frontend + SpringBoard + app + UITests.

Rebase al final, sin esperar a nadie: la sesión arranca ya sobre `origin/2.1` y trabaja sin esperar el CI de ningún otro PR. Justo antes de abrir su PR, hace `git fetch` y rebasa sobre `origin/2.1`, y resuelve ahí cualquier conflicto (el ruleset de `2.1` tiene strict=false). Si el rebase trajo cambios que tocan lo suyo, vuelve a compilar y a correr los tests afectados sobre el árbol rebasado, con un solo simulador.

DerivedData y cachés de XcodeBuildMCP: al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de worktrees retirados o ya mergeados, sin pedir aprobación. No toques los de otra sesión viva. Si el borrado falla, dilo en el cierre.

## Como se sabe que esta bien
- Registrar o editar el importe de un movimiento estando en Distribución actualiza el hero sin cambiar de pestaña.
- No se recalcula más veces por gesto que antes (medido, con números en el PR).
- Test con control rojo con el código viejo; builds `Yala` y `Yala Dev` verdes; capturas antes y después, o guion de device-QA.
- PR a 2.1 en auto-merge, ticket movido, card del tablero movida, Mini limpia (sim apagado y borrado, sin DerivedData de la sesión).

## Paso 0

Medido en este árbol (`f9e693e06`) antes de decidir:

- `CategoriesTabView.swift:227` — `.onChange(of: allTransactions.count) { recomputeSankey() }` es el único observador de datos de la pestaña; `calculateData()` (hero, flujo, pies, necesidades, período anterior) solo cuelga de filtros. El ticket es cierto.
- Todo mutador desemboca en `DetailContainerView.reloadAndRecalculate()`: `dataVersion` (`:207`, lo bumpean `NewTransactionViewModel`, `TransactionService`, la sync…) y los `onDisappear` de los sheets de alta y edición (`:727`, `:787`). Ese camino pasa por el debounce de 150 ms (`scheduleRecalculation`, `:625`) y acaba en `dataViewModel.loadData()`, el ÚNICO sitio donde se asigna `allTransactions`.
- Editar un importe no cambia la identidad de las filas: `loadData()` re-fetchea los mismos objetos, `fetched != allTransactions` da `false` y nada aguas abajo se entera.
- `TrendsTabView.swift:188` tiene el mismo agujero (`allTransactions.count` como único disparador de datos) → ticket aparte, no se toca.

Decisiones (autocontestadas, sesión autónoma; ninguna es de producto):

1. **Señal = contador de recargas en `DetailContainerViewModel`** (`dataGeneration`, `+1` al final de cada `loadData()` con contexto). Distribución observa ese contador y llama a `calculateData()` + `recomputeSankey()`. Cuelga del debounce que ya existe y corre DESPUÉS del fetch, así que lee el array fresco. Descartado: observar `dataVersion` en la pestaña (salta 150 ms antes de la recarga y lee el array viejo, y una ráfaga de bumps recalcula una vez por bump); observar el array (no ve una edición de importe); firmar importes en el body (O(N) por render).
2. **El observador de `allTransactions.count` se sustituye, no se suma.** El array solo cambia dentro de `loadData()`, así que el contador cubre todo lo que cubría `.count` y además las ediciones in situ. Sumarlo duplicaba el Sankey en cada alta.
3. **Al volver de segundo plano Distribución recalcula una vez** (el contenedor ya recarga ahí). Es correcto: con la app fuera pudo entrar sync.
4. **Test:** unitario sobre `DetailContainerViewModel` (el contador avanza al recargar tras un alta y tras editar un importe; `allTransactions.count` no se mueve con la edición, que es el porqué) + XCUITest de punta a punta (Distribución en Balance → «+» → alta → el hero cambia). Controles rojos: el unitario con el `+1` quitado, el XCUITest con el observador viejo.
5. **Para leer el hero en el XCUITest se añade `accessibilityIdentifier("stats_hero_amount")`** a su `AmountText`. No cambia nada visible.
6. **Veces por gesto:** contadores DEBUG temporales en `calculateData()`/`recomputeSankey()`, medidos antes y después (alta, edición de importe, cambio de período, entrar en la pestaña). No se commitean.

**Revisión de las decisiones 1 y 3 tras medir.** Con el `+1` en cada `loadData()`, el alta salía 2 recálculos y 2
Sankey (antes 0 y 1): el contenedor recarga dos veces por alta, al guardar (`dataVersion`) y al cerrar la pantalla de
éxito (`onDisappear`), y la segunda no trae nada. El Sankey pasaba de 1 a 2 por gesto. Ahora el contador **solo avanza
si la recarga trae algo**: otro `dataVersion` desde la última (lo suben todos los mutadores en sitio, comprobado en
`TransactionService`, `NewTransactionViewModel.save`, el borrado del editor y las ediciones masivas de
`RecordsViewModel`) o arrays distintos. Medido después: alta 1 / 1 / 3 (`calculateData` / Sankey / pases), abrir y
cerrar el formulario sin guardar 0 / 0 / 1, y volver de segundo plano sin datos nuevos ya no recalcula (la decisión 3
deja de aplicar).

**Asumido:** el pipeline pide «apagar y borrar ese simulador». Borrar el único iPhone 17 Pro de iOS 27.0 dejaría sin
destino al gate de las demás sesiones (`testing.md`, «El device DEBE casar con el runtime»), así que se apaga y se
hace `erase`, que libera su espacio y conserva el dispositivo.

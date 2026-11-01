---
esfuerzo: medium
release: no
---
# Los widgets miden los períodos con la misma hora con la que se guardó su foto

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `widgets-hora-de-la-foto` · Sesión cola **S35f1b** · al cerrar → **S35f2** (`widgets-tanda-3-categorias`).

## Contexto
Hallazgo de la review adversarial de la tanda 2 de widgets (PR #722, 31-oct). Regla de Jürgen del 2026-10-30: todo entra en 2.2 antes del barrido QA, nada a backlog.

Card: `tablero ver tablero-widgets-la-hora-de-la-foto-lastupdated-n-v8ou`
- Problema: `WidgetDataCache.updateCache` calcula los ocho períodos con `periodsNow` (Yala/Services/WidgetDataCache.swift, cerca de la línea 591) y luego escribe `lastUpdated` con un `Date.now` nuevo (cerca de la línea 638). Una foto que empieza a las 23:59:59 del último día del mes y se guarda pasada la medianoche hace que los widgets, que miden todo a la hora de la foto, lean «Este mes» como el mes siguiente: barras de Entradas y salidas vacías y comparaciones de Gastos y del neto contra el mes equivocado.
- Hecha cuando: `lastUpdated` es el mismo ahora que usan los períodos, con un test que lo fije; PR a 2.2 con auto-merge.

## Qué se pide
1. Verifica la causa en el código antes de tocar nada (las líneas son orientativas).
2. Un solo «ahora» para períodos y `lastUpdated`, con test unitario que reproduzca el cruce de medianoche.
3. Pasa la card a «in qa» de Jürgen o a done si no hay nada que mirar en el teléfono (con `--agente` de la sesión).

Si sale algo que no cabe aquí, crea cards en 2.2, «ready to launch», `cierra-sola`, prioridad alta, asignadas a frank (nada a backlog). Lista sus títulos en el PR y en el cierre.

Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
- Nada fuera de esta card. No rediseñes widgets (eso es la tanda 3).
- marketing/ ni Web/.
- No lances otras sesiones Yala. Ningún otro PR ni rama.

## Cómo se sabe que está bien
- La card cumple su «hecha cuando» y los tests están verdes.
- PR a 2.2 con auto-merge y la sesión termina con `/cerrar-total`.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

- **Causa verificada** en `Yala/Services/WidgetDataCache.swift`: `periodsNow = Date.now` (l. 591) y `lastUpdated: Date.now` (l. 638) eran dos relojes. Confirmado.
- **Un solo «ahora»**: `buildSnapshot(context:now:)` recibe `now` (por defecto `.now`, solo los tests lo fijan) y `lastUpdated` = ese `now`. Pasa de `private` a interno para el test.
- **Mismo patrón, misma función**: los dos fallbacks legacy (`thisMonthSummary`/`allTimeSummary`) también usan `periodsNow`; y `lastBuiltAt` en `updateCache` pasa a ser la hora de la foto (con el reloj nuevo, una foto de las 23:59:59 guardada a las 00:00:01 no se rehacía al volver a primer plano ese día).
- **Fuera**: los demás `Date.now` del builder (90 días de recientes, tendencias, presupuestos) no los leen los períodos ni `lastUpdated`; no se tocan.
- **Test**: unitario con store en memoria, `now` = 31-ene-2026 23:59:59; fija `lastUpdated == now` y que «Este mes» medido a la hora de la foto es el que calculó la caché.
- **QA de teléfono**: no hace falta (no se ve; el cruce de medianoche no se reproduce a mano). Card a done.

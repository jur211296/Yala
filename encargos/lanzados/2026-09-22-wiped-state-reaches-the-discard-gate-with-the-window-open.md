# El estado .wiped llega a la puerta de descarte con la ventana de sesión abierta

## Contexto
Cola A nocturna en serie tras merge de PR #206 (restore-retry ya no reabre la ventana cada 90 s). Residual de la review de #205 / `restore-session-window-has-no-reachable-ceiling`: el camino `.wiped` llama a `onStartFresh()` directo y deja la ventana de sesión huérfana y viva hasta el tope duro.

Ticket: `tickets/backlog/wiped-state-reaches-the-discard-gate-with-the-window-open.md` (medium). Rama base `2.1`.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, actualizar `docs/TICKETS.md` (índice al día), merge a `2.1` y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio (`--solo-crear` / fichero en tickets/) antes de cerrar. Solo parar ante decisión/acceso real. Board Yala = repo `tickets/` + `docs/TICKETS.md` (create/move en disco).

## Regla noche (21:00–6:00 Lima)
NO uses AskUserQuestion. Elige la opción recomendada abajo y sigue. Si el riesgo fuera irreversible / demasiado alto para asumir, aparca el ticket con nota y cierra sin inventar.

## Decisión de producto (recomendada — noches)
Objetivo: ningún camino a la puerta de descarte deja la ventana de sesión viva; el cancel del diálogo (si existe) sigue sin tocarla.

Recomendado: **apaga la ventana en el camino `.wiped` con el mismo verbo que ya usan los otros seis** (`ICloudRestoreSessionSignal.noteRestoreDiscardRequested` / el que dejó #205), sin exigir un diálogo de confirmación extra si el copy de `.wiped` ya declara que los datos se borraron aquí. Si al unificar es más limpio subir el apagado un nivel por el que pasen los siete caminos al *comprometer* el descarte (no al cancel), hazlo — siempre que cancel del diálogo no apague nada.

No inventes copy nuevo salvo que el test/UX lo exija; prioriza cerrar el agujero medido.

## Qué se pide
1. Lee el ticket completo y el código de `WelcomeRestoreView.wipedView` / `showStartFreshConfirm` / señal de sesión.
2. Implementa el fix según la decisión recomendada.
3. Tests: recorrido `.wiped` que hoy no existe; el escáner `discardingTheImportClosesTheWindowFromTheConfirmation` no basta solo.
4. Gate del repo; mutantes/adversarial según plantilla del carril.
5. Mueve el ticket a `qa` (o `done` si no hace falta QA manual) con guion si aplica; actualiza `docs/TICKETS.md` y ESTADO.
6. PR → merge a `2.1` → `/cerrar-total`.

## Qué NO hay que tocar
- `marketing/` / Web/
- Otros tickets de cola salvo residuales reales de camino (crear ticket propio)
- No relanzar restore-retry ni reabrir #206

## Cómo se sabe que está bien
- Criterios del ticket marcados
- Gate verde; índice TICKETS.md al día
- PR mergeado a 2.1 y `/cerrar-total` limpio

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.

---

## Paso 0 — decisiones (resueltas en autónomo, bypass; nadie estaba delante)

Medido antes de contestar: el ticket se escribió el 2026-09-21 y desde entonces entró #206, que
añadió `noteRestoreUnavailable()` a los dos `return` tempranos de `startSearch()`. **El agujero
sigue abierto**: ese verbo solo tira `parkedStartedAt` y `graceStartedAt` — por diseño y escrito
en su docblock, «no toca la ventana ni la titularidad». `restoreStartedAt` y `currentFlow` siguen
vivos, y `wipedView` sigue con `primaryAction: onStartFresh` (línea 694).

**D1 · ¿`.wiped` pasa a confirmar como los otros seis?** → **No.**
Su copy afirma que la persona borró sus datos EN ESTE dispositivo, y el escáner
`bothStatesThatClaimDataStillConfirm` ya fija por escrito —con su criterio medido— que `.wiped` es
el único desenlace concluyente por acto propio. Añadirle diálogo sería copy nuevo y una pregunta
por algo que él mismo acaba de decidir. El ticket lo deja abierto y la recomendación del encargo
también: «sin exigir un diálogo extra si el copy ya declara que los datos se borraron aquí».

**D2 · ¿Dónde va el apagado: en cada camino, o un nivel arriba?** → **Un nivel arriba**, en un
punto único `discardImportAndStartFresh()` por el que pasan los siete caminos al COMPROMETER el
descarte. Tres razones medidas, no de estilo:
  · el escáner `onlyOneProductionCallSiteTurnsItOff` exige **un solo call-site** de
    `noteRestoreDiscardRequested` — duplicar el par de líneas lo deja en el filo;
  · con un punto único, «todos los caminos apagan» pasa a ser comprobable con un conteo:
    `onStartFresh()` tiene que aparecer **una vez** en el fichero, y dentro de ese helper. Un
    octavo camino que llame directo lo caza el escáner el día que se escriba;
  · el `cancel` del diálogo no llega ahí, que es el segundo criterio del ticket.

**D3 · ¿Orden dentro del helper?** → **Apagar ANTES de `onStartFresh()`**, y fijado por rangos en
el escáner. Invertirlo es un mutante que compila y hace daño: `onStartFresh()` es lo que cambia de
pantalla, y el `.onDisappear` que viene detrás llama a `noteRestoreAbandoned`, que pone
`currentFlow = nil` — el descarte se encontraría sin dueño y su `guard` lo dejaría en no-op.

**D4 · ¿Qué red cubre el AC «un test que recorra el camino de `.wiped`»?** → **Las dos capas**,
porque ninguna sola basta y conviene no confundirlas:
  · **source-scan** (`RestoreStartFreshGateTests` + `ICloudRestoreSignalWiringTests`): es lo único
    que ancla la VISTA. Los dos lados son closures de SwiftUI que ningún unit test invoca.
  · **comportamiento** (`ICloudRestoreSessionSignalTests`): el recorrido de los cuatro pasos sobre
    la señal, que mide la INTERACCIÓN entre `noteRestoreUnavailable` (paso 3) y
    `noteRestoreDiscardRequested` (paso 4) — si el primero tocara la titularidad, el segundo sería
    un no-op y la ventana se iría viva a la puerta con el escáner en verde.

**D5 · ¿Estado final del ticket?** → **`qa`** con guion, no `done`. El recorrido pide dos
dispositivos (el sello del wipe viaja por `PreferenceSyncService`, una preferencia sincronizada) y
CloudKit no existe en simulador.

**D6 · ¿Review adversarial?** → **Sí.** Toca la ventana del guard de frontera de cuenta, que es
exactamente «sync donde un bug sale caro». Los cuatro tickets anteriores de esta familia cazaron
defectos míos en la review.

# El tope de 90 s cierra la ventana de sesión con el import todavía bajando

## Contexto
Cola A autónoma (serie). Acaba de mergearse a `2.1` el PR #201 (vuelta a iCloud: aviso al rendirse + verify/red en techo). Residual medium de #200 (`abandoned-restore`): `restore-timeout-closes-the-session-window-with-the-import-still-running` ya está en `tickets/in-progress/` e índice `docs/TICKETS.md` al día en `2.1`.

El daño es el mismo que cerró `force-fetch-and-wait-ignores-cancellation`, por otro eje: agotar el tope de 90 s con el import de CloudKit en marcha llama `noteRestoreFinished` y apaga `restoreStartedAt`, así el dueño legítimo cae en `.blockedForeignData` mientras sus datos siguen bajando. La pantalla `.importIncomplete` ya admite ese caso. Desde #200 existe `noteRestoreAbandoned` (suelta dueño sin apagar reloj).

Hora Lima diurna (6:00–21:00): puedes AskUserQuestion a Jürgen (vía aviso al bot Frank) si la semántica del reintento o del apagado no queda clara. Si es obvio con los criterios de abajo, sigue sin preguntar.

## Qué se pide
Arreglar el ticket `restore-timeout-closes-the-session-window-with-the-import-still-running` en rama de encargo, PR a `2.1`, gate, merge y `/cerrar-total`.

**Recomendado (si no hace falta AskUserQuestion):** cuando el tope se agota **con import en marcha**, no apagues la ventana de sesión como “finished”; usa la semántica de abandon/suelta (o equivalente medido) para que el dueño no quede bloqueado en su propia cuenta. Cuando el tope se agota **sin nada que importar**, sigue cerrando la ventana sin esperar caducidad. El reintento desde `.importIncomplete` no debe poder re-anclar el tope duro a voluntad.

Criterios del ticket (aceptación):
- Restore que agota 90 s con import en marcha → dueño legítimo no bloqueado en su cuenta.
- Restore que agota el tope sin nada que importar → ventana cierra sin esperar caducidad.
- Reintento desde `.importIncomplete` no re-ancla el tope duro a voluntad.

## Qué NO hay que tocar
- `marketing/` / Web/ (lane Lola).
- No abrir el medium hermano `reverse-verify-network-bucket-hides-a-definitive-server-no` ni los low de #201 salvo residual medido propio (entonces ticket con `--solo-crear` / fichero en `tickets/` antes de cerrar).
- No inventar PASS de device-QA; ticket a `qa` con guion si hace falta probar en iPhone.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, actualizar `docs/TICKETS.md` (índice al día), merge a `2.1` y `/cerrar-total` sin preguntar si corre el gate o el commit. Bugs/decisiones nuevas → ticket propio antes de cerrar. Solo parar ante decisión/acceso real de Jürgen. Board Yala = `tickets/` + `docs/TICKETS.md` (no inbox Tim / no kanban-inbox).

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory.

## Como se sabe que esta bien
Aceptación del ticket cubierta con tests/medición; PR mergeado a `2.1`; board (`tickets/` + `docs/TICKETS.md`) al día; `/cerrar-total` limpio.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

Hora Lima diurna, pero ninguna necesitó a Jürgen: las cuatro se contestan midiendo. El árbol completo,
con las alternativas descartadas y el porqué, vive en el propio ticket
(`tickets/qa/restore-timeout-closes-the-session-window-with-the-import-still-running.md`, sección
`## Paso 0`). Aquí el resumen y lo que la review corrigió.

**D1 · ¿Qué predicado separa «tope agotado con import en marcha» de «sin nada que importar»?**
→ Primera respuesta: el desenlace que ya viaja a la vista (`RestoreImportSettlement`). **La review la
tumbó y se cambió**: ese enum elige el COPY, y su `.inconclusive` agrupa dos poblaciones que a esta
pregunta contestan distinto —la que no vio un import y la que vio uno con error vigente, casi siempre
retriable y con CloudKit trayendo filas detrás—. ⇒ el criterio son los **dos términos crudos**
(`settled || !hasObservedImportActivity`) y vive en `ICloudRestoreInProgressLogic`, que es su
complemento exacto.

**D2 · ¿El error vigente de CloudKit cierra la ventana?** → Primera respuesta: sí, por coherencia con el
copy. **Falsa**: `isRetriable` da `true` hasta en su `default`, así que a un restore grande con red floja
se le apagaba la ventana con la descarga viva — el bug del ticket, sin arreglar, entrando por el copy.
Hoy no cierra; la acotan el asentamiento y el tope duro de 600 s.

**D3 · ¿Cómo se cumple «el reintento no re-ancla el tope duro»?** → Conservando la titularidad mientras
la persona siga dentro de Restaurar ⇒ el `noteRestoreAbandoned` se muda de `RestoreProgressView` a
`WelcomeRestoreView`. Medido que el ticket hermano se conserva. Residual que la review midió y que este
ticket NO cierra: salir de Restaurar y volver sí renueva el tope duro — ticket propio
`leaving-and-reentering-restore-renews-the-hard-cap`.

**D4 · ¿Qué salida apaga además del final de la espera?** → «Empezar desde cero», desde su propia
confirmación. Lo destapó la review como regresión de este mismo ticket: sin ella esa salida se llevaba la
ventana abierta hasta diez minutos, y ahí la persona acaba de declarar que descarta el import.

**D5 · ¿Verbo nuevo en la señal?** → No. `noteRestoreFinished` y `noteRestoreAbandoned` cubren; lo que
cambia es quién llama y cuándo.

# Gemelo de la ida: al subir a la nube, dos motivos definitivos turnándose ya no alargan la espera a tres días

## Contexto
Acaba de mergearse a 2.1 el ticket `alternating-definitive-causes-never-reach-the-short-ceiling` (PR #222): en la vuelta a iCloud, un tercer reloj de «cualquier motivo definitivo» hace que dos causas que se turnan salgan a los 15 min acumulados, no a las 72 h. La medición de ese encargo dejó abierto el gemelo de la ida: `snapshot-upload-alternating-definitive-causes-never-reach-the-short-ceiling` (backlog, high, área modo-nube/migración).

En la subida del snapshot (`uploadingSnapshot` / «Migrar a la nube»), el techo corto por causa (`CauseStallClock` en `MigrationRunner.observeSnapshotStall`) tira lo acumulado al cambiar de motivo. Dos definitivos turnándose (p. ej. `localFailure` al leer antes del push + `accountUnavailable` 403 del push, o `sessionExpired` + `localFailure`) reinician el corto para siempre y la salida cae en el plazo largo. El ticket ya documenta que es alcanzable en la subida; en los pasos sin cifra (22/35/80 %) se midió y no es alcanzable de forma sostenida — no los toques.

Quién recibe esto arranca en contexto limpio: lee el ticket en `tickets/backlog/snapshot-upload-alternating-definitive-causes-never-reach-the-short-ceiling.md` y la resolución del gemelo cerrado en `tickets/done/alternating-definitive-causes-never-reach-the-short-ceiling.md`.

## Que se pide
Cierra el ticket aplicando el **mismo patrón** que la vuelta (opción ya decidida, robusta):

1. Tercer reloj de «cualquier motivo definitivo» en el journal de la subida (`CauseStallClock` con una sola clave; campos aditivos en `MigrationState` + bump de schema si hace falta), que suma entre motivos distintos, se pausa sin motivo y se reinicia al cambiar de fase.
2. La máquina decide el techo corto (15 min) contra ese reloj; el reloj por causa se queda solo para elegir el copy (`snapshotExitReasonRaw` / equivalente).
3. Criterios del ticket:
   - Dos motivos definitivos turnándose en la subida salen a los 15 min acumulados, no a las 72 h.
   - Un `localFailure` aislado tras horas sin red sigue sin cobrar esas horas.
   - El copy de la salida no afirma un motivo que no llegó solo al plazo (texto genérico si ninguno llegó solo a 900 s).
4. Tests que cubran la alternancia y el caso aislado; mutantes/adversarial del estilo del gemelo si aplica.
5. Mueve el ticket a in-progress al empezar; al cerrar: docs (`docs/TICKETS.md`, ESTADO si toca), board del repo, PR a 2.1, merge cuando el gate lo permita, `/cerrar-total`.
6. Bugs o decisiones nuevas de camino → ticket propio (`--solo-crear`) antes de cerrar; no los dejes solo en ESTADO.

## Decisiones (ya tomadas — no reabrir)
- Producto: se cierra el agujero (no se aceptan las 72 h). Misma razón que en la vuelta: el techo corto existe porque 72 h delante de algo definitivo es demasiado.
- Forma: tercer reloj de definitivo acumulado, no simplificar quitando el reloj por causa.
- Ante duda de implementación, elige la opción más robusta / buena práctica, nunca la más simple.
- Horario diurno (Lima): si aparece una decisión de producto o acceso NUEVA que no cubra lo anterior, usa AskUserQuestion. No repreguntes la decisión del gemelo.

## Que NO hay que tocar
- `marketing/` ni Web/ (lane Lola).
- Los pasos de activación sin cifra (22 %, 35 %, 80 %) — medidos como no alcanzables de forma sostenida para este agujero.
- No reinventar el techo de la vuelta; reutiliza el patrón del gemelo cerrado.
- No suspendas el gate «>3 files → ¿Sigo?» / wait for approval: en esta cola autónoma ese gate está anulado; implementa hasta gate/PR/merge/`/cerrar-total` sin pedir permiso para seguir.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, actualizar `docs/TICKETS.md`, merge y `/cerrar-total` sin preguntar si corre el gate o el commit. Solo parar ante decisión/acceso real (AskUserQuestion diurno). Bugs/decisiones nuevas → ticket propio antes de cerrar. Board Yala: mueve tú el markdown en `tickets/` (Tim no aplica).

## Como se sabe que esta bien
- Criterios de aceptación del ticket marcados.
- PR mergeado a 2.1 con tests verdes del gate (UI advisory no bloquea).
- Ticket en done (o qa solo si hace falta device-QA real; este arreglo es de reloj/código — preferir done sin iPhone si no hay guion manual útil).
- `/cerrar-total` limpio; `docs/TICKETS.md` al día.

## Avisos al bot dueño (Frank)
POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el ticket y vas a /cerrar-total — incluye en el aviso un resumen corto de cierre en lenguaje de usuario (qué se hizo), no solo «cerré»;
  (4) acabaste un tramo y no tienes siguiente paso claro (aunque no haya pregunta formal) — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build que vas a reintentar, ni ruido de CI advisory.

## Paso 0 (Frank, 2026-09-23)

Decisiones de implementación, auto-contestadas (el encargo ya fija producto y forma):

- **Campos**: `snapshotStallDefinitiveAt` + `snapshotStallDefinitiveAccruedSeconds`, con prefijo `snapshotStall` a
  propósito: `CloudSyncSchemaParityTests` deriva la familia por ese prefijo y `clearSnapshotStallCeiling()` los borra
  con los otros cuatro (entrar/salir de la fase, página confirmada, reset, normalización). Schema **12 → 13**.
- **Una sola implementación del reloj de lo definitivo**: helper estático en `CauseStallClock` que llaman la vuelta y la
  subida. La regla de área dice «no lo copies a una tercera etapa: llámalo»; la función de la vuelta pasa a delegar en
  él, sin cambiar su comportamiento (sus tests y mutantes lo fijan).
- **Máquina**: el evento `snapshotUploadStalled` cambia `causeStalledSeconds` por `definitiveStalledSeconds`; el
  predicado `snapshotCauseCeilingReached` renombra su parámetro a `stalledSeconds` (lo consultan máquina y runner con
  relojes distintos), igual que en la vuelta.
- **Copy**: sigue contra el reloj de causa (`snapshotExitReason`). Con motivos mezclados sale `stalled` («dejó de
  avanzar»), el genérico.
- **Canario** `cloudSnapshotUploadWaiting` sin cambios (mismo razonamiento que la vuelta). El breadcrumb sí gana
  `definitive=`.
- **Device-QA**: no. El escenario no se monta a voluntad en un iPhone; ticket a `done`.
- **No se tocan** los pasos sin cifra (22/35/80 %) ni `marketing/`.

**Addendum (review):** el «texto genérico» `stalled` de la subida dice «lleva días sin avanzar», falso a los 15 min.
Pregunta a Jürgen (AskUserQuestion, 2026-09-23): eligió un motivo propio, `mixedCauses`, con texto sin plazo en los
16 locales.

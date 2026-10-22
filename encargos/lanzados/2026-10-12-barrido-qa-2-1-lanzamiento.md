---
esfuerzo: high
---
# Barrido de QA 2.1: la lista final para que Jürgen haga hoy todo el QA y se lance 2.1

**Card:** `tablero-barrido-de-qa-2-1-lista-final-para-jurge-bapd` · **Prioridad:** high · Pedido de Jürgen (12-oct 06:20): hoy hace todo el QA sí o sí y quiere lanzar 2.1 lo antes posible. Repite el barrido anterior (`tablero-barrido-de-qa-dejar-solo-lo-imprescindib-d9xa`, entregable `docs/qa/tanda-qa-jurgen-2.1.md`) con lo que entró desde entonces.

## AUTONOMÍA (léelo primero)
Jürgen está dormido. **Nunca uses AskUserQuestion y nunca esperes respuesta**: decide tú, apunta la decisión en el PR y cierra de forma autónoma hasta `/cerrar-total`. NO uses el simulador entre 9:00 y 11:00 Lima; un simulador como máximo y `xcrun simctl shutdown all` al terminar.

## Paso 0 (antes del barrido)
Desde una rama al día con origin/2.1 (`git fetch origin && git rebase origin/2.1`), copia los 4 `.ckdb` refrescados tras el deploy de CloudKit del 2026-10-12 desde `/Users/jur/Yala/Cloudkit Schemas/` (yala-production, yala-development, yala_dev-production, yala_dev-development) sobre `Cloudkit Schemas/` del worktree, commitea `docs(cloudkit): export real del esquema personal tras el deploy del 2026-10-12` y corre `-only-testing:YalaTests/PersonalCloudKitSchemaParityTests` (verde esperado; si falla, para y repórtalo). Card o2li.

## Qué se pide
1. Revisar TODAS las cards `in qa` de Yala (`tablero listar --proyecto Yala --todas`) y todos los tickets de `tickets/qa/` en `origin/2.1`, y decidir por cada uno **done** o **mantener**, con una línea de motivo.
2. Revisar lo que entró en 2.1 desde el barrido anterior: PRs **#451 a #466** y los que entren mientras corre la sesión (`gh pr list --base 2.1 --state merged`). Por cada uno: ¿necesita validación real de Jürgen en dispositivo? Si sí y no tiene ticket en `tickets/qa/`, créalo con guion. Incluye seguro:
   - **#454** — notificación tocada con Yala cerrada del todo (presupuesto → Presupuestos; pago planificado → Pagos planificados). Guion: `tickets/qa/notification-delegate-assigned-after-launch.md`. El bug nunca se reprodujo: el QA en iPhone es la única verificación real.
   - **#456** — compartir varias fotos (3, más de 10 con aviso, 10 fotos grandes de cámara). Guion: `tickets/qa/sharing-several-photos-hides-yala.md`.
   - **#441** — guion de foto compartida pendiente en `tickets/qa/share-image-reading-does-not-always-start.md`.
   - La card `tablero-receiptdropuitests-test-lockedpdf-falla-pbwh` (posible crash de UIKit en iPad al cerrar el campo de contraseña de un PDF): si se reproduce en iPad real, es bug de producto.
   - Las que estén en las sesiones de la cola si ya entraron (0ekl pestaña Panel, msje foto compartida con hoja abierta).

**Pasa a done** si: alcanza con el QA hecho en simulador o con tests (cita el test o la captura); no requiere validación real de Jürgen; es imposible o muy difícil de reproducir a mano; o es un edge case demasiado remoto.
**Nunca pasa a done** sin evidencia fuerte (tests de integración, goldens, humo en staging, capturas del flujo real): dinero real, migraciones, borrado de datos, la nube con dos dispositivos, compras.
Cards «Decidir …» en in qa: si la decisión está tomada e implementada, done; si no, mantener y decirlo.

## Cómo
1. No hace falta simulador; úsalo solo para verificar algo puntual, respetando la carga.
2. En un solo PR a 2.1: `git mv` de `tickets/qa/` a `tickets/done/` con la línea «Cerrado en el barrido de QA 2026-10-12: <motivo>», tickets de QA nuevos con guion, y `docs/TICKETS.md` al día.
3. En el mismo cierre, cards a done con `tablero mover <id> --a done --agente frank` y el motivo en la nota. Las que se mantienen siguen in qa asignadas a `jurgen`.
4. Entregable: actualizar `docs/qa/tanda-qa-jurgen-2.1.md` (y copia en `~/Claude/entregas/`) como **lista ordenada para hacerla hoy**:
   - agrupada por lo que necesita: **un iPhone**, **iPad**, dos iPhone con el mismo iCloud, TestFlight, cuenta Pro;
   - dentro de cada grupo, ordenada por riesgo para el lanzamiento (lo que bloquea 2.1 primero);
   - por item: id de la card, título, guion corto (3 a 6 pasos con el resultado esperado) y minutos estimados;
   - **tiempo total estimado**, y qué items bloquean el lanzamiento de 2.1 y cuáles no;
   - tabla de lo que pasó a done (id, título, motivo).
5. En el aviso de cierre: cuántas pasaron a done, cuántas quedan, el tiempo total y la lista de bloqueantes de 2.1.

## Reglas de siempre
- Arranca sobre `origin/2.1`. Justo antes del PR: `git fetch` y rebase sobre `origin/2.1`, resolviendo conflictos ahí.
- Tickets nuevos al tablero antes del `/cerrar-total`: si un ticket nuevo no tiene card, `tablero crear --proyecto Yala --agente frank --asignado frank --estado backlog --prioridad <la del ticket> --version 2.1 --titulo "<título claro en español neutro>" --contexto "<una línea>" --enlace "Ticket|https://github.com/jur211296/Yala/blob/2.1/tickets/backlog/<slug>.md"`. SIN --fecha.
- Sin deploy, sin secretos y sin decisiones de UI de Jürgen: si algo lo pide, para y anótalo en el cierre.
- Cierre: `/cerrar-total` autónomo (PR a 2.1 en auto-merge, limpieza de simulador, worktree y DerivedData).

## Carga de la Mini (OBLIGATORIO)
- Todo xcodebuild va con `nice -n 10 xcodebuild -jobs 2 ...`; antes de cada build, load < 8.
- Nunca dos builds o tests a la vez; pipeline serie: build → 1 simulador → tests → erase.
- Nunca pases xcodebuild por `| head`: escribe a un log y lee el log. Los `-only-testing:` en un array de zsh.

## SIMULADORES iOS EN LA MINI (regla nueva, 2026-10-12)
Si usas el simulador o XCUITest: nunca más de un simulador encendido a la vez, y al terminar (y antes de cerrar) ejecuta `xcrun simctl shutdown all`. La Mini se cayó por memoria el 2026-10-12 ~13:30.

## Paso 0 (resuelto en autónomo, 2026-10-12 22:50 Lima)

- **D1 · `.ckdb`.** Copiados los cuatro de `~/Yala/Cloudkit Schemas/`. Los dos `yala-*` ya eran idénticos a `origin/2.1`; cambian solo los dos `yala_dev-*` (índices `QUERYABLE` en `CD_syncID` y `___recordID`, y alineación). Commit propio.
- **D2 · Criterio de done.** El del encargo. Un ticket que solo cambia una pregunta o quita un borrado, con test de integración y mutante, cuenta como evidencia fuerte, igual que en el barrido del 10-oct.
- **D3 · iPad.** `46n1` pasa a done: el XCUITest en el iPad simulado es rojo→verde y el arreglo es la identidad de una vista. El grupo iPad queda con el PDF con contraseña (`pbwh`), con ticket nuevo en `qa`.
- **D4 · Cards `blocked` que piden los dos iPhone** (`e1ah` unirse a un grupo, `d44s` preferencias). No las pide el encargo, pero son QA de Jürgen con el mismo montaje: entran en la lista sin cambiar de estado. `e1ah` cuenta como bloqueante: nadie ha unido a dos personas por el canal backend en producción.
- **D5 · Notificaciones.** `bdxj` (#454) y `scheduled-payments-notif-dedup` se prueban juntas: el resumen agendado llega con la app cerrada y su toque es el toque en frío.
- **D6 · #427 sigue en conflicto.** No lo rebaso: es código de otra sesión. El paso que depende de él queda marcado.
- **D7 · Sin simulador.** Solo el test de paridad del esquema.

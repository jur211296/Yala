# Dar salida a quien tiene cambios de grupo sin subir y no puede volver a entrar, sin subirlos firmados por otra cuenta

## Contexto
Cola A (sync/cloud con riesgo real, una sesión a la vez). Ticket: `tickets/backlog/groups-outbox-rows-without-a-live-session-have-no-exit.md` (medium). Hoy, si la sesión de grupos caducó con filas vivas en `GroupSyncOutbox`, «Cerrar sesión» se bloquea con `BlockReason.sessionExpired`: quien no puede volver a entrar (cuenta borrada, perdió el correo) se queda sin forma de cerrar sesión en ese teléfono. Además el outbox no tiene dueño: si entra OTRA cuenta, esas filas se suben firmadas por ella. Lee el ticket, la D15 del paso 9 (`session-exits-one-verb-per-session`) y la salida de emergencia del export, que es el modelo a seguir.

## Decisiones ya tomadas (Frank, por norma de opción robusta; no las vuelvas a preguntar)
1. Salida para quien no puede entrar: descarte AVISADO, nunca silencioso. El bloqueo actual sigue siendo el camino por defecto («vuelve a entrar para subirlos»), pero se añade una salida explícita tipo emergencia del export: cuenta cuántos cambios de grupo se perderán, pide confirmación destructiva y solo entonces descarta y cierra.
2. El outbox tiene dueño: cada fila queda ligada a la cuenta que la creó. Si entra otra cuenta, esas filas NO se suben con ella: se retienen para su dueño o se ofrecen al descarte avisado. Nunca se reatribuyen en silencio.
Copy en la línea de la emergencia del export y en todos los idiomas que ya tenga la app.

## Que NO hay que tocar
- No cambiar el resto de salidas del paso 9 ni la regla «nunca descarta sin avisar».
- Nada del carril adaptativo: hay otra sesión en paralelo (`iphone-large-text-sizes-break-layouts`). No uses simuladores `YalaLane-Adapt-*`, ni `simctl shutdown all`, `erase all` o `killall Simulator`.

## Como se sabe que esta bien
- Tests que fijen: caducada con filas y puede entrar (sube y cierra, sin cambio); caducada sin poder entrar (descarte avisado con conteo correcto, cierra); entra otra cuenta (no sube filas ajenas); cancelar el descarte no borra nada.
- Gate verde (UI tests del CI advisory; contrasta con la base). PR contra 2.1 mergeado, ticket a qa con guion corto de device-QA o a done si los tests lo cubren, `docs/TICKETS.md` al día, residuales a ticket propio.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, PR contra 2.1, merge, board del repo (`tickets/` y `docs/TICKETS.md`) y `/cerrar-total` sin preguntar. Es horario diurno: AskUserQuestion solo si necesitas acceso, un dispositivo o una decisión demasiado importante para asumirla; lo demás lo decides tú con la opción recomendada. Si trabajas pasadas las 21:00, no preguntes: elige lo recomendado o aplaza a ticket.

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando: (1) necesitas una decisión de producto o de acceso de Jürgen; (2) abriste el PR o dejaste preview/artifact listo; (3) terminaste el ticket y vas a /cerrar-total, con un resumen corto de cierre en lenguaje de usuario; (4) acabaste un tramo y no tienes siguiente paso claro, una vez y no en bucle. NO avises por un test rojo que vas a reclasificar, un build que vas a reintentar ni ruido de CI advisory.

## Paso 0 (Frank, 2026-09-28, auto-contestado en MODO AUTÓNOMO)

Medido antes de decidir: la salida «Cerrar sesión y perderlos» YA existe para el teléfono sin App Attest
(`CloudSessionSignOut.exitDiscardingUnsyncedGroups`, aviso con cifra + botón destructivo, lo aceptado por FILA).
Es el molde de la emergencia del export, así que se EXTIENDE en vez de escribir una quinta salida.

1. **Qué motivos abren la salida.** `.sessionExpired` (celdas C, D, F), `.cloudSessionExpired` en el paso 2 del
   cierre en la nube (solo filas de GRUPOS) y un motivo nuevo, `.groupsChangesFromAnotherAccount` (la sesión viva es
   de otra cuenta). El attest sigue igual. **Fuera**: los cambios PERSONALES de la nube con la sesión caducada (su
   salida solo existe para el attest) → residual a ticket.
2. **Forma del aviso.** La del attest: un aviso con la cifra de las MISMAS filas que se aceptan, «Ahora no» como
   salida por defecto (no pierde nada) y «Cerrar sesión y perderlos» destructivo. Sin «¿seguro?» extra: el cierre ya
   se confirmó en la hoja de alcance, y la del export/attest son el molde pedido.
3. **Lo aceptado recuerda su CAUSA.** Retomar solo sigue si el bloqueo sigue siendo de la misma causa (sin sesión,
   otra cuenta, attest). Si la persona vuelve a entrar y la subida falla por otra cosa, se bloquea como siempre.
4. **Dueño por fila.** `GroupSyncOutbox.ownerUserID` lo estampa el drain. Regla pura por transacción: con sesión, su
   `sub`; sin sesión, el último dueño que vio el canal (`GroupSyncCursor.outboxOwnerUserID`, mismo store y misma vida
   que el outbox); y si la sesión cambió de cuenta desde el último drain, lo escrito ANTES del inicio de sesión nuevo
   (`SessionSignInBoundary`, lo apunta `CloudAuthService` al entrar) es del dueño anterior. Sin testigo, del anterior
   (retener gana a reatribuir).
5. **Subida.** `pushPending` solo sube filas cuyo dueño es la sesión. Las de otra cuenta, y las sin dueño probado, se
   quedan: nunca se re-sellan. Filas de un build anterior: toman el dueño de su entrada del espejo del App Group, que ya
   guardaba el `sub`; sin entrada, se quedan sin dueño (fail-closed, residual a ticket).
6. **Salidas.** El push-all del cierre bloquea con `.groupsChangesFromAnotherAccount` cuando solo quedan filas ajenas;
   los cierres ofrecen perderlas, el desasociar no (como el attest), «Empezar de cero» sí (como `.sessionExpired`).
   Puerta de Grupos del Welcome: solo al dueño, nunca al invitado (molde del attest).
7. **Copy** en los 16 `.lproj` con `add-l10n-key.sh`; un texto común para «sin sesión» y «otra cuenta» (los dos se
   arreglan entrando con la cuenta que los apuntó) y uno propio en la nube que nombra la puerta.
8. **Canarios**: los del attest no cambian (su serie); nuevos `groupsSignOutLossOffered/Discarded` con `cause=`.
9. **Review adversarial**: sí (sync + frontera de cuenta).

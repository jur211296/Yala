# El paso 1 del cierre en la nube propaga el motivo real (transitorio / sesión caducada), no «revisa tu conexión»

## Contexto
Cola A autónoma (Frank). Cierre limpio de `cloud-signout-with-the-engine-stopped-says-check-your-connection` (PR #251, mergeado a 2.1): el paso 1 ya no escribe `.permanent` a mano para el motor parado; llama a `CloudSignOutFlowLogic.personalPushAllShownReason`, que deja pasar esos tres motivos y colapsa el resto. Este ticket es el hermano: cuando `pushAllPendingForSignOut` trae `.transient` (red/5xx/decode) o `.sessionExpired` (401), el paso 1 aún los tira al aviso permanente «revisa tu conexión».

Ticket: `tickets/backlog/cloud-signout-collapses-the-personal-push-all-reason-into-permanent.md`.
El fragmento de «Lo medido» con `reason: .permanent` es anterior al #251 — lee el código actual y el ticket actualizado.

Misma forma del bug que se cerró el 2026-09-14 en el paso 2 (grupos). El camino personal es otro objeto; el patrón de solución ya existe.

## Decisión de producto (ya tomada — no preguntes)
Opción robusta, misma lógica que grupos el 2026-09-14:
1. Propagar el motivo clasificado: `.transient` → aviso honesto de reintentar más tarde (`.uploadRetryLater` u equivalente existente).
2. Propagar también `.sessionExpired` con el aviso que diga que la sesión caducó (no «revisa tu conexión»).
3. Reusar `CloudSignOutFlowLogic` (función pura / gemela si hace falta) — exhaustiva y probada; no inventar un tercer clasificador.

No hace falta AskUserQuestion por techos/copy de este cierre: la decisión de arriba basta. Solo AskUserQuestion si aparece un acceso/secreto o una decisión irreversible que no cubra esto (horario 06:00–21:00 Lima).

## Que se pide
1. En `performCloudSecureSignOut` paso 1 / motor personal: dejar de colapsar todo a `.permanent`; propagar transient y sessionExpired con el aviso correcto.
2. Tests (unit / lógica pura) que fijen: 5xx/red → retry later; 401 → session expired; no «revisa tu conexión» en esos casos.
3. Board: ticket a done (o qa solo si el cierre exige device); actualizar `docs/TICKETS.md`. Residuales → ticket nuevo antes de cerrar.
4. PR a `2.1`, merge cuando el gate lo permita, `/cerrar-total`.

## MODO AUTÓNOMO HASTA TERMINAR
La regla del repo «wait for approval si >3 files» / «¿Sigo?» tras el plan queda SUSPENDIDA en este encargo. Implementa, gate, commit, board, PR, merge y `/cerrar-total` sin pedir permiso para seguir. No preguntes «¿le doy?» ni apruebes el plan con Jürgen.

## Que NO hay que tocar
- `marketing/`, Web/, clinicas-dentales-bi.
- No reabrir el ticket del motor parado (#251) salvo bug real descubierto.
- No relajar el clasificador de grupos; este es el espejo personal.
- No inventar copy nuevo si ya hay claves L10n que encajan.

## Como se sabe que esta bien
- Con cambios personales pendientes, un fallo transitorio del push-all de cierre ya no muestra «revisa tu conexión»; muestra reintentar / esperar.
- Un 401 de sesión caducada nombra la caducidad, no la conexión.
- Tests verdes del clasificador / flujo.
- Ticket en disco al día + índice `docs/TICKETS.md`.
- PR mergeado a `2.1` y `/cerrar-total` limpio.

## Paso 0

Medido en el árbol del encargo (`0d423b00`), no heredado del ticket:

- **El 401 ya llega separado.** `SyncPushClient` devuelve `.sessionExpired` y `classify` lo deja pasar; solo lo colapsaba
  `personalPushAllShownReason`. ⇒ viaja tal cual y su aviso es `groups.errors.sessionExpired` («Tu sesión caducó. Vuelve a
  iniciar sesión…»), que no nombra grupos. La puerta existe: «Dónde viven tus datos» ofrece «Inicia sesión» con el motor
  en `.stoppedUntilSignIn`.
- **Lo pasajero NO llega separado.** `pushAllForSignOut` pasa `uploadFailed: false` —el propio comentario dice que el día
  que se arregle este ticket, ahí se cablea el testigo—, así que un 5xx o sin red es `.transient` y dejarlo viajar diría
  «un momento más, espera unos segundos»: la mentira que se retiró en grupos el 2026-09-16. ⇒ **testigo positivo** en el
  motor personal (molde `GroupsSyncClient.stoppedByFailedUpload(for:)`): lo enciende `SyncPushClient` donde habló con el
  servidor y falló (red, no-HTTP, decode, 5xx/429/4xx, 409 no-reversa, 401 del attest, token que no se renueva con la
  sesión guardada) y NO en lo del teléfono (`buildDelta`, el corte `continueWhile`). La puerta de attest del ciclo con un
  `.transient` también lo enciende: el ciclo paró sin poder subir y esperar segundos no lo cura.
- **La copy de `.uploadRetryLater` dice «tus grupos».** No encaja con cambios personales, y no hay otra clave que lo
  diga. ⇒ motivo nuevo `.personalUploadRetryLater` (molde `.personalAttestUnavailable`), que `personalPushAllShownReason`
  traduce desde `.uploadRetryLater`, con texto nuevo en los 16 locales calcado del de grupos: «Tus últimos cambios no
  llegaron a la nube. Siguen guardados en este teléfono y no se pierden; inténtalo de nuevo en un rato.» Cierto para toda
  la población que lo ve: el cierre bloquea sin borrar y las filas siguen en el outbox.
- **`.transient` sin testigo viaja tal cual** («un momento más»): el tope de iteraciones con el outbox drenando, un fetch
  local que falla. Mismo trato que en grupos.
- Sin reintento interno nuevo: la nube ya da el aviso al momento (decisión del 2026-09-14).
- Review adversarial: sí (sync, cierre de sesión).
- Residual previsto: el aviso de sesión caducada no dice DÓNDE entrar, y el push-all del cierre no para el motor en
  `.stoppedUntilSignIn` (lo hace el bucle de cadencia). Ticket nuevo, no se arregla aquí.

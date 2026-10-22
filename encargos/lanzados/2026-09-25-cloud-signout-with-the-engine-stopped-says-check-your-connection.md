# Cerrar sesión con la sincronización parada ya no diga «revisa tu conexión»

## Contexto
Acaba de mergear a `2.1` el PR #250 (`sign-out-push-all-runs-a-sync-cycle-past-the-migration-gate`): con el motor parado por el candado, el cierre ya no sincroniza a escondidas; sin pendientes cierra, y con cambios sin subir se bloquea sin perder nada. La review dejó este ticket medium: ese bloqueo sigue enseñando `L10n.Settings.signOutBlockedMessage` («Revisa tu conexión e inténtalo de nuevo»), y la conexión no tiene nada que ver. La salida real es actualizar Yala, o «Reintentar» en Almacenamiento.

Ticket: `tickets/backlog/cloud-signout-with-the-engine-stopped-says-check-your-connection.md`
Hermano cercano (NO es el alcance salvo que el mismo camino lo fuerce): `cloud-signout-collapses-the-personal-push-all-reason-into-permanent` — ahí el motivo existe y se tira con `_`; aquí, con el candado, `pushAllVerdictWithoutEngine` ya devuelve `.blocked(_, .permanent)` sin un motivo que viaje. Misma familia de UI, causa distinta.

## Decisiones de producto (ya tomadas — no preguntes)
1. Con el motor parado por el candado (`canRunDomain()` cerrado / journal ilegible / migración o vuelta a iCloud a medias), el aviso del cierre **no** habla de la conexión.
2. El texto nombra la salida real: actualizar Yala cuando el build no entiende el registro; o abrir Almacenamiento y usar «Reintentar» cuando la vuelta a iCloud falló o quedó a medias.
3. Enfoque robusto (no el más simple): introduce un motivo/razón de bloqueo distinta de «conexión / permanent genérico» para este caso, en lugar de reutilizar el copy de red. Si hace falta un `L10n` nuevo, créalo.
4. Ofrecer exportar movimientos antes de cerrar con journal ilegible: **solo** si ya existe un camino claro de export en Ajustes/Almacenamiento y engancharlo es trivial. Si no, deja ese tramo fuera y no inventes un flujo nuevo de export en este ticket; el criterio de aceptación medible es el copy correcto + el bloqueo que no pierde datos.
5. No ensanches el alcance al hermano `cloud-signout-collapses-the-personal-push-all-reason-into-permanent` salvo que el mismo cambio de clasificación lo arregle de paso. Si queda aparte, déjalo en backlog.

## Que se pide
Implementa el ticket `cloud-signout-with-the-engine-stopped-says-check-your-connection` según sus criterios de aceptación y las decisiones de arriba. Tests que fijen el copy/razón con el motor parado y cambios pendientes. Gate + mutantes + review + PR a `2.1` + merge + board (ticket a done o qa según toque; `docs/TICKETS.md` al día) + `/cerrar-total`.

## MODO AUTÓNOMO HASTA TERMINAR
La regla del repo «espera aprobación si >3 ficheros» / «¿Sigo?» tras el plan **queda suspendida** en este encargo. Implementa de cabo a rabo: plan → código → gate → mutantes → review → PR → merge → board/`docs/TICKETS.md` → `/cerrar-total`, sin pedir permiso para continuar. No uses AskUserQuestion para copy ni techos de este ticket: las decisiones ya están arriba. Solo para en acceso/secrets reales que no puedas resolver.

## Que NO hay que tocar
- `Web/` ni `marketing/` (Lola).
- Clínicas / datos de salud.
- No relances otros tickets de cola ni device-QA.
- No inventes un flujo nuevo de export si no hay camino claro ya en producto.

## Como se sabe que esta bien
- Con el motor parado por el candado y cambios sin subir, «Cerrar sesión» se bloquea sin perder nada y el aviso **no** dice «revisa tu conexión»; nombra la salida real (actualizar Yala y/o Reintentar en Almacenamiento).
- Tests del caso; gate verde; mutantes del cambio muertos; PR mergeado a `2.1`; ticket movido y `docs/TICKETS.md` al día; `/cerrar-total` limpio.

## Paso 0

Decidido antes de escribir código (MODO AUTÓNOMO: auto-contestado, sin nadie delante).

1. **Dos motivos nuevos, no uno.** Con el candado cerrado, la causa se lee del journal: ilegible → `.syncStoppedNeedsUpdate`
   (salida: actualizar Yala; si ya está al día, cerrarla y abrirla, que es lo que ya dice la tarjeta de Almacenamiento
   para ese mismo estado); legible → `.syncStoppedMidMigration` (fase en vuelo, vuelta a iCloud fallida, espejo montado:
   salida en «Dónde viven tus datos», con «Reintentar» si falló). Un solo motivo obligaría a un texto que nombre las
   dos salidas a quien solo tiene una.
2. **Quién clasifica:** una función pura (`CloudSignOutFlowLogic.engineStoppedReason(read:)`) que recibe la lectura del
   journal; `pushAllVerdictWithoutEngine` recibe el motivo sin default. Sin runtime (flag del motor apagado) sigue
   `.permanent`: no es el candado.
3. **El paso 1 del cierre en la nube deja pasar los dos motivos** tal cual; el resto sigue colapsado a `.permanent`
   (hermano `cloud-signout-collapses-the-personal-push-all-reason-into-permanent`, que queda en backlog).
4. **Exportar antes de cerrar: fuera.** El único export enganchado a un aviso de cierre es el del teléfono sin App Attest,
   que va con una salida que PIERDE datos; aquí el bloqueo no pierde nada y no hay salida que perder. Engancharlo no es
   trivial (su vuelta al aviso está atada a ese motivo). Queda fuera, como dice la decisión 4.
5. **Título:** el de siempre, «No pudimos cerrar tu sesión». Solo cambia el mensaje.
6. **Retry del cierre solo-grupos:** los dos motivos se muestran al momento (`surfacePermanent`): esperar 45 s no
   actualiza la app ni termina una vuelta a iCloud.

**Corrección tras la review (2026-09-25).** El punto 1 se queda corto: con una fase ESTABLE y el candado cerrado (el espejo
de iCloud aún montado), Almacenamiento enseña la nube activa y no hay nada que terminar. Se añade un tercer motivo,
`.syncStoppedNeedsRelaunch` («ciérrala y vuelve a abrirla»), y el texto del journal ilegible deja de afirmar «esta versión
no pudo leer»: dice «no pudimos comprobar» y pone primero «cierra y abre», como la tarjeta de Almacenamiento.

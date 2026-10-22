# Dar salida a quien tiene la sesión de la nube caducada y movimientos personales sin subir, sin perderlos a ciegas

## Contexto
Cola A (sync/cloud con riesgo real, UNA sola sesión de Yala a la vez por orden de Jürgen del 28-sep 16:31). Ticket: `tickets/backlog/cloud-sign-out-with-an-expired-session-and-personal-changes-has-no-exit.md` (medium), residual del PR #294 (`groups-outbox-rows-without-a-live-session-have-no-exit`). Hoy, con la sesión de la nube caducada y cambios PERSONALES sin subir, el paso 1 de `CloudSessionSignOut.performCloudSecureSignOut` bloquea con `.cloudSessionExpired` y sin salida: quien no puede volver a entrar (cuenta borrada, perdió el correo) no puede cerrar sesión en ese teléfono. Lee el ticket, el PR #294 y la salida `exitDiscardingUnsyncedPersonalChanges` del caso sin App Attest, que es el molde.

## Decisiones ya tomadas (Frank, opción robusta; no las vuelvas a preguntar)
La pregunta del ticket («Lo que falta decidir») queda contestada: SÍ, se ofrece la misma salida, reforzada porque el dato es más caro.
1. El camino por defecto sigue siendo «vuelve a entrar para subirlos». Se añade una salida explícita, extendiendo el molde del attest (no una salida nueva): aviso con la cifra de los movimientos que se perderían, **«Exportar movimientos» como primera acción destacada**, «Ahora no» que no borra nada, y «Cerrar sesión y perderlos» destructivo.
2. Lo aceptado recuerda su causa (como en #294): si vuelve a entrar y la subida falla por otra cosa, se bloquea como siempre.
3. Los cambios personales pendientes quedan ligados a la cuenta que los creó y nunca se suben con otra cuenta (misma regla de dueño que #294; si hoy ya se cumple, fíjalo con test; si no, arréglalo aquí).
4. Copy en los 16 `.lproj` con `add-l10n-key.sh`, en la línea del aviso del attest. Canarios con `cause=`. Review adversarial: sí.

## Que NO hay que tocar
- No cambiar el resto de salidas ni la regla «nunca descarta sin avisar». No tocar la salida de grupos del #294 salvo para compartir código.
- Nada del carril adaptativo. No uses simuladores `YalaLane-Adapt-*`, ni `simctl shutdown all`, `erase all` o `killall Simulator`. El disco del Mini va justo (unos 20 GB libres): limpia DerivedData propia al cerrar y no crees simuladores nuevos.

## Como se sabe que esta bien
- Tests que fijen: caducada con cambios y puede entrar (sube y cierra, sin cambio); caducada sin poder entrar (aviso con cifra correcta, exportar funciona y no borra, perder cierra); «Ahora no» no borra nada; otra cuenta no sube cambios personales ajenos.
- Gate verde (UI tests del CI advisory; contrasta con la base). PR contra 2.1 mergeado, ticket a qa con guion corto de device-QA o a done si los tests lo cubren, `docs/TICKETS.md` al día, residuales a ticket propio.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, PR contra 2.1, merge, board del repo (`tickets/` y `docs/TICKETS.md`) y `/cerrar-total` sin preguntar. Ahora es horario diurno hasta las 21:00: AskUserQuestion solo si necesitas acceso, un dispositivo o una decisión demasiado importante para asumirla; lo demás lo decides tú con la opción recomendada. Pasadas las 21:00 no preguntes: elige lo recomendado o aplaza a ticket.

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando: (1) necesitas una decisión de producto o de acceso de Jürgen; (2) abriste el PR o dejaste preview/artifact listo; (3) terminaste el ticket y vas a /cerrar-total, con un resumen corto de cierre en lenguaje de usuario; (4) acabaste un tramo y no tienes siguiente paso claro, una vez y no en bucle. NO avises por un test rojo que vas a reclasificar, un build que vas a reintentar ni ruido de CI advisory.

## Paso 0 (Frank, 2026-09-28, auto-contestado en MODO AUTÓNOMO)

Medido antes de decidir:
- El paso 1 del cierre en la nube solo abre salida con `.attestUnavailable`; la sesión caducada (`.sessionExpired` crudo →
  `.cloudSessionExpired` mostrado) bloquea sin salida. La oferta personal no lleva causa (`PersonalLossOffer(rows:)`).
- **Decisión 3 ya se cumple**: `CloudSyncRuntime.performCycle` corta ANTES de la red con otra cuenta
  (`sessionBelongsToAnotherAccount` → `.sessionExpired`), con test en `CloudSyncRuntimeTests`, y «Iniciar sesión» en «Dónde
  viven tus datos» exige la misma cuenta. Aquí se fija además en el push-all del cierre (`pushAllForSignOut` inyectable).

Decisiones (asumidas, opción recomendada):
1. **Generalizar, no duplicar**: la oferta y lo aceptado de lo personal llevan causa (`attestUnavailable` | `noSession`),
   como grupos. `GroupsLossAcceptance` pasa a `CausedLossAcceptance` y lo usan los dos lados.
2. **La decisión del paso 1 sale a una función pura** (`personalUploadBlockDecision`): seguir con lo aceptado, bloquear sin
   salida u ofrecer la pérdida con su causa. El coordinador solo la cablea.
3. **El aviso**: título «No pudimos cerrar tu sesión» (el de grupos sin sesión); mensaje con la cifra, cómo subirlos
   («Dónde viven tus datos» → «Iniciar sesión»), exportar antes y la pérdida. Botones: Exportar (primero y preferido con
   `.keyboardShortcut(.defaultAction)`), «Cerrar sesión y perderlos», «Ahora no». Dos keys nuevas en 16 `.lproj`.
   **Corregido al implementar**: el preferido iba a encenderse solo con la sesión caducada, pero `swiftui-ds.md` mide que
   algo dependiente del `@State` en el `actions` de un `.alert` rompió flujos ajenos. Va estático, y el aviso del attest
   gana también el «Exportar» destacado (mismo dato en juego; su comportamiento no cambia).
4. **Antes de ofrecer, la sonda del History** también con la sesión caducada (`personalVerdictAfterProbe`), por lo mismo que
   el attest: no se acepta perder lo que el aviso no contó.
5. **Canarios**: los tres del attest no cambian (su serie). Nuevos `cloudSignOutPersonalLossOffered/Exported/Discarded` con
   `cause=noSession`.
6. Otra cuenta con sesión viva sale como sesión caducada (así lo lee el motor): mismo aviso, misma salida. No se inventa un
   motivo nuevo.
7. Tests: lógica pura + push-all real con runtime de stubs + source-scan del cableado (el coordinador en la nube exige
   singletons de red; es el patrón de las suites hermanas). Device-QA: guion corto, el ticket va a `qa`.

### Tras la review adversarial (3 lentes: máquina de estados, pérdida de datos, UI/copy/reglas)

Ningún alto. Arreglado aquí:
- **La sesión que no hay se prueba** (lente 2, media): todo 401 del gateway llega como `.sessionExpired`, también con la
  sesión renovable. La salida solo se ofrece —y lo aceptado solo sigue— con `CloudSyncRuntime.ownersSessionIsGone` (el SDK
  borró la sesión, u otra cuenta). Sin runtime, `false`.
- **Sin `.keyboardShortcut(.defaultAction)`** (lente 3, media): primer uso en la app, no se puede ver en el simulador y la
  regla de `.alert` de `swiftui-ds.md` lo desaconseja. «Exportar» queda primero y no destructivo, sin negrita. Revisa la
  decisión 3 de arriba.
- **Ajustes solo anota la cifra y la causa de tus datos con su oferta viva** (lentes 1 y 3, baja).
A ticket: la puerta que falta con otra cuenta tras relanzar (low), el sello de claim de un dueño anterior (medium, inferido,
preexistente) y dos notas en residuales abiertos.

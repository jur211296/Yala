---
id: groups-join-is-not-retried-when-the-network-returns
status: backlog
priority: low
area: "groups, invitaciones"
created: 2026-09-17
source: "review adversarial de `groups-actions-read-an-offline-token-refresh-as-a-session-expiry` (lente de lo que ve la persona), 2026-09-17"
---

# Una invitación que falló sin red no se reintenta al volver la red, aunque la pantalla diga que sí

## El problema, en lenguaje de usuario

Sin conexión, toco «Unirme al grupo». A los 20 s Yala me dice «Está tardando un poco más de lo normal. Seguimos conectando
con tu grupo en segundo plano. Puedes usar Yala mientras tanto: el grupo aparecerá en la pestaña Grupos apenas esté listo.»
Toco «Seguir a la app». Vuelve la red con Yala abierta y no pasa nada: el grupo no aparece hasta que bloqueo el teléfono,
cambio de app o vuelvo a abrir Yala. Mientras tanto, la pestaña Grupos no dice que haya una unión en curso.

## Lo medido (2026-09-17, leído en el código, sin ejecutar)

- Un fallo pasajero de `join_group` (sin red, un 5xx, el 401 de App Attest y, desde el 2026-09-17, el token que no se
  renueva sin red) no avisa: `GroupBackendInviteEntryHandler.handleJoinError` conserva la invitación y re-arma el tap.
- Lo que vuelve a intentar la unión: el arranque, el paso a `.active` (`ContentView`, `GroupJoinReconciler.reconcile(trigger:
  .foreground)`), un nuevo toque del enlace, el CTA de la hoja y `GroupJoinIntentTracker.retry`. **Nada reacciona a que
  vuelva la red.**
- El texto `groups.invite.slow.body` promete que sigue conectando «en segundo plano» y que el grupo aparecerá «apenas esté
  listo» (`GroupInviteOnboardingView`).
- La pestaña Grupos pinta su franja de unión desde `GroupJoinIntentTracker.phase`, y en el camino backend un fallo pasajero
  no mueve la fase: sigue `.idle` y la franja no sale (`GroupsContainerView.joinIntentBanner`).
- **Antes del 2026-09-17**, con el token caducado sin red, la unión abría la hoja de inicio de sesión y su cinturón la
  cerraba y volvía a intentarlo en bucle: parpadeaba, pero completaba la unión en cuanto volvía la red. Ese bucle se quitó a
  propósito (`groups-actions-read-an-offline-token-refresh-as-a-session-expiry`), y con él ese reintento continuo.

## Lo que hay que decidir (Jürgen)

1. Reintentar al volver la red: un vigilante de conexión (`NWPathMonitor`) que lance el reconciler. Hoy la app no tiene
   ninguno a propósito (decisión D6 de `groups-push-reads-an-offline-token-refresh-as-a-session-expiry`).
2. Ajustar el texto para que no prometa «apenas esté listo», y enseñar la franja de unión en la pestaña.
3. Dejarlo: se cura en el siguiente `.active`.

## Relación con otros tickets

- `groups-join-intent-expires-silently-after-transient-failures` — lo que pasa si el fallo dura 7 días.
- `groups-loop-in-backoff-ignores-the-return-to-foreground` — la cadencia del canal de sync al volver a la app.

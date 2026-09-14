---
id: apple-id-close-blocked-has-no-visible-outcome
status: backlog
priority: high
area: "modo-nube, sesiones"
created: 2026-09-14
source: "hallazgo propio al implementar `apple-id-change-should-close-the-private-session` (2026-09-14)"
---

# Si el cierre por cambio de Apple ID se bloquea, la persona no ve nada

## Qué pasa

El aviso de «Cambiaste de cuenta de iCloud» (`ShellDataAlertsModifier`) llama a
`CloudSessionSignOut.shared.signOut(...)`. Ese coordinador puede terminar en `.blocked` — en la celda D
(sesión privada + cuenta de grupos asociada) el push-all de grupos bloquea si no puede subir: sin red,
con el canal en pausa, con la sesión de la cuenta caducada.

**Cuando eso ocurre desde este camino, nadie lo enseña.** Medido el 2026-09-14: los tres sitios que
pintan `phase == .blocked` son `ProfileView` (Ajustes), `WelcomeGroupsGateView` (la puerta del
invitado) y `GroupsAssociationSection` — y ninguno está montado, porque el aviso sale sobre el Panel.

Para la persona: toca «Cerrar sesión y quitarlos», el alert se cierra, y **no pasa nada visible**. Ni
progreso, ni error, ni la pantalla de reinicio.

## Por qué no se arregló en el mismo PR

Porque la salida barata está prohibida por la rule de área. Encender un segundo alert desde el
`actions` del primero son **dos `.alert` encadenados del mismo anchor**, que es el molde exacto que
`.claude/rules/swiftui-ds.md` describe como brick de sesión: si UIKit descarta el segundo, su flag se
queda en `true`, `blocker()` lo devuelve para siempre y el router no vuelve a drenar nada.

Lo que la rule prescribe es **una sola presentación con FASES dentro** (el molde de
`WelcomePrivateICloudGateView` y `LateICloudMirrorNoticeView`), y eso es una vista nueva: otro objeto,
no un remate del ticket que la descubrió.

## Lo que la review midió y este ticket no sabía

El bloqueo no solo es invisible: **deja al coordinador tapiado para el resto del lanzamiento**, y eso
alcanza a gestos que no tienen nada que ver.

- `CloudSessionSignOut.signOut` abre con `guard phase == .idle` (`:115`), así que con la fase en
  `.blocked` no entra nadie más.
- `WelcomeGroupsGateView` (`:515` y `:574`) devuelve `.unavailable` con `phase != .idle`: la puerta del
  invitado deja de ofrecer sus gestos sin decir por qué.
- `detachGroupsAccount` devuelve `.busy` y la sección de asociación de Ajustes se queda muda.
- `acknowledgeBlocked()` tiene dos llamadores (`ProfileView:229`, `WelcomeGroupsGateView:635`): si la
  persona no entra en Ajustes, la fase no vuelve a `.idle` en todo el lanzamiento.
- Y es alcanzable también en la celda **C**, no solo en D: `blockIfGroupsCannotUpload` bloquea con
  `.sessionExpired` si quedan filas de outbox de grupos de una sesión caducada, sin tocar la red.

**El alcance que el aviso tampoco dice.** El copy habla de «los datos de Yala de este teléfono», pero el
cierre además cierra la sesión de la cuenta de Yala (`CloudAuthService.signOut()`, siempre), limpia el
consent de Grupos y, en la celda D, borra el store de grupos. La app tiene una pieza dedicada a contarlo
por celda —`DestructiveScopeLogic.signOutOperation`, la hoja de alcance de `ProfileView`— y este camino
la salta entera. La pantalla con fases es el sitio natural para traerla.

## Lo que SÍ converge hoy — por qué esto no bloqueaba el PR

- El estado **no se pierde**: el coordinador se queda en `.blocked` vivo, y `ProfileView` re-presenta
  ese aviso al abrir Ajustes (su propio docblock lo dice, `ProfileView.swift:595`).
- El aviso **vuelve solo en el arranque siguiente**: el latch de `AppBootstrapper` es por proceso, así
  que un relanzamiento vuelve a ofrecer el cierre.
- El bloqueo más probable (el push de grupos sin red) es transitorio y se cura al recuperar la
  conexión.

Lo que se pierde es la explicación, no los datos. **Nació `medium` por eso y subió a `high` el mismo
día**, cuando la review midió que la fase pegada además tapia gestos ajenos (arriba): eso ya no es solo
una explicación que falta.

## Alcance propuesto

Una pantalla con fases para este cierre —confirmar / subiendo / bloqueado con su motivo / listo— que
reemplace al `.alert`. Reusa el copy de bloqueo que ya existe (`settings.signOutBlocked*`,
`settings.signOutPending*`) y los motivos de `CloudSignOutFlowLogic.BlockReason`, que ya distinguen
sesión caducada, canal en pausa y lo pasajero.

## Criterios de aceptación

- [ ] Tras confirmar el cierre por cambio de Apple ID, la persona ve progreso mientras corre.
- [ ] Si el cierre se bloquea, ve el motivo con el copy que ya existe y puede reintentar.
- [ ] No hay dos presentaciones encadenadas del anchor de `ContentView`.
- [ ] El flag de presentación tiene un camino de bajada que no dependa de que UIKit presente.

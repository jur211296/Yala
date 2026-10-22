---
id: cloud-signout-with-the-engine-stopped-says-check-your-connection
status: done
priority: medium
area: "modo-nube, cierre de sesión, migración"
created: 2026-09-25
updated: 2026-09-25
source: "review adversarial de `sign-out-push-all-runs-a-sync-cycle-past-the-migration-gate` (2026-09-25)"
---

# Cerrar sesión con la sincronización parada dice «revisa tu conexión», y la salida es otra

## El problema, en lenguaje de usuario

Si la sincronización con la nube está parada a propósito —abriste una versión anterior de Yala que no entiende en qué punto
iba el cambio a la nube, o una vuelta a iCloud falló y no le diste a «Reintentar»— y tienes cambios sin subir, «Cerrar
sesión» se bloquea (bien: no se pierden). Pero el aviso te dice que revises tu conexión. La conexión no tiene nada que ver
y reintentar no cambia nada. Lo que te saca de ahí es actualizar Yala, o «Reintentar» en Almacenamiento.

## Medido (2026-09-25)

- Desde `sign-out-push-all-runs-a-sync-cycle-past-the-migration-gate`, con el candado del motor cerrado el push-all del
  cierre devuelve `.blocked(_, .permanent)` (`CloudSignOutFlowLogic.pushAllVerdictWithoutEngine`): con filas en el outbox,
  o con ediciones en el History que el motor no capturó (entonces la cifra es `Int.max`).
- El paso 1 de `CloudSessionSignOut.performCloudSecureSignOut` enseña `.permanent` con el texto de
  `L10n.Settings.signOutBlockedMessage` («Revisa tu conexión e inténtalo de nuevo»).
- Mismo colapso de familia que `cloud-signout-collapses-the-personal-push-all-reason-into-permanent`, pero con una causa que
  ese ticket no nombra: ahí el motivo existe y se tira; aquí no hay motivo que viaje.

## Qué habría que decidir (producto)

- El texto de este bloqueo y a dónde manda (Almacenamiento, actualizar Yala).
- Si con el journal ilegible se ofrece además exportar los movimientos antes de cerrar.

## Criterios de aceptación

- [x] Con el motor parado por el candado, el aviso del cierre no habla de la conexión y nombra la salida real.

## Paso 0 (2026-09-25, MODO AUTÓNOMO)

Las decisiones de producto venían en el encargo. Lo que quedaba por decidir se auto-contestó:

- **Un motivo por salida, no uno genérico.** La causa se lee del journal y de la fase, clasificada por lo que enseña
  «Dónde viven tus datos» en ese mismo estado, porque es adonde manda el aviso.
- **Sin runtime** —el motor apagado por flag— no es el candado: sigue `.permanent`.
- **Exportar antes de cerrar: fuera.** El único export enganchado a un aviso de cierre va con una salida que pierde
  datos, la del teléfono sin App Attest. Aquí el bloqueo no pierde nada, y engancharlo no es trivial: su vuelta al aviso
  está atada a ese motivo. Es la decisión 4 del encargo.
- **Título sin cambios**, «No pudimos cerrar tu sesión». Solo cambia el mensaje.

## Resultado (2026-09-25)

**Qué cambia para quien usa la app.** Si tienes cambios sin subir y la sincronización con la nube está parada a
propósito, «Cerrar sesión» sigue bloqueándose sin perder nada. Pero el aviso ya no dice «revisa tu conexión», sino la
salida que toca:

- **No pudimos comprobar en qué punto va el paso a la nube.** Cierra Yala y vuelve a abrirla; si sigue igual,
  actualízala desde la App Store.
- **El paso entre la nube e iCloud no terminó.** Abre «Dónde viven tus datos», aquí en Perfil, y termínalo desde ahí;
  si falló, toca «Reintentar».
- **El paso terminó, pero la sincronización espera a que reabras la app.** Ciérrala del todo y vuelve a abrirla.

**Qué se tocó.**

- Tres motivos nuevos en `CloudSignOutFlowLogic.BlockReason`: `syncStoppedNeedsUpdate`, `syncStoppedMidMigration` y
  `syncStoppedNeedsRelaunch`.
- `engineStoppedReason(read:)` elige el motivo: journal ilegible, fase no estable o fase estable.
- `pushAllVerdictWithoutEngine` recibe el motivo sin valor por defecto.
- El push-all del cierre recibe inyectada la lectura del journal.
- El paso 1 del cierre deja pasar esos tres motivos con `personalPushAllShownReason`, un `switch` exhaustivo. El resto
  sigue colapsado.
- Tres textos nuevos en los 16 locales.

**Verificado.**

- Tests nuevos: dos tablas (`engineStoppedReason` y `personalPushAllShownReason`), el cierre con el journal legible y una
  edición sin capturar, y el copy.
- 15 mutantes muertos, cada uno por el test que le tocaba.
- Review de tres lentes. Dos cazaron que, con fase estable y el candado cerrado (el espejo de iCloud aún montado), el
  aviso mandaba a terminar un paso que Almacenamiento enseña como terminado. Eso dio lugar a `syncStoppedNeedsRelaunch`.
- Una lente vio que el texto del journal ilegible afirmaba «esta versión no pudo leer». El código no conoce esa causa,
  así que ahora dice «no pudimos comprobar» y pone primero «cierra y abre», como la tarjeta de Almacenamiento.

**Asumido sin medir.**

- Que reabrir la app cura el espejo montado con fase estable. Viene del comentario de C-1 en
  `CloudSyncRuntime.canRunDomain`, y no se ha reproducido.

**Fuera.**

- El hermano `cloud-signout-collapses-the-personal-push-all-reason-into-permanent` sigue en backlog: lo pasajero y la
  sesión caducada del paso 1 siguen saliendo como «revisa tu conexión».
- `.waitingForLeader` cae en «termínalo desde Almacenamiento». La pantalla enseña esa espera con su botón de salir; no
  se separó.

**Sin device-QA**: el simulador no reproduce el estado real, que se da al bajar de build en TestFlight, y la lógica queda
fijada en unit.

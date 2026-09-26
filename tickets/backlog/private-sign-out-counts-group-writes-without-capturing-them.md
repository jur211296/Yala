---
id: private-sign-out-counts-group-writes-without-capturing-them
status: backlog
priority: low
area: "groups, modo-nube"
created: 2026-09-26
updated: 2026-09-26
source: "review adversarial de `groups-drain-failure-reads-as-nothing-pending` (2026-09-26), lente de datos"
---

# El cierre de sesión privado puede llevarse un gasto de grupo recién apuntado

## El problema, en lenguaje de usuario

Casi nunca pasa. En el cierre de sesión privado (el que no sube grupos), un gasto de grupo apuntado segundos antes
puede no contar como «pendiente», y el borrado se lo lleva sin avisar.

## Por qué pasa (leído el 2026-09-26; inferido, no ejecutado)

- `CloudSessionSignOut.blockIfGroupsCannotUpload` (llamado al entrar en `performSessionExit` y pegado al arm) cuenta
  solo las filas vivas del outbox (`liveGroupsPendingCount`). No drena el History ni mira el espejo del App Group.
- Con filas de grupos backend, el borrado del cierre privado se lleva también el dominio de grupos.
- Un gasto que aún vive solo en el History (el drain del canal no corrió: sin sesión, `startIfEligible` no arranca) o
  solo en el espejo cuenta 0.

Es la instancia hermana de `groups-drain-failure-reads-as-nothing-pending`, que cerró el push-all, el desasociar y
«Empezar de cero» con una captura previa (`GroupsSyncClient.captureLocalWritesForExit`) y
`CloudSignOutFlowLogic.groupsCaptureVerdict`.

## Por qué no se hizo en ese ticket

La captura hace `save()` (rehidrata y drena), y aquí corre al principio del gesto, ANTES de ninguna espera de
quiescencia del import de iCloud: el cierre privado tiene el espejo personal montado, y un `save()` sobre un import a
medio asentar es el SIGTRAP de `swiftdata-cloudkit.md`. Meterla tal cual cambiaría un riesgo por otro.

## Por dónde va

- O una lectura sin escribir (History de grupos posterior al cursor + espejo), molde `hasUncapturedPersonalChanges`.
- O la captura detrás de `awaitPersonalQuiescenceForGroupsSignOut`, como el push-all.

## Criterios de aceptación

- [ ] Un gasto de grupo solo en el History o solo en el espejo bloquea el cierre privado con «vuelve a entrar».
- [ ] Sin nada pendiente, el cierre privado no cambia.

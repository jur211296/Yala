---
id: welcome-fresh-start-on-a-cloud-phone-wipes-rows-with-the-engine-alive
status: backlog
area: cloud-sync
priority: medium
created: 2026-11-13
updated: 2026-11-13
source: review adversarial del arreglo de adopt-over-a-device-already-in-cloud-mode-has-no-exit (13-nov)
---

# «Empezar de cero» en un teléfono en la nube borra filas con el motor todavía vivo

## Qué pasa (inferido, sin medir)

En un teléfono con el modo en `.cloud`, sesión viva y el motor personal corriendo (el caso de un alta nube recién hecha), el
borrado de filas de «Empezar de cero» del Welcome (`ShellDataAlertsModifier.performFreshStartWipe` y la puerta privada,
`ContentView.performDeviceCorpusWipe` / `performICloudCorpusWipe`) corre antes de que el cierre nuevo
(`CloudSessionSignOut.armReturnToFreshInstallAfterWelcomeFreshStart`) pare el motor. Si un drain recoge esos borrados,
suben a la cuenta de la nube como tombstones.

Ya pasaba antes del arreglo del 13-nov. En el caso medido, la cuenta es la que la persona está descartando.

## Qué haría falta

Medir si el drain llega a recoger esos borrados. Si sí: con `.cloud`, saltarse el borrado de filas y dejar que lo haga el
borrado por archivos del arranque (que se lleva lo mismo), conservando la subida de grupos previa y su confirmación.

---
id: old-receivers-of-a-keeping-wipe-delete-the-origin-reminders
status: backlog
priority: low
area: "borrado, sync iCloud"
created: 2026-10-29
updated: 2026-10-29
source: "review adversarial del encargo 2026-10-29-vaciar-datos-mantiene-cuenta (S27i)"
---

# Un dispositivo con una versión anterior borra los recordatorios que «Vaciar datos» conserva

Desde S27i, «Vaciar datos» con vida personal conserva los recordatorios y manda la señal con la marca de que el parque
sigue (`PreferenceSyncService.signalWipeKeepingSetup`). Un iPad del mismo iCloud con una versión anterior entra por
`skipOnboarding`, pero su código viejo llama a `wipeAllUserData(remoteWipeCut:)` sin `keepsReminders`: borra los
`NotificationItem` anteriores a la señal y resetea sus preferencias. Esos borrados viajan por el espejo al origen, que
pierde los recordatorios que prometió conservar.

Es desfase de versiones: desaparece cuando todo el parque está en 2.2. Opciones si hiciera falta antes: no emitir la marca
hasta que el parque declare la versión (no hay dónde leerlo hoy), o avisar en el origen. Medir primero cuántos parques
mezclan versiones.

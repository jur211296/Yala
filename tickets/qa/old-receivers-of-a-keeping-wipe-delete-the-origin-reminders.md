---
id: old-receivers-of-a-keeping-wipe-delete-the-origin-reminders
status: qa
priority: low
area: "borrado, sync iCloud"
created: 2026-10-29
updated: 2026-11-07
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

## Hecho (2026-11-07, lote 2.3)

Mitigación en el **origen**, sin tocar el protocolo entre versiones: al vaciar conservando la cuenta y avisar al parque,
los recordatorios conservados se vuelven a crear iguales (nombre, texto, hora, días, tipo, orden, configuración) con un
id nuevo y fecha posterior a la señal (`DataWipeService.recreateKeptRemindersAfterSignal`). El corte de la 2.1 solo se
lleva lo creado hasta la señal, así que las copias sobreviven lleguen antes o después que ella; las originales ya las
borra el propio origen. Solo en el origen que avisa conservando la cuenta: ni el receptor ni «Empezar de cero» sin aviso.

Tests: `KeepingWipeOldReceiverRemindersTests` (control: sin re-crear, el corte de la 2.1 se los lleva; re-creados, no se
lleva ninguno y salen iguales) + su scan de cableado.

## Guion de QA (iPhone 14 con un TestFlight de esta versión + un dispositivo con la 2.1 del App Store, mismo iCloud)

1. En el iPhone 14 (TestFlight de esta versión): crea dos recordatorios en Ajustes › Notificaciones, uno personalizado con
   días elegidos.
2. Deja el otro dispositivo con la 2.1 cerrado.
3. En el iPhone 14: Ajustes › Vaciar datos › confirmar. Los recordatorios siguen en Notificaciones.
4. Abre el dispositivo con la 2.1 y espera a que procese el vaciado.
5. En el iPhone 14, pasados un par de minutos: los dos recordatorios siguen ahí, con su hora y sus días.

Nota: Yala Dev usa otro contenedor de iCloud y otro almacén de ajustes que la app publicada, así que con Yala Dev la
señal no llega a la 2.1: este guion pide el TestFlight. Va en la tanda de TestFlight de 2.3, no antes.

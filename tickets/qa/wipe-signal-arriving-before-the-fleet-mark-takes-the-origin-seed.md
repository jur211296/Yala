---
id: wipe-signal-arriving-before-the-fleet-mark-takes-the-origin-seed
status: qa
priority: low
area: "borrado, sync iCloud"
created: 2026-10-29
updated: 2026-11-07
source: "review adversarial del encargo 2026-10-29-vaciar-datos-mantiene-cuenta (S27i)"
---

# Si la señal de vaciado llega antes que la marca del parque, el receptor se lleva la semilla del origen

`signalWipeKeepingSetup` escribe `lastOnboardingTimestamp` y `lastWipeTimestamp` en el mismo `synchronize`, pero el
iCloud KV no garantiza el orden de entrega entre claves. Si la señal llega sola, el receptor la procesa con
`fleetStartedOver = false`: resetea sus ajustes, va al onboarding y su corte se lleva lo que no tiene fecha ni uso —las
categorías recién sembradas del origen y sus recordatorios anteriores a la señal—. Esos borrados viajan al origen, que
se queda sin categorías (el Panel ofrece «Crear categorías») y sin recordatorios.

No medido en dispositivos. Va en el device-QA del ticket `wipe-data-keeps-the-account-and-delete-account-wipes-everything`
(paso A). Si se reproduce: que el receptor espere la marca un tiempo corto antes de decidir, o que la marca viaje dentro
del valor de la señal (un solo key).

## Hecho (2026-11-07, lote 2.3)

El receptor ya no decide con la señal sola. Si llega `lastWipeTimestamp` sin la marca del parque, la consume (como
siempre), la deja **aparcada** y espera hasta 20 s (`PreferenceSyncService.wipeMarkWait`). Si en ese rato llega la marca,
entra por «el parque sigue»: se queda en la app, conserva ajustes y recordatorios, y su corte no se lleva la semilla del
origen. Si no llega, decide como antes (onboarding), que es lo correcto para un origen de los de antes. La espera
sobrevive a cerrar la app (se apunta en `UserDefaults`) y se decide con la sesión que haya al cerrarla.

Tests: `RemoteWipeSignalDetectionTests` (orden de llegada: señal sola → espera; llega la marca → `skipOnboarding: true`;
sin marca tras la espera → `false`; relanzamiento; sesión en la nube sin espera). La reproducción real del desorden del
iCloud KV no se puede forzar en el simulador.

## Guion de QA (dos dispositivos del mismo iCloud, Yala Dev)

1. En el iPhone 14 y en un segundo dispositivo, misma cuenta de iCloud, sesión privada, con algunos registros y las
   categorías de siempre.
2. En el iPhone 14: Ajustes › Vaciar datos › confirmar.
3. En el otro dispositivo, con la app abierta: en unos segundos tiene que quedarse en la app (aviso «Se vaciaron tus
   datos desde otro dispositivo»), **sin** volver a la bienvenida.
4. En el iPhone 14: el Panel sigue con las categorías (no ofrece «Crear categorías») y los recordatorios siguen en
   Ajustes › Notificaciones.

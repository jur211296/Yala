---
id: wipe-signal-arriving-before-the-fleet-mark-takes-the-origin-seed
status: backlog
priority: low
area: "borrado, sync iCloud"
created: 2026-10-29
updated: 2026-10-29
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

---
id: panel-fresh-seed-reads-the-icloud-drive-token
status: backlog
priority: low
area: "icloud, panel, preferencias"
created: 2026-11-05
updated: 2026-11-05
source: "review adversarial del lote N4 (iCloud Drive y preferencias), lente de las esperas"
---

# Con iCloud Drive apagado, un dispositivo nuevo puede devolver el Panel de los otros a su configuración inicial

## Qué pasa, en lenguaje de usuario

Tengo el Panel ordenado a mi gusto en el iPhone. Instalo Yala en el iPad, con la sesión de iCloud abierta pero iCloud
Drive apagado, y el Panel del iPhone vuelve al orden de fábrica.

## Lo medido (leído, 2026-11-05, rama 2.3)

- `PanelPreferencesMigration.freshSeedDecision` decide en `AppPreferences.init` si siembra ya o difiere al paso 8.5 del
  arranque, con `SwiftDataConfiguration.isICloudAvailable()` (token de iCloud Drive). Con Drive apagado el token falta y
  siembra en el acto; `setupDefaultsForNewUser()` escribe los valores por defecto en el iCloud-KV y, por LWW, pisa la
  configuración que estaba por bajar.
- El paso 8.5 ya decide con `hasICloudAccount` desde el lote N4. En el `init` no se puede: CloudKit aún no contestó.

## Lo que falta medir antes (device)

- ¿Viaja el iCloud-KV (`NSUbiquitousKeyValueStore`) con iCloud Drive apagado y la sesión abierta? Si no viaja, no hay
  daño y el ticket se descarta.

## Si viaja

Diferir siempre que se pida diferir (el 8.5 re-invoca la migración ya con la respuesta de CloudKit), comprobando que
los tests que construyen `AppPreferences` sobre un almacén limpio no dependan de la siembra en el `init`.

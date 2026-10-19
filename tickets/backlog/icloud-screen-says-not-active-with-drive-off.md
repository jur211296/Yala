---
id: icloud-screen-says-not-active-with-drive-off
status: backlog
priority: low
area: "icloud, ajustes"
created: 2026-10-19
updated: 2026-10-19
source: "review adversarial del lote decidido 2.2 · 05 (L20-14), lente de verdad del texto — leído, no medido en un iPhone"
---

# Con iCloud Drive apagado, la pantalla de iCloud dice que iCloud no está activo aunque sincroniza

## El problema, en lenguaje de usuario

Si la persona tiene la sesión de iCloud abierta pero iCloud Drive apagado, Ajustes › Sincronización iCloud le dice
«iCloud no está activo en este iPhone · Tus datos se quedan solo aquí» y le ofrece «Abrir Ajustes del iPhone» para
iniciar sesión. Pero sus datos sí se sincronizan: Yala usa CloudKit, que funciona con Drive apagado.

## Por qué pasa (leído el 2026-10-19)

`iCloudSyncService.isAccountAvailable` es `SwiftDataConfiguration.isICloudAvailable()`, que lee `ubiquityIdentityToken`:
mide iCloud **Drive**, no CloudKit (`.claude/rules/swiftdata-cloudkit.md`, regla del 2026-09-10). Con Drive apagado el
espejo se adjunta igual. Antes de L20-14 la pantalla ya decía «Sin cuenta iCloud» en ese caso; desde L20-14 además
afirma que los datos se quedan solo aquí.

## Qué habría que decidir

- Leer la cuenta con `CKContainer.accountStatus()` (o el error de la propia llamada) para esta pantalla, y dejar el
  token de Drive para la tabla de mounts, que es para lo que existe.
- Qué decir en el caso «sesión abierta, Drive apagado»: hoy no hay texto para él.

## Criterios de aceptación

- Con Drive apagado y sesión de iCloud abierta, la pantalla no dice que iCloud no está activo ni que los datos se quedan
  solo aquí. Medido en un iPhone (el simulador no tiene iCloud).

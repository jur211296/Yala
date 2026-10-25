---
id: icloud-screen-says-not-active-with-drive-off
status: done
priority: low
area: "icloud, ajustes"
created: 2026-10-19
updated: 2026-10-25
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

## Cierre (lote 12.2, 2026-10-25)

La pantalla decide «sin cuenta» con `iCloudSyncService.hasICloudAccount` (token de Drive **o** `CKContainer.accountStatus()
== .available`), y `checkAccountStatus` y `forceSync` también. Con Drive apagado y CloudKit vivo ya no dice «iCloud no está
activo» ni esconde «Sincronizar ahora». Tests: `ICloudAccountWitnessTests` (lógica, servicio y cableado) y el scan de
`UXAudit22Lote20NubeTests`. La comprobación en el iPhone va en el guion de la card n5zw (mismo montaje: Drive apagado).
Card 90yc.

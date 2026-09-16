---
id: cloud-onboarding-offers-the-cloud-to-a-phone-without-app-attest
status: backlog
priority: low
area: "modo-nube, attest, onboarding"
created: 2026-09-15
updated: 2026-09-15
source: "hallazgo de `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes` (2026-09-15)"
---

# La puerta que no ofrece la nube a un teléfono sin App Attest no está conectada a nada

## El problema, en lenguaje de usuario

Mi teléfono no tiene App Attest. Elijo «Tu cuenta en la nube» al empezar, uso la app con normalidad y nada de lo que apunto
llega nunca a mi cuenta: el motor corta en su puerta de attest antes de subir.

## Lo medido (leído en el código, sin ejecutar)

- `AttestSyncGate.shouldOfferCloudOnly(isAttestSupported:)` existe desde I7b (`c56dcd772`, «DARK») con la decisión del owner
  de bloquear por adelantado, y **no tiene ni un solo llamador** en `Yala/`.
- Su docblock, y el de `classify` en el mismo fichero, afirman que ese caso «se caza antes, cuando la persona aún no ha
  elegido». Nada lo caza: el único lector de `DCAppAttestService.isSupported` fuera del cliente es el panel de depuración
  (`CloudSyncDebugView`).
- Desde el 2026-09-15 esa persona puede al menos cerrar sesión exportando y perdiendo lo que no subió
  (`cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes`), pero solo tras un día sin App Attest.
- Sin medir: cuántos teléfonos reales tienen `isSupported == false`. El docblock lo da por «vanishingly rare» en hardware con
  iOS 26, sin cifra.

## Lo que hay que decidir

1. Conectar la puerta al Welcome: sin App Attest, no se ofrece la nube.
2. Retirar la función y corregir los docblocks, y aceptar que esa población entra y depende de la salida del cierre.
3. Medir antes cuántos teléfonos hay así.

## Relación con otros tickets

- `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes` — la salida que hoy es la única red.

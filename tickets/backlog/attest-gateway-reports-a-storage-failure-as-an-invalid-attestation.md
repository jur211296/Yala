---
id: attest-gateway-reports-a-storage-failure-as-an-invalid-attestation
status: backlog
priority: low
area: "attest, gateway"
created: 2026-09-15
updated: 2026-09-15
source: "review adversarial de `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes` (2026-09-15)"
---

# El gateway responde «atestación inválida» cuando lo que falla es su propia base de datos

## El problema, en lenguaje de usuario

Mi teléfono atesta bien, pero el servidor tiene un problema al guardar mi key. En vez de «inténtalo en un rato», el teléfono
entiende que su atestación no vale, y si el problema dura un día acaba oyendo que no puede sincronizar.

## Lo medido (leído en el código, sin ejecutar)

- En `/v1/attest/register` y `/v1/attest/assert` la escritura en D1 (`insertAttestKey`, `updateCounter`) vive dentro del
  mismo `try` que la verificación (`gateway/src/attest/routes.ts:110-120` y `:152-158`). Su `catch` responde a TODO con 401
  `yala_attest_invalid`.
- `.run()` lanza cuando D1 falla (`gateway/src/db.ts:35-48`). En cambio `getAttestKey`, fuera del `try`, acaba en `onError`,
  que responde 500 `yala_unavailable` (`gateway/src/index.ts:111-113`).
- Desde el 2026-09-15 el motor personal cuenta `yala_attest_invalid` como rechazo del attest en la racha del teléfono
  (`AttestSyncGate.countsTowardAttestStreak`). Un fallo de D1 sostenido 24 h, con al menos 3 ocasiones distintas, le daría
  el veredicto terminal a un teléfono que atesta.
- Sin medir: la frecuencia de fallos de escritura en D1.

## Lo que hay que decidir

1. Dejar dentro del `try` solo la verificación y sacar la escritura, para que su fallo acabe en 500.
2. Dejarlo: el umbral de 24 h y el primer acierto lo acotan.

## Relación con otros tickets

- `cloud-phone-without-app-attest-cannot-sign-out-with-personal-changes` — donde empezó a contar.
- `.claude/rules/gateway-attest.md` — qué cuenta en la racha del teléfono.

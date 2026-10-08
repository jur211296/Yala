---
id: wipe-data-group-rows-return-only-on-the-next-cold-launch
status: backlog
priority: medium
area: "groups, settings"
created: 2026-09-27
updated: 2026-10-08
source: "review adversarial de `wipe-data-keeps-groups-but-drops-their-bridged-rows` (2026-09-27, lentes de momento y de reglas); inferido por lectura, NO reproducido"
---

# Tras «Vaciar datos» los gastos de grupo solo vuelven al siguiente arranque en frío

## El síntoma, en lenguaje de usuario

Vacío mis datos, termino el onboarding y sigo usando Yala sin cerrarla. Mis grupos muestran sus saldos, pero en Registros
y en el Panel faltan sus gastos, o salen solo algunos. Vuelven todos cuando iOS cierra la app y la abro de nuevo.

## Lo medido (2026-09-27, leyendo código)

- `GroupsBridgeRestoreConvergence.convergeIfPending` tiene un solo llamador en caliente,
  `AppBootstrapper.retryPendingBridges`, que corre en `bootstrap()` y en `rebootstrapAfterSwap`. Volver al primer plano no
  lo dispara.
- Mientras tanto el sync de grupos re-puentea solo los gastos y liquidaciones que cambian, así que lo personal enseña un
  subconjunto.
- Es el mismo momento que #282 aceptó para sus dos borrados. Converger en el mismo proceso exige la quiescencia del import
  (la precondición de la convergencia) y decidir si se hace antes o después del onboarding personal.

## Qué hay que decidir

¿Se converge dentro de la sesión (al terminar el onboarding, o en un primer plano con la petición puesta), o basta con
el arranque siguiente?

## Relacionados

- [[wipe-data-keeps-groups-but-drops-their-bridged-rows]]
- [[late-remote-wipe-signal-undoes-the-rows-the-origin-reconverged]]

## Nota (2026-09-27, review de `late-remote-wipe-signal-undoes-the-rows-the-origin-reconverged`)

El receptor de la señal tardía hereda este momento, y ahí pesa más: su borrado se lleva las filas también del ORIGEN, y
no vuelven a ningún dispositivo hasta el siguiente arranque en frío del receptor, que suele ser el que menos se abre.
Mientras tanto hay una ventana (inferida): si en el origen se aprueba el borrador de una liquidación antes de que le
llegue el borrado de su pata virtual, la transacción real (D7, sin `splitSettlementID`) sobrevive; el receptor ve la
liquidación sin ninguna pata, la re-puentea y el Inbox vuelve a pedir ese pago. Converger en el mismo proceso
(`GroupsBridgeRestoreConvergence.runAfterActivation`, que ya espera la quiescencia) cerraría la mayor parte.

## Medido en 2.1 (triage 2026-10-08)

- `DataWipeService.wipePersonalDataKeepingGroups` marca la convergencia pendiente (`DataWipeService.swift:338-339`).
- El único que la ejecuta es `retryPendingBridges` (`AppBootstrapper.swift:1795`), en `bootstrap()` y en `rebootstrapAfterSwap`, y «Vaciar datos» no hace swap de container.
- `runAfterActivation` (`GroupsBridgeRestoreConvergence.swift:198`) ya espera la quiescencia, pero solo lo llama `FullModeActivationView.swift:463`.
- Recomendación técnica: llamarlo al terminar el onboarding que sigue al vaciado.
- Desde el 2026-09-28 (`8993e4ce5`, `ae204458d`, `1c81703ff`) el receptor tardío corta por la hora de la señal y reparte lo que repone. La nota sobre el receptor no se re-midió: su convergencia también espera a un arranque en frío.

Triage 2026-10-08: abierto · medium → medium · DataWipeService marca la convergencia pendiente, pero solo la ejecuta el arranque (retryPendingBridges); «Vaciar datos» no pasa por un swap de container y nadie converge en caliente

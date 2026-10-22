---
id: dormant-convergence-request-from-a-groups-only-wipe
status: backlog
priority: low
area: "groups, onboarding"
created: 2026-09-27
source: "review adversarial de `wipe-data-keeps-groups-but-drops-their-bridged-rows` (2026-09-27, lentes de momento y de dinero); inferido por lectura, NO reproducido"
updated: 2026-10-08
---

# La petición de convergencia de un «Vaciar datos» en solo-grupos queda dormida y la heredan caminos que no la pidieron

## El síntoma, en lenguaje de usuario

Ninguno visible casi nunca. En el peor caso: tras vaciar mis datos en solo-grupos y activar Yala completo con
«Restaurar», el Inbox me pide a qué cuenta llegó un cobro de grupo que ya había aprobado en mi vida anterior.

## Lo medido (2026-09-27, leyendo código)

- En solo-grupos la convergencia sale en su guard de sesión privada y deja las dos peticiones puestas hasta activar Yala
  completo. Es a propósito: sin ellas esas filas no vuelven nunca.
- **Restaurar**: `FullModeActivationView` pide solo `markPending()`, pero hereda la petición de liquidaciones. Si el
  import tarda más que la espera de quiescencia (30 s), una liquidación cuya pata restaurada aún no ha llegado se
  re-puentea (pata virtual y borrador); cuando llega la restaurada, la deduplicación ya corrió. Quedan dos patas virtuales
  y un borrador; aprobado, cuenta doble.
- **Cierre de sesión**: `removeUserPreferenceKeys` no nombra las dos keys y solo las retira el relevo de persona, así que
  una petición dormida sobrevive a un cierre y la consume la sesión privada siguiente. Casi siempre inocuo (la
  convergencia es idempotente y solo toca liquidaciones sin ninguna pata).

## Qué hay que decidir

¿El restaurar retira la petición de liquidaciones heredada, y el cierre de sesión retira las dos?

## Relacionados

- [[wipe-data-keeps-groups-but-drops-their-bridged-rows]]

## Medido en 2.1 (triage 2026-10-08)

- `FullModeActivationView` sigue pidiendo solo `GroupsBridgeRestoreConvergenceStore.markPending()` al restaurar, y `markPending()` no retira `settlementLegsKey`, así que la petición de liquidaciones heredada sigue viva.
- La única retirada de las dos keys sigue siendo `GroupsBridgeRestoreConvergenceStore.clear` en el relevo de persona de `DataWipeService`; el cierre de sesión no las nombra.
- Sigue pendiente la decisión. Recomendación: sí a las dos (restaurar retira la de liquidaciones heredada; el cierre retira las dos), que cierra el doble conteo sin cambiar el caso normal.

Triage 2026-10-08: abierto · low → low · las dos peticiones siguen dormidas y heredables; el doble conteo exige restaurar con un import de más de 30 s y aprobar el borrador.

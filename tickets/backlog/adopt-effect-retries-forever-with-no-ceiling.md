---
id: adopt-effect-retries-forever-with-no-ceiling
status: backlog
priority: medium
area: "modo-nube, migración, adopt"
created: 2026-09-23
updated: 2026-09-23
source: "review adversarial de `an-incomplete-inventory-reads-as-the-whole-corpus` (2026-09-23), lente de desenlaces"
---

# Si entrar en tu cuenta de la nube no puede terminar, la app lo reintenta para siempre sin decírtelo

## El problema, en lenguaje de usuario

Entro en mi cuenta de la nube en un segundo teléfono. La app tiene que reconciliar lo que este teléfono tenía con lo
que ya está en la nube. Si esa reconciliación no puede terminar, la app lo reintenta cada vez que la abro, sin
decirme nada: la pantalla de Almacenamiento se queda como si no hubiera empezado, la sincronización no arranca y no
hay tarjeta ni salida.

## Por qué pasa (leído el 2026-09-23 en este árbol; no ejecutado)

`runAdoptOrphanReconcile` devuelve `.transient` → `runAdoptFlow` lanza `adoptRetry` → el runner deja el efecto
pendiente (`drainPendingEffects`, `Stop.effectFailed`) y `runGuarded` se lo traga. El par queda en
`(notStarted, pendiente)`, `startRuntimeIfStable` no arranca el motor y la pantalla pinta `.idle`. No hay techo ni
tarjeta: es el mismo hueco que `forward-migration-steps-have-no-ceiling-and-no-exit` cerró en los pasos de la ida.

Ya pasaba con la red (enumeración, Merkle, push). Desde `an-incomplete-inventory-reads-as-the-whole-corpus` pasa
también con una tabla local que no se deja leer, que es la causa que esperar NO arregla: antes de ese ticket el adopt
se completaba sin las huérfanas de esa tabla —pérdida silenciosa—; ahora no pierde nada, pero tampoco termina nunca.

Detalle de coste: cada intento enumera el backend entero y consulta `/sync/merkle` ANTES de leer el inventario local,
así que una avería local paga la red en cada reintento. Leer el inventario primero lo evitaría sin cambiar el
desenlace.

## Qué habría que decidir (es de producto)

1. ¿El adopt lleva techo, como los pasos de la ida? ¿Corto para la avería local y largo para la red?
2. ¿Qué ve la persona al vencer, y qué salida tiene? Ojo con `adopt-claim-stays-parked-with-no-ceiling`: la salida de
   la ida (`failedRollback` → «Reintentar» → `notStarted`) es un callejón para quien adopta.

## Criterios de aceptación

- [ ] Decisión de Jürgen sobre techo, texto y salida.
- [ ] Un adopt que no puede terminar por una causa que esperar no arregla sale con esa salida, con test.

## Relacionado

- `adopt-claim-stays-parked-with-no-ceiling` — el paso del claim del adopt (22 %), otro sitio del mismo flujo.
- `an-incomplete-inventory-reads-as-the-whole-corpus`.

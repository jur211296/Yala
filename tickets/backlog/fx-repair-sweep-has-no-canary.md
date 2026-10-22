---
id: fx-repair-sweep-has-no-canary
status: backlog
priority: low
area: "currency, telemetría"
created: 2026-09-08
updated: 2026-10-08
source: hallazgo de camino en chat-rows-sealed-before-the-fix-have-no-repair-path (2026-09-08)
---

# El barrido que rebobina tasas no deja ni un canario

## Qué pasa

`TransactionUpdateService.repairLegacyOneToOneRatesIfNeeded` corrige tasas de transacciones en todo
el parque instalado, y lo único que deja es un `print` bajo `#if DEBUG`. Su gemelo de la misma
función —el reparador de la cola— sí emite (`MetricsService.canary(.fxRepairQueueStuck, …)` con
`skipped`/`futile`).

Consecuencia: **no hay forma de saber si el rebobinado sirvió de algo.** Ni cuántas filas había
dañadas de verdad, ni cuántas se curaron en el sitio, ni cuántas volvieron a la cola, ni en cuántos
dispositivos el barrido se selló sin haber visto corpus. El ticket que lo pidió
(`chat-rows-sealed-before-the-fix-have-no-repair-path`) preguntaba «qué corpus alcanza», y hoy eso
solo lo responde un device-QA de una instalación.

## Por qué importa más que en un barrido normal

Es one-shot: si se selló mal en una parte del parque, no hay segunda oportunidad y tampoco señal de
que haya pasado. Un canario es lo único que distinguiría «no había nada que curar» de «nunca llegó a
mirar».

## Criterio de hecho (AC)

- [ ] El barrido emite un canario con el reparto: curadas en el sitio, reabiertas, candidatas totales.
- [ ] Emite también el caso de «no sellado por falta de corpus», que es el que avisaría de un sellado
      prematuro sistemático.
- [ ] El caso nuevo va **al final** del enum de canarios, no en medio: su posición se lee fuera.

## Medido en 2.1 (triage 2026-10-08)

- `TransactionUpdateService.repairLegacyOneToOneRatesIfNeeded` sigue sin `MetricsService`: solo `print` bajo `#if DEBUG` (incluido el «store sin transacciones; el barrido se reintenta»).
- Sigue colgando de `AppBootstrapper.loadExchangeRates`, justo antes de `updateProvisionalTransactions`.

Triage 2026-10-08: abierto · low → low · el barrido one-shot sigue sin canario; es telemetría, no un daño visible.

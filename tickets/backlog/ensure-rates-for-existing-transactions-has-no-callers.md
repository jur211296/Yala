---
id: ensure-rates-for-existing-transactions-has-no-callers
status: backlog
priority: very-low
area: "currency, fx, limpieza"
created: 2026-09-08
source: review adversarial de repair-queue-has-no-exit-for-partial-rate-rows (2026-09-08)
updated: 2026-10-08
---

# `ensureRatesForExistingTransactions` no la llama nadie

## Qué pasa

Medido el 2026-09-08 sobre `Yala/`, `YalaTests/` y `YalaUITests/`: `ensureRatesForExistingTransactions`
no tiene ni un llamador. Está declarada en `ExchangeRateServiceProtocol` y definida en el servicio, y
ahí se acaba.

Su docblock dice que debería llamarse «después del onboarding o al cambiar las divisas secundarias».
Ninguno de los dos caminos la llama hoy.

## Por qué merece un ticket y no un borrado a ciegas

Son dos posibilidades opuestas y hay que decidir cuál:

1. **Es código muerto** y se retira (con su línea del protocolo).
2. **Es una llamada que se perdió en algún refactor**, y entonces falta cobertura de tasas justo
   después del onboarding — que es cuando el usuario acaba de elegir divisas y todavía no tiene
   histórico.

La segunda tiene consecuencias para el usuario, así que no es un borrado mecánico.

## Criterio de hecho (AC)

- [ ] Decidir cuál de las dos es, mirando el historial de git de sus llamadores.
- [ ] Si es muerta: retirarla del servicio y del protocolo.
- [ ] Si falta el cableado: reponerlo donde corresponda, con test.

## Medido en 2.1 (triage 2026-10-08)

- Sigue sin llamadores: `git grep` solo la encuentra en `ExchangeRateService.swift` (protocolo, línea 24, y definición, línea 341).
- Primer criterio respondido: `git log -S` muestra que nació en `b6ad52ce8` (2026-01-31, «centralize currency definitions») sin ningún llamador, y ningún commit posterior la llamó. No es una llamada perdida en un refactor.
- Recomendación: opción 1 (código muerto, retirarla del servicio y del protocolo). Con ella baja a `very-low`: es limpieza.

Triage 2026-10-08: abierto · low → very-low · nunca tuvo llamadores desde que nació en b6ad52ce8; es limpieza de código muerto, sin efecto para el usuario.

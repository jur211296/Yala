---
name: bulk-cuenta-divisa-vieja
description: PR #110 — el método del ticket se BORRÓ (nunca tuvo llamador en toda la historia); el bloque bulk entero del servicio está muerto y ya divergió una vez en silencio. Sin device-QA.
metadata:
  type: project
---

**`TransactionService.bulkUpdateAccount` se borró, no se parcheó** (PR #110, 2026-09-08). El ticket
lo planteaba como «una asimetría entre tres hermanos: dos recalculan y uno no». Medido, era otra cosa.

**Why:** dos hechos que el ticket no tenía y que cambian la decisión:

1. **Nunca tuvo un llamador, en toda la historia del repo** — `git log -S` sobre todas las ramas, cero
   commits. No perdió su llamador: nació especulativo en el refactor C.3 y la UI jamás migró.
2. **Divergía de la ruta viva en DOS cosas.** Le faltaba también el bloqueo de transferencias.
   Parchear solo el recálculo habría dejado el segundo daño dentro y el método con aspecto de
   revisado — que es peor que el estado original.

**How to apply:**

- **El bloque bulk del servicio está muerto ENTERO, no era un método suelto**: seis operaciones, cero
  llamadores; `BulkEditSheet` llama siempre a `RecordsViewModel`. Y midiendo más lejos, los únicos
  usos vivos de `TransactionService` en todo el repo son `setContext` y `create` — `save`, `delete` y
  `deleteMultiple` tampoco los llama nadie. Ticket: `transaction-service-bulk-block-is-dead-code`.
  **Si alguien propone «unificar por la del servicio», la dirección correcta es la contraria**: la
  lógica buena y probada vive en el ViewModel.
- **La ruta viva (`RecordsViewModel.bulkUpdateAccount`) no tenía NINGÚN test** hasta este PR, ni del
  recálculo ni del bloqueo de transferencias, pese a ser lo que la app ejecuta de verdad. Conviene
  asumir lo mismo de los otros cinco bulk del ViewModel antes de tocarlos.
- **Fue a `done` directo, sin pasar por `qa/`**, y el criterio se puede reusar: se borró código sin
  llamador y se añadieron tests; la ruta que el usuario ejecuta no cambió ni una línea. No hay nada
  que mirar en pantalla, así que un device-QA aquí solo habría inflado la cola de Jürgen.
- **Deja tres tickets**: `initial-balance-date-move-leaves-converted-amount-stale` (medium, el mismo
  patrón por el tercer input —la fecha— en las cuatro rutas de import CSV),
  `converted-amount-sweep-blind-to-input-changes` (medium, el detector que ya existe vigila la mitad
  del patrón) y el del código muerto (low).

**El dato de sync que conviene recordar, porque es contraintuitivo y ya llevaba mal escrito en dos
tickets:** cambiar `currencyCode` **no emite un grupo `money` aparentemente coherente** — no emite el
grupo en absoluto. Ni `currency_code` ni `account_ref` pertenecen a grupo alguno en
`EntityEmissionMap`, y `DeltaEmitter` arma `touchedGroups` solo con las columnas cambiadas **que
tienen grupo**, así que el guard `coherenceGroupPartial` ni llega a evaluarse. La diferencia importa
al diagnosticar: invita a buscar el fallo en el guard, y el guard nunca corrió.

Relacionado: [[la-asercion-que-no-puede-fallar]] (quinto eslabón: tres de mis cuatro aserciones no
podían fallar) y [[mi-docblock-tambien-es-una-premisa]] (tercera variante: nombré un guard que
vigilaba otra superficie).

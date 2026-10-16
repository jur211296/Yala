---
id: records-orphaned-by-earlier-account-deletions-stay-invisible
status: qa
priority: high
area: "accounts, transactions, data-repair"
created: 2026-10-15
updated: 2026-10-16
source: encargo tablero-al-eliminar-una-cuenta-sus-movimientos-q-ofst (medido en simulador)
---

# Los movimientos que ya se quedaron sin cuenta por un borrado anterior siguen ahí, sin contar y sin salida

## Qué le pasa al usuario

Hasta la 2.1 de este encargo, eliminar una cuenta dejaba sus movimientos sin cuenta (`Account.transactions` es
`.nullify`). El arreglo impide que pase más, pero **no repara lo que ya pasó**: en el iPhone de QA de Jürgen siguen
Taxi 25 y Teléfono 33 de «Efectivo QA».

## Lo medido (2026-10-15, simulador iPhone 17 Pro, seed `cuenta-con-movimientos`, build anterior al arreglo)

Tras eliminar «Efectivo QA» (dos gastos, −58):

- El Panel pasó de **S/ 942** a **S/ 1.000**: los 58 desaparecieron del saldo y de «Gastos» (S/ 0,00).
- Estadísticas › Resumen dice «1 movimiento»; Estadísticas › Registros lista los tres, con el resumen «Gasto S/ 0,00».
- Las dos filas salen sin nombre de cuenta. Captura: `capturas/antes-2.png` del PR del encargo.

## Decisión (Jürgen, 2026-10-15 17:04)

Avisar que hay movimientos sin cuenta de borrados antiguos y dejar elegir a qué cuenta moverlos.

## Qué se hizo (2026-10-15)

- El Panel enseña un aviso «Movimientos sin cuenta» con la cifra. Abre una hoja con la cifra, cuáles son y «Mover a»
  (mismo lenguaje que la hoja de eliminar cuenta). Mover sigue las reglas de esa hoja: convierte con el tipo de cambio de
  su fecha, quita las dos patas de una transferencia cuya otra pata ya está en el destino, y un saldo inicial pasa a ajuste.
- El recuento se repite en cada recarga del Panel, así que también salen los que llegan tarde por sync (ticket
  `account-deletion-can-still-orphan-records-that-arrive-later`). El aviso espera a que el import esté quieto.
- Fuera, con ticket: las filas de grupo sin cuenta (`orphaned-group-records-stay-out-of-the-notice`).
- Medido en simulador (seed `movimientos-sin-cuenta`): antes, Panel S/ 1.000 y Gastos S/ 0 sin aviso; después de mover a
  «Banco QA», S/ 942 y Gastos S/ 58, sin aviso. Capturas en `~/Claude/worktrees/_capturas/2026-10-15-borrados-movimientos-sin-cuenta/`.
- Tests: `OrphanedRecordsLogicTests`, `OrphanedRecordsServiceTests`, XCUITest `OrphanedRecordsUITests`.

## Device-QA (Jürgen, iPhone de QA)

1. Instala el build de 2.1 que lleve este cambio.
2. Abre Yala en el Panel: debe salir «Movimientos sin cuenta» con un 2 (Taxi 25 y Teléfono 33 de «Efectivo QA»).
3. Toca el aviso: la hoja lista Taxi y Teléfono. Elige la cuenta en soles y toca «Mover a «…»».
4. El aviso desaparece, el saldo baja 58 y «Gastos» sube 58. En Registros, las dos filas ya llevan el nombre de la cuenta.

## Barrido de QA · 2026-10-16

Barrido de QA 2026-10-16 · se queda: lo funcional pasó en el simulador (Yala Dev, iOS 27.0, `c648223bc`, semilla `movimientos-sin-cuenta`): el Panel avisa «Movimientos sin cuenta · 2» con S/ 1.000; la hoja lista Taxi −25 y Teléfono −33; «Mover a «Banco QA»» deja el saldo en S/ 942, Gastos en S/ 58 y el aviso desaparece; en Buscar, Taxi ya lleva «Banco QA». Capturas `~/Claude/worktrees/_capturas/2026-10-16-barrido-qa-2-1-2/sovw-1…4`. `OrphanedRecordsUITests` (2) y `GroupRowsWithoutGroupUITests` (3) re-corridos en verde. Solo espera tu visto bueno al aviso nuevo del Panel, en el lote de capturas de `docs/qa/tanda-qa-jurgen-2.1.md`. Ya no pide iPhone.

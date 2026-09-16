---
id: csv-import-leaves-no-origin-mark-and-reuses-opposite-categories
status: backlog
priority: medium
area: "data, import"
created: 2026-09-16
updated: 2026-09-16
source: "AC pendiente de `csv-import-rows-fall-in-the-chat-sign-sweep` (criterio 3), creado en el barrido /qa del 2026-09-16"
---

# El importador de CSV no deja marca de origen en sus filas y reusa categorías de la naturaleza contraria

## El problema, en lenguaje de usuario

Importo mi histórico desde un CSV. Para la app, esas filas son indistinguibles de las que escribí a mano
hoy: nada dice que vinieron de un archivo. Y si el archivo trae un ingreso en una categoría que en Yala
existe como gasto (o al revés), la app la reusa igual, así que el signo y la categoría quedan en
desacuerdo. Lo primero obligó a proteger lo importado del barrido del chat con una heurística de «lote»
que falla con un import de una sola fila. Lo segundo descuadra totales.

## Lo medido (leído en el código de `2.1` @ `bebd57a57`, sin ejecutar)

- **Sin marca de origen.** Los cuatro `TransactionItem(` del importador no asignan `createdAt`
  (`Yala/Utils/TransactionCSVImportService.swift:187`, `:1107`, `:1502`, `:1663`), así que toma el
  default `Date.now` (`Yala/Models/TransactionItem.swift:95`).
- **Categoría solo por nombre.** El modo estricto busca la categoría por nombre, sin mirar `isIncome`.
  En modo «crear categorías nuevas», `CategoryImportHelper` reusa cualquier categoría homónima, y su
  comentario lo declara intencional, para que «Otros» sirva a las transferencias
  (`Yala/Utils/CategoryImportHelper.swift:45-47`). El detalle con todas las coordenadas ya está medido
  en `records-standalone-amount-discrepancy` (:85-95), que lo trata como causa de totales descuadrados
  pero no pide arreglar el importador.
- **Por qué importa la marca.** `csv-import-rows-fall-in-the-chat-sign-sweep` resolvió que el barrido del
  signo del chat no toque lo importado. Sin marca, lo distingue por la vecindad de `createdAt` (lote), y
  su residual conocido es que **un import de una sola fila no tiene vecino** y se trata como un gasto
  dictado.

## Aviso de diseño

**No reescribir `createdAt` con la fecha de los datos.** El propio importador filtra lo recién importado
por `createdAt >= importStart` (`TransactionCSVImportService.swift:236`, `:1157`, `:1548`, `:1711`), y el
barrido lo usa como señal de lote. Una marca de origen explícita no rompe ninguna de las dos cosas.

## Criterio de hecho

- [ ] Las filas importadas llevan una marca de origen explícita que el barrido del chat puede leer sin
      heurística de lote. Su ausencia en las filas ya importadas se trata como decida el ticket.
- [ ] Una fila cuyo signo contradice la naturaleza de su categoría se resuelve al importar (categoría de
      la naturaleza correcta, aviso o rechazo, según se decida), sin romper «Otros» en transferencias.
- [ ] Tests que fijan las dos cosas, con mutante que las ponga en rojo.

## Relacionados

- `csv-import-rows-fall-in-the-chat-sign-sweep` — de donde sale; queda en qa con su guion a mano.
- `records-standalone-amount-discrepancy` — la parte de la categoría, medida.

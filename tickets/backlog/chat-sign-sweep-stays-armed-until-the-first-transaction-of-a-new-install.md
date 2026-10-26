---
id: chat-sign-sweep-stays-armed-until-the-first-transaction-of-a-new-install
status: backlog
priority: low
area: "data, import, chat"
created: 2026-10-25
updated: 2026-10-25
source: hallazgo de camino del lote 12.6 (card d4od, ticket csv-import-leaves-no-origin-mark-and-reuses-opposite-categories)
---

# En una instalación nueva, el barrido del signo del chat sigue armado hasta el primer registro

Tipo: bug latente. Medido por lectura del código en `origin/2.2` (`dbdb5dfed`), sin reproducir.

## Qué pasa

`ChatUnsignedExpenseRepairService.repairUnsignedChatExpensesIfNeeded` es un barrido de una vez que voltea el signo de
los gastos que el chat guardó sin firmar entre el 2026-04-27 y el arranque en que corre. Con el store vacío **no marca
su flag** y se reintenta en el arranque siguiente (a propósito: un restore de iCloud puede traer el corpus viejo más
tarde). En una instalación nueva eso deja el barrido armado hasta que exista el primer registro, y entonces corre sobre
lo que la persona haya creado en esta instalación: `createdAt` está dentro de la ventana (`createdAt <= sweepRunAt`).

Una fila positiva en una categoría de gasto que no sea de un lote (2 s, `batchFlags`) y sin marcador de sistema se
voltea a negativa en el arranque siguiente. Hoy la app casi nunca crea esa fila (el formulario, la Bandeja, el chat y,
desde el lote 12.6, Apple Pay, la voz y el importador eligen la categoría por la naturaleza del signo), pero hay un
caso que sí: **importar un CSV de una sola fila con un reembolso** («Comida › Restaurantes» con +20), que el importador
conserva en la categoría de gasto a propósito. Con un import de varias filas, el lote lo protege.

## Por qué no se arregló en el lote 12.6

El ticket del importador pedía una marca de origen en cada fila. Se descartó ahí: exige un campo nuevo en
`TransactionItem` (despliegue del esquema de CloudKit a Production y columna nueva del canal personal de la nube), y su
único lector es este barrido. El hueco real que queda es este, y se cierra en el barrido, no en el importador.

## Salidas posibles (sin decidir)

- Cortar la ventana en el primer arranque de esta instalación con un build que ya firma: lo creado después no puede ser
  del código viejo. Ojo con el restore de iCloud: las filas restauradas conservan su `createdAt` viejo, así que siguen
  dentro.
- O marcar el flag en el alta de una instalación nueva (Welcome sin restore), y dejarlo armado solo cuando hay restore.

## Hecho cuando

Un registro creado en esta instalación (también un CSV de una fila con un reembolso) no lo voltea el barrido, y un
corpus viejo que llega por restore sigue reparándose. Con test de las dos cosas.

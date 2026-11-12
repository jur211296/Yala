---
id: group-expense-detail-like-record-detail
status: backlog
area: groups
priority: low
created: 2026-10-26
updated: 2026-10-26
source: lienzo «Una sola Yala» (card k2up), lo que quedó fuera del PR de la sesión S11
---

# El detalle de un gasto de grupo, con la forma del detalle de un registro

## Qué falta

El lienzo «Una sola Yala» (decisión de Jürgen del 2026-10-19, todas las recomendadas) pide que el detalle de un gasto
de grupo se parezca al de un registro. La sesión S11 hizo dos de las tres piezas: abre a media pantalla y «tu parte»
va en el color de la app. Falta la tercera:

- Una sola tarjeta de datos con las filas (Pagó, Tu parte, Categoría, Reparto), como `TransactionDetailSheet`.
- «Duplicar · Eliminar» abajo, con «Editar» arriba a la derecha (hoy Eliminar vive dentro del formulario).

Y, en la barra del detalle del grupo, «Miembros» y el engranaje siguen hechos a mano en vez de `YalaToolbarButton`.

## Por qué quedó fuera

Es rehacer la hoja (otra jerarquía y dos acciones nuevas en ella), no alinear piezas. Duplicar un gasto de grupo no
existe hoy: hace falta decidir qué se copia (reparto, pagador, fecha).

## Hecho cuando

El detalle de un gasto de grupo y el de un registro, lado a lado, tienen la misma estructura; los XCUITest de
`GroupsSmokeUITests` (detalle → editar) siguen verdes.

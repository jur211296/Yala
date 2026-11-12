---
id: balance-chart-last-axis-label-overlaps-and-today-pill-covers-the-top-label
status: done
priority: low
area: panel
created: 2026-10-16
updated: 2026-10-25
source: revisión de Lola de las capturas App Store 2.1 (16-oct, opcional «etiquetas del gráfico»)
---

# En la gráfica del Saldo, «apr 26» pisa a «oct 26» y la pastilla «Today» tapa «100K»

## Qué se ve

Panel del iPhone, Tendencias › Saldo con «Todo el tiempo» (dos años de datos): la última etiqueta del eje X («oct 26»,
la de hoy) cae a medio carácter de la anterior («apr 26») y se superponen. Y la pastilla «Today / Hoje» del último
punto se dibuja encima de la etiqueta más alta del eje Y («100K»). En el iPad, con más ancho, no pasa. Recortes:
`~/Claude/propuestas/ficha-app-store-2.1/_revision-lola/crops/en-6.9-08-chart.png`.

## Qué hay que mirar

La etiqueta de hoy se añade aparte de las marcas regulares del eje (`SmartAxisHelper`); si cae a menos de una
etiqueta de distancia de la anterior, una de las dos sobra. La pastilla necesita apartarse del eje Y o el eje dejar
hueco arriba.

## Cerrado (cola 2.2 · lote 12.5, 2026-10-25)

Ya estaba arreglado en 2.2 por la auditoría UX 2.2 · L3-17 (`d558cf1e6`): `SmartAxisHelper.droppingCrowdedNeighbors` aparta la penúltima etiqueta y la pastilla «Hoy» no sale del área de dibujo. Medido en el simulador (iPhone 17 Pro, «Todo el tiempo», semilla realista con dos años): «oct 24 · oct 25 · oct 26» sin pisarse y «Today» lejos de «75K» (`capturas/evidencia-card5-grafica-saldo-todo-el-tiempo.png` del PR). Sin cambio de código.

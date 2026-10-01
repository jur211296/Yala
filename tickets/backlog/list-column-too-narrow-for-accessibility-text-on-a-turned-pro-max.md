---
id: list-column-too-narrow-for-accessibility-text-on-a-turned-pro-max
status: backlog
priority: low
area: "design-system, iphone, adaptativo, records, planning, accessibility"
created: 2026-10-01
source: "iphone-landscape-headers-fill-the-short-screen (carril adaptativo), separado en su Paso 0 (D6)"
---

# Con texto AX5 en el Pro Max girado, la columna de la lista se queda estrecha

**Sale de** [[iphone-landscape-headers-fill-the-short-screen]], que lo traía anotado y lo dejó fuera a propósito: aquel
compacta la cabecera con poco alto; esto es el ancho de la columna de la lista.

## Qué le pasa al usuario

Girado, el Pro Max es ancho regular y Registros y Planificación pintan lista y detalle a la vez. La columna de la lista
mide lo mismo que en un iPad (`DS.Adaptive.listColumn*Width`, el ancho de un SE). Con texto AX5 ahí dentro «Este mes»
se parte en dos líneas y el chip «Presupuestos» se corta. Se puede usar, pero se lee mal.

Evidencia: `qa/evidencia-adaptativo-20261001/iphone-supports-landscape-orientation/despues/promax-ax5__03-planificacion-h.jpg`
y `promax-ax5__04-registros-h.jpg`.

## Por qué no basta lo que hay

`ListDetailOverlayLogic.listYieldsToDetail` aparta la lista **solo con algo abierto en el detalle**. Con «Elige un…» la
lista se queda en su columna estrecha, que es justo el caso de las capturas.

## Qué hacer, si se hace

Decidir si con tamaños de accesibilidad el split da más ancho a la lista (o la deja sola hasta que se abre algo) en
`ListDetailSplit`. Toca a Registros, Planificación y Grupos a la vez, y también al iPad con AX5: es una decisión de
layout del contenedor, no de una pantalla.

## Relacionados

[[iphone-landscape-headers-fill-the-short-screen]] · [[iphone-supports-landscape-orientation]] ·
[[large-text-leftovers-outside-the-main-iphone-screens]]

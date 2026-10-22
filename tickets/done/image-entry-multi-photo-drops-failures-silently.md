---
id: image-entry-multi-photo-drops-failures-silently
status: done
priority: medium
area: "image"
created: 2026-10-04
source: recorrido del registro por imagen (encargo 2026-10-04-mejorar-el-registro-por-imagen-de-punta-a-punta)
---

# Con varias fotos, las que fallan desaparecen sin aviso

## Qué le pasa al usuario

Elige 5 tickets de un viaje. Dos fallan (timeout, foto ilegible). La hoja dice «3 transacciones detectadas» y
nada más: el usuario cree que estaban todos y no sabe cuáles faltan.

## Dónde (medido en este árbol, base `5a7f6f9e6`)

`Yala/App/Views/Image/ImageSelectionView.swift`, `processAllImages()`: el `catch` por imagen solo imprime en
DEBUG y el resultado solo cuenta los borradores creados. No hay recuento de fotos que fallaron.

## Qué debería pasar

El resultado dice cuántas fotos no se pudieron leer y ofrece reintentarlas. Lo cubren las propuestas B y C del
lienzo; con A queda igual.

## Cerrado (2026-10-04)

Lo arregla el rediseño C del registro por imagen (`image-entry-end-to-end-redesign`).

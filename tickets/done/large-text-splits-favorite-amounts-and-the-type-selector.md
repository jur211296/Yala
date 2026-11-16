---
id: large-text-splits-favorite-amounts-and-the-type-selector
status: done
priority: medium
area: "a11y, nuevo-registro, favoritos"
created: 2026-11-12
updated: 2026-11-12
source: "revisión 2.3 · Nuevo registro, decisiones 63, 64 y 82 del 9-nov (card tablero-2-3-texto-grande-y-codigo-muerto-en-nuev-sqvu)"
qa-status: passed
qa-date: 2026-11-12
qa-notes: visto en el simulador iPhone 17 Pro y iPad Air 11 a AX3 y a tamano normal; tamano normal identico al pixel
---

# Con texto grande, importes de Favoritos y «Transferencia» partidos; vista de importe sin usar

## Qué le pasaba al usuario

Con el texto en tamaños de accesibilidad (AX3):

1. En Ajustes › Favoritos el importe se partía al lado del nombre («S/ / 3,000. / 00»), y la necesidad también
   («Opcio-nal», «Sin clasifi-cación»).
2. En Nuevo registro, «Transferencia» se partía en tres líneas en el selector de tipo («Trans-feren-cia»).

Y en el código quedaba `TransactionAmountInputView`, un importe con su selector de divisa que nadie usaba.

## Arreglo (2026-11-12)

- Favoritos: con texto de accesibilidad el importe y la necesidad bajan a su propia línea, enteros (el molde de
  «Esto entendí» de 2.2). A tamaño normal, la fila de siempre.
- Selector de tipo: si alguna etiqueta no cabe entera en su parte, los tipos se apilan, uno debajo del otro, y la cápsula
  elegida se sigue deslizando. A tamaño normal, la fila de siempre (diff de píxeles: 0 píxeles distintos).
- Se borró `TransactionAmountInputView`.

«Esto leí» no se tocó: su arreglo de 2.2 ya estaba en 2.3.

## Cómo se sabe

- `YalaUITests/NuevoRegistroTextoGrande23UITests` (4 casos): los dos de AX3 en rojo sobre la base y verdes con el
  arreglo; los dos de tamaño normal, verdes en los dos.
- `YalaTests/NuevoRegistroCodigoMuertoTests`: rojo con la vista de vuelta, verde sin ella.

Nada que probar a mano: se vio en el simulador.

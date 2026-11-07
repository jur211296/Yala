---
id: new-record-chip-row-hides-the-tags-chip-without-a-hint
status: qa
priority: low
area: "registro, ui"
created: 2026-11-05
updated: 2026-11-07
source: "mitad de producto de record-selectors-uitest-taps-the-tags-chip-off-screen (lote T8)"
---

# ¿La fila de chips de «Nuevo registro» enseña que hay un chip más a la derecha?

## Qué se sabe

El 2026-10-07 se midió en el iPhone 17 Pro (402 pt de ancho) que, con cuenta y subcategoría elegidas, el chip de
Etiquetas de «Nuevo registro» empieza en x=417: fuera de la pantalla, en la fila horizontal de chips
(`NewTransactionView`, `new_transaction_tags_chip`). El XCUITest lo resuelve arrastrando la fila
(`openSelectorFirstRow`); una persona tiene que adivinar que la fila se desplaza.

## Qué falta

Mirar en la versión actual, en el iPhone de 402 pt y en el SE, si la fila enseña algún indicio (un chip cortado en el
borde, un fundido) de que hay algo más. **Sin medir sobre la versión de hoy**: la posición del 7-oct puede haber cambiado.
Si no hay indicio, es una decisión de producto (indicio, otra fila u otro orden), no un arreglo de test.

## Medido el 2026-11-07 (lote 2.3, versión de 2.3, simulador iOS 27.2, seed `minimal`, cuenta y subcategoría elegidas)

Ya no hay fila horizontal: desde el lote 2.2 · 02 (L2-10) los chips fluyen en dos filas, así que el x=417 del 7-oct no
existe. Lo que queda depende del alto:

- **iPhone 17 Pro (402 × 874 pt):** «Etiquetas» se ve entero en la segunda fila (x=20, y=726), por encima de «Guardar».
  No hace falta indicio.
- **iPhone SE (375 × 667 pt):** la fila de cuenta y categoría asoma cortada por arriba de «Guardar» y «Etiquetas»
  (y=608–642) queda **entera debajo de «Guardar»** (y=593–643), que es la barra fija del pie. Se alcanza deslizando el
  formulario hacia arriba (tras deslizar, y=543). El único indicio es la media fila que asoma; nada dice que debajo hay
  otro chip.

Capturas: `chips-iphone-17-pro.png`, `chips-iphone-se.png`, `chips-iphone-se-deslizando.png` (en la evidencia del PR del
lote 2.3).

**Hallazgo de test:** `TransactionFormDecided02BUITests.test_tagsChip_isVisibleWithoutScrolling` pasa en el SE con el
chip tapado: comprueba que el marco cabe en la ventana, y `isHittable` también da `true`. No mira lo que tiene encima.

## Decisión de producto pendiente (no se implementa en este lote)

En el SE, ¿qué hace «Etiquetas» cuando no cabe sobre «Guardar»?

- **A.** Nada: se llega deslizando, como el resto del formulario en un teléfono pequeño.
- **B.** Un indicio: fundido o sombra en el borde de «Guardar» cuando hay contenido debajo.
- **C.** Otro orden: «Etiquetas» en la primera fila, junto a cuenta y categoría, o los tres más compactos en el SE.
- **D.** Otra fila: subir los chips por encima de los atajos (Mi parte · Favorito · Recurrente).

## Guion de QA (iPhone SE en simulador, Yala Dev)

1. Panel › «+» › Registro manual. Escribe un monto y toca fuera del teclado.
2. Elige una cuenta y una categoría.
3. Mira el pie: «Etiquetas» no se ve; desliza el formulario hacia arriba y aparece encima de «Guardar».
4. Decide A/B/C/D en la tarjeta.

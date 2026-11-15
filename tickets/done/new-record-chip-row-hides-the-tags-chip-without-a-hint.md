---
id: new-record-chip-row-hides-the-tags-chip-without-a-hint
status: done
priority: low
area: "registro, ui"
created: 2026-11-05
updated: 2026-11-15
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

## Medido el 2026-11-14 (versión 2.3 de hoy, iPhone SE 3.ª gen. en simulador, iOS 27.2, seed `minimal`, modo oscuro)

El caso es más estrecho que el 7-nov:

- **Categoría de nombre corto** («Restaurantes»): cuenta y categoría caben en una fila y «Etiquetas» (y=543–577) se ve
  **entera** sobre «Guardar» (y=593). Al completar el formulario desaparece la línea «Para guardar, falta…» y deja sitio.
- **Categoría de nombre largo** («Mantenimiento y reparaciones»): los chips pasan a tres filas y «Etiquetas» (y=575)
  asoma **a medias** por debajo de la barra de «Guardar». Deslizando un poco queda entera.

Capturas y maquetas de las opciones en `docs/qa/barrido-iphone-2026-11-14/decisiones/capturas/`. La decisión se pidió en
el artifact de decisiones del barrido (`docs/qa/barrido-iphone-2026-11-14/decisiones/`); Frank recomienda **A**.

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

Cerrado en el barrido de QA 2026-11-15 (barrido final de 2.3): pasa con sus tests verdes o por decisión ya tomada; detalle en docs/qa/barrido-2-3-final/lista.md.

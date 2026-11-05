---
id: new-record-chip-row-hides-the-tags-chip-without-a-hint
status: backlog
priority: low
area: "registro, ui"
created: 2026-11-05
updated: 2026-11-05
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

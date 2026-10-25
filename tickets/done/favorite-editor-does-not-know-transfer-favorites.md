---
id: favorite-editor-does-not-know-transfer-favorites
status: done
priority: low
area: "favorites"
created: 2026-10-22
updated: 2026-10-25
source: lote decidido 2.2 · 02, sesión A (L2-14)
---

# El editor de Ajustes › Favoritos no sabe editar un favorito de transferencia

## Qué pasa

Desde 2.2 un favorito puede ser de transferencia, con origen y destino (L2-14). Se crea desde el formulario de registro
(«Favorito» en una transferencia). La lista de Ajustes › Favoritos lo enseña bien («origen → destino», con el icono de
transferencia), pero al tocarlo abre `FavoriteEditorView`, que solo ofrece gasto e ingreso (`availableTransactionTypes`): ninguno sale
marcado, enseña cuenta, categoría y etiquetas, y no el destino. Medido leyendo el código el 2026-10-22: guardar desde ahí
conserva el tipo transferencia y el destino (el editor no los toca), y deja la divisa en la de la cuenta.

Consecuencias (review adversarial del 2026-10-22):

- Un favorito de transferencia anterior a 2.2, sin destino, no se puede completar desde ahí: hay que borrarlo y volverlo a
  guardar desde el formulario.
- El selector de cuenta no excluye el destino: se puede guardar con origen igual a destino.
- Tocar «Gasto» lo convierte en gasto y el destino se queda puesto, invisible.
- Se le puede poner categoría a una transferencia.

## Qué hay que decidir

Si el editor de Ajustes gana el modo transferencia (origen, destino, monto y descripción, como la hoja de guardar), o si
un favorito de transferencia solo se edita borrándolo y volviéndolo a guardar desde el formulario.

## Cierre (lote 12.2, 2026-10-25)

Decidido en autónomo (Paso 0, D6): el editor gana el modo transferencia con lo que ya hay. Un favorito de transferencia
enseña origen y destino con los chips del formulario de registro, sin categoría, etiquetas ni selector de tipo; el selector
de una cuenta excluye la otra y el guardado rechaza origen igual a destino (`FavoriteEditorTransferLogic`). Guardar un gasto
quita un destino colgando. Uno nuevo desde Ajustes sigue siendo gasto o ingreso. Tests: `FavoriteEditorTransferTests` y el
XCUITest `FavoritesCrudUITests#test_transferFavorite_editsOriginAndDestination` (rojo con el código anterior, captura
`capturas/antes-1-favorito-transferencia.png`). Card 93ta.

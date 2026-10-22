---
id: favorite-editor-does-not-know-transfer-favorites
status: backlog
priority: low
area: "favorites"
created: 2026-10-22
updated: 2026-10-22
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

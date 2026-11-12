---
id: favorites-at-record-time-amount-types-and-delete-2-3
status: done
priority: medium
area: "favorites"
created: 2026-11-12
updated: 2026-11-12
source: revisión 2.3 · Nuevo registro, decisiones 22, 69, 70, 71 y 72 (card tablero-2-3-favoritos-al-registrar-importe-tipos-bjoe)
qa-status: passed
qa-date: 2026-11-12
qa-notes: XCUITest FavoritesAlRegistrar23UITests en el simulador iPhone 17 Pro iOS 27.2, rojo sin el arreglo y verde con el, capturas en entregas
---

# Favoritos al registrar: el monto listo, los tipos bien y sin borrar a ciegas

Decidido el 9-nov (`docs/ux/revision-2-3-artefacto/fuente/decisiones-discusion.md`), ficha en
`docs/ux/revision-vistas-2.3/32-nuevo-registro/`.

1. **F1 + F4 (decisión 22).** Tocar un favorito rellena el formulario, abre el teclado y deja el monto seleccionado:
   escribir lo sustituye (antes había que borrar «12.00»). También el monto de origen de una transferencia entre
   monedas, y desde «Ver todos» al cerrarse la hoja. Los textos que prometían registrar «con un toque» dicen lo que pasa,
   en los 16 idiomas (`favorites.createTemplate`, `favorites.saveDescription`, `l2d.favorites.transferHelp`,
   `tips.favorites.detail` y los dos del tutorial). Las novedades publicadas de 2.2 no se tocan.
2. **Decisión 69.** La fila de favoritos del formulario solo enseña los del tipo elegido (en «Ingreso» ya no salen
   «Café» ni las transferencias). «Ver todos» y Ajustes siguen con todos.
3. **Decisión 70.** El editor ofrece «Gasto | Ingreso | Transferencia», con los nombres del formulario. Elegir
   «Transferencia» pide origen y destino. Un favorito de transferencia abierto sigue sin selector (card 93ta).
4. **Decisión 71.** Deslizar un favorito en Ajustes (y el «−» de Editar) pregunta con la misma alerta del editor. De paso:
   con «Solo gastos» el borrado resolvía el índice sobre la lista entera y borraba otro favorito; ahora usa la que se ve.
5. **Decisión 72.** Una transferencia sin destino (anterior a 2.2) se lista con su cuenta, «Cuenta Principal», no
   «Cuenta Principal → …».

Tests: `YalaTests/FavoritesAlRegistrar23Tests` (lógica, textos y borrado) y
`YalaUITests/Flows/FavoritesAlRegistrar23UITests` (cuatro casos, rojos sin el arreglo).

Encontrado y fuera: el reordenado tiene el mismo fallo de índices con «Solo gastos»
(`favorites-reorder-uses-the-shown-index-on-the-full-list`).

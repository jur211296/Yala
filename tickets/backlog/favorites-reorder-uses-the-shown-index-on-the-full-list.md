---
id: favorites-reorder-uses-the-shown-index-on-the-full-list
status: backlog
priority: low
area: "favorites"
created: 2026-11-12
updated: 2026-11-12
source: lote 2.3 · favoritos al registrar (hallazgo al arreglar el borrado deslizando)
---

# Reordenar favoritos con «Solo gastos» mueve otro favorito

## Qué pasa

En Ajustes › Favoritos la lista pinta `displayedFavorites`, que con «Solo gastos» quita los de ingreso y transferencia.
`FavoritesListViewModel.moveFavorites(from:to:)` recibe los índices de esa lista filtrada y los aplica sobre
`favorites`, la lista entera. Con un ingreso o una transferencia delante de los gastos, arrastrar un gasto mueve otro
favorito y reescribe el `displayOrder` de todos.

Medido leyendo el código el 2026-11-12, no reproducido en pantalla. El borrado tenía el mismo defecto y se arregló en el
lote de favoritos al registrar (`FavoritesAlRegistrar23DeletionTests.expensesOnly_resolvesTheIndexOnTheShownList`).

## Qué hacer

Resolver los índices sobre `displayedFavorites` y recolocar los ocultos sin cambiar su orden relativo. Test con un ingreso
delante de dos gastos y «Solo gastos» activo.

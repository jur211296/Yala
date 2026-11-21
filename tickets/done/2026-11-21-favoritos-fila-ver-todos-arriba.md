---
id: 2026-11-21-favoritos-fila-ver-todos-arriba
status: done
priority: medium
area: "nuevo-registro-b1, favoritos"
created: 2026-11-21
updated: 2026-11-21
source: "decisión de Jürgen del 20-nov (09:55), reclamada el 21-nov (05:47) desde TestFlight 2.3 (6)"
---

# Fila de Favoritos de Nuevo registro: «Ver todos» junto al rótulo, chips completos mientras quepan y centrados

En TestFlight 2.3 (6) la fila de Favoritos de la hoja B1 salía con el rótulo arriba y, debajo, bolitas de solo icono
alineadas a la izquierda con «Ver todos ›» al final. No era lo decidido.

## Decisión (Jürgen, 21-nov-2026 05:47, sustituye a la del 20-nov 09:55)

«Ver todos ›» a la altura del rótulo Favoritos, a la derecha; los favoritos se muestran como chips completos (icono y
nombre) mientras quepan en el ancho; solo cuando ya no caben pasan a bolitas de solo icono; la fila va centrada.

## Hecho

- `IconFavoritesRow` (`NuevoRegistroB1Pieces.swift`): cabecera con el rótulo y «Ver todos ›» en la misma línea (el
  relleno de toque del botón no agranda la línea); debajo, `ViewThatFits` entre chips completos y bolitas. Las bolitas
  van en un scroll cuyo contenido toma como mínimo el ancho visible, así que quedan centradas mientras quepan y
  arrancan en el margen cuando hacen scroll. Sin anchos fijos.
- Se mantiene: solo los del tipo elegido, transferencia con el icono de la cuenta destino, nombres con texto de
  accesibilidad, tocar una bolita la estira con su nombre, y los identificadores (`new_transaction_favorites_row`,
  `new_transaction_favorites_see_all`, `new_transaction_favorite_chip_<nombre>`). Nuevo: `new_transaction_favorites_label`.
- La pieza solo la monta `NewTransactionView`, que es el formulario de Nuevo registro y de los registros que abren
  desde Bandeja, Grupos, pagos y favoritos; los favoritos no salen al editar un registro guardado.
- Fixture `-uitest-seed-extra-favorites <n>` (`DevSeedExtraFavorites`) para medir con 3, 5 y 10 favoritos.

## Pruebas

`YalaUITests/FavoritosFilaB1/FavoritosFilaUITests` (4 casos, verdes en el iPhone SE y el 17 Pro): «Ver todos» en la
línea del rótulo y en el margen derecho; tres favoritos completos y centrados; cinco con un nombre largo pasan a bolitas
centradas; diez hacen scroll desde el margen. Capturas antes/después (`FavoritosFilaCapturasUITests`) en SE y 17 Pro,
claro y oscuro, en el artifact del cierre.

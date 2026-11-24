---
id: 2026-11-23-filtro-categoria-registros-detent-large
status: done
priority: medium
area: "filters, records"
created: 2026-11-23
updated: 2026-11-24
source: "Jürgen, pruebas de Yala 2.3 en el iPhone (23-nov)"
---

# El filtro de categoría de Registros esconde las subcategorías a media altura

En la hoja de «Categoría ▾» de Registros, tocar una categoría saca sus subcategorías debajo de la rejilla. La hoja abría
a media altura y las subcategorías quedaban fuera de la vista: no se notaba que habían aparecido.

## Hecho cuando

- Sin nada elegido, la hoja abre a media altura; con alguna categoría ya elegida, abre grande.
- Elegir una categoría sube la hoja a grande, con su animación, y sus subcategorías quedan a la vista.
- Pruebas de la lógica en `YalaTests/FiltroCategoriaDetent/`.

## Resolución (2026-11-24)

- `RecordsQuickCategoryDetentLogic` decide la altura al abrir y qué categoría acaba de elegirse.
- La hoja sube por UIKit (`growsSheetToLarge`, el molde medido de `swiftui-ds.md`): cambiar la `selection` de SwiftUI no
  mueve una hoja presentada. Plan B (abrir siempre grande) no hizo falta.
- Medido en el simulador: con 13 categorías la rejilla llena la hoja grande y las subcategorías seguían bajo el borde. La
  hoja se desplaza hasta ellas cuando el alto deja de cambiar (un desplazamiento pedido mientras la hoja crece se pierde,
  medido). El último grupo baja hasta el final del contenido, para quedar entero sobre «Listo»; uno de en medio, al centro.
- Bajar la hoja a media altura con el dedo deja que la próxima categoría elegida la vuelva a subir.
- Verificado en el iPhone 17 Pro (simulador, iOS 27.2): abrir vacía (media), elegir Alimentación (sube y enseña sus 4
  subcategorías), elegir Transporte en otra corrida, sumar una segunda categoría con la hoja ya grande y reabrir con algo
  elegido (abre grande). Capturas en `~/Claude/entregas/2026-11-24-filtro-categoria-registros-detent-large/evidencia/`.

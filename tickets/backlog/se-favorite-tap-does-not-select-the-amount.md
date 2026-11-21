---
id: se-favorite-tap-does-not-select-the-amount
status: backlog
priority: medium
area: "registro"
created: 2026-11-21
updated: 2026-11-21
source: "gate de la sesión «hoja B1 en Bandeja y Grupos» (21-nov): pedido por el revisor con checklist"
---

# En el iPhone SE, tocar un favorito no deja el importe seleccionado

En Nuevo registro, tocar el favorito «Café» abre el teclado, pero en el iPhone SE el importe «12.00» no queda
seleccionado: el cursor va al final y lo que se escribe no lo sustituye (la prueba escribe «4.5» y el importe sigue en
«12.00»; en el último fotograma del vídeo el teclado ya se cerró).

- Medido: `FavoritesAlRegistrar23UITests#test_f1_tappingAFavorite_opensTheKeyboardWithTheAmountSelected` cae 2 de 2
  en el iPhone SE (iOS 27.2) y pasa en el iPhone 17 Pro, con el binario de la sesión de la hoja B1 en Bandeja y Grupos.
- Inferido, sin medir contra la base: es anterior a esa sesión. Su cambio en Nuevo registro no toca la selección del
  importe (`selectsAmountOnRequest`) ni la fila de favoritos, y con «Café» (en soles) no sale la línea que quitó.
- Evidencia: `~/Claude/entregas/2026-11-20-nuevo-registro-b1-llevar-a-bandeja-y-grupos/evidencia/se-favorito-importe-sin-seleccionar.png`
  (izquierda, la captura del caso; derecha, el último fotograma).

Siguiente paso: correr el caso en el SE sobre 2.3 sin la sesión para fecharlo, y mirar si en el SE la petición de
selección llega antes de que el campo tenga el foco (el formulario se recoloca más con el teclado en una pantalla baja).

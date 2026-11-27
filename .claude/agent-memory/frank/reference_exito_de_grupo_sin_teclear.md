---
name: exito-de-grupo-sin-teclear
description: Cómo llegar a la pantalla de éxito de un gasto de grupo y al formulario de 3+ en el simulador sin teclear (y sin romper el teclado de los XCUITest)
metadata:
  type: reference
---

Seed `grupos` + `-uitest-deeplink groups`: «Viaje a Cusco» (3 miembros) → fila `group_expense_row_Souvenirs` →
Editar → tocar `group_expense_split_row` abre el reparto; tocar las filas de Beto y Tú las deja en $0 (todo para Ana).
Guardar la primera vez solo enseña «Elige de qué cuenta salió»: entonces `group_expense_account_row` → «Ahorros USD» →
Guardar → pantalla de éxito. Todo por toques: sin `type_text`/`axe type`, que dejan el simulador en «teclado físico» y
tumban los XCUITest siguientes ([[axe-no-ve-las-hojas]]: dentro de la hoja, `snapshot_ui` + `tap` de XcodeBuildMCP).

En Estadísticas › Distribución › Gráficas el «?» de la torta SÍ abre su hoja: corregido el mismo 27-nov. Lo de «no
está en el árbol y no responde» salió de buscarlo por su id (lo pisaba el de la página, ya arreglado: ahora es
`widget_info_categoriesPie`) y de tocar con `axe tap`, que ese día no llegaba a nada en el simulador de la Mini; con el
`tap` de XcodeBuildMCP abre. El Panel por defecto (también con `realista`) no trae la torta de categorías.

Y en zsh, `touch $F` con varias rutas en una variable no la parte: toca un fichero llamado con todas. Lista literal.

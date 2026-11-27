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

En Estadísticas › Distribución › Gráficas el «?» de la torta no está en el árbol de accesibilidad y el toque no abre
nada (medido el 2026-11-27); el Panel con seed `minimal` no trae las tortas. Para la hoja de ayuda, no cuentes con
capturarla por ahí.

Y en zsh, `touch $F` con varias rutas en una variable no la parte: toca un fichero llamado con todas. Lista literal.

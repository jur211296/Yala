# Revisión por vistas 2.3 · Cuentas, tarjetas, categorías, etiquetas y divisas (zona 39)

Revisión de UX y eficiencia de lo que se ordena en Ajustes, con el caso de Lucía: ajustar el saldo de una cuenta (el banco dice
S/ 1,250 y Yala S/ 1,180), archivar una Visa vieja sin perder lo gastado, poner Alimentación y Movilidad arriba y renombrar
Transporte, crear la etiqueta «Viaje a Cusco» y añadir el euro a sus monedas. No implementa nada y no elige: cada problema
prioritario (ocho) trae de tres a cuatro alternativas maquetadas y una recomendación. Decide Jürgen.

- **Abrir:** `index.html` (se abre en el móvil y en la Mac; capturas y estilo van al lado, en `capturas/` y `estilo.css`).
- **Respaldo:** `revision-cuentas-categorias.pdf` (65 páginas, ~6,5 MB).
- **Regenerar:** `cd fuente && python3 capturas.py <carpeta de PNG> && python3 build.py` (con `--todo <ruta>` deja la página única para imprimir el PDF).

## Vistas cubiertas

AccountFormView, AdjustmentModeSelectorView (solo en el modo «Solo anotar mis gastos»; leída en el código), AccountsSettingsListView,
CategoriesSettingsListView, CategoryDetailView, SubcategoryDetailView, SubcategoryNeedSelectorView, TagsSettingsListView, TagFormView y
CurrencySettingsView. Capturas del simulador (iPhone 17 Pro e iPad Pro 13, iOS 27.2) con las semillas de prueba de la app, sin
cambios (más el cambio a región Perú en divisas): vacío, con datos, editar, crear, eliminar, archivar, cambiar de moneda, texto grande (AX3) e iPad. El conductor de capturas
es `fuente/Revision39CapturasUITests.swift.txt` y no va en la app.

«Sin conexión» no se pudo poner en el simulador: lo de tipos de cambio se documenta desde el código.

## Problemas, por severidad

| | Problema | Recomendada |
|---|---|---|
| 1 · alta | Archivar una tarjeta aparta también lo que se gastó con ella (y su deuda deja de restar), y el interruptor está al fondo de cinco pantallas | A1: hacer ya tu opción A del 8-oct (archivar conserva el historial), con botón y hoja en la ficha corta del rediseño del 3-oct, avisando si la tarjeta aún debe |
| 2 · alta | Las categorías no se pueden ordenar; Ajustes (A-Z) y el selector al registrar (orden de fábrica) no coinciden | B1: «Reordenar» como en Cuentas, y ese orden manda al registrar; «Ingresos» aparte |
| 8 · alta | Con texto grande (AX3), Cuentas pierde los nombres de las cuentas y Etiquetas su última fila | H1 + H2: la fila se apila y las listas miden solas su alto |
| 3 · media-alta | Crear una categoría pide una subcategoría solo tras tocar Guardar: 12 toques y una alerta para tres subcategorías | C1: nombre y subcategorías en la misma pantalla, con «Sin dividir» |
| 4 · media | Al ajustar el saldo, el teclado tapa «¿Cómo lo corregimos?» y la opción preelegida puede reescribir todos los meses; tres nombres para el saldo de partida | D2: «Listo» en el teclado y «registro de ajuste» siempre preelegido (+ D4, los textos) |
| 5 · media-alta | Con número de cuenta, la lista enseña el número (casi completo) en vez del nombre | E1: el rediseño de la lista ya aprobado el 3-oct (nombre y «•••• 0019») (+ E2, pedir solo cuatro dígitos) |
| 6 · media | «Monedas secundarias» parece tocar las cuentas, viene con USD y EUR elegidas y solo caben dos; según el código, añadir una tapa la pantalla con «Actualizando registros…» sin tocar ninguno (en el simulador no se vio) | F1: «Tipos de cambio que sigues» (+ F3, no tapar la pantalla) |
| 7 · media | «No lo uses al registrar» se dice de cuatro formas; Etiquetas enseña «#5E5CE6», corta a 20 sin avisar y su X no pregunta | G1: «Usar al registrar» en Etiquetas y subcategorías (+ G3, arreglos de Etiquetas) |

Eficiencia, medido (Debug, simulador, 2 cuentas): abrir Ajustes › Cuentas tarda **32 ms** sin registros, **113 ms** con dos años y
**447 ms** con diez (mediana de 7 aperturas; marca `PERF ajustes-cuentas`). Crece con los registros porque la lista los lee todos para
calcular saldos, en el hilo principal. Hipótesis leídas en el código, con cómo medirlas: el saldo de cada fila recorre todos los
registros en cada pintado; el formulario de cuenta lee registros, pagos, favoritos y borradores al abrir; añadir una moneda baja un año
de tipos de cambio con la pantalla tapada (no se vio en el simulador).

## Lo que ya estaba decidido

Tres decisiones tuyas siguen sin hacer y la revisión se apoya en ellas: archivar conserva el historial (8-oct, opción A;
`tickets/backlog/archiving-exclusion-open-decisions.md`), la lista de Cuentas con el nombre y el número enmascarado y la ficha corta del
formulario (3-oct; `accounts-settings-list-redesign.md` y `account-form-redesign.md`). «Activas» en singular ya tiene ticket
(`single-item-active-toggle-uses-the-plural-filter-label.md`).

## Decisiones para Jürgen

1. Problema 1: ¿se hace ya la opción A del 8-oct (archivar conserva el historial), con el botón y la hoja de A1? ¿Avisar si la tarjeta aún debe? ¿Deslizar en la lista como atajo (A2)?
2. Problema 2: ¿Categorías gana «Reordenar» y ese orden manda en selector, filtros e informes (B1)? ¿«Ingresos» en su sección? ¿Fila «Frecuentes» (zona 32, C2)?
3. Problema 3: ¿nueva categoría con sus subcategorías en una pantalla (C1)? ¿Se permite «Sin dividir»?
4. Problema 4: ¿«registro de ajuste» siempre preelegido (D2)? ¿Un solo nombre, «saldo de partida», y signos «Tengo / Debo» (D4)?
5. Problema 5: ¿se adelanta el rediseño de la lista ya aprobado (E1)? ¿Solo cuatro dígitos en el campo, y recortar los números ya guardados (E2)?
6. Problema 6: ¿«Tipos de cambio que sigues» (F1) y sin tapar la pantalla (F3)? ¿Seguir solas las monedas de las cuentas (F2)?
7. Problema 7: ¿«Usar al registrar» en Etiquetas y subcategorías (G1) y el lote de Etiquetas (G3)?
8. Problema 8: ¿se corrigen ya la fila de Cuentas (H1) y el alto de las listas (H2)? Son de accesibilidad y podrían ir sin esperar al resto.

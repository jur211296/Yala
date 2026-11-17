Yala
# Registros: filtros rápidos de Cuenta y Categoría más bonitos, alineados y sin el hueco del hero
---
toca: Yala/App/Views/Records/Components/RecordsQuickFilterBar.swift, Yala/App/Logic/RecordsQuickFiltersLogic.swift, Yala/App/Views/Records/RecordsStandaloneView.swift, Yala/App/Views/Records/RecordsFiltersView.swift, Yala/App/Views/Statistics/RecordsTabView.swift, Yala/App/Views/Records/QuickFilters/, Yala/Utils/L10n+RecordsQuickFilters23.swift, Yala/Resources/*.lproj/Localizable.strings, YalaTests/RecordsQuickFilters/, tickets/done/2026-11-15-registros-filtros-rapidos.md
esfuerzo: high
cierre: cierra-sola
---

## Qué pidió Jürgen (15-nov, con captura de la pestaña Registros en el iPhone)
Los filtros rápidos que se añadieron debajo de «Nuevo registro / Voz / Foto / Yala IA» se ven muy mal.

1. **Quitar el chip de periodo («Este mes»).** El selector de periodo de arriba del hero ya es útil y simple. Quedan solo **Cuenta**, **Categoría** y **Más filtros**.
2. **Chips más bonitos y acordes a la app:** un poco más de espacio entre ellos, y quizá un ícono (por ejemplo tarjeta para Cuenta y etiqueta para Categoría) siguiendo el design system (vidrio, tipografía y colores de Yala).
3. **Misma experiencia de selección que en el resto de la app.** Al tocar Cuenta o Categoría, la selección (varias a la vez) debe sentirse como la del onboarding cuando se crea el primer presupuesto y se eligen varias categorías (`Yala/App/Views/Onboarding/PrimerosPasos/FirstBudgetFlowView.swift`), y como la elección de cuenta o categoría en Nuevo registro. Reutiliza esos componentes y no inventes una hoja nueva con otro estilo. Si el componente reutilizable vive fuera de `toca`, úsalo sin modificarlo o envuélvelo en `Yala/App/Views/Records/QuickFilters/`.
4. **Alineación:** la fila de Cuenta, Categoría y Más filtros va en la misma línea que los botones de vista lista y calendario, para que no quede el hueco de la captura. Comprueba que no se corte en el iPhone SE (si no entra, define una solución elegante y anótala en «Decidido sin consultar»).
5. **Hueco del hero:** en esta vista, entre el título del hero («Te queda») y el número grande hay demasiado espacio. Redúcelo para que se lea como un bloque. Solo el hero de Registros. El hero del Panel lo cambia otra sesión (`panel-saldo-y-tu-dinero`), así que no lo toques.

## Reglas
- Brand voice (`docs/planning/BRAND-VOICE.md`). Textos en `L10n+RecordsQuickFilters23.swift` y en todos los `Localizable.strings`. El español, neutro latinoamericano.
- Los filtros siguen funcionando igual (la misma lógica y combinación con Más filtros). Si quitar el chip de periodo deja código muerto en `RecordsQuickFiltersLogic`, límpialo.
- Modo claro y oscuro, Dynamic Type y VoiceOver con etiquetas claras.

## Pruebas
- Tests en `YalaTests/RecordsQuickFilters/` para la lógica (sin periodo, selección múltiple de cuentas y categorías, combinación con Más filtros).
- Prueba de punta a punta en el iPhone 14 por DeviceMCP (o simulador; en la Max puedes abrir un segundo simulador si otra sesión ocupa el primero), con capturas de antes y después, incluido el iPhone SE.

## Entrega y cierre
- Antes y después como artifact visual de Claude (nunca Markdown ni PDF).
- PR a 2.3, sin firma de IA.
- Cierre según el modo fijado al arrancar: si está completo y el modo lo permite, `/cerrar-total`. En nocturno, lo vital va a checkpoint con card para Jürgen, sin mergear lo incompleto.
- En el cierre van «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con su motivo o «Nada».

## Paso 0 — decisiones (resueltas por Frank, modo semi; menores y reversibles)

Ficheros: `RecordsQuickFilterBar.swift` (sin chip de Fecha, chips con icono y aire, hojas nuevas), `RecordsQuickFiltersLogic.swift` (selección múltiple pura), `QuickFilters/` (dos hojas nuevas), `RecordsTabView.swift` (fila única con Lista/Calendario y hero más junto), `RecordsStandaloneView.swift` (pide el hero compacto), `L10n+RecordsQuickFilters23.swift` + `Localizable.strings` (fuera `records23.quick.date`, una clave nueva), `SummaryHeaderStack.swift` (parámetro opcional para el aire del hero; fuera de `toca`, aditivo), `.claude/rules/session-filters.md` (la regla decía «un toque, un valor»), tests.

1. **Cuenta: varias a la vez con la fila de Nuevo registro** (`AccountSelectorRow`, sin modificarla). Tocar añade o quita; se aplica al cerrar («Listo» o deslizando). «Todas las cuentas» en la barra de la hoja cuando hay algo elegido.
2. **Categoría: la rejilla del primer presupuesto** (`TutorialSelectableTile`) y, debajo, las subcategorías de lo elegido en círculos para quitar las que no se quieran (como el paso 2 del onboarding). Se aplica al cerrar, de una vez: aplicado a cada toque, el Panel deduce «Gasto» de la primera categoría y lo deja puesto al sumar una de ingresos. Se pierde el buscador de la hoja rápida: el onboarding no lo tiene y «Más filtros» lo conserva.
3. **Forma en la sesión:** solo categorías enteras → `selectedCategories`; alguna a medias → todo en `selectedSubcategories`. Nunca las dos (el filtro exige las dos a la vez). Es lo que ya hace «Más filtros».
4. **Fila única:** Cuenta · Categoría · Más filtros a la izquierda, Lista/Calendario a la derecha. Si no cabe (SE, texto grande), los chips se parten en dos líneas con `FilterBandLayout` y los botones de vista se quedan arriba a la derecha. En modo duplicados (sin chips) el selector vuelve a su sitio.
5. **Hero:** aire rótulo→cifra `xs` (lo que usa el Panel desde hoy), solo en la pestaña Registros; Estadísticas › Registros sigue igual que sus pestañas hermanas.
6. **Iconos:** `creditcard` para Cuenta, `tag` para Categoría, `line.3.horizontal.decrease` para Más filtros; separación `sm`.

# Auditoría UX 2.2 · lote 8: Registros: ver, editar, buscar y filtrar

> **ALCANCE ESTRICTO:** solo los flujos del lote 8. Los criterios UX/UI se aplican solo a sus pantallas. Si ves algo fuera, anótalo en una línea en el informe y no lo toques.

Card: la de título «Auditoría UX 2.2 · lote 8: …» (búscala con `tablero listar --version 2.2`; muévela a in progress al empezar y a done al cerrar) (Yala, 2.2, high). Card madre ogl6: no la muevas.

**Base y PR: 2.2.** `lanzar-sesion` ignora --base: Frank ya te deja sobre origin/2.2; ANTES de tu primer commit, `git fetch origin && git log origin/2.2..HEAD` debe salir vacío. PR contra **2.2**.

## Fuentes
- Brief madre (método, cinco lentes, formato de informe, HTML acumulado y «Criterios UX/UI permanentes de Jürgen»): ~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md. Léelo entero.
- Mapa: docs/ux/mapa-de-flujos-2.2.md (sección lote 8).
- Lotes anteriores como ejemplo: ~/Claude/entregas/Yala--auditoria-ux-2-2-lote-7-cuentas-categorias/informe.md y ~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html.
- Referencia visual: ~/Claude/referencias-ui/kargul-2026-10-07/.

## Lote 8 · Registros: ver, editar, buscar y filtrar (del mapa)
| # | Flujo | Entrada | Pantallas | Ficheros | XCUITest |
|---|---|---|---|---|---|
| 8.1 | Ver todos mis registros | Más › Registros (o su pestaña) · pie del Panel · Estadísticas › Registros | `RecordsStandaloneView` (`ListDetailSplit`) → `RecordsTabView` (hero, `FilterControlBar`, lista) | `V/Records/RecordsStandaloneView.swift`, `V/Statistics/RecordsTabView.swift`, `V/Records/Components/RecordRowView.swift` | `StatisticsNavigation`, `AdaptiveNavigation` |
| 8.2 | Ver el detalle de un registro | Tocar una fila | `TransactionDetailSheet` (hoja en iPhone, columna en iPad) | `V/Records/TransactionDetailSheet.swift` | `RecordsDetailSheet` |
| 8.3 | Editar un registro | Detalle › Editar · menú contextual · ⌘E · resultado de búsqueda | `NewTransactionView` en edición | `V/Transactions/NewTransactionView.swift`, `VM/RecordsViewModel.swift` | `RecordsDetailSheet`, `KeyboardShortcuts` |
| 8.4 | Borrar un registro | Editor › Eliminar · pulsación larga › Eliminar · ⌫ en iPad | Alerta «Confirmar» / diálogo del menú | `NewTransactionView.swift`, `V/Records/Components/RecordRowContextMenu.swift` | no |
| 8.5 | Duplicar un registro | Pulsación larga › Duplicar · editor › Duplicar | `NewTransactionView` como duplicado → toast | `V/Records/Components/RecordRowContextMenu.swift` | no |
| 8.6 | Cambiar la categoría rápido | Pulsación larga › «Cambiar categoría» | `SubcategorySelectorSheet`, se aplica al cerrar | `V/Records/Components/RecordRowContextMenu.swift` | no |
| 8.7 | Ver los registros en calendario | Selector Lista/Calendario | `RecordsCalendarView` → día | `V/Records/Components/RecordsCalendarView.swift` | no |
| 8.8 | Encontrar duplicados | ··· › «Identificar duplicados» | `DuplicateModeBanner` | `V/Records/Components/RecordsOverflowMenu.swift` | no |
| 8.9 | Seleccionar varios y borrarlos | ··· › Seleccionar › papelera | Diálogo de confirmación | `V/Records/RecordsStandaloneView.swift` | parcial (`BulkEdit`, solo abrir) |
| 8.10 | Editar varios a la vez | Seleccionar >1 › lápiz | `BulkEditSheet` (cuenta, subcategoría, etiquetas, nota, monto) | `V/Records/BulkEditSheet.swift`, `VM/BulkEditViewModel.swift` | `BulkEdit` |
| 8.11 | Buscar un movimiento | Pestaña lupa · ⌘F | `GlobalSearchView` (chips Todo/Nota/Categoría…) → editor; «Ver todo» → Estadísticas › Registros | `V/Search/GlobalSearchView.swift` | parcial (`KeyboardShortcuts`, ⌘F) |
| 8.12 | Filtrar registros | ··· › Filtros · chips de `FilterControlBar` | `RecordsFiltersView` (cuentas, categorías, etiquetas, tipo, necesidad, divisa, «nota contiene») → «Aplicar» | `V/Records/RecordsFiltersView.swift`, `VM/RecordsFiltersViewModel.swift`, `V/Filters/FilterControlBar.swift` | `Filters`, `DeferredFilters`, `CurrencyFilterStats` |
| 8.13 | Filtrar excluyendo | Segmento Incluir/Excluir | `RecordsFiltersView` → `ExcludeModeBadge` | `V/Filters/ExcludeModeBadge.swift` | `AdvancedFilters` |
| 8.14 | Abrir un registro en otra ventana (iPad) | Menú contextual | Ventana nueva | `Yala/App/Scenes/OpenInNewWindowButton.swift` | `MultiWindow` |
| 8.15 | Ver un gasto de grupo desde mis registros | Tocar un registro que viene de un grupo | Formulario en solo lectura con aviso | `NewTransactionView.swift` | no |

**Visto en el código:**
- Hay dos listas de Registros distintas (Más › Registros y Estadísticas › Registros).
- El detalle solo ofrece «Editar»: no hay borrar ni duplicar ahí. No se puede deslizar para borrar.
- La alerta de borrar se titula «Confirmar» y no dice qué se borra.
- La búsqueda abre el editor, no el detalle como en Registros. «Ver todo» pone el período global en «Todo» sin avisar.
- La selección múltiple está escondida en el menú ···.
- Cerrar los filtros con la X descarta lo elegido sin avisar; cambiar Incluir/Excluir borra la selección.
- En gastos de grupo, «Duplicar» sale atenuado sin explicar por qué.

**Tickets abiertos del lote:** `filtro-de-cuentas-se-colapsa-al-navegar-a-registros`,
`stats-filter-segment-tap-should-ask-include-or-exclude`, `faq-says-long-press-starts-bulk-edit`,
`bulk-move-to-another-currency-account-relabels-the-amount`, `save-error-alert-lies-when-the-context-autosaves`,
`ipad-list-highlights-the-open-row`, `ipad-records-empty-detail-half-hidden-with-chat-open`.
**Cards de 2.2 que lo cambian:** «Al tocar un segmento de una gráfica con exclusiones activas, que la app pregunte…»,
«El detalle de un registro pinta "≈ 0,00"…».

---

## Qué hacer
1. Recorre cada flujo en el simulador; capturas en ~/Claude/entregas/<sesión>/capturas/.
2. Informe en español (entregas/<sesión>/informe.md): mejoras numeradas L8-1, L8-2…; por cada una: problema, tipo de usuario, captura, opciones A/B/C y recomendación. Añade la sección del lote 8 al HTML acumulado sin borrar nada.
3. No implementes cambios de UX: solo propone. Arregla únicamente bugs claros, cada uno con su card (Yala, 2.2, frank), en un PR a 2.2 con antes/después.
4. Una card en espera decisión (Yala, 2.2, assignee jurgen) por cada mejora, con sus opciones y la ruta de sus capturas.

## Elecciones de UI: variantes y CERRAR (Jürgen, 2026-10-14 13:01)
Si alguna mejora es una elección visual, construye ~/Claude/propuestas/auditoria-ux-2.2/variantes-L8.html: autocontenida (imágenes en base64), pestañas o rejilla, **2–3 variantes claramente distintas lado a lado** por item más el «antes», hechas con maquetas reales en el simulador. Guarda también las PNG de cada variante en ~/Claude/entregas/<sesión>/capturas/ (`L8-k-antes.png`, `L8-k-A.png`…), porque Frank se las enseñará a Jürgen pregunta por pregunta.
**No esperes la elección de Jürgen.** Cuando termines, `xcrun simctl shutdown all` y cierra normal con /cerrar-total. Frank junta las decisiones después y las guarda en las cards para la fase de implementación.

## Reglas duras de UI
- NADA de degradados, NADA de glows/brillos, NADA de contraste en blanco sólido.
- El botón «Siguiente» NO se toca.
- El liquid glass se queda.
- La moneda «S/» frente a «PEN» es una preferencia del usuario: nunca la pongas como opción A/B/C.
- Capturas de HOY (de esta sesión) y maquetas reales en el simulador para cada propuesta visual.
- Copy nueva en los 16 idiomas (es-AR con voseo).

## Cómo
- Pipeline serie en la Mini: `nice -n 10 xcodebuild -jobs 2`, como máximo 1 simulador, `xcrun simctl shutdown all` al terminar.
- Tests de lo que arregles con -only-testing y /gate.

## Reglas
Totalmente autónomo: nunca AskUserQuestion ni preguntas, decide tú. Sin deploy.

## Paso 0 (Frank, 2026-10-14, autónomo)

- **Base:** `origin/2.2` (959dd3a64); `origin/2.2..HEAD` vacío. PR contra 2.2.
- **Corpus:** `-uitest-seed realista` (2 cuentas, 2 años) para 8.1–8.14; `-uitest-seed grupos` + un gasto de grupo creado en la app para 8.15 (ningún seed deja un gasto de grupo puenteado y vivo).
- **Qué cuenta como bug claro (se arregla):** datos que se pierden o se descuadran, un número que miente, un texto mal formado o que describe algo que no existe, VoiceOver que lee otra cosa. Todo lo demás es propuesta con card.
- **«Ver todos» de Buscar (cuenta 204 y enseña 0):** arreglo mínimo que no toca el modelo de filtros: «Ver todos» despliega en Buscar todos los resultados que contó, sin cambiar el período global. Llevarlo a Registros con un filtro de búsqueda real queda como propuesta (L8), porque cambia el modelo de filtros de toda la app.
- **Edición y borrado en lote de registros de grupo:** se bloquea igual que ya se bloquean las transferencias (aviso y nada cambia); el borrado en lote se salta los de grupo y lo dice en la confirmación. Mismo criterio que el menú contextual (`RecordContextActionLogic`). Toca el bridge de grupos ⇒ review adversarial.
- **«Octubre De 2026»:** se arregla solo en el calendario de Registros (alcance estricto); las otras cuatro pantallas con el mismo patrón van anotadas en el informe.
- **Copy nueva:** 16 idiomas (es-AR con voseo), leyendo BRAND-VOICE.
- **Variantes visuales:** maquetas locales en el simulador (parche fuera del PR), `variantes-L8.html` autocontenido.

---
id: stats-filter-segment-tap-should-ask-include-or-exclude
status: backlog
priority: medium
area: "statistics, filters, ux"
created: 2026-09-17
updated: 2026-10-08
source: "UX Jürgen 2026-09-17 (bugs de experiencia sin ticket)"
---

# Al tocar un segmento con filtros activos, preguntar si filtrar o excluir (no asumir excluir)

## Qué pasa hoy (experiencia)

Si el usuario ya está usando **excluir** (p. ej. excluir una cuenta) y luego toca un segmento de una gráfica, la app **asume excluir** ese segmento. No ofrece la alternativa de **filtrar/incluir** solo ese segmento.

## Qué quiere Jürgen

Revisar a fondo la integración de filtros **entre vistas** y **dentro de una misma vista**. Al tocar un segmento, **preguntar**: ¿excluir o filtrar ese segmento? Así se puede **combinar incluir y excluir** con más flexibilidad.

## Alcance

- Estadísticas (gráficas / segmentos) y cómo el gesto escribe en el modelo de filtros de sesión.
- Consistencia al navegar entre subvistas (Distribución, Tendencias, Registros, etc.): el mismo gesto no debe mutar el filtro de formas distintas sin aviso.
- No es solo copy: es el modelo de composición include∪exclude.

## Nota

Ticket de producto/UX gordo: conviene `/spec` corto antes de implementar el diálogo y la composición.

## Pregunta para Jürgen (triage 2026-10-08)

El modelo de hoy no puede combinar incluir y excluir: tiene un solo interruptor de modo, y cambiarlo vacía los filtros.

- **A.** Diálogo al tocar un segmento, solo con el modo excluir activo: «Excluir» o «Ver solo esto». La segunda opción cambia de modo y avisa de que se pierden las exclusiones. Barato, pero no combina.
- **B.** Composición real: cada dimensión guarda un conjunto de incluidos y otro de excluidos, y tocar un segmento pregunta siempre. Es lo que pediste («combinar incluir y excluir»), pero toca `SessionState`, `FilterService` y todas las barras de filtros. Necesita un `/spec`.
- **C.** El tap mantiene el modo actual, y una pulsación larga abre un menú con las dos acciones. Además de A o de B.

**Recomendación: B, con `/spec` antes.** A no da la combinación que pediste, y hacerlo después obligaría a rehacer el diálogo. Con B la prioridad queda en `medium`.

## Medido en 2.1 (triage 2026-10-08)

- `SessionState.isExcludeMode` (`SessionState.swift:229`) es un solo interruptor para todas las dimensiones, y su `didSet` (`:232-245`) vacía todas las selecciones al cambiar. Por eso, estando en excluir, «ver solo este segmento» obliga hoy a perder las exclusiones.
- Los taps de `CategoriesTabView.swift:541` y `:723-731` (Sankey) escriben en el modo activo, sin preguntar.
- Ningún commit de Estadísticas posterior al 2026-09-17 toca la composición de filtros.

Triage 2026-10-08: abierto · medium → medium · El modo excluir sigue siendo un único interruptor global que vacía todas las selecciones al cambiar, y tocar un segmento no ofrece elegir; sin commits que lo toquen desde el 2026-09-17

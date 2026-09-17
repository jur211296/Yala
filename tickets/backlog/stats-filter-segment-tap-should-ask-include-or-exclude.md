---
id: stats-filter-segment-tap-should-ask-include-or-exclude
status: backlog
priority: medium
area: "statistics, filters, ux"
created: 2026-09-17
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

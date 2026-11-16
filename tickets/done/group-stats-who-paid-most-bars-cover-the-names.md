---
id: group-stats-who-paid-most-bars-cover-the-names
status: done
priority: medium
area: groups, statistics, ui
created: 2026-11-07
updated: 2026-11-10
source: revisión por vistas 2.3 de Grupos (zona 37), PR #856
---

# En «¿Quién puso más?» las barras tachan los nombres

En Estadísticas de un grupo, la tarjeta «¿Quién puso más?» pinta las barras **encima** del nombre de cada persona: en el
viaje de prueba, «Lucía» y «Beto» salen atravesados por su barra. Pasa a tamaño normal y con texto AX3. Además, tu fila
dice «Lucía» y no «Tú», como el resto de Grupos.

Evidencia: capturas `16-estadisticas` y `ax3-16-estadisticas` de `docs/ux/revision-vistas-2.3/37-grupos/capturas/`
(iPhone 17 Pro simulado, iOS 27.2, 7-nov-2026). Código: `GroupStatsView.swift` (barras con alto fijo n × 44, l. 291) y
`GroupStatsViewModel.swift:307-317` (el nombre).

Criterio: los nombres se leen enteros, sin la barra encima, a tamaño normal y con AX3; tu fila dice «Tú».

## Resuelto (2026-11-10, mejoras necesarias 2.3 · lote 06)

«¿Quién puso más?» deja la gráfica de 44 pt fijos por persona y pasa a filas: el nombre arriba y, debajo, la barra con el
importe al final; con texto de accesibilidad el importe baja a su línea. Tu fila dice «Tú». El carrusel de «Todas» mide
el alto de cada página en vez de estimarlo. Lo fijan `GroupsNecesarias23Lote06UITests#test_whoPaidMost_*` (tamaño normal
y AX3 en el carrusel de «Viaje a Cusco»; rojo con el código de antes) y `GroupsNecesarias23Lote06Tests`. Capturas antes y
después en el PR.

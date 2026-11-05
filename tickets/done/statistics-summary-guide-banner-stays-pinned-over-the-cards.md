---
id: statistics-summary-guide-banner-stays-pinned-over-the-cards
status: done
area: statistics
priority: low
created: 2026-10-14
updated: 2026-11-05
source: auditoría UX 2.2, lote 5 (primeros días), encontrado fuera del lote — es del lote 11
---

# En Estadísticas › Resumen, la guía «Yala analiza por ti» se queda arriba y tapa las tarjetas al desplazar

**Clase:** observación de UI para el lote 11 (Estadísticas). No se tocó en el lote 5.

## Qué se vio (medido en el simulador, 2026-10-14)

Primera visita a Estadísticas: al bajar, el banner de guía «Yala analiza por ti» no se va con el contenido; queda
bajo los chips y la tarjeta de «Tu salud financiera» o «Insights con IA» pasa por debajo, cortada.

Capturas: `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-5-primeros-dias/capturas/5.7-02-globo-al-bajar.png`, `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-5-primeros-dias/capturas/B5-despues-2-globo-al-verse-el-selector.png`.

## Resolución (2026-11-05, lote P3 de 2.3)

La guía la montaba `DetailContainerView` encima de las páginas, fuera de su scroll. Ahora cada subpestaña la pinta como
primera pieza de su scroll (`StatsGuideSlot`, por entorno), en las cuatro: se va con el contenido, como la del Panel.
Test: `StatisticsGuideScrollsAwayUITests` (seam `-uitest-show-guides`); con el código de antes la guía subía 52 pt y el
hero 553 (rojo), con el arreglo verde. Capturas en el PR.

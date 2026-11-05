# Lote P3 · Estadísticas
toca: `CategoriesTabView.swift`, `StatisticsView.swift`

Rama base: 2.3. Un solo PR. Máquina: cualquiera. Usa simulador (pipeline serial).
Lote producto (cola-2-3-propuesta.md §3 P3).

Cards:
1. Entrar en Estadísticas tarda ~1 s, casi todo en pintar.
2. Con «Todo el tiempo», el Sankey de Distribución se recalcula en cada repintado.
3. Distribución recalcula dos veces cada vez que tocas el filtro.
4. Panel y Estadísticas · un filtro que se quedó puesto tras quitarlo y la guía que tapa las tarjetas (sin versión).

Hecha cuando: las cuatro hechas, tests en verde. No inventes features nuevas de Estadísticas.

PREGUNTAR, NO SALTAR. `tablero` + /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D0 · Rama base** → `2.3`, como dice el encargo. El worktree nació de `2.2`; se recolocó la rama (sin commits propios) sobre `origin/2.3`.
Por qué: el encargo lo pide y la cola de 2.3 vive ahí. Alternativa descartada: trabajar sobre 2.2 (PR contra la rama equivocada).

**D1 · Card «Sankey con Todo el tiempo»: dónde se corta la deriva** → anclar el inicio de `.allTime` al inicio del día (hace 10 años desde `startOfToday`) en `DetailPeriod.dateInterval` y en su espejo `WidgetPeriod.dateInterval`; y el respaldo de `.custom` sin rango cierra en el fin de hoy, no en `now`.
Por qué: la clave del Sankey (`sankeyInputKey`) incluye el intervalo; con `now` cambiaba en cada evaluación. Corrige la causa, no el síntoma. Alternativa descartada: sacar el intervalo de la clave o compararla por días (dejaría la deriva viva para cualquier otro consumidor).

**D2 · Card «Distribución recalcula dos veces»** → quitar el observador duplicado de la naturaleza en `CategoriesFilterRecalcObservers`; se queda el del body, que además recoloca lista y carrusel antes de recalcular. El debounce que el ticket también menciona queda fuera.
Por qué: el criterio de la card y del ticket es «un toque, un recálculo». Alternativa descartada: añadir debounce de 200 ms (cambia el tiempo de respuesta de todos los filtros; no lo pide la card; se anota como hallazgo).

**D3 · Card 4, la guía que tapa las tarjetas** → la guía de cada subpestaña pasa a ser la primera pieza del scroll de esa subpestaña (`StatsGuideSlot`, por entorno), en las cuatro, no solo Resumen.
Por qué: el contenedor la montaba encima de todas las páginas; arreglar solo Resumen dejaría las otras tres con el mismo defecto. Alternativa descartada: dejarla fija y dar margen superior al scroll (sigue robando alto de pantalla).

**D4 · Card 4, el filtro del Panel que se quedó puesto** → reproducir en simulador con el código de hoy y el log abierto. La causa probable ya la cerró el lote P2 ayer (la vuelta a `.active` dejaba el freno del Panel puesto si la escena llegaba antes que la app, y todo cambio de filtro se tiraba en silencio hasta relanzar). Si no se reproduce, se descarta con medición y esa explicación.
Por qué: el hechaCuando admite «descartado con medición». Alternativa descartada: añadir otro mecanismo defensivo sin reproducción.

**D5 · Card «Entrar en Estadísticas tarda ~1 s»** → su hechaCuando exige medir en un iPhone en Release; esta máquina no tiene iPhone físico y en Release las marcas de tiempo no existen. Se mide en simulador (Debug) antes/después de este lote y se pregunta al bot a las 5:00 cómo cerrar esa card (hora nocturna hasta entonces).
Por qué: regla dura de no saltar ni asumir. Alternativa descartada: cerrar la card con la medida del simulador como si fuera la del iPhone.

**D6 · Test de la guía** → nuevo seam DEBUG `-uitest-show-guides` (las guías se callan bajo `-uitest`) y un XCUITest que comprueba que la guía sube al desplazar en Resumen y Distribución.
Por qué: sin seam no hay forma determinista de verla en XCUITest. Se mide que el test cae con el código de antes.

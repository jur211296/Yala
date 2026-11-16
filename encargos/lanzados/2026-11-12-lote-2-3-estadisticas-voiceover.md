Yala
# Decidido 9-nov 2.3 · Estadísticas: la comparación en Tendencias y VoiceOver de las gráficas
card: tablero-2-3-estadisticas-la-comparacion-en-tende-1yeg
toca: Yala/App/Views/Statistics/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Discusión del artefacto 2.3, decisiones 29 y 26. Card reutilizada. Ficha: docs/ux/revision-vistas-2.3/35-estadisticas/ficha.md.

## Encargo y criterio de terminado
Implementar SOLO estos 2 puntos:
1. La comparación deja de cambiar en silencio en Tendencias. Opción A: Tendencias lleva el mismo selector de comparación (dice contra qué compara) y todas las pestañas cortan hasta hoy.
2. VoiceOver lee las gráficas con conclusión y cifras, no como un recuento (V1 + V2), y cada tipo lleva la descripción de gráficas de iOS (Audio Graph). Se valida con tests y el árbol de accesibilidad, no en un QA a mano de Jürgen.

Reglas del lote:
- La decisión ya está tomada el 9-nov (`docs/ux/revision-2-3-artefacto/fuente/decisiones-discusion.md`). Implementa exactamente la opción elegida; no reabras la decisión ni ofrezcas alternativas.
- Antes de cada punto: confirma en código que sigue vivo en origin/2.3 y corre `git log origin/2.3..origin/2.2 -- <vista>`. Si 2.2 ya lo arregló, no lo portes a mano: documéntalo en el PR y queda para la decisión de integrar 2.2 en 2.3 (card tablero-2-3-no-tiene-los-arreglos-de-2-2-de-las-3a6c).
- Un test de regresión por punto (unit o XCUITest según `qa/coverage-index.json`), rojo sin el arreglo y verde con él. Capturas antes y después de lo que se vea.
- Textos nuevos según docs/planning/BRAND-VOICE.md y en los 16 idiomas, cuando toque copy.
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día.
- gate de proyecto.
## Añadido por Frank (Jürgen, 10-nov 6:03 Lima)
- Este lote espera en la cola a que cierre el merge de 2.2 en 2.3. Antes de nada, comprueba que `git rev-list --count origin/2.3..origin/2.2` dé 0 o casi 0. Si 2.3 no tiene lo de 2.2, para de inmediato con un `BLOQUEANTE:` corto.
- Haz tú el QA en el simulador o en el iPhone 14 por DeviceMCP y mueve la card a done con evidencia. Solo queda en qa lo que de verdad necesite la mano de Jürgen, y lo dices en el cierre.

FIN

## Sobre el catálogo de textos (`Yala/Resources`)

Jürgen (10-nov 12:54 Lima) sacó `Yala/Resources` del `toca:` de los lotes 2.3 para que corran dos sesiones a la vez. Puedes editar el catálogo de textos igual, pero otra sesión puede estar tocándolo en paralelo: antes de abrir el PR y de cerrar, ponte al día con `origin/2.3` (o la base del encargo) y resuelve cualquier cruce en `Yala/Resources` conservando los textos de las dos ramas. Anótalo en el cierre.

## Paso 0 (Frank, 12-nov, sesión nocturna)

Comprobado antes de tocar nada:
- Base: la rama nació de `2.2`; se rehízo sobre `origin/2.3` (sin commits propios). `git rev-list --count origin/2.3..origin/2.2` = 0: 2.3 ya tiene lo de 2.2.
- `git log origin/2.3..origin/2.2 -- Yala/App/Views/Statistics/` vacío: 2.2 no arregló ninguno de los dos puntos.
- Los dos siguen vivos en `origin/2.3`: Tendencias no tiene selector (`TrendsTabView` lee `sessionState.comparisonMode` sin pintarlo) y Distribución/Tendencias cortan el período anterior en el último día con datos (`comparisonDataEnd`, `alignedPreviousItems`, `alignedPreviousTotal` con el dominio de datos), Resumen en hoy (`alignedPreviousInterval(asOf: now)`). VoiceOver: las seis gráficas dicen recuentos y solo `CashFlowCellMiniChart` tiene `accessibilityChartDescriptor`.
- La «otra sesión viva» que avisó `lanzar-sesion` (registrar-decisiones del 5-nov) no existe: ni rama remota, ni worktree, ni tmux en la Max ni en la Mini. PRs abiertos que tocan Estadísticas: el de archivar cuentas (TrendsTabView) y el de deshacer en lote (DetailContainerView, RecordsTabView); el cruce se resuelve al rebasar.

Decisiones (auto-contestadas; la decisión de producto ya la tomó Jürgen el 9-nov):
1. **«Hasta hoy» = la misma regla que Resumen**: `DateAlignmentHelper.alignedPreviousInterval(asOf: hoy)`. En un período en curso el anterior se corta en el día equivalente a hoy; en uno cerrado se compara entero (ya no se recorta al último día con datos). El Panel no cambia: el parámetro nuevo es opcional y solo lo pasan las pestañas de Estadísticas.
2. **El selector de Tendencias es el mismo `ComparisonModeSelector`**, bajo el título «Tendencias», con la misma regla de visibilidad que Distribución (variaciones encendidas y período comparable). Sin `dataEnd`: la frase dice «hasta hoy» como en Resumen. Distribución deja de pasar `dataEnd`.
3. **VoiceOver (V1)**: la etiqueta dice qué es la gráfica y el valor la conclusión con cifras (de dónde a dónde, el punto alto o bajo, las partes). Una pieza pura por tipo (`ChartSpokenSummary`), con tests; los importes pasan por `AmountPrivacy.spoken` (montos ocultos).
4. **V2**: cada tipo publica su `AXChartDescriptor` (ejes, series y puntos) con `accessibilityChartDescriptor`. Seis tipos: tendencia, comparación, tarta de categorías, entradas y salidas, día de la semana y necesidades.
5. Las piezas viven en el Panel y en Estadísticas: el arreglo vale en los dos (son las mismas gráficas).
6. Textos nuevos en los 16 idiomas con `qa/scripts/add-l10n-key.sh`.

## Resultado (Frank, 12-nov)

- Punto 1 (decisión 29, A): Tendencias lleva `ComparisonModeSelector` bajo su título y las tres pestañas comparan hasta hoy con la regla de Resumen (`DateAlignmentHelper.previousItemsUntilToday`, `untilToday:` en la curva y su cifra). El Panel no cambia.
- Punto 2 (decisión 26, V1 + V2): las ocho gráficas de Estadísticas (línea, comparación, tres tartas, entradas y salidas, día de la semana, necesidades) dicen su conclusión con cifras (`ChartSpokenSummary`) y publican la descripción de gráficas de iOS (`ChartAccessibilityDescriptor`). 20 textos nuevos en los 16 idiomas.
- Tests: `Estadisticas23ComparacionVoiceOverUITests` rojo sobre la base y verde con el arreglo; `Estadisticas23ComparacionHastaHoyTests` y `Estadisticas23GraficasVoiceOverTests`.
- Sin ticket propio: la card del tablero es el registro.

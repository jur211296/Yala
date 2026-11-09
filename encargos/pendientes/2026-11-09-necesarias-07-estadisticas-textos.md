Yala
# Mejoras necesarias 2.3 · Estadísticas: textos que dicen lo que no es
card: tablero-mejoras-necesarias-2-3-estadisticas-text-9qip
toca: Yala/App/Views/Statistics/,Yala/App/Logic/,Yala/Resources/
esfuerzo: high

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Lote 07 de 11 de la consolidación final de las revisiones por vistas 2.3 (`docs/ux/revision-vistas-2.3/consolidacion-necesarias-2026-11/ficha.md`). Cada punto es un defecto objetivo con evidencia: un bug, un fallo de accesibilidad o un texto que dice algo falso. No se elige ninguna alternativa de rediseño de las revisiones.
Fichas de origen: docs/ux/revision-vistas-2.3/35-estadisticas/ficha.md (problemas en la tabla; secundarios en `02-revision.html`). PRs de las revisiones: https://github.com/jur211296/Yala/pull/853.

## Encargo y criterio de terminado
Implementar SOLO estos 5 puntos:
1. «Probaste Mascotas y animales este Este mes»: el nombre del período entra en «este %@» (Localizable es línea 4170; stats.distribution.insight.newCategory).
2. Los vacíos dicen insights en inglés y «Sin conexion… estaran» sin tildes; Distribución pone Aún no tienes categorías aunque las haya y solo falten datos del período (CategoriesTabView.swift:973-978; insights.emptyBody insights.offlineCached insights.offlineNoCache).
3. La guía de Tendencias dice que si la línea sube gastas más y la métrica por defecto es el saldo; la de Registros dice Todos tus gastos y la lista trae ingresos (StatsQuickActions.swift:48-57).
4. El Sankey corta sus etiquetas en el borde (Gastos S/ 3,507 () y el botón de montos es un $ aunque la moneda sea soles (SankeyLabelModeToggle.swift:21-22).
5. La cabecera de Distribución dice 8 categorías y la tarta le dice a VoiceOver 7; «11696 registros» sale sin separador de miles.

Reglas del lote:
- Antes de cada punto: confirma en código que sigue vivo en origin/2.3 y corre `git log origin/2.3..origin/2.2 -- <vista>`. Si 2.2 ya lo arregló, no lo portes a mano: documéntalo en el PR y queda para la decisión de integrar 2.2 en 2.3 (card tablero-2-3-no-tiene-los-arreglos-de-2-2-de-las-3a6c).
- Si un punto exige una decisión de producto, sepáralo y déjalo pendiente con su pregunta; no elijas alternativa.
- Un test de regresión por punto (unit o XCUITest según `qa/coverage-index.json`), rojo sin el arreglo y verde con él. Capturas antes y después de lo que se vea.
- Textos nuevos según docs/planning/BRAND-VOICE.md y en los 16 idiomas; corre la batería de paridad de l10n.
- Punto 5: el recuento tiene que ser el mismo para la vista y para VoiceOver; elige el que dice la verdad de lo que se ve y documenta por qué.
- No cambies qué cifra enseña cada pantalla ni sus nombres (Balance, Saldo): es decisión pendiente junto con el Panel.
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día. Card a in qa con su guion; el device-QA no bloquea el merge.
- gate de proyecto.
FIN

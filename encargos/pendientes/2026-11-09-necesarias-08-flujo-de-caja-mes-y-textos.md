Yala
# Mejoras necesarias 2.3 · Flujo de caja: mes equivocado, «vs» sin traducir, vacío y contraste
card: tablero-mejoras-necesarias-2-3-flujo-de-caja-mes-tyuj
toca: Yala/App/Views/Reports/,Yala/Resources/
esfuerzo: high

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Lote 08 de 11 de la consolidación final de las revisiones por vistas 2.3 (`docs/ux/revision-vistas-2.3/consolidacion-necesarias-2026-11/ficha.md`). Cada punto es un defecto objetivo con evidencia: un bug, un fallo de accesibilidad o un texto que dice algo falso. No se elige ninguna alternativa de rediseño de las revisiones.
Fichas de origen: docs/ux/revision-vistas-2.3/36-reportes-flujo/ficha.md (problemas en la tabla; secundarios en `02-revision.html`). PRs de las revisiones: https://github.com/jur211296/Yala/pull/859.

## Encargo y criterio de terminado
Implementar SOLO estos 4 puntos:
1. La hoja Gastos no considerados enseña siempre el mes en curso aunque se abra desde otro mes (CashFlowOthersSheet.swift:22-29).
2. «vs» va escrito a mano en el detalle de una línea y sale «vs» en los 16 idiomas (CashFlowCellDetailSheet.swift:452).
3. El vacío de Flujo de caja dice «No hay registros en este periodo» aunque el flujo de caja no tiene período (report.noDataDescription).
4. Te quedó y Te faltó y las variaciones pintan el importe en índigo o rosa como texto, tonos que no llegan a AA sobre tarjeta según la regla de la casa (NetFlowSummaryView).

Reglas del lote:
- Antes de cada punto: confirma en código que sigue vivo en origin/2.3 y corre `git log origin/2.3..origin/2.2 -- <vista>`. Si 2.2 ya lo arregló, no lo portes a mano: documéntalo en el PR y queda para la decisión de integrar 2.2 en 2.3 (card tablero-2-3-no-tiene-los-arreglos-de-2-2-de-las-3a6c).
- Si un punto exige una decisión de producto, sepáralo y déjalo pendiente con su pregunta; no elijas alternativa.
- Un test de regresión por punto (unit o XCUITest según `qa/coverage-index.json`), rojo sin el arreglo y verde con él. Capturas antes y después de lo que se vea.
- Punto 4: usa los tokens de texto que ya pasan AA; no cambies el diseño de la tarjeta.
- Textos nuevos según docs/planning/BRAND-VOICE.md y en los 16 idiomas.
- El cálculo del ritmo sin plan va en el lote 02, no aquí; el candado Pro del flujo de caja avanzado es una pregunta abierta para Jürgen: no lo toques.
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día. Card a in qa con su guion; el device-QA no bloquea el merge.
- gate de proyecto.
FIN

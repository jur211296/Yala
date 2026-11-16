Yala
# Mejoras necesarias 2.3 · Flujo de caja: mes equivocado, «vs» sin traducir, vacío y contraste
card: tablero-mejoras-necesarias-2-3-flujo-de-caja-mes-tyuj
toca: Yala/App/Views/Reports/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3-b

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
## Añadido por Frank (Jürgen, 10-nov 6:03 Lima)
- Este lote espera en la cola a que cierre el merge de 2.2 en 2.3. Antes de nada, comprueba que `git rev-list --count origin/2.3..origin/2.2` dé 0 o casi 0. Si 2.3 no tiene lo de 2.2, para de inmediato con un `BLOQUEANTE:` corto.
- Haz tú el QA en el simulador o en el iPhone 14 por DeviceMCP y mueve la card a done con evidencia. Solo queda en qa lo que de verdad necesite la mano de Jürgen, y lo dices en el cierre.

FIN

## Sobre el catálogo de textos (`Yala/Resources`)

Jürgen (10-nov 12:54 Lima) sacó `Yala/Resources` del `toca:` de los lotes 2.3 para que corran dos sesiones a la vez. Puedes editar el catálogo de textos igual, pero otra sesión puede estar tocándolo en paralelo: antes de abrir el PR y de cerrar, ponte al día con `origin/2.3` (o la base del encargo) y resuelve cualquier cruce en `Yala/Resources` conservando los textos de las dos ramas. Anótalo en el cierre.

## Relanzamiento (Frank, Jürgen 10-nov 20:50 Lima)
El primer intento paró con `BLOQUEANTE:` porque 2.3 no tenía 16 commits de 2.2 (PR https://github.com/jur211296/Yala/pull/895). Este intento espera al merge corto `merge-corto-2-2-en-2-3-b`. Antes de nada, revisa el PR 895: si dejó trabajo útil, reutilízalo; si queda obsoleto, ciérralo con una nota que apunte al PR nuevo. La comprobación de que el conteo dé 0 sigue vigente.

## Paso 0 — decisiones (resueltas en autónomo, modo semi)

Medido antes de decidir: `git rev-list --count origin/2.3..origin/2.2` = 0; `git log origin/2.3..origin/2.2 -- Yala/App/Views/Reports` vacío; los cuatro puntos siguen vivos en `origin/2.3`. El PR 895 que cita el relanzamiento es el lote 07 (Estadísticas), ya mergeado: no hubo primer intento de este lote que reutilizar. La sesión «registrar decisiones 2026-11-05» que avisa `lanzar-sesion` no tiene worktree ni tmux: el candado está caducado.

1. **Hoja «no considerados»**: lee el mes elegido en la tira (`selectedMonthKey`). Si el mes elegido no existe en la proyección, cae al mes en curso como antes. Un mes elegido sin «no considerados» enseña la hoja vacía, nunca la del mes en curso. Sin texto nuevo.
2. **«vs»**: una frase entera por caso, traducida, en vez de pegar verbo + «vs» + «estimado»: «Gastaste %1$@; el estimado era %2$@.» / «Recibiste %1$@; el estimado era %2$@.» en los 16 idiomas. Las claves viejas `cellDetailSpent/Earned` se quedan (no se borra copy sin medir otros usos).
3. **Vacío de Flujo de caja**: mensaje propio sin período: «Aquí verás tu flujo de caja cuando tengas tus primeros registros.» La Comparativa conserva el suyo (ahí sí hay período).
4. **Contraste**: «Te quedó» y la variación positiva en `Color.incomeAmount`; «Te faltó» y la variación negativa en `Color.groupOweAmount` (el rosa de marca oscurecido). Son los dos tokens de texto que la casa ya mide AA en claro y oscuro (`ThemeTokenContrastTests`). No existe un índigo de texto AA en claro, así que «lo que quedó» toma el turquesa de dinero que entra, que es la convención del Panel. El chip de variación es compartido (33 usos): se le añade un modo de texto AA que solo usa este resumen; el resto de la app no cambia (va a «Encontrado»).
5. **Tests**: XCUITest para 1, 2 y 3 (áreas deterministas `cash-flow-plan`/`reports-comparative`) con capturas; unit de source-scan + catálogo para 2, 3 y 4, y unit de la elección del mes para 1.
6. Fuera: el ritmo sin plan (lote 02), el candado Pro, los otros «vs» de Estadísticas/Panel y los índigo/rosa como texto del detalle de una línea y de la tabla de la Comparativa: se anotan en «Encontrado».
7. **Ampliación (Jürgen, por la sesión, 12-nov):** la nota de la card asigna a este lote las decisiones 2 y 35 del 9-nov
   (`docs/ux/revision-2-3-artefacto/fuente/decisiones-discusion.md`). El encargo se escribió antes de esa discusión, así
   que manda la decisión: el candado Pro del flujo de caja avanzado se retira (decisión 2) y la frase de Gráficas dice el
   período del promedio (decisión 35). La frase usa «últimos N meses» como el KPI de ahorro, que ya lo dice así en los 16
   idiomas; con un solo mes, «Este mes».

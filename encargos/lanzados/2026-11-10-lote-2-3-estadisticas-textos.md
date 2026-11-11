Yala
# Mejoras necesarias 2.3 · Estadísticas: textos que dicen lo que no es
card: tablero-mejoras-necesarias-2-3-estadisticas-text-9qip
toca: Yala/App/Views/Statistics/, Yala/App/Logic/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

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
## Añadido por Frank (Jürgen, 10-nov 6:03 Lima)
- Este lote espera en la cola a que cierre el merge de 2.2 en 2.3. Antes de nada, comprueba que `git rev-list --count origin/2.3..origin/2.2` dé 0 o casi 0. Si 2.3 no tiene lo de 2.2, para de inmediato con un `BLOQUEANTE:` corto.
- Haz tú el QA en el simulador o en el iPhone 14 por DeviceMCP y mueve la card a done con evidencia. Solo queda en qa lo que de verdad necesite la mano de Jürgen, y lo dices en el cierre.

FIN

## Sobre el catálogo de textos (`Yala/Resources`)

Jürgen (10-nov 12:54 Lima) sacó `Yala/Resources` del `toca:` de los lotes 2.3 para que corran dos sesiones a la vez. Puedes editar el catálogo de textos igual, pero otra sesión puede estar tocándolo en paralelo: antes de abrir el PR y de cerrar, ponte al día con `origin/2.3` (o la base del encargo) y resuelve cualquier cruce en `Yala/Resources` conservando los textos de las dos ramas. Anótalo en el cierre.

## Paso 0

Medido el 2026-11-10 en `origin/2.3` (`ecb9c2ff8`).

- **Base.** `origin/2.3..origin/2.2` = 16 commits: el arreglo de borradores de Grupos (PR #863), el QA físico y la
  subida de la build 9. Ninguno toca Estadísticas ni `Yala/App/Logic` de este lote. Se da por «casi 0» y se sigue. El
  worktree nació en 2.2; la rama se rehízo desde `origin/2.3` antes de tocar nada.
- **Alcance: los cinco puntos y nada más.** La nota de la card adjunta la decisión 27 (F2 + F1 + F4: «llevas»,
  «1 jueves», «Nueva», día de la semana a 4 semanas, gráfica de saldo). La propia decisión dice que de ella solo
  «este Este mes» va en este lote, así que el resto se deja anotado en la card para su propio encargo.
- **(1) El nombre del período no entra en una frase.** Los nombres («Este mes», «Mes pasado», «Últimos 30 días»)
  son rótulos, no sustantivos. El mismo fallo sale en tres frases: «Probaste X este Este mes», «Tu período Este mes
  está empezando…» (Distribución) y «Este es tu primer Este mes con Yala» (Tendencias). Las tres se reescriben sin el
  período: la tarjeta ya está dentro del período elegido. Claves nuevas, en los 16 idiomas. «por día en Este mes» del
  Resumen se deja: su frase no se rompe igual y cambiarla toca qué compara la variación. Va a «Encontrado».
- **(2) Vacíos.** Las tildes de «Sin conexión… estarán» ya llegaron a 2.3 con el merge de 2.2 (lote de idiomas
  12.4): se documenta, no se toca. `offlineCached`/`offlineNoCache` no se pintan en ningún sitio (medido). «insights»
  pasa a «observaciones», el nombre de la sección, en es, en, fr, it y pt (ja, nl, pl y zh ya usan su palabra). El
  vacío de Distribución deja de decir «Aún no tienes categorías/subcategorías» y dice que no hay gastos en el período.
- **(3) Guías.** Tendencias: la métrica por defecto es Saldo, así que la guía explica la gráfica sin dar por hecho
  que es gasto. Registros: «Todos tus registros», con ingresos y gastos. No se cambian los nombres Balance ni Saldo.
- **(4) Sankey.** El botón de montos pinta el símbolo de la divisa en la que se ve el Sankey («S/», «€», «$»), no
  un «$» fijo. El corte: el Sankey se desplaza a lo ancho y la etiqueta de la columna que queda en el borde se partía
  en seco («Gastos S/ 3,507 (»). La revisión no propuso alternativas; se aplica la regla que Jürgen ya decidió para
  los carruseles (2026-10-25): el borde por el que queda contenido se funde, no se corta.
- **(5) Recuentos.** La cabecera contaba las categorías con importe cero y dejaba fuera «Sin categoría»; la tarta
  (VoiceOver) contaba sus trozos, «Sin categoría» y «Otros» incluidos. Un solo recuento para las dos: categorías
  reales con importe en el período. Es lo que se ve como categoría en la tarta y en la lista; «Sin categoría» no es
  una categoría y «Otros» agrupa varias. Igual para subcategorías. «11696 registros» se escribe con el separador
  de miles del formato de los importes.
- **Tests.** Unit (Swift Testing) por punto, rojos sin el arreglo. Capturas antes/después en el simulador.

Yala
# Decidido 9-nov 2.3 · Estadísticas: tocar una categoría abre su detalle
card: tablero-2-3-estadisticas-tocar-una-categoria-abr-02my
toca: Yala/App/Views/Statistics/, Yala/App/Views/Records/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Discusión del artefacto 2.3, decisión 25 (B1). Card reutilizada. Ficha: docs/ux/revision-vistas-2.3/35-estadisticas/ficha.md. Reabre a propósito lo decidido el 25-26 oct para Distribución.

## Encargo y criterio de terminado
Implementar SOLO este punto:
1. Tocar una categoría abre su detalle (gastado y comparación, subcategorías, últimos registros, «Ver en Registros»); «atrás» vuelve y no se toca ningún filtro. Filtrar sigue en Filtros.

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

## Paso 0 (Frank, 11-nov, auto-contestado)

- Sigue vivo en `origin/2.3`: `CategoriesTabView.askAboutCategory` escribe «Solo X» desde la lista, la tarta y el Sankey. `git log origin/2.3..origin/2.2 -- Yala/App/Views/Statistics/` vacío (2.3 ya tiene todo lo de 2.2).
- Qué toques abren el detalle: los de una **categoría** en Distribución (fila de la lista, trozo de la tarta y nodo del Sankey). Subcategorías, etiquetas y necesidades siguen preguntando/filtrando: la decisión 25 habla de categorías. El Panel no cambia (la decisión es de Estadísticas).
- «Sin categoría» no abre nada (como hoy: no hay categoría que abrir).
- El detalle respeta el período, la comparación y los filtros que ya hay (las cifras son las mismas que la fila tocada) y no escribe ninguno.
- «Ver en Registros» es el único gesto del detalle que filtra: pone «Solo <categoría>» y lleva al chip Registros de Estadísticas (el contra de B1 lo dice: filtrar queda en Filtros o en «Ver en Registros»).
- Tocar un registro del detalle abre su hoja de detalle, la misma del chip Registros.
- Las filas de categoría llevan «›» (la maqueta de B1).
- Textos: se reusan «Gastado», «Ingresos», «Total», «Subcategorías», «Últimos registros» y «del gasto»; nuevo solo «Ver en Registros» de esta pantalla, en los 16 idiomas.
- Regresión: XCUITest (la categoría tocada abre el detalle, sin cápsulas de filtro; atrás vuelve sin filtros) + unit del cálculo. `SegmentFilterChoiceUITests` pasa a probar la pregunta con subcategorías.

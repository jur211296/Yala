Yala
# Decidido 9-nov 2.3 · Registros: VoiceOver, carga, el selector vacío y la tarjeta de Siri
card: tablero-2-3-registros-voiceover-carga-el-selecto-94i8
toca: Yala/App/Views/Records/, Yala/App/Intents/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Discusión del artefacto 2.3, decisiones 60, 61, 78, 77 y 76. Card reutilizada. Ficha: docs/ux/revision-vistas-2.3/31-registros/ficha.md.

## Encargo y criterio de terminado
Implementar SOLO estos 5 puntos:
1. VoiceOver lee cada fila con su fecha.
2. La pista de las etiquetas de la fila deja de decir «Tag» en inglés: va traducida en los 16 idiomas.
3. Un fallo de carga o de red se ve distinto de la lista vacía (estado de carga y de error).
4. Con la lista vacía, el selector Lista/Calendario se queda.
5. En la tarjeta de Siri, el importe escala, la fila sin cuenta se oculta y la fecha lleva el mes en letras.

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

## Paso 0 (Frank, 12-nov, nocturno)

- Base: la rama nació de `2.2` (290 commits detrás de `2.3`); rehecha sobre `origin/2.3`. `origin/2.3..origin/2.2` = 0: el merge corto ya entró.
- Los 5 puntos siguen vivos en `2.3` (medido en código). Nada que portar de 2.2.
- 1 · Fecha en VoiceOver: la etiqueta de la fila termina con la fecha larga («12 de noviembre de 2026»), en el idioma de la app. En el modo duplicados la fecha ya va ahí: no se repite el caption.
- 2 · Pista de etiquetas: clave nueva `records.row.tagHint` («Etiqueta») en los 16 idiomas.
- 3 · Carga y error: lista sin filtrar aún → indicador «Cargando tus registros…» que solo asoma pasados 0,4 s (para no destellar, card C7). Fallo al leer los movimientos con la lista vacía → estado de error con «Reintentar»; con filas viejas en memoria se siguen enseñando. Vale para Registros y Estadísticas › Registros (misma lista).
- 4 · Selector con lista vacía: el selector se queda encima del vacío; en modo Calendario el calendario también se queda (si no, el selector diría «Calendario» sin calendario).
- 5 · Tarjeta de Siri: importe con fuente escalable (`largeTitle` en negrita, encoge si no cabe), cuenta opcional (el intent deja de pasar «—» y la fila no se pinta), fecha con mes en letras.
- Supuesto: no se toca `RecordDateSectionView` (lo tocan dos PRs abiertos).

Yala
# Decidido 9-nov 2.3 · Nuevo registro: texto grande y código muerto
card: tablero-2-3-texto-grande-y-codigo-muerto-en-nuev-sqvu
toca: Yala/App/Views/Transactions/, Yala/App/Views/Favorites/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Discusión del artefacto 2.3, decisiones 63, 64 y 82. Card reutilizada. Ficha: docs/ux/revision-vistas-2.3/32-nuevo-registro/ficha.md.

## Encargo y criterio de terminado
Implementar SOLO estos 3 puntos:
1. Con texto grande, los importes dejan de partirse («S/ 3,000. / 00»), con el mismo arreglo que «Esto leí» en 2.2 (también en Favoritos).
2. Con texto grande, «Transferencia» deja de partirse en tres líneas: el selector de tipo se apila o abrevia.
3. Se borra la vista de importe sin usar que queda en el código, con su selector de divisa que no se ve.

Reglas del lote:
- La decisión ya está tomada el 9-nov (`docs/ux/revision-2-3-artefacto/fuente/decisiones-discusion.md`). Implementa exactamente la opción elegida; no reabras la decisión ni ofrezcas alternativas.
- Antes de cada punto: confirma en código que sigue vivo en origin/2.3 y corre `git log origin/2.3..origin/2.2 -- <vista>`. Si 2.2 ya lo arregló, no lo portes a mano: documéntalo en el PR y queda para la decisión de integrar 2.2 en 2.3 (card tablero-2-3-no-tiene-los-arreglos-de-2-2-de-las-3a6c).
- Un test de regresión por punto (unit o XCUITest según `qa/coverage-index.json`), rojo sin el arreglo y verde con él. Capturas antes y después de lo que se vea.
- Textos nuevos según docs/planning/BRAND-VOICE.md y en los 16 idiomas, cuando toque copy.
- Capturas a tamaño normal y con texto grande (AX3) en iPhone y, si aplica, iPad.
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día.
- gate de proyecto.
## Añadido por Frank (Jürgen, 10-nov 6:03 Lima)
- Este lote espera en la cola a que cierre el merge de 2.2 en 2.3. Antes de nada, comprueba que `git rev-list --count origin/2.3..origin/2.2` dé 0 o casi 0. Si 2.3 no tiene lo de 2.2, para de inmediato con un `BLOQUEANTE:` corto.
- Haz tú el QA en el simulador o en el iPhone 14 por DeviceMCP y mueve la card a done con evidencia. Solo queda en qa lo que de verdad necesite la mano de Jürgen, y lo dices en el cierre.

FIN

## Sobre el catálogo de textos (`Yala/Resources`)

Jürgen (10-nov 12:54 Lima) sacó `Yala/Resources` del `toca:` de los lotes 2.3 para que corran dos sesiones a la vez. Puedes editar el catálogo de textos igual, pero otra sesión puede estar tocándolo en paralelo: antes de abrir el PR y de cerrar, ponte al día con `origin/2.3` (o la base del encargo) y resuelve cualquier cruce en `Yala/Resources` conservando los textos de las dos ramas. Anótalo en el cierre.

## Paso 0 (Frank, 2026-11-12, nocturno)

- Base: `origin/2.3` (la rama nació de 2.2 y avanzó en rápido a 2.3; `origin/2.3..origin/2.2` = 0, el merge de 2.2 ya entró).
- Punto 1 vivo en 2.3: `FavoriteRowView` pone el importe al lado del nombre y con texto grande se parte. «Esto leí» ya está
  arreglado (PR 816 de 2.2, `VoiceDraftReviewCard`) y ese arreglo ya está en 2.3: no hay nada que portar. Se aplica el
  mismo molde a la fila de Favoritos: con texto de accesibilidad el importe (y su necesidad) baja a su línea; a tamaño
  normal, la fila de siempre. 2.2 no tocó `FavoriteRowView`.
- Punto 2 vivo: `TransactionTypeSelectorView` reparte el ancho en tres y «Transferencia» se parte. Opción tomada de las dos
  que da la decisión 64: **apilar**, no abreviar (abreviar exige copy nuevo en 16 idiomas y un «Transf.» que se lee peor).
  Se apila cuando alguna etiqueta no cabe entera en su tercio, medido por un `Layout` propio con los mismos hijos (la
  cápsula se sigue deslizando); a tamaño normal, la fila de siempre. 2.2 no tocó la vista.
- Punto 3 vivo: `TransactionAmountInputView` no tiene ningún uso en `Yala/`; se borra el fichero. Sin referencias en el
  proyecto (carpetas sincronizadas).
- Tests: un XCUITest a AX3 para 1 y 2 (rojo en la base, verde con el arreglo) y un source-scan para 3.
- Sin copy nuevo: no hay textos que traducir.

Yala
# Decidido 9-nov 2.3 · Nuevo registro: favoritos con el importe listo, tipos bien y sin borrar a ciegas
card: tablero-2-3-favoritos-al-registrar-importe-tipos-bjoe
toca: Yala/App/Views/Favorites/, Yala/App/Views/Transactions/, Yala/App/Views/Settings/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Discusión del artefacto 2.3, decisiones 22, 69, 70, 71 y 72. Card reutilizada. Ficha: docs/ux/revision-vistas-2.3/32-nuevo-registro/ficha.md. Se apoya en la barra de G1 del lote de la barra sobre el teclado; si ese PR aún no entró, rebasa y cita.

## Encargo y criterio de terminado
Implementar SOLO estos 5 puntos:
1. Repetir un favorito abre con el importe seleccionado y el teclado abierto (F1 + F4); los textos dejan de prometer «un toque». F2 (favoritos en el Panel) no por ahora.
2. En «Ingreso», la fila de favoritos filtra por el tipo elegido (deja de mostrar gastos y transferencias).
3. El editor de favoritos nombra los tres tipos, no solo «Gastos · Ingresos».
4. Deslizar un favorito en Ajustes pregunta antes de borrar, como el editor (regla de la decisión 39).
5. Un favorito de transferencia viejo muestra las dos cuentas o su nombre, no «Cuenta Principal → …».

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

## Paso 0 (Frank, 12-nov 00:40 Lima, nocturno)

Medido: `git rev-list --count origin/2.3..origin/2.2` = 0 (2.3 tiene todo lo de 2.2). `git log origin/2.3..origin/2.2`
sobre Favorites/, NewTransactionView y FavoriteChipsRow: vacío. Los cinco puntos siguen vivos en origin/2.3 (c48bcbfb4).
La barra de G1 ya está en 2.3 (PR de la barra sobre el teclado mergeado).

Decisiones tomadas sin preguntar (defaults sensatos, ninguna vital):

1. **F1 + F4.** Tocar un favorito (fila o «Ver todos») rellena, enfoca el importe y lo deja seleccionado: escribir lo
   sustituye. También en un favorito de transferencia (importe de origen). Un favorito sin importe abre el teclado en el
   importe vacío. Selección con `TextField(text:selection:)` (iOS 18+). Textos que prometían «un toque» para registrar:
   `favorites.createTemplate` y `favorites.saveDescription` con el texto de la maqueta F4, más `l2d.favorites.transferHelp`,
   `tips.favorites.detail` y los dos del tutorial. `whatsNew.v22.*` no se toca: son las novedades publicadas de 2.2.
2. **Filtro por tipo en los tres tipos**, no solo en Ingreso: la decisión dice «la fila filtra por el tipo elegido». Con
   «Solo gastos» sigue la regla de siempre. «Ver todos» no filtra (no es la fila).
3. **Editor: «Gasto | Ingreso | Transferencia»** con los nombres del formulario (`TransactionType.displayName`).
   Elegir «Transferencia» enseña origen y destino (el modo que ya existía para editar). Un favorito de transferencia
   abierto sigue sin selector (card 93ta). En «Solo gastos», solo «Gasto», como hoy.
4. **Deslizar (y el «−» de Editar) pregunta** con la misma alerta del editor; vibra al confirmar. De paso, el borrado
   resuelve el favorito sobre la lista que se pinta: con «Solo gastos» los índices de la lista filtrada borraban otro.
5. **Transferencia sin destino:** solo el nombre de la cuenta que tiene («Cuenta Principal»); con las dos,
   «origen → destino»; sin ninguna, «Transferencia».

Tests: XCUITest por punto visible (1, 3, 4) + unit de la lógica (2, 5) y de los textos (1).

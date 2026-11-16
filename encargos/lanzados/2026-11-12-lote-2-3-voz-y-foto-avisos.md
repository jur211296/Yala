Yala
# Decidido 9-nov 2.3 · Nuevo registro: voz y foto, avisos, la hoja y accesibilidad
card: tablero-2-3-voz-y-foto-al-registrar-avisos-la-ho-69q6
toca: Yala/App/Views/Voice/, Yala/App/Views/Image/, Yala/App/Views/Transactions/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Discusión del artefacto 2.3, decisiones 80, 62, 81, 65 y 83. Card reutilizada. Ficha: docs/ux/revision-vistas-2.3/32-nuevo-registro/ficha.md.

## Encargo y criterio de terminado
Implementar SOLO estos 5 puntos:
1. La hoja de la foto con varios registros abre a la altura que muestre más de una fila.
2. Voz y foto anuncian a VoiceOver cada cambio de fase y los fallos.
3. «Volver a grabar» y «Otra foto» preguntan antes de descartar lo entendido (regla de la decisión 39).
4. Las filas de «¡Listo!» muestran hasta dos líneas y luego cortan, no una sola línea.
5. «Registrar otro» tiene identificador de accesibilidad para los tests.

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

## Paso 0

Medido antes de tocar nada (12-nov, nocturno): `origin/2.3` ya trae todo `origin/2.2` (0 commits pendientes) y
`git log origin/2.3..origin/2.2` no tiene nada en `Voice/`, `Image/` ni `Transactions/`. Los cinco puntos siguen vivos
en 2.3. La «sesión viva» que avisa `lanzar-sesion` sobre `Voice/` (registrar-decisiones del 5-nov) es una rama local
sin tmux ni PR: no hay choque real.

1. **Hoja de la foto con varios (decisión 80).** Al llegar a «Leí N registros» con más de uno, la hoja deja de ofrecer
   media altura y pasa a grande sola: la lista se ve entera y se desplaza dentro. Cambiar solo el detent elegido no
   mueve la hoja (regla medida en `swiftui-ds.md`); quitar `.medium` del juego sí la obliga. Con una sola fila o en
   cualquier otra fase, igual que hoy. Voz con varios queda fuera: la decisión nombra la foto.
2. **Anuncios a VoiceOver (decisión 62).** Cada cambio de fase anuncia su título; los fallos, título y explicación, y
   también «no se pudo guardar» y las fotos que no se leyeron. Prioridad alta para que el foco de la hoja no lo corte.
   La foto no anuncia al abrirse (el título ya tiene el foco); la voz sí dice «Escuchando». Para XCUITest, un testigo
   solo en DEBUG con el último anuncio.
3. **Preguntar antes de descartar (decisión 81, regla de la 39).** «Volver a grabar» y «Otra foto» preguntan solo si
   hay registros de esta vez sin guardar; desde un fallo no hay nada que perder y siguen sin preguntar. Una `.alert`
   (un `confirmationDialog` colgado de un botón no pinta «Cancelar»): «Descartar» destructivo y «Seguir revisando».
4. **Filas de «¡Listo!» (decisión 65).** Fecha y descripción hasta dos líneas, alineadas a la derecha, y luego «…».
5. **«Registrar otro» (decisión 83).** Identificador `transaction_success_create_another`.

Asumido sin preguntar: los textos nuevos de la pregunta (título, mensaje y «Seguir revisando»).

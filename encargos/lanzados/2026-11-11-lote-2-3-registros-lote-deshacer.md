Yala
# Decidido 9-nov 2.3 · Registros: selección en lote con «Deshacer»
card: tablero-2-3-seleccion-en-lote-en-registros-con-d-wz9n
toca: Yala/App/Views/Records/, Yala/App/ViewModels/, Yala/Services/CloudSync/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Discusión del artefacto 2.3, decisiones 18 y 75. Card reutilizada. Ficha: docs/ux/revision-vistas-2.3/31-registros/ficha.md. Toca sync: review adversarial.

## Encargo y criterio de terminado
Implementar SOLO estos 3 puntos:
1. «Seleccionar todo» deja de marcar miles sin poder deshacer el lote. Opción E1 + E2: «Deshacer» también en lote (mismo aviso que el borrado de uno; medir el «antes» de miles) y textos que dicen cuánto es («Seleccionar los 2.334», pregunta con fechas e importe, «Seleccionar día»).
2. «2334» pasa a llevar separador de miles en la selección y al borrar (lo resuelve E2).
3. En la edición masiva, la fila «Categoría» deja de decir «Hoy: 3 subcategorías distintas»; usa «Ahora: 3 subcategorías distintas» o similar, sin «Hoy» que parece fecha.

Reglas del lote:
- La decisión ya está tomada el 9-nov (`docs/ux/revision-2-3-artefacto/fuente/decisiones-discusion.md`). Implementa exactamente la opción elegida; no reabras la decisión ni ofrezcas alternativas.
- Antes de cada punto: confirma en código que sigue vivo en origin/2.3 y corre `git log origin/2.3..origin/2.2 -- <vista>`. Si 2.2 ya lo arregló, no lo portes a mano: documéntalo en el PR y queda para la decisión de integrar 2.2 en 2.3 (card tablero-2-3-no-tiene-los-arreglos-de-2-2-de-las-3a6c).
- Un test de regresión por punto (unit o XCUITest según `qa/coverage-index.json`), rojo sin el arreglo y verde con él. Capturas antes y después de lo que se vea.
- Textos nuevos según docs/planning/BRAND-VOICE.md y en los 16 idiomas, cuando toque copy.
- Review adversarial obligatoria: el deshacer en lote mueve datos y toca sync. Mide el «antes» con miles de registros.
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día.
- gate de proyecto.
## Añadido por Frank (Jürgen, 10-nov 6:03 Lima)
- Este lote espera en la cola a que cierre el merge de 2.2 en 2.3. Antes de nada, comprueba que `git rev-list --count origin/2.3..origin/2.2` dé 0 o casi 0. Si 2.3 no tiene lo de 2.2, para de inmediato con un `BLOQUEANTE:` corto.
- Haz tú el QA en el simulador o en el iPhone 14 por DeviceMCP y mueve la card a done con evidencia. Solo queda en qa lo que de verdad necesite la mano de Jürgen, y lo dices en el cierre.

FIN

## Sobre el catálogo de textos (`Yala/Resources`)

Jürgen (10-nov 12:54 Lima) sacó `Yala/Resources` del `toca:` de los lotes 2.3 para que corran dos sesiones a la vez. Puedes editar el catálogo de textos igual, pero otra sesión puede estar tocándolo en paralelo: antes de abrir el PR y de cerrar, ponte al día con `origin/2.3` (o la base del encargo) y resuelve cualquier cruce en `Yala/Resources` conservando los textos de las dos ramas. Anótalo en el cierre.

## Paso 0 (Frank, 2026-11-11)

Medido antes de decidir:
- `origin/2.3..origin/2.2` = 16 commits: el arreglo de borradores de Grupos (#863) y commits de release/docs del 10-nov.
  Ninguno toca la selección ni el lote de Registros. Lo tomo como «casi 0»; el resto lo cubre la card de integrar 2.2 en 2.3.
- La rama nació de `origin/2.2`; la recoloqué sobre `origin/2.3` (sin commits propios que perder).
- El aviso de «otra sesión» sobre Records/ViewModels/CloudSync era de un PR ya mergeado el 5-nov, sin worktree ni tmux.
- Los 3 puntos siguen vivos en 2.3 y 2.2 no los arregló.

Decisiones (asumidas, dentro de la opción E1 + E2 ya decidida):
1. Borrado en lote con «Deshacer»: por el mismo borrado diferido que el de un registro (`RecordPendingDeletion`), con un
   lote que se borra con UN guardado. Nada toca la base hasta que vence el aviso: deshacer no sube nada a iCloud.
   El «antes» de un borrado es solo el conjunto de ids.
2. Edición en lote con «Deshacer»: foto del «antes» de cada registro tocado (y su pareja de transferencia) y foto del
   «después». Deshacer restaura solo los registros que siguen igual que tras el lote (no pisa un cambio hecho por otro
   camino) y solo los campos que difieren. Es otro cambio que sube a iCloud, igual que el lote. Sin ⌘Z (⌘Z es de borrados).
3. Textos: «Seleccionar los N» con separador; «N seleccionados» y «¿Eliminar N registros?» con separador del idioma de la
   app (`String(format:locale:)`); la pregunta dice fechas (del primero al último) e importe total si todo es de una
   moneda (suma sin signo; con varias monedas, solo fechas), y «Tendrás unos segundos para deshacerlo».
   El botón de la alerta sigue diciendo «Eliminar» literal: un label dinámico en un `.alert` rompió la app (regla swiftui-ds).
4. «Seleccionar día» / «Deseleccionar día» en la cabecera de cada día en modo selección; la pista pasa a
   «Toca los registros o «Seleccionar día»».
5. Edición masiva: «Hoy: …» pasa a «Ahora: …» en las 4 variantes de español (los demás idiomas ya decían «Currently/Aktuell»).
6. Aviso tras editar: «N registros ahora son <subcategoría>» si solo cambió la categoría; si no, «Cambiaste N registros».

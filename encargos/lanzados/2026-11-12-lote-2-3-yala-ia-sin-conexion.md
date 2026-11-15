Yala
# Decidido 9-nov 2.3 · Yala IA: qué decir sin conexión o con el servidor caído
card: tablero-2-3-yala-ia-que-decir-sin-conexion-o-con-rlkk
toca: Yala/App/Views/Chat/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Discusión del artefacto 2.3, decisión 42 (F1 + F3). Card reutilizada. Ficha: docs/ux/revision-vistas-2.3/38-bandeja-ia/ficha.md. Los cuatro nombres de la Bandeja y el texto de los correos sin leer al pasar a Pro ya van en el lote necesario 03, ya encolado.

## Encargo y criterio de terminado
Implementar SOLO este punto:
1. Yala IA deja de decir «en unos minutos» y apagar la caja cuando no hay servidor. Opción F1 + F3: sin conexión, el chat lo dice al abrir («Necesitas conexión…») y ofrece apuntar a mano; con conexión y servidor caído, el mensaje de hoy. Sin Pro y sin conexión, el muro no queda sin salida: ofrece lo gratis (apuntar a mano; Siri en teléfonos con modelo propio), dentro de las reglas de App Store.

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

Medido el 12-nov (sesión nocturna, base `origin/2.3` en `2d94e70c8`):

- `git rev-list --count origin/2.3..origin/2.2` = **0**: 2.3 ya tiene lo de 2.2. `git log origin/2.3..origin/2.2 -- Yala/App/Views/Chat/` vacío: 2.2 no lo arregló.
- Sigue vivo: `ChatAssistantViewModel.isAIAvailable = !suggestionsFailed` y `ChatSheetView.unavailableState` dicen «no está disponible… en unos minutos» sin mirar la red; el muro de Pro sin precios pinta `ProPricesUnavailable` y el botón apagado (`UpgradePromptSheet.plans`).
- Ningún PR abierto ni ticket trata esto. #926, #922, #908 tocan `RecordsStandaloneView`/`DetailContainerView`/`UITestHooks`: aquí, una línea por fichero.

Decisiones (auto-contestadas; la de producto ya la tomó Jürgen el 9-nov, F1 + F3):

1. **Qué es «sin conexión»**: `NetworkMonitor.shared.isConnected == false` (el mismo que ya usa el envío). Con red y sin respuesta del servidor → el mensaje de hoy, sin cambios.
2. **Sin conexión manda sobre todo lo demás al abrir**: aunque las sugerencias salgan de la caché del día, el chat vacío dice «Necesitas conexión para usar Yala IA.» y la caja queda apagada (enviar fallaría igual).
3. **Al volver la conexión se reactiva solo**: el chat vuelve a pedir las sugerencias. Sin texto «Volviste a estar en línea» (estaba en la maqueta, no en la decisión).
4. **«Apuntar a mano» en el chat**: botón «Nuevo registro» que cierra el chat y abre el formulario del que lo abrió (Panel, Registros, Estadísticas), al terminar de cerrarse el chat.
5. **F3 solo en el muro de Yala IA**: sin conexión y sin precios, en vez de «No pudimos cargar los precios» y el botón apagado: «Sin conexión: el precio se verá cuando te conectes», sin botón de compra, y «Mientras tanto»: «Apuntarlo a mano» (si quien abre el muro sabe abrir el formulario) y «Anotar con Siri» con su frase (solo si el modelo del iPhone está listo, `SiriEntryRoute.onDevice`). El «Anotar con Siri» es informativo: Siri no se invoca desde la app. «Ahora no» y el pie legal se quedan. Al volver la conexión, recarga los precios.
6. **Textos nuevos (3)**, los demás se reusan: `chat.offline.body`, `uxpro.gate.offlinePrices`, `uxpro.gate.offlineMeanwhile`, en los 16 idiomas.
7. **Tests**: lógica pura con unit tests (rojo sin el arreglo) + XCUITest con seam `-uitest-network-offline` para el chat y el muro.

Ficheros: `ChatAssistantViewModel`, `ChatSheetView`, `YalaAIChatPresentation`, `UpgradePromptSheet`, `PanelSheetsModifier`, `RecordsStandaloneView`, `DetailContainerView`, `NetworkMonitor` (seam), `UITestHooks`, `L10n`, 16 `Localizable.strings`, tests, `qa/coverage-index.json`, ticket.

# ImageEntryReviewUITests: «Guardar» apagado con un registro completo según la hora

## Contexto
Card del tablero `tablero-imageentryreviewuitests-guardar-apagado-rjft` (Yala 2.1, medium). Es el rojo vivo de la tanda 2 de YalaUITests. Ticket: `tickets/backlog/image-entry-uitests-save-stays-off-for-a-complete-record.md`.
Evidencia medida (Frank, 2026-10-12): en el dispatch de CI 38202370371 (rama de #462, HEAD d4af456, ~04:53 UTC = 23:53 Lima), la tanda 2 cayó con 9 fallos en `ImageEntryReviewUITests`, 3/3 cada uno:
- `test_readsWithoutCountdown_andSavesInTheSameSheet` (L60: «Un registro completo se tiene que poder guardar»)
- `test_missingSubcategory_blocksSave_untilChosen` (L96: «Con la subcategoría elegida, el registro se puede guardar»)
- `test_twoPhotos_showOneRowEach_andSaveTogether` (L107: «Dos registros completos se tienen que poder guardar juntos»)
Las nocturnas del 9, 10 y 11-oct (08:17 UTC) los pasan. Hipótesis de la card: el seam `-uitest-image-result` formatea «hoy» con `DateFormatter` sin zona (`ImageSelectionView.swift:1274-1277`) y `TEST_RUNNER_TZ=America/Lima` solo llega al runner, no a la app; entre 00 y 05 UTC, UTC y Lima están en días distintos y la fecha se lee como futura (`isFutureDate`) ⇒ «Guardar» apagado. Falta medir quién parsea en qué zona. El PR #462 arregló la espera de asentamiento de XCUITest (el hero de Distribución); léelo por si su helper aplica.

## Qué se pide
- Medir la causa (no asumirla): reproducir en local con el reloj/zona en la franja 00-05 UTC y confirmar qué fecha ve la app.
- Arreglar en el sitio correcto. Si es solo el seam de test, arregla el seam. **Si un usuario real puede ver «Guardar» apagado con una fecha leída como futura** (p. ej. una foto leída cerca de medianoche, zona del dispositivo ≠ zona del parser), es bug de producto: arréglalo y dilo claro en el PR.
- Los tres casos pasan a cualquier hora (probado en la franja 00-05 UTC y en horario normal), sin bajar lo que verifican.

## Qué NO hay que tocar
- No desactivar ni saltar tests, no subir timeouts a ciegas, no cambiar la matriz del CI. Prompt/modelo de lectura, nube/CloudKit, marketing/.
- Si encuentras otro hallazgo, crea card: `tablero crear --proyecto Yala --titulo "..." --version 2.1 --agente frank` (sin --fecha).

## Reglas de build y Mini (obligatorias)
- `nice -n 10 xcodebuild -jobs 2 ...`. Antes de cada build, esperar a que el load average (uptime) sea < 8.
- Nunca filtrar la salida del build con `| head`. `-only-testing` como array de argumentos (uno por target/test).
- Pipeline serial: limpiar → build sin sim booteado → boot 1 simulador → tests → apagar y erase de ese simulador. Un solo simulador a la vez; nunca build con sim booteado.
- DerivedData de esta sesión y cachés de XcodeBuildMCP de worktrees que ya no existen: bórralos al cerrar sin preguntar. No toques los de otra sesión viva.
- Gate tras el CI del PR anterior (#462, ya mergeado): arranca sobre `origin/2.1`. Justo antes del gate, `git fetch` y rebase una sola vez con el sim apagado si 2.1 se movió. Build y simulador van después de ese rebase, una sola vez.
- PR contra la rama `2.1`.

## Cómo se sabe que está bien
Causa medida y descrita en el PR; los tres casos de `ImageEntryReviewUITests` pasan 3/3 en la franja 00-05 UTC y fuera de ella; PR abierto a 2.1. Al terminar, `/cerrar-total` (sim apagado y borrado, Mini limpia).

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Seam de test o producto?** → Producto. La foto y la voz fijan la fecha leída a las 12:00 del día
(`VisionDraftFactory.parseDate`, `TranscriptionParserService`), y «Guardar» y la Bandeja la comparan con el
instante actual (`effectiveDate > Date.now`). Antes del mediodía local, «hoy» cuenta como futuro.
Por qué: el seam formatea y el parser lee en la misma zona (`TimeZone.current` los dos), así que la hipótesis
UTC/Lima no explica nada; lo que separa verde de rojo es la hora local frente al mediodía (las nocturnas
arrancan ~14-15 UTC, el dispatch caído ~04-05 UTC, la app corre en la zona del host). Se confirma midiendo.

**D2 · ¿Qué es «fecha futura»?** → Un día de calendario posterior a hoy (`Calendar.current`, granularidad
`.day`), el criterio del formulario manual (`NewTransactionViewModel.preValidate`).
Alternativa descartada: quitar el mediodía de los parsers o recortar a `now` — cambia la hora guardada de
cada registro y no arregla los borradores ya guardados en la Bandeja.

**D3 · ¿Dónde vive el criterio?** → Un solo predicado puro en `Yala/App/Logic`, consumido por los cuatro
sitios que hoy comparan por instante: las dos hojas (imagen y voz) y `DraftService` (aprobar uno y aprobar
en lote). Por qué: cuatro copias del mismo `>` son como divergió.

**D4 · ¿Se toca el seam `-uitest-image-result`?** → No. Fecha «hoy» igual que el modelo real; con el
arreglo pasa a cualquier hora, y cambiarlo taparía justo el bug de producto.

**D5 · ¿Cómo se prueba a cualquier hora?** → Unit del predicado con reloj y zona inyectados (mañana, tarde,
medianoche, mañana siguiente); `DraftService` con un borrador fechado al final de hoy (determinista: futuro
por instante, hoy por día); y el XCUITest corrido de madrugada (rojo antes, verde después) y con la app en
una zona donde es por la tarde.

# Entrar a Yala desde fuera cierra la hoja abierta en otra pestaña

## Contexto
Card del tablero `tablero-entrar-a-yala-desde-fuera-cierra-la-hoja-7kcf` (Yala 2.1, medium). Al entrar a Yala desde fuera (enlace profundo, widget, notificación, atajo) para ir al Panel, la app cierra la hoja (sheet) que el usuario tenía abierta en otra pestaña; si era un formulario a medias, se perdería lo escrito (inferido, sin medir). Ticket: `tickets/backlog/entry-to-panel-closes-sheets-of-other-tabs.md`. Lee también el PR #441 (diff y cuerpo), de donde sale el hallazgo, para entender el enrutado de entrada actual y no duplicarlo.

## Qué se pide
- Reproducir con un test (unitario del router/coordinador de entradas, o XCUITest si no hay otra forma) que hoy falle: hoja abierta en pestaña A + entrada externa al Panel ⇒ la hoja de A no debe perderse (o, si hay que cerrarla, no perder lo escrito). Elige la opción más segura y coherente con el diseño actual; documenta la decisión en el PR.
- Arreglo acotado al enrutado de entradas externas.
- Capturas antes/después si cambia lo que se ve (`capturas/antes.png`, `capturas/despues.png`; mira `~/Claude/referencias-ui/README.md`).

## Qué NO hay que tocar
- Nada de nube/CloudKit, divisas, widgets (salvo como origen de la entrada), ni marketing/.
- No rediseñes la navegación por pestañas.
- Si encuentras otro hallazgo, crea card: `tablero crear --proyecto Yala --titulo "..." --version 2.1 --agente frank` (sin --fecha).

## Reglas de build y Mini (obligatorias)
- `nice -n 10 xcodebuild -jobs 2 ...`. Antes de cada build, esperar a que el load average (uptime) sea < 8.
- Nunca filtrar la salida del build con `| head`. `-only-testing` como array de argumentos (uno por target/test).
- Pipeline serial: limpiar → build sin sim booteado → boot 1 simulador → tests → apagar y erase de ese simulador. Un solo simulador a la vez; nunca build con sim booteado.
- DerivedData de esta sesión y cachés de XcodeBuildMCP de worktrees que ya no existen: bórralos al cerrar sin preguntar. No toques los de otra sesión viva.
- Gate tras el CI del PR anterior (#452, widgets): arranca ya sobre `origin/2.1`; no partas de su rama. Justo antes del gate, mira si #452 sigue en CI; si sigue, espera a que entre y rebasa una sola vez con el sim apagado; si 2.1 no se movió, sigue; si ese CI falla, no esperes: rebasa con lo que haya. Build y simulador van después de ese rebase, una sola vez.
- PR contra la rama `2.1`.

## Cómo se sabe que está bien
Con una hoja abierta en otra pestaña, entrar desde fuera al Panel ya no pierde lo que el usuario tenía (test nuevo rojo antes / verde después); PR abierto a 2.1 con antes/después en el cuerpo. Al terminar, `/cerrar-total` (sim apagado y borrado, Mini limpia).

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.
> **Revisado tras medir** (2026-10-11, iPhone 17 Pro, iOS 27.0, build de `origin/2.1` sin cambios): la primera versión
> de este Paso 0 culpaba al cambio de pestaña. No es así. Con `yaladev://panel` y un «Nuevo registro» a medias en
> Estadísticas, la pestaña cambia por debajo y **la hoja sigue abierta con lo escrito** (encima del Panel); con el
> detalle de un registro, igual. Lo que la cierra es lo que el Panel **presenta** después (la lectura de la foto
> compartida, la Bandeja de una notificación): el candado del Panel solo mira sus propias hojas y presenta con la de
> otra pestaña arriba.

**D1 · ¿Esperar o cerrar la hoja?** → Esperar. Lo que el Panel presenta (foto compartida, Bandeja, consentimiento,
Pro…) se queda en cola mientras la ventana tenga algo presentado, y sale solo al cerrarse.
Por qué: es la regla que ya rige para las hojas del propio Panel («una foto compartida no cierra una hoja abierta:
espera», `docs/entry-points.md`), y es lo único que no pierde datos sin saber qué hoja hay. Alternativa descartada:
cerrar solo las hojas sin datos por guardar — exige que cada hoja publique si está sucia, y es la opción B que sigue
pendiente de Jürgen en `shared-photo-waits-silently-behind-an-open-panel-sheet`; si la elige, valdrá para las dos.

**D2 · ¿Cómo se sabe que hay una hoja de otra pestaña?** → `ModalPresentationProbe.isAnythingPresented(in:)` de la
ventana del Panel, como ya hacen los atajos de teclado (`keyboardMayAct`).
Por qué: las hojas de Estadísticas, Planificación, Registros o Grupos no publican ningún flag. Alternativa descartada:
un flag por hoja (no escala y se olvida en la próxima hoja nueva).

**D3 · ¿Se toca `.navigate`?** → No. Medido: cambiar de pestaña no cierra la hoja. Retenerlo sería cambiar algo que no
pierde nada.

**D4 · ¿Quién vuelve a drenar al cerrarse la hoja?** → Un reintento cada 300 ms que solo corre mientras el Panel retiene
algo **únicamente** por esa presentación (con las demás dimensiones libres), y se cancela al desmontarse.
Por qué: cerrar una hoja de otra pestaña no cambia ninguna señal que el Panel observe. Alternativa descartada:
notificaciones privadas de UIKit o un flag por hoja (D2).

**D5 · `test_foreignSheetOpen_sharedImage_startsReading` (de #441)** → cambia de contrato: el detalle sigue abierto al
compartir y la lectura arranca al cerrarlo.

**D6 · Tests** → XCUITest nuevo `ExternalEntryForeignSheetUITests`: (a) «Nuevo registro» a medias en Estadísticas +
foto compartida ⇒ el formulario sigue con lo escrito y la lectura arranca al cerrarlo (rojo antes / verde después);
(b) el mismo formulario + `yaladev://panel` ⇒ sigue abierto (red de lo medido en D3, verde en los dos). Unit:
`panelCanDrain` con la nueva dimensión. Id invisible nuevo en la X de Nuevo registro (`new_transaction_close`).

**D7 · Lo que no entra** → el consumidor `.contentView` (pantallas de unirse a un grupo desde un enlace de invitación)
y el `.mainTab` (avisos de prueba expirada, downgrade, hitos) tienen el mismo patrón: presentan sin mirar hojas de otras
pestañas. No se tocan aquí — el primero mezcla avisos críticos que no deben esperar; card aparte.

**D8 · Capturas** → del caso (a): antes (la lectura encima y el formulario perdido) y después (el formulario intacto).

Asumido: sin ADR — extiende una regla ya escrita en `docs/entry-points.md`, que se actualiza.

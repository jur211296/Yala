# Al guardar el primer gasto, el aviso «¿era de prueba?» cierra el formulario antes de la pantalla de éxito

## Contexto
Card del tablero `tablero-al-guardar-el-primer-gasto-el-aviso-era-5jpb` (Yala 2.1, medium). Ticket: `tickets/backlog/first-expense-practice-alert-tears-down-the-success-screen.md` (triage medium 2026-10-08, PR #403). Al guardar el primer gasto, `PanelView` consume `pendingPracticeCleanup` en el acto con la hoja del formulario encima, y el aviso «¿era de prueba?» desmonta el formulario antes de que se vea la pantalla de éxito. El #384 (17e0281cb) solo cambió cuándo se arma el aviso. Ojo: el PR #453 añadió al candado del Panel que no presenta nada mientras haya una hoja presentada en la ventana (`windowPresentationVisible`); mira si este aviso pasa por ese candado y reutilízalo en vez de inventar otro mecanismo. Primero verifica en `origin/2.1` si el bug sigue existiendo; si ya no, cierra el ticket con evidencia.

## Qué se pide
- Reproducir con un test (XCUITest si hace falta) que falle antes: primer gasto guardado ⇒ la pantalla de éxito se ve completa y el aviso «¿era de prueba?» sale después de cerrarla.
- Arreglo acotado: el aviso espera a que el formulario/pantalla de éxito se cierre.
- Capturas antes/después (`capturas/antes.png`, `capturas/despues.png`; mira `~/Claude/referencias-ui/README.md`).

## Qué NO hay que tocar
- El texto del aviso, la lógica de borrar datos de práctica, onboarding, nube/CloudKit, marketing/.
- Si encuentras otro hallazgo, crea card: `tablero crear --proyecto Yala --titulo "..." --version 2.1 --agente frank` (sin --fecha).

## Reglas de build y Mini (obligatorias)
- `nice -n 10 xcodebuild -jobs 2 ...`. Antes de cada build, esperar a que el load average (uptime) sea < 8.
- Nunca filtrar la salida del build con `| head`. `-only-testing` como array de argumentos (uno por target/test).
- Pipeline serial: limpiar → build sin sim booteado → boot 1 simulador → tests → apagar y erase de ese simulador. Un solo simulador a la vez; nunca build con sim booteado.
- DerivedData de esta sesión y cachés de XcodeBuildMCP de worktrees que ya no existen: bórralos al cerrar sin preguntar. No toques los de otra sesión viva.
- Gate tras el CI del PR anterior (#454): arranca ya sobre `origin/2.1`; no partas de su rama. Justo antes del gate, mira si #454 sigue en CI; si sigue, espera a que entre y rebasa una sola vez con el sim apagado; si 2.1 no se movió, sigue; si ese CI falla, no esperes: rebasa con lo que haya. Build y simulador van después de ese rebase, una sola vez.
- PR contra la rama `2.1`.

## Cómo se sabe que está bien
Al guardar el primer gasto se ve la pantalla de éxito y el aviso sale al cerrarla (test rojo antes / verde después); PR abierto a 2.1 con antes/después en el cuerpo. Al terminar, `/cerrar-total` (sim apagado y borrado, Mini limpia).

## Paso 0

- **¿Sigue el bug en `origin/2.1` (fed08c788)?** Sí, por código: `PanelView.consumePendingPracticeCleanup()` pasa el aviso a `sheets.practiceCleanupItem` en su `onChange` sin mirar nada. No pasa por el candado de `PanelShell.drainPanelIfActive` (`RouterConsumerGateLogic.panelCanDrain`). Se confirma con el XCUITest rojo.
- **Mecanismo:** se reutiliza el candado entero del Panel (`panelCanDrain`, con `windowPresentationVisible` del #453 y su reintento de 300 ms). El consumo del aviso sale de `PanelView` y pasa a `PanelShell.drainPanelIfActive`: con el candado abierto y sin nada que el router acabe de presentar, se enciende el aviso. Sin mecanismo nuevo.
- **Asumido: el aviso espera también a que el Panel sea la pestaña activa** (es una dimensión de `panelCanDrain`). Un `.alert` de una pestaña oculta no tiene dónde presentarse; el primer presupuesto creado desde Planificación verá el aviso al volver al Panel.
- **Orden con el router:** si en la misma pasada hay un intent del Panel en cola, gana el intent; el aviso espera a que su hoja se cierre (el `onChange` de `hasActivePresentation` vuelve a pasar por el candado).
- **Estado de partida del test:** no hay perfil de seed con cuentas y cero registros. Se añade `sin-registros` (categorías + cuentas, sin transacciones ni saldos iniciales), solo DEBUG.
- **Test:** XCUITest nuevo: guardar el primer gasto ⇒ `transaction_success_accept` aparece; tras «Aceptar», el aviso con «Conservar».
- Texto del aviso, borrado de práctica, onboarding y nube: no se tocan.

# Voz, imagen o nuevo registro desde un widget o Siri llevan a la pestaña Panel

## Contexto
Card del tablero `tablero-voz-imagen-o-nuevo-registro-desde-un-wid-0ekl` (Yala 2.1). Ticket: `tickets/backlog/widget-and-siri-entries-wait-for-the-panel-tab.md`. **Decisión de Jürgen (12-oct 06:14): opción A — llevar al Panel.**
Hoy `yala://voice-entry`, `image-entry` y `new-transaction` (widgets de entrada rápida, «Registrar con Siri», Centro de Control, ⌘N) encolan su hoja para el Panel pero no piden `.navigate(.panel)`: si la app estaba en Estadísticas, Planificación u otra pestaña, el toque trae Yala delante y no pasa nada hasta que la persona vuelve al Panel por su cuenta. La foto compartida sí lleva al Panel (`enqueueSharedImage`). Según el ticket, es una línea por entrada en `AppBootstrapper.executeAction` más su fila en `docs/entry-points.md`.
Lee #441, #453 (el Panel no presenta encima de la hoja de otra pestaña: con una hoja abierta, espera a que se cierre), #457 (estas entradas sobreviven al segundo plano, buffer con caducidad de 15 min) y #459 (avisos diferibles vs críticos). Reutiliza esos mecanismos; no inventes otro.

## Qué se pide
- Que voz, imagen y nuevo registro desde widget/Siri/Centro de Control (y ⌘N si aplica) cambien a la pestaña Panel, como la foto compartida, y la hoja salga ahí. Con una hoja abierta en otra pestaña, se respeta la espera de #453 (no se pierde lo escrito).
- Tests rojo antes / verde después: desde Estadísticas, enlace de voz/nuevo registro ⇒ la app va al Panel y abre la hoja; con hoja abierta en otra pestaña ⇒ espera y no la cierra. Actualiza `WidgetEntryBackgroundUITests` si su contrato cambia.
- `docs/entry-points.md` al día y el ticket a `done`.
- **Capturas antes/después** (`capturas/antes.png`, `capturas/despues.png`, en `~/Claude/worktrees/_capturas/<fecha>-<slug>/`; mira `~/Claude/referencias-ui/README.md`): antes, el toque deja la app en Estadísticas sin hoja; después, Panel con la hoja abierta.

## Qué NO hay que tocar
- El aparcamiento de #457, la clasificación de #459, la foto compartida (otra card, msje), nube/CloudKit, marketing/.
- Si encuentras otro hallazgo, crea card: `tablero crear --proyecto Yala --titulo "..." --version 2.1 --agente frank` (sin --fecha).

## Reglas de build y Mini (obligatorias)
- `nice -n 10 xcodebuild -jobs 2 ...`. Antes de cada build, esperar a que el load average (uptime) sea < 8.
- Nunca filtrar la salida del build con `| head`. `-only-testing` como array de argumentos (uno por target/test).
- Pipeline serial: limpiar → build sin sim booteado → boot 1 simulador → tests → apagar y erase de ese simulador. Un solo simulador a la vez; nunca build con sim booteado.
- DerivedData de esta sesión y cachés de XcodeBuildMCP de worktrees que ya no existen: bórralos al cerrar sin preguntar. No toques los de otra sesión viva.
- Gate tras el CI del PR anterior (#467): arranca ya sobre `origin/2.1`; no partas de su rama. Justo antes del gate, mira si #467 sigue en CI; si sigue, espera a que entre y rebasa una sola vez con el sim apagado; si 2.1 no se movió, sigue; si ese CI falla, no esperes: rebasa con lo que haya. Build y simulador van después de ese rebase, una sola vez.
- PR contra la rama `2.1`.

## Cómo se sabe que está bien
Tocar voz, foto o nuevo registro en un widget o Siri con la app en otra pestaña lleva al Panel y abre la hoja (sin cerrar un formulario a medias); tests en verde; capturas antes/después; PR abierto a 2.1. Al terminar, `/cerrar-total` (sim apagado y borrado, Mini limpia).

---

## Paso 0 (Frank, 2026-10-12)

Medido en el árbol antes de decidir:

- `executeAction` (`AppBootstrapper.swift`) lo usan `yala://voice-entry`, `image-entry`, `new-transaction` y la acción
  del Centro de Control (`voice-entry`, `image-entry`). Ninguna rama pide `.navigate(.panel)`.
- ⌘N **ya** lleva al Panel (`RootCommandPerformer.perform`, `.navigate(.panel)` + `.presentNewTransaction`): no se toca.
- `.navigate(.panel)` con una hoja abierta en otra pestaña cambia la pestaña por debajo sin cerrarla, y el Panel espera
  a que se cierre para presentar (#453, `ExternalEntryForeignSheetUITests#test_halfFilledFormInAnotherTab_panelLink_keepsTheForm`).

Decisiones:

1. **Una línea al principio de `executeAction`**: `.navigate(.panel)` antes de cualquier intent, en las tres entradas y
   en todas sus ramas (Pro, consentimiento, hoja directa). Es lo que hace `enqueueSharedImage`, que también navega
   antes de la hoja de Pro. Asumido: la hoja de Pro y la del consentimiento también salen en el Panel.
2. **No se toca** el aparcamiento de #457 (`.navigate` sigue sin aparcarse: se consume al instante, no espera a una
   hoja) ni la clasificación de #459.
3. **El contrato de `WidgetEntryBackgroundUITests` cambia**: la entrada ya no espera en Estadísticas. Para que siga
   esperando —y así probar que sobrevive al segundo plano— la deja esperando un «Nuevo registro» a medias en
   Estadísticas; al volver y cerrarlo, la hoja sale en el Panel.
4. **Red nueva**: `WidgetEntryToPanelUITests` (voz, imagen y nuevo registro desde Estadísticas ⇒ Panel con la hoja) y
   un caso de voz con formulario a medias en `ExternalEntryForeignSheetUITests` (espera, no lo cierra, sale al cerrarlo).
5. Capturas: el «antes» sale de la corrida roja de la red nueva sobre el código sin arreglar.

### Paso 0 bis — la foto compartida (msje), añadida por Jürgen a media sesión

Jürgen decidió la opción B del ticket `shared-photo-waits-silently-behind-an-open-panel-sheet` y pidió hacerla en este
PR o en otro desde este worktree.

1. **Mismo PR y mismo commit de código.** Un solo gate y una sola CI. Iba a ir en un commit aparte, pero el sello del
   gate lleva HEAD dentro (`qa/scripts/worktree-stamp.sh`): un segundo commit de código pediría un segundo gate entero.
   El cuerpo del commit y del PR separan las dos partes.
2. **Qué se cierra**: la Bandeja, el registro por imagen en «elige una foto» y el «?» de un widget del Panel sin un
   tamaño cambiado. Son las tres del ticket. Asumido: solo si están **solas** en la ventana. Con algo encima (un borrador
   en edición, el selector de fotos, un aviso) puede haber datos, y se espera.
3. **Qué espera, como hasta hoy**: todo lo demás. Un «Nuevo registro» a medias, Ajustes, el chat, la revisión de una
   lectura anterior, una hoja de otra pestaña. Ante la duda, espera: es una lista de lo que se puede cerrar, no de lo
   que no.
4. Asumido: **la práctica guiada** del registro por imagen no se cierra, porque cerrarla la daría por saltada.
5. **Solo la foto compartida** (y el recibo soltado en el iPad, que entra por `enqueueSharedImage`). Voz, imagen y nuevo
   registro desde un widget siguen esperando: el encargo de esta sesión no pidió cerrar nada.
6. **Capturas**: `antes-2.png` / `despues-2.png`, Bandeja abierta al compartir. El «antes» sale de un build con la
   llamada del cierre quitada.

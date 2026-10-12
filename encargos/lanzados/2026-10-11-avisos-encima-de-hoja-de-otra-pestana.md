# Invitaciones y avisos de la app se presentan encima de la hoja de otra pestaña

## Contexto
Card del tablero `tablero-invitaciones-y-avisos-de-la-app-se-prese-wwob` (Yala 2.1, medium). Ticket: `tickets/backlog/invite-and-app-notices-present-over-other-tab-sheets.md`. Hallazgo del PR #453: el Panel ya no presenta encima de la hoja de otra pestaña (dimensión `windowPresentationVisible` en `RouterConsumerGateLogic.panelCanDrain`, con `ModalPresentationProbe.isAnythingPresented(in:)` y re-chequeo cada 300 ms en `PanelShell`). Pero las pantallas de unirse a un grupo (`.contentView`) y los avisos de prueba expirada, downgrade e hitos (`.mainTab`) tienen el mismo patrón: se presentan encima de un formulario a medias de otra pestaña y pueden cerrarlo y perder lo escrito. Lee #453, #441, #457 y `docs/entry-points.md`; reutiliza ese candado, no inventes otro.

## Regla obligatoria: los avisos críticos NO esperan
`.contentView` mezcla avisos críticos que no deben quedarse en cola detrás de un formulario. Antes de tocar nada, en el Paso 0:
- Lista todo lo que presentan `.contentView` y `.mainTab` y clasifícalo en **crítico** (no espera) y **diferible** (espera a que se cierre la hoja).
- Criterio de crítico: seguridad o integridad de datos/cuenta (sesión caducada o cerrada, cuenta borrada, wipe/migración en curso o fallida, bloqueo de app, consentimiento legal obligatorio, errores que impiden seguir). Estos se siguen presentando como hoy.
- Criterio de diferible: invitaciones a grupos, prueba expirada, downgrade, hitos/celebraciones, ofertas y avisos informativos. Estos esperan a que se cierre la hoja, sin perderse (si hay que aparcarlos al ir a segundo plano, usa el buffer de #457).
- Deja la tabla de la clasificación en el cuerpo del PR y en `docs/entry-points.md`. Si algún caso es dudoso de verdad, trátalo como crítico y anótalo en el PR.

## Qué se pide
- Tests rojo antes / verde después: formulario a medias en otra pestaña + invitación (y un aviso diferible) ⇒ el formulario sigue con lo escrito y el aviso sale al cerrarlo. Un test que fije que un aviso crítico sigue saliendo de inmediato.
- Capturas antes/después (`capturas/antes.png`, `capturas/despues.png`; mira `~/Claude/referencias-ui/README.md`).

## Qué NO hay que tocar
- El contenido/textos de los avisos, la lógica de Pro/downgrade, nube/CloudKit, marketing/.
- Si encuentras otro hallazgo, crea card: `tablero crear --proyecto Yala --titulo "..." --version 2.1 --agente frank` (sin --fecha).

## Reglas de build y Mini (obligatorias)
- `nice -n 10 xcodebuild -jobs 2 ...`. Antes de cada build, esperar a que el load average (uptime) sea < 8.
- Nunca filtrar la salida del build con `| head`. `-only-testing` como array de argumentos (uno por target/test).
- Pipeline serial: limpiar → build sin sim booteado → boot 1 simulador → tests → apagar y erase de ese simulador. Un solo simulador a la vez; nunca build con sim booteado.
- DerivedData de esta sesión y cachés de XcodeBuildMCP de worktrees que ya no existen: bórralos al cerrar sin preguntar. No toques los de otra sesión viva.
- Gate tras el CI del PR anterior (#458): arranca ya sobre `origin/2.1`; no partas de su rama. Justo antes del gate, mira si #458 sigue en CI; si sigue, espera a que entre y rebasa una sola vez con el sim apagado; si 2.1 no se movió, sigue; si ese CI falla, no esperes: rebasa con lo que haya. Build y simulador van después de ese rebase, una sola vez.
- PR contra la rama `2.1`.

## Cómo se sabe que está bien
Con un formulario a medias en otra pestaña, las invitaciones y avisos diferibles ya no lo cierran; los críticos siguen saliendo al momento; tabla de clasificación en el PR; tests en verde; PR abierto a 2.1. Al terminar, `/cerrar-total` (sim apagado y borrado, Mini limpia).

## Paso 0 (auto-contestado, sesión lanzada en bypass)

Ficheros: `RouterConsumerGateLogic.swift` (clasificación + decisiones), `AppRouter.swift` (drenar saltando lo retenido),
`ContentView.swift` (drenaje de `.contentView` y de `.mainTab` + reintento de 300 ms), `AppBootstrapper.swift` +
`UITestRouterNoticeStage.swift` (seam DEBUG para encolar un aviso en caliente), tests unitarios y XCUITest,
`docs/entry-points.md`, `qa/coverage-index.json`, ticket.

Decisiones:
1. **Candado reutilizado**: `ModalPresentationProbe.isAnythingPresented(in:)` sobre la ventana líder, como el Panel.
   Solo cuenta con la matriz del shell LIBRE: con la cadena del Welcome cerrándose por una invitación (B4-04) no se
   mira la ventana, o el cover que se va retendría la invitación que lo cerró.
2. **Clasificación por caso de `RouterIntent`** (función pura, con test exhaustivo). Críticos (no esperan): `remoteWipe`,
   `iCloudMismatch`, `appleIDChangedClosePrivate`, `presentRemoteWipeNotice`, `presentLateICloudMirrorNotice`,
   `remoteOnboardingCompleted`. Dudosos → como críticos (anotado en el PR): `showGroupSyncError` (error de un gasto de
   grupo que no llegó a su sitio), `presentFullModeActivation` y `presentGroupsOrganizerStep` (respuesta a un toque
   dentro de la app, no avisos; «Activar Yala completo» se toca desde DENTRO de la hoja de Ajustes y esperar a que se
   cierre dejaría el toque sin respuesta). Diferibles: aviso de la Bandeja, oferta de prueba, Novedades, error y
   archivado de invitación, pantallas de unirse/entrar/consentir de Grupos, puerta neutra del invitado; en `.mainTab`
   prueba expirada, downgrade e hitos. `navigate` y pedir reseña no presentan hoja de Yala: como hoy.
3. **Un diferible retenido no tapa a un crítico**: el drenaje salta los retenidos (`drainNext(where:)`). En `.mainTab`
   lo que no presenta hoja (`navigate`) tampoco espera detrás de un aviso retenido por una hoja de otra pestaña.
4. **Segundo plano**: se aparcan en el buffer de #457 (15 min) los diferibles sin fuente que los re-emita: respuesta a un
   enlace de invitación (`showInviteError`, `showGroupArchivedNotice`) y el hito (solo se pide al guardar el registro N
   exacto). El resto vuelve solo: invitación → `PendingJoinStore`; prueba expirada/downgrade → sus productores; Bandeja →
   borradores; oferta y Novedades → arranque siguiente.
5. **Instrumento del test**: invitación real `yaladev://invite?s=…` (canal CKShare retirado ⇒ «Enlace no válido», sin
   seam). Aviso diferible y crítico en caliente por un seam DEBUG `yaladev://uitest-notice?kind=…` que solo sustituye
   al productor (`RouterEntryGate.submit`); la decisión que se prueba es la real.

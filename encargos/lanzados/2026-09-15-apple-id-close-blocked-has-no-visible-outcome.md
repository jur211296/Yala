# Implementar ticket: apple-id-close-blocked-has-no-visible-outcome

## Contexto
Cola nocturna bypass. Tras #167. Si el cierre por cambio de Apple ID se bloquea, nadie lo enseña y el coordinador queda tapiado.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, board, `docs/TICKETS.md`, merge, `/cerrar-total`. Bugs/decisiones nuevas → ticket `--solo-crear` y avisar a Frank. Device-QA → `tickets/qa/` si aplica.

Avisos a Frank: (1) decisión/acceso; (2) PR; (3) `/cerrar-total` resumen producto; (4) idle una vez.
No lances el siguiente: Frank encadena. No marketing/.

## Que se pide
1. Leer ticket + flujo Apple ID close del #159.
2. Si el cierre se bloquea: outcome visible (copy/alerta) y el coordinador no queda tapiado.
3. PR a `2.1`; board/`TICKETS.md`; `/cerrar-total`.

## Que NO hay que tocar
marketing/. Wipe de prod.

## Como se sabe que esta bien
Criterios del ticket; tests; PR mergeado; `/cerrar-total`.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hechos medidos antes de decidir (2026-09-15, este árbol).**

- Con `confirmedWithoutICloudCopy: true` las celdas C y D no esperan al export, así que
  `.exportUnconfirmed` es inalcanzable desde este aviso. Lo alcanzable: C → `.sessionExpired`
  (`blockIfGroupsCannotUpload`); D → `.transient`, `.sessionExpired`, `.channelPaused` y `.permanent`
  (residuo tras el teardown). Además `signOut` tiene `return` mudos que no tocan la fase.
- **Una puerta más del mismo síntoma, no escrita en el ticket:** el tap resuelve la celda con
  `CloudSyncFlags.groupsBackendEnabled` (compuesto) y el coordinador con
  `groupsBackendCompiledCapability`. Con el kill remoto de Grupos, o sin snapshot de remote-config
  (falla cerrado), y sesión de grupos viva: el tap dice C, el coordinador dice D, `confirmedPath` no
  casa y `signOut` vuelve sin hacer nada. `ProfileView.signOutRowPath` y `WelcomeGroupsGateView.exitCell`
  ya leen el compilado.
- El blocker `"appleIDChangedAlert"` no sale por telemetría (`surfacedBlockers`) y quienes leen
  `shellModalBlocker` solo miran si es `nil`.
- `YalaSyncMeta-UITest` es persistente y `-uitest-reset` no purga `GroupSyncOutbox`. Bajo XCUITest un
  cierre que termina bien arma un boot-wipe REAL (`armSignOutWipe` no tiene guard de test).
- Copy que ya existe y basta: `settings.signOutBlocked*`, `settings.signOutPending*`,
  `groups.errors.{sessionExpired,channelPaused,uploadRetryLater}`, `settings.signOutWorking`,
  `action.retry`, `icloud.appleIDChanged.*`.

**D1 · ¿Qué sustituye al `.alert`?** → Una sola hoja (`.sheet`) con fases —preguntar / cerrando /
bloqueado— en su propio `ViewModifier`, del anchor de `ContentView`, entrando por la cola como hoy. Sin
swipe: se sale por sus botones, como de un alert.
Por qué: la rule prohíbe dos `.alert` encadenados y las fases dan sitio al progreso y al motivo (molde
`LateICloudMirrorNoticeView`). Alternativa descartada: `fullScreenCover`, que compite con el cover
terminal del relanzamiento en el mismo anchor, y «Ahora no» no es terminal.

**D2 · ¿Dónde vive el estado que tiene que sobrevivir a la vista?** → En `ContentView`, un solo
`@State` de dominio, `appleIDCloseNotice: AppleIDCloseNotice?` (`nil` · `.asking` · `.closing` ·
`.couldNotStart`). Es la CONDICIÓN VIVA que entra en la matriz. Lo que se ve mientras cierra no se
duplica: se deriva de `CloudSessionSignOut.phase`.
Por qué: si UIKit tumba la hoja y la red la re-presenta, una vista con fase propia volvería a
«preguntar» con el cierre corriendo. Alternativa descartada: fase local en la vista.

**D3 · ¿El cierre corre atado a la vista o suelto?** → Suelto (`Task {}`), como hoy en el alert y en
Ajustes. La vista lo pide y observa la fase.
Por qué: cancelar `pushGroupsForSignOut` fabrica un `.blocked(.transient)`. Alternativa descartada:
`.task(id:)`.

**D4 · Qué ve la persona en cada fase.** → `.closing` con el coordinador `.idle`/`.working`: el título
del aviso y un spinner; el caption `settings.signOutWorking` solo con `waitingForPending`, igual que
Ajustes. `.blocked(motivo)`: título y mensaje del motivo + «Reintentar» + «Ahora no».
`.awaitingRelaunch`: la hoja se retira y el cover terminal (dueño único) la releva. `.couldNotStart`:
«Un momento más» con las mismas dos salidas. La tabla es pura (`AppleIDCloseNoticeLogic`).
Por qué: en C el cierre dura un parpadeo y no sube nada; «Guardando tus cambios pendientes…» ahí sería
falso. Alternativa descartada: copy nuevo «Cerrando sesión…», 16 idiomas por un parpadeo.

**D5 · ¿De dónde sale el texto del bloqueo?** → Del MISMO mapa motivo→texto que Ajustes, extraído a
`SignOutBlockedCopy`; `ProfileView.signOutBlockedMessage` pasa a delegar. Sin claves nuevas.
Por qué: dos composiciones de la misma decisión divergen. Alternativa descartada: copiar el `switch`.

**D6 · ¿Qué hace cada botón?** → «Cerrar sesión y quitarlos» resuelve la celda AL TOCAR (D7): si ya no
es C/D, suelta el aviso; si el coordinador está `.blocked` por otro gesto, lo reconoce y arranca el suyo
(la confirmación nueva manda); si está `.working`, no arranca y enseña `.couldNotStart`. Tras el
`await`, si la fase es `.idle` o `.working`, el cierre no corrió ⇒ `.couldNotStart`. «Reintentar» hace
lo mismo. «Ahora no» suelta el aviso, que vuelve en el arranque siguiente, y reconoce el bloqueo **solo
si es el de este cierre**: uno ajeno guarda la decisión pendiente de su pantalla (el `blockedExit` del
export de Ajustes) y quien no pidió cerrar no lo toca.
Por qué: ningún estado de la hoja se queda sin salida, y el bloqueo de este cierre vuelve a `.idle` en
todas. Alternativa descartada: pantalla de «no disponible» con copy nuevo.

**D7 · ¿Con qué getter se resuelve la celda al tocar?** → `groupsBackendCompiledCapability`, el del
coordinador, Ajustes y la puerta del Welcome.
Por qué: el compuesto deja el `return` mudo de arriba. Alternativa descartada: ticket aparte, porque es
el mismo síntoma y una línea.

**D8 · La red de presentación.** → Molde `SignOutRelaunchNetModifier`: el `onAppear` del contenido
prueba que UIKit presentó y el `onDismiss` re-arma si la condición sigue viva, con
`RelaunchNetLogic.verdict`. Al agotarse el cap se SUELTA la condición viva con canario nuevo
(`appleIDCloseNoticeNotPresented`), salvo que el cierre siga `.working`, que sigue intentando porque
`isSignOutWorking` ya retiene el router. Si está `.blocked` por este cierre, lo reconoce al soltar. La
red se retira con `.awaitingRelaunch`.
Por qué: es el criterio 4, y dos redes toggleando el mismo anchor son la carrera del 2026-07-14.
Alternativa descartada: `ModalPresentationProbe`, que existe porque un alert no tiene contenido.

**D9 · ¿Entra la hoja de alcance (`DestructiveScopeLogic.signOutOperation`)?** → No. Ticket nuevo.
Por qué: ninguna variante dice la verdad de este cierre. «Con copia» promete esperar a iCloud y «sin
copia» afirma que no hay copia en ninguna parte, así que haría falta copy nuevo y una decisión de
producto. No es criterio del ticket.

**D10 · Nombre del blocker.** → `showAppleIDChangedAlert`/`"appleIDChangedAlert"` pasan a
`appleIDCloseNoticePending`/`"appleIDCloseNotice"`.
Por qué: ya no es un alert y el nombre no viaja por telemetría. Alternativa descartada: conservarlo
como `remoteWipeAlert`, que sí salía por telemetría.

**D11 · ¿Cómo se prueba?** → Unit de la tabla pura y del mapa de copy; source-scans del cableado; y
XCUITest con dos seams nombrados: `-uitest-apple-id-changed` encola el intent y
`-uitest-groups-outbox-pending` siembra una fila viva de outbox de grupos, para que C se bloquee DE
VERDAD con `.sessionExpired`. `-uitest-reset` purga esas filas. Ningún XCUITest confirma un cierre que
termine bien.
Por qué: los criterios 1-2 se ven en pantalla, y un seam que forzara el veredicto del coordinador
dejaría ciego al test (rule de testing). Alternativa descartada: forzar `.blocked` en el coordinador.

**D12 · Device-QA y destino del ticket.** → Sin ticket de QA nuevo: se actualiza el recorrido 5 de
`device-qa-apple-id-change-closes-private-session` (D en modo avión). El ticket va a `done`.
Por qué: lo simulable lo cubre el XCUITest, y lo que falta —red real en D— ya tiene guion.

**D14 · Lo que cambió la review adversarial (cuatro lentes, 2026-09-15).** → Tres cambios de diseño, los
tres por defectos míos. (1) Un estado más, `.stopped`: el cierre corrió y volvió. Con un solo `.closing`, la
combinación con `.idle` se pintaba como progreso, y si Ajustes —montado debajo de la hoja, porque las hojas
de las pestañas no entran en la matriz— reconocía el bloqueo, la hoja se quedaba en un spinner sin botones
reteniendo el router. (2) La hoja congela la ETAPA al retirarse: «Ahora no» sobre un bloqueo pintaba un
progreso durante la animación. (3) El identificador del bloqueo sale del mismo motivo que el texto. Y redes
nuevas por escáner para lo que un mutante dejaba vivo: «Reintentar» vacío, la fase de progreso, el cap de la
red y la paridad del nombre de los args.
Descartado: meter las hojas de las pestañas en la matriz del shell. Es el mecanismo general y cambia todos
los intents del shell; va anotado en `orphan-alerts-behind-fullscreen-covers`.
Y los mutantes de XCUITest refutaron dos afirmaciones del propio test. Con «Ahora no» sin reconocer el
bloqueo, el caso seguía verde, porque el manejador de interrupciones de XCTest lo reconocía al tocar. Y otra
hoja no discrimina que la matriz retenga la cola. El caso 2 ahora mira el aviso antes de tocar, y el caso 1
solo afirma lo que su mutante mata.

**D13 · Residuales que se dejan escritos y no se tocan.** → (a) El drenaje no re-mide la celda: la
re-mide el tap, y si ya no es C/D la hoja se retira sin hacer nada. (b) «Reintentar» tras un
`.permanent` de residuo post-teardown en D recorre el mismo camino que Ajustes; no es de este ticket.

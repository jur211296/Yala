# «Empezar de cero» separa la cifra: cambios tuyos con su motivo y cambios de otra cuenta con el suyo (decisión A de Jürgen)

## Contexto
Ticket: `tickets/backlog/fresh-start-copy-for-another-accounts-group-changes-borrows-the-own-reason.md` (léelo entero; las coordenadas son del 2026-10-05, re-mídelas).
Desde el PR #365, «Empezar de cero» cuenta también los cambios de grupos de OTRA cuenta guardados en este teléfono, porque el borrado se los lleva. Cuando además hay cambios tuyos que no suben por otro motivo, la cifra suma los dos y el texto explica solo el motivo de los tuyos. El caso peor: con tu cuenta no disponible (`.permanent`) el texto dice que volver a intentarlo no lo arregla, y para los de la otra cuenta eso es falso (entrando con ella subirían). Con un motivo pasajero, el texto promete que esperar arregla N cambios cuando solo arregla los tuyos.

Decisión de Jürgen (2026-10-05, tarjeta `tablero-decidir-empezar-de-cero-explica-los-camb-n3k4`): **A.** Separar la cifra: «N cambios tuyos que no han subido (motivo) y M de otra cuenta que solo puede subir ella», cada uno con su motivo. Principio: la persona no puede aceptar perder lo que el aviso no le explicó bien. Jürgen quiere siempre lo más robusto y la mejor práctica, aunque tarde más.

Antecedentes en `2.1` o entrando:
- PR #365 (mergeado): «Empezar de cero» cuenta los cambios de otra cuenta.
- PR #366 (mergeado): con el drain atascado y cambios de otra cuenta, el aviso nombra las dos causas.
- PR #368 (en cola de auto-merge): con el drain atascado y el History ilegible, ninguna oferta de perder sale sin cifra (incluida «Empezar de cero», `settleFreshStartBlock`, `FreshStartGroupsLoss`, `CloudSignOutFlowLogic.groupsLossShownReason`). Misma zona: construye encima, no lo deshagas.

Relacionado y fuera de esta sesión (no lo implementes, solo no lo rompas): `stuck-groups-unread-history-with-another-account-names-one-cause`, `personal-loss-without-a-count-covers-own-edits-made-after-the-notice`, `stuck-groups-drain-with-another-account-and-a-cycle-reason-names-two-of-three-causes` (Jürgen decidió dejarlo como está).

## Qué se pide
1. Medir en el código de hoy los casos 1, 2 y 3 del ticket en «Empezar de cero» (bienvenida y donde más se ofrezca).
2. Implementar la A: cuando hay cambios tuyos sin subir Y cambios de otra cuenta, el aviso y el «¿seguro?» separan las dos cifras, cada una con su motivo verdadero. Cuando solo hay de una clase, el texto de hoy sigue si dice la verdad. Arreglar también «tus grupos» cuando los cambios no son tuyos y el singular «esa cuenta» si pueden ser varias (caso 3).
3. Textos nuevos en los 16 locales (es-AR voseo, es-ES pretérito perfecto, español neutro en el resto), sin inventar plazos; plurales correctos. Reusa textos existentes donde ya digan la verdad.
4. Caso 4 del ticket (alert de la pantalla principal `ShellDataAlertsModifier.refuseWhileGroupsArePending`): solo medir si es alcanzable con el onboarding completo. Si lo es, es un bucle sin salida: ticket aparte en `tickets/backlog/` con propuestas A/B/C y recomendación; no lo implementes.
5. Tests: rojo medido antes del fix, verde después, mutantes que importen, controles (solo tuyos, solo de otra cuenta, sin pendientes, cada motivo).
6. Review adversarial con lente de datos y lente de verdad del copy.
7. Hallazgos nuevos → tickets en `tickets/backlog/`; device-QA si aplica → guion en `tickets/qa/` y tarjeta del tablero a `in qa`; si no aplica, tarjeta a `done`. La tarjeta es `tablero-decidir-empezar-de-cero-explica-los-camb-n3k4`.
8. Si el cambio se ve en pantalla, deja `capturas/antes.png` y `capturas/despues.png` en el worktree y lista las rutas en el resumen.

## Qué NO hay que tocar
- No cambies qué se borra ni qué se cuenta: solo cómo se explica. La cifra total y las salidas siguen iguales.
- No cambies la decisión B2 del cierre de sesión ni del desasociar, ni el orden de causas del drain atascado.
- Nada de marketing/, nada de servidor ni migraciones de Supabase.
- No implementes los tickets relacionados de arriba.

## Pipeline en la Mini (serial, obligatorio)
1. Limpiar: sims muertos, DerivedData de sesiones ya cerradas, cachés de XcodeBuildMCP de worktrees que ya no existen. Sin preguntar.
2. Build con `xcodebuild -jobs 2` sin simulador booteado.
3. Boot de 1 solo simulador.
4. Tests.
5. Apagar y borrar ese simulador.
Prohibido solapar swift-frontend + SpringBoard + app + UITests.

DerivedData y cachés de XcodeBuildMCP: al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees retirados o con PR ya mergeado. No preguntes. No toques los de un worktree vivo. Si el borrado falla, dilo en el cierre.

Gate después del CI del PR anterior: la sesión arranca ya, sobre `origin/2.1`. Justo antes del gate, mira si el PR #368 sigue en CI. Si sigue, espera a que entre y rebasa una sola vez, con el simulador apagado. Si `2.1` no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.

## Cómo se sabe que está bien
- Con cambios tuyos sin subir y cambios de otra cuenta, «Empezar de cero» dice cuántos son de cada clase y por qué, y ningún texto promete que esperar o reintentar arregla los de la otra cuenta, ni que los de la otra cuenta no tienen arreglo.
- Con una sola clase, el texto dice la verdad (incluido «tus» y el plural de cuentas).
- Lo que se borra y lo que se acepta no cambia.
- Gate verde (builds sin warnings nuevos, unit completa, XCUITest de las áreas tocadas, centinela 0), salvo rojos conocidos con ticket.
- PR abierto contra `2.1` y cierre con `/cerrar-total` en modo cola (autónomo, auto-merge, sin esperar CI). Al cerrar, la Mini queda limpia: sim apagado y borrado, DerivedData y cachés de esta sesión fuera, worktree retirado, tmux muerta.

## Paso 0 (2026-10-05, Frank)

**Premisas medidas (leyendo el árbol de hoy, `088f4e43f`).**
- Caso 1 se sostiene: con `.permanent` la oferta cuenta `loss.count` = todas las filas vivas (también las retenidas de otra
  cuenta) + el espejo entero, y el texto es `lossPermanent` («volver a intentarlo no lo va a arreglar»).
- Caso 2 se sostiene: con un motivo que no ofrece la salida, la cifra es la de la subida + las entradas del espejo de otra
  cuenta (`freshStartBlockCountingAnotherAccount`) y el texto es el del motivo («en un rato», «unos segundos»).
- Caso 3 se sostiene: `lead`, `title` y `lossConfirmBody` dicen «tus grupos» también con `.groupsChangesFromAnotherAccount`,
  y `lossOtherAccount` dice «esa cuenta».
- Caso 4: lo mide un agente aparte; el resultado va al ticket o al cierre.

**Decisiones (autónomo, asumidas).**
1. **Dónde vive la partición.** `FreshStartGroupsBlock` gana `anotherAccountCount`: cuántos de `pendingCount` solo los sube
   otra cuenta (filas retenidas + entradas del espejo de otra cuenta). Sin valor por defecto, como `readsUncaptured`. La
   cifra total y las salidas no cambian.
2. **La forma del texto es pura y probada** (`CloudSignOutFlowLogic.freshStartGroupsCopyShape`): `.own` (sin nada de otra
   cuenta: el texto de hoy), `.anotherAccount` (motivo «otra cuenta»: su texto, sin «tus»), `.mixed(own:anotherAccount:)`
   (las dos clases: cifra partida si se puede contar, neutra si no).
3. **Mixto = cifra partida + motivo de los tuyos + frase de los de otra cuenta + cola.** El motivo de los tuyos reusa los
   textos del cierre donde ya dicen la verdad de lo tuyo (`uploadRetryLater`, `transient`, `channelPaused`,
   `captureUnfinished`, `attestUnavailable`); `.permanent` y `.sessionExpired` tienen texto nuevo, porque los de hoy hablan
   de «los» (todos). La cola: con salida, «puedes perderlos todos»; sin salida, «cuando suban los tuyos, podrás perder solo
   los de otra cuenta» (camino verificado: `heldRowsVerdict` y `freshStartResidualReason` dan «otra cuenta» con su salida).
4. **Plurales sin stringsdict**: el patrón «Etiqueta: %d.» que ya usa `lossConfirmBody`. Las variantes (es-ES, es-AR,
   en-GB, pt-PT) no tienen stringsdict.
5. **«Otra cuenta» sin número**: «apuntados con otra cuenta», «la cuenta que apuntó cada uno». Se reescribe
   `lossOtherAccount`; `lossOtherAccountAndCaptureUnfinished` NO (tests de #366 fijan su frase y es del ticket relacionado
   fuera de alcance): va a «Encontrado».
6. **En la subida sin salida la parte de otra cuenta es solo el espejo** (lo que se sumó): la cifra de la subida unas veces
   incluye las filas retenidas y otras no. No se toca (no cambia lo que se cuenta): ticket aparte.
7. **Título**: «Faltan cambios de grupos por subir» (sin «tus») salvo en `.own`. Las tres pantallas lo leen de
   `SignOutBlockedCopy`.

**Ajustes tras la review adversarial (2026-10-05, dos lentes).**
- Datos: con el drain atascado, los cambios del History que el registro atribuye a otra cuenta entran en la parte ajena
  (salían como «tuyos»). En la subida sin salida, con filas retenidas, la cifra no se parte: su total unas veces las trae y
  otras no.
- Copy: con todo de otra cuenta y un motivo sin salida, no se usa el texto del motivo («tus grupos», «en un rato»); sin App
  Attest, el del teléfono. La cola «si los tuyos llegan a subir…» depende de la pantalla (`retryOffersTheLossExit`): el
  alert del shell nunca ofrece perderlos y no la dice. «Cuando suban» → «si llegan a subir» (el atasco puede no curarse).
  `splitOwnSessionExpired` dice «la cuenta que los apuntó», no «tu cuenta».
- Descartado: device-QA. El estado no se provoca a mano (precedente de los dos tickets hermanos); ticket a `done`.

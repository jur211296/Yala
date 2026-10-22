# Implementar ticket: groups-channel-seal-has-no-reachable-producer

## Contexto
Cola autónoma bypass. Tras #169. Tras el fix del 403 infra (#154), `stoppedUntilRelaunch` quedó sin productor alcanzable.

## Decisión de Jürgen (2026-09-14)
**4A: Retirarlo.** Quitar `stoppedUntilRelaunch`, parámetro en GroupsLoopRestartLogic.shouldStart, guards que lo leen y tests que lo fijan. No darle productor nuevo ni dejarlo documentado como muerto.

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, board repo (`tickets/` + `docs/TICKETS.md`), merge, `/cerrar-total`. NO sync al store/Kanban del panel. Bugs/decisiones nuevas → ticket `--solo-crear` y avisar a Frank. Device-QA → `tickets/qa/` si aplica.

Avisos a Frank: (1) decisión/acceso; (2) PR; (3) `/cerrar-total` resumen producto; (4) idle una vez.
No lances el siguiente: Frank encadena. No marketing/.

## Que se pide
1. Leer ticket + usos de stoppedUntilRelaunch.
2. Retirar el mecanismo completo (4A).
3. PR a `2.1`; board/`TICKETS.md`; `/cerrar-total`.

## Que NO hay que tocar
marketing/. 4B/4C. Wipe de prod. Store/Kanban del panel.

## Como se sabe que esta bien
Cero productores/lectores del sello; tests verdes; PR mergeado; `/cerrar-total`.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.
> La decisión de producto ya estaba tomada (4A, Jürgen, 2026-09-14); estas son las de ejecución.

**La premisa, medida antes de decidir nada (2026-09-15, este árbol).** En el canal de Grupos,
`.accountUnavailable` tiene tres productores: el 403 del kill en el push y en el pull, que encienden el
testigo y nunca armaron el sello, y el 409 `yala_account_reverting` del push, el único que lo armaba.
Ese 409 solo lo emite `beginFreezeCheck`, que se llama en `/sync/push` y `/prefs/push`
(`gateway/src/sync/routes.ts:150` y `:491`); `gateway/src/groups/routes.ts` no pasa por ahí. El ticket
acertaba: el sello no tenía productor alcanzable.

**D1 · ¿Entra el `.stoppedUntilRelaunch` del runtime personal (`CloudSyncRuntime`)?** → No.
Por qué: es otro mecanismo, con productores vivos (attest terminal y el 409 de `/sync/push`).
Alternativa descartada: barrer el nombre en todo `Yala/`, que tocaría el canal personal sin decisión.

**D2 · ¿Qué hace la rama `.stopUntilRelaunch` del loop de Grupos sin sello?** → Para el loop en esa
vuelta, queda re-arrancable y conserva sus dos motivos de log (`channel-disabled` / `account-unavailable`).
Por qué: es lo que queda al quitar la escritura del sello, y el log es lo que se lee en un incidente.
Alternativa descartada: colapsar los dos motivos en uno, que cambia el log sin que nadie lo pidiera.

**D3 · ¿Se renombra la acción `SyncCadencePolicy.CadenceAction.stopUntilRelaunch`?** → No.
Por qué: la comparte el runtime personal, donde sí significa eso. En el loop de Grupos, un comentario dice
qué hace esa rama aquí.

**D4 · ¿Se van también el testigo del kill y `stoppedByChannelKill(for:)`?** → No.
Por qué: `CloudSessionSignOut` los lee para elegir el aviso «el canal está en pausa», y el loop para el
motivo del log. Se reescribe su docblock, que justificaba su existencia con el sello.

**D5 · ¿Qué pasa con los tests que usaban el seam `_testStoppedUntilRelaunch` para probar que NO se
sellaba?** → Sale la aserción sobre el seam y se queda la de conducta (el loop re-arranca). Se renombran
los dos cuyo nombre nombraba el sello: `killSwitch403_stopsLoop_andTheNextStartRestartsIt` e
`infra403_backsOffInTheLoop_insteadOfStoppingIt`. `stoppedUntilRelaunch_doesNotStart` se borra entero.
Por qué: la conducta —que la parada del kill no se quede puesta y que el 403 de infraestructura haga
backoff— es la que un latch futuro rompería. Alternativa descartada: borrar los dos tests, que dejaría sin
red el re-arranque tras el kill.

**D6 · ¿Y las lápidas de `GroupsSyncClientTests` de los dos tests retirados el 14-sep?** → Se reducen a
un aviso de cinco líneas sin el sello: un `StubHTTPSession(statusCode: 403)` no para el loop, y un test de
loop que espere esa parada cuelga en vez de fallar.
Por qué: esa trampa sigue viva y no está en `.claude/rules/testing.md`; lo que citaba el sello, no.

**D7 · ¿Se reescriben los tickets que citan el sello?** → No.
Por qué: son medidas fechadas contra un commit (`groups-killswitch-403-blocks-detach-forever`,
`groups-expense-notif-only-on-foreground`, el cerrado del 403 de infraestructura), y ningún guion de
device-QA depende del sello.

**D8 · Los docblocks del re-arranque citan un guard «D8» de mount-mismatch que salió de la tabla con la
sesión de visita (`783a4ec9b`).** → No se tocan aquí: ticket `low` propio,
`groups-loop-restart-docs-cite-a-retired-mount-guard`.
Por qué: es otro objeto y ya estaba así antes de este cambio. La enumeración de gates del docblock de
`startIfEligible` pierde solo «stop».

**D9 · ¿Device-QA?** → No aplica.
Por qué: el sello no tenía productor alcanzable, así que en producción nada cambia. La red es la suite
unitaria, y el ticket va a `done/`.

**D10 · ¿Review adversarial?** → Sí, dos lentes de solo lectura (corrección/alcance y tests).
Por qué: toca los gates del loop de sync de Grupos, la zona donde `CLAUDE.md` la pide.

**D11 · ¿Test nuevo que fije que el 409 ya no cierra el canal?** → Sí. Revisada tras la review: la
primera respuesta fue «no».
Por qué: la promesa de `GroupsLoopRestartLogic.shouldStart` —ninguna parada del loop se queda puesta—
tenía red en la sesión caducada y en el kill, pero no en el 409, que es la tercera forma de parar. Fijar
esa promesa no es documentar el sello como muerto. Alternativa descartada (la primera respuesta): no
escribirlo, que dejaba el único cambio de conducta del PR sin un solo test que cayera al revertirlo.

**D12 · Los otros hallazgos de la lente de tests.** → Se arreglan los tres.
- Al quitar la aserción sobre el seam, el test del kill dejó de cubrir los guards de `syncNowFromPush` y
  `syncNowAfterLocalSave`, que eran la otra mitad de la regresión del 2026-08-03. Ahora ejerce los dos
  después de la parada.
- El mismo test heredaba `storageMode` de un global que escriben otras suites. Ahora lo fija, como su
  vecino del 403 de infraestructura.
- El re-arranque del test del 403 de infraestructura sale: sin sello ya no distinguía ese 403, lo cubre
  `restart_afterSessionExpiredStop_rearmsLoop_whenSessionAlive`, y su mensaje afirmaba lo contrario.
Por qué: los tres afectan a tests que este PR ya estaba reescribiendo. Lo que se queda fuera: los dos motivos
de log de la parada siguen sin test, como antes del PR (no hay seam sobre el `Logger`).

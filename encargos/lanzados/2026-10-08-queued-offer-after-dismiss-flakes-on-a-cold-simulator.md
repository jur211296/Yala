# Al cerrar un aviso, el siguiente en cola (oferta, bandeja, invitación) a veces no aparece hasta reabrir la app

## Contexto
Ticket `tickets/backlog/queued-offer-after-dismiss-flakes-on-a-cold-simulator.md`. Card tablero `tablero-al-cerrar-un-aviso-el-siguiente-que-espe-h411` (ya en curso, assignee frank). Triage medium 2026-10-08 midió que es producto: `markReady` sube la revisión dentro del update y el `onChange` no llega. Brief en `~/Claude/tmp-frank/queued-offer-after-dismiss-flakes-on-a-cold-simulator.md`.

Acaba de cerrar PR #411 (pdf multipágina) en cola de auto-merge a 2.1: justo antes del gate, si ese PR sigue en CI, espera a que entre y rebases una sola vez con el simulador apagado; si 2.1 no se movió, sigue de frente; si ese CI falla, no esperes: rebase con lo que haya y sigue. Build y simulador van después de ese rebase, una sola vez.

## Que se pide
Aplicar la opción A (recomendada): diferir el `recompute` una vuelta del main actor en `ReadinessGateObservers` / el camino que dispara `recompute` al cerrar avisos (`appleIDCloseNoticePending` y afines), de modo que al cerrar la hoja del cambio de Apple ID o el aviso de vaciado remoto salga lo que estaba en cola del shell (oferta de prueba, aviso de bandeja, invitación de grupo) sin relanzar la app.

Confirmar el fallo con evidencia (repro o test) y el arreglo con tests. Si A no basta, documenta por qué y solo entonces considera B (`AsyncStream`) o C (re-mirar la cola al liberar la matriz); no preguntes a Jürgen por A vs B vs C.

## Que NO hay que tocar
- No reabrir el tema de PDF / registro por imagen.
- No tocar clinicas ni otros proyectos.
- No cambiar contratos de nube salvo que el ticket lo exija (aquí es cliente).
- No pedir decisión de producto: A ya es la recomendada.

## Pipeline Mini (obligatorio)
1. Limpiar sims muertos / basura / DerivedData de worktrees retirados / cachés XcodeBuildMCP de worktrees que ya no existen.
2. Build con `xcodebuild -jobs 2` sin simulador booteado.
3. Boot 1 solo sim.
4. Tests.
5. Apagar y erase/limpiar data de ese sim.
Prohibido solapar swift-frontend + SpringBoard + app + UITests. Norma: 1 simulador a la vez.

## Cierre
Al terminar: PR a 2.1 con auto-merge cuando pasen checks, card a in qa (o done si no hay QA manual), `/cerrar-total` autónomo. Al cerrar: apagar sims usados, erase data, quitar worktree/DerivedData/cachés XcodeBuildMCP de este worktree si el PR ya mergeó o el árbol ya no hace falta, y no dejar basura. Si creaste algún secreto en el Llavero, anótalo en el resumen de cierre para que Frank lo mueva a 1Password (vault Yala).

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Qué se aplaza: el recálculo entero o solo la liberación?** → Solo la liberación (`markReady` + publicar
`shellModalBlocker = nil`). Bloquear sigue siendo inmediato.
Por qué: aplazar también el `markUnready` dejaría una vuelta en la que un `onChange(revision)` drena con el shell ya
tapado por lo que se acaba de presentar (dos presentaciones del mismo anchor). Liberar tarde solo retrasa un drenaje.
Alternativa descartada: diferir el `recompute` entero desde `ReadinessGateObservers`, por esa ventana.

**D2 · ¿Dónde vive el aplazamiento: en los cierres de `ReadinessGateObservers` o en `updateContentViewReadiness`?**
→ En `updateContentViewReadiness`, que es lo que llaman todos los `onChange` (observadores, `isWipingData`,
asentamiento del arranque, `isMainTabModalVisible`, fase del cierre).
Por qué: es el mismo patrón en todos (`markReady` dentro de la actualización); arreglarlo solo en el modificador dejaba
las otras cinco instancias. Alternativa descartada: tocar solo `ReadinessGateObservers` (instancias vivas sin arreglar).

**D3 · ¿El camino B4-04 de `drainContentViewIntents` también se aplaza?** → No: llama a la versión inmediata
(`applyContentViewReadiness`). Drena en la misma llamada y no depende del `onChange`; aplazarlo rompería su
`drainNext` inmediato.

**D4 · ¿Publicar `shellModalBlocker = nil` va con el `markReady` o antes?** → Juntos, en la vuelta aplazada.
Por qué: `PanelShell` drena al ver `nil`; separarlos cambiaría el orden entre consumidores respecto a hoy.

**D5 · ¿Cómo se fija para que no vuelva?** → Source-scan del cuerpo ENTERO de `updateContentViewReadiness` (guard que
bloquea en el acto + `Task { @MainActor in applyContentViewReadiness() }`) y de que `markReady(.contentView` solo
aparece en `applyContentViewReadiness`, con mutante en las dos direcciones. Red de comportamiento: los cuatro
XCUITest del registro del ticket y N=25 arranques instrumentados antes/después por seam.

**D6 · Ticket y tablero** → Sin QA manual de iPhone: el arreglo se prueba entero en simulador. Ticket a `done`, card a
done. B y C no se tocan salvo que A no baste.

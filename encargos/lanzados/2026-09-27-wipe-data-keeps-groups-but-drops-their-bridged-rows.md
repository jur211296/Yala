# «Vaciar datos» conserva los grupos pero se lleva sus gastos y liquidaciones de lo personal

## Contexto
Tras el merge de #282 (activation-start-fresh-drops-group-settlement-legs), la review dejó este medium en backlog: `wipe-data-keeps-groups-but-drops-their-bridged-rows`. En Ajustes, «Vaciar datos» borra TransactionItem sin predicado (también las filas puenteadas) y conserva el dominio de Grupos, pero no pide `GroupsBridgeRestoreConvergenceStore.markPending()` ni `markSettlementLegsPending()`. Resultado: grupos y saldos siguen, pero gastos y liquidaciones de grupo desaparecen de Registros/Panel/Inbox hasta que alguien edite después.

Cola A real-risk (pérdida silenciosa de filas puenteadas). Serial A: una sola sesión Yala a la vez. Device-QA pendiente de otros tickets no frena este código.

## Decisión de producto (ya tomada — no preguntes)
«Vaciar datos» que conserva grupos = «borrar mi vida personal y volver a empezarla» con los grupos intactos. Misma receta que los borrados de iCloud que conservan grupos (#282 / aviso tardío): tras el wipe, marcar convergencia de bridge + patas de liquidación para que lo personal vuelva a reflejar gastos y liquidaciones de grupo una vez cada uno, sin duplicados. No dejes lo personal sin rastro de los grupos.

## Que se pide
Cierra el ticket `tickets/backlog/wipe-data-keeps-groups-but-drops-their-bridged-rows.md`:
1. Tras `DataWipeService.wipeAllUserData` / `UserDataResetView.handleWipeAllData` cuando se conservan grupos, arma la misma convergencia que #282 (`markPending` + `markSettlementLegsPending` o el API vigente equivalente).
2. Cubre el libro detach (`GroupsDetachedBridgeLedger`) si el wipe masivo deja entradas huérfanas que bloquean el re-puenteo — alinear con el hueco descrito en `groups-detach-ledger-has-no-exit` solo en lo que este wipe toca; no abras ese ticket entero salvo que quede inseparable.
3. Tests (unit + mutantes según norma del repo) que fallen sin el arreglo.
4. Gate + review adversarial; PR a `2.1`; merge; ticket a `qa` o `done` según norma; actualizar `docs/TICKETS.md` e índice.
5. Cierra con `/cerrar-total` (worktree propio).

## MODO AUTÓNOMO (override Jürgen 2026-09-22)
La regla del repo «espera aprobación si >3 archivos» / «¿Sigo?» tras el plan queda suspendida en este encargo. Implementa de punta a punta hasta gate/PR/merge/`/cerrar-total` sin pedir permiso para continuar. Solo usa AskUserQuestion de día (06:00–21:00 Lima) si hace falta acceso/secreto/dispositivo de Jürgen o una decisión demasiado grave para asumir — la de producto de arriba ya está tomada.

## Que NO hay que tocar
- marketing/
- clinicas-dentales-bi / datos de salud
- Cola B UI/UX redesign
- prod Supabase; solo local/staging si toca nube
- No relances otros encargos; no abras tickets Cola C

## Como se sabe que esta bien
- Tras «Vaciar datos» con grupos conservados, lo personal refleja gastos y liquidaciones de grupo según la decisión (vuelven una vez, Inbox pregunta cuenta si aplica), sin duplicados.
- Gate verde; mutantes; PR mergeado a 2.1; ticket movido; `docs/TICKETS.md` al día; `/cerrar-total` hecho.

## Paso 0 (Frank, 2026-09-27 — auto-contestado, MODO AUTÓNOMO)

1. **Dónde se arma la convergencia.** En una función nueva, `DataWipeService.wipePersonalDataKeepingGroups`, que es
   «Vaciar datos» entero: el borrado y, solo si terminó, `markSettlementLegsPending()` y luego `markPending()` (el
   orden de #282). `UserDataResetView` la llama en vez de `wipeAllUserData`. Así el arreglo se prueba con el bridge
   real y no solo con un escaneo del fuente de una vista.
2. **En los dos aterrizajes** (sesión privada → onboarding personal; solo-grupos → shell de grupos). La convergencia ya
   espera a la sesión privada por su propio guard, así que en solo-grupos queda dormida hasta la activación.
3. **Cuándo vuelve lo personal:** en el arranque siguiente, por `AppBootstrapper.retryPendingBridges` —el mismo momento
   que #282—. No se converge en el mismo proceso: la precondición de la convergencia es la quiescencia del import.
4. **El borrado reactivo del otro dispositivo NO arma nada** (asumido). La señal solo sale en modo iCloud, así que las
   filas que el dispositivo de origen repone llegan por el espejo; armar en los dos puentearía dos veces.
5. **El libro de conservados (`GroupsDetachedBridgeLedger`) se retira dentro de `wipeAllUserData`, en los dos alcances.**
   Afirma «este gasto ya está en el Panel», y el borrado se lleva ese movimiento: sin retirarlo, la convergencia daría
   esos gastos por atendidos sin crear nada. Cubre de paso los dos borrados de #282, como pide su ticket. **No** va a
   `removeRowDerivedKeys`: esa lista la usa también el cierre de sesión en la nube, donde las filas vuelven del backend
   y retirar el libro las duplicaría. El resto de `groups-detach-ledger-has-no-exit` (borrado a mano, edición remota) no
   se toca.
6. Tests: comportamiento contra el bridge real (gasto + liquidaciones vuelven una vez tras «Vaciar datos»; un gasto
   conservado en el libro vuelve), cableado de la vista, y mutantes sobre las tres piezas.

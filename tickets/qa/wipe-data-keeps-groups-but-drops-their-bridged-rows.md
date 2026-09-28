---
id: wipe-data-keeps-groups-but-drops-their-bridged-rows
status: qa
priority: medium
area: "groups, settings"
created: 2026-09-27
updated: 2026-09-27
qa-status: needs-testing
source: "review adversarial de `activation-start-fresh-drops-group-settlement-legs` (2026-09-27, lente de reglas); inferido por lectura, NO reproducido"
---

# «Vaciar datos» conserva los grupos pero se lleva sus gastos y liquidaciones de lo personal

## El síntoma, en lenguaje de usuario

En Ajustes vacío mis datos. Mis grupos y sus saldos siguen ahí, pero cuando vuelvo a empezar mis cuentas personales, los
gastos y las liquidaciones de grupo ya no aparecen en Registros, en el Panel ni en el Inbox. Solo vuelven los que alguien
edite después.

## Lo medido (2026-09-27, leyendo código)

- `UserDataResetView.handleWipeAllData` llama a `DataWipeService.wipeAllUserData`, que borra `TransactionItem` sin
  predicado: también las filas puenteadas (`splitExpenseID`, `splitSettlementID`). El dominio de Grupos se conserva por
  diseño.
- Después solo aplica el aterrizaje (`applyWipeLanding`). No pide `GroupsBridgeRestoreConvergenceStore.markPending()`
  ni `markSettlementLegsPending()`, que es lo que piden desde el 2026-09-27 los dos borrados de iCloud que conservan
  grupos (ticket `activation-start-fresh-drops-group-settlement-legs`).

## Qué hay que decidir

Si «Vaciar datos» es «borrar mi vida personal y volver a empezarla» (los gastos de grupo vuelven a lo personal, con la
misma receta) o si debe dejar lo personal sin rastro de los grupos. El copy de la pantalla decide cuál es la promesa.

## Criterios de aceptación

- [x] Tras «Vaciar datos» con grupos conservados, lo personal refleja los gastos y liquidaciones de grupo según la
      decisión de arriba, sin duplicados.

## Relacionados

- [[activation-start-fresh-drops-group-settlement-legs]]

## Decisión (Jürgen, 2026-09-27, en el encargo)

«Vaciar datos» que conserva los grupos es «borrar mi vida personal y volver a empezarla» con los grupos intactos: los
gastos y las liquidaciones de grupo vuelven a lo personal una vez cada uno, con la misma receta que los dos borrados de
iCloud que conservan grupos.

## Qué cambia para el usuario

Quien vacía sus datos en Ajustes y conserva sus grupos vuelve a ver, desde el siguiente arranque de la app, los gastos y
las liquidaciones confirmadas de sus grupos en Registros, el Panel y la cuenta de grupos. El Inbox le pregunta de qué
cuenta salió cada gasto que pagó y a qué cuenta llegó cada pago que recibió. Nada sale dos veces. Los grupos que ya había
borrado no dejan rastro.

## Qué se hizo

- `DataWipeService.wipePersonalDataKeepingGroups`: es «Vaciar datos» entero. Pide la convergencia del bridge y la de las
  liquidaciones (`markSettlementLegsPending()` y luego `markPending()`) y después borra. **Antes, no después**: el
  borrado guarda por pasos, y uno que lanza —o un kill— tras borrar las transacciones dejaba los gastos de grupo fuera sin
  nadie que los pidiera. Pedir de más es inocuo: la convergencia es idempotente sobre filas intactas. `UserDataResetView`
  borra por ahí.
- Vale en los dos aterrizajes. Con sesión privada, las filas vuelven en el siguiente arranque en frío. En solo-grupos la
  petición espera a que la persona active Yala completo.
- `wipeAllUserData` retira en cualquier alcance el libro de conservados al desasociar (`GroupsDetachedBridgeLedger`): se
  lleva los movimientos que ese libro afirma, y sin retirarlo la convergencia daba esos gastos por atendidos sin crear
  nada. Cubre también los dos borrados de iCloud de #282. No va en `removeRowDerivedKeys`, que también corre en el borrado
  del arranque tras cerrar sesión.
- La convergencia salta las liquidaciones de un grupo oculto (borrado o retirado). Hallazgo de la review, que vale
  también para los borrados de #282: `bridgeSettlement` no mira el grupo oculto, y re-puentearla dejaba la pata de la
  liquidación sin la del gasto que la compensaba, o sea una deuda fantasma.
- El borrado reactivo del otro dispositivo (`performLocalWipeForRemoteSync`) no pedía nada: la señal solo sale en modo
  iCloud y las filas que repone el dispositivo de origen le llegan por el espejo. **Superado el 2026-09-27**: eso solo
  valía si el receptor procesaba la señal antes de que el origen convergiera; ahora también pide la convergencia (ticket
  `late-remote-wipe-signal-undoes-the-rows-the-origin-reconverged`).

## Verificado

- Unit contra el bridge real y el `wipeAllUserData` real (`GroupsBridgeRestoreConvergenceBehaviourTests`): gastos y
  liquidaciones vuelven una vez y otra convergencia no duplica; lo que el libro daba por puesto vuelve; la liquidación de
  un grupo borrado no vuelve; el borrado sin reset de preferencias también retira el libro. Cableado de la vista y del
  orden (`SignOutRowIdentifiersTests.userDataReset_asksTheGroupRowsBack`) y el barrido de claves que no toca el libro
  (`GroupsDetachedBridgeLedgerTests.rowDerivedSweep_keepsTheLedger`).
- Mutantes: ver el PR.
- Review adversarial de tres lentes (dinero, momento, reglas). Arreglado dentro: la deuda fantasma de los grupos ocultos,
  el orden de las peticiones, la regla de área que quedaba falsa, el motivo del libro mal escrito, un control que no podía
  fallar y el alcance del libro sin probar. Fuera, con ticket: ver «Relacionados».

## Guion de QA en iPhone (opcional; no bloquea)

Hace falta una sesión privada con al menos un grupo con un gasto que pagaste tú y una liquidación confirmada que te
pagaron.

1. Abre Registros y apunta los gastos y cobros de grupo que ves.
2. Ve a Perfil → Ajustes → «Vaciar datos» y confirma las dos veces.
3. Termina el onboarding personal (crea una cuenta).
4. Cierra Yala del todo (desliza hacia arriba en el selector de apps) y vuelve a abrirla.
5. **Comprueba:** en Registros vuelven los gastos y cobros de grupo del paso 1, una sola vez; en el Inbox hay un borrador
   por cada gasto que pagaste y por cada pago que te hicieron, pidiendo la cuenta; en Grupos los saldos siguen igual.
6. Cierra y abre Yala otra vez: nada se duplica.

## Relacionados (hallazgos de la review, fuera de alcance)

- [[wipe-data-group-rows-return-only-on-the-next-cold-launch]]
- [[late-remote-wipe-signal-undoes-the-rows-the-origin-reconverged]]
- [[dormant-convergence-request-from-a-groups-only-wipe]]
- [[a-wipe-that-throws-between-drafts-and-transactions-loses-settlement-drafts]]
- [[activation-discard-loses-the-group-history-question]] (nota añadida: el mismo hueco tras «Vaciar datos» en solo-grupos)

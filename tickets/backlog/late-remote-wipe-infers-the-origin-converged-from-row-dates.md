---
id: late-remote-wipe-infers-the-origin-converged-from-row-dates
status: backlog
priority: low
area: "groups, sync"
created: 2026-09-27
source: "re-review adversarial de `late-remote-wipe-signal-undoes-the-rows-the-origin-reconverged` (2026-09-27); inferido por lectura, NO reproducido"
---

# El receptor del vaciado deduce que el origen ya repuso por la fecha de las filas, y a veces no es así

## El síntoma, en lenguaje de usuario

Vacío mis datos en el iPhone y no lo cierro. Alguien añade un gasto al grupo. Luego abro el iPad, que se vacía. En los
días siguientes, si los dos convergen casi a la vez, algunos gastos de grupo salen dos veces, con dos borradores en el
Inbox.

## Lo medido (2026-09-27)

- `DataWipeService.wipeLocallyForRemoteWipeSignal` pide la convergencia si alguna `TransactionItem` puenteada es
  posterior a la señal. Casi siempre es la reposición del origen, pero también la crea el sync de grupos: cada re-puente
  borra y recrea las virtuales (`GroupTransactionBridge.bridgeExpense`), con `createdAt = now`.
- Si el origen aún no convergió (sigue vivo sin arranque en frío), quedan dos peticiones. Duplican solo si las dos
  convergencias se cruzan antes que el espejo; `retryPendingBridges` espera al import quieto, así que suele no pasar.
- Hueco vecino: si al receptor le llegan los borradores repuestos antes que sus transacciones, no pide y los borra en todo
  el parque (sin duplicado, pero se pierde la pregunta «¿de qué cuenta salió?»).

## Qué hay que decidir

Si vale una prueba positiva en el iCloud-KV: el origen escribe «convergí para el vaciado T» al retirar su petición, y el
receptor pide solo con ese sello y filas posteriores. Su coste: si el KV llega más tarde que el espejo, el receptor no
pide y vuelve la pérdida del ticket padre.

## Relacionados

- [[late-remote-wipe-signal-undoes-the-rows-the-origin-reconverged]]

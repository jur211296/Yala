---
id: groups-detach-ledger-has-no-exit
status: backlog
priority: medium
area: "groups, modo-nube"
created: 2026-09-11
source: "review adversarial del paso 10 (`groups-account-association-in-storage-row`), lente de sync"
---

# El libro de gastos conservados al desasociar no tiene salida: puede dejar un gasto sin movimiento personal para siempre

## El problema, en lenguaje de usuario

Solté mi cuenta de grupos y elegí conservar los gastos que había pagado. Más tarde volví a asociar la
misma cuenta. Como esos gastos ya estaban en mi Panel, la app no los vuelve a crear — eso es lo correcto
y es lo que evita verlos dos veces. Pero si **borro a mano** uno de esos movimientos, el gasto del grupo
se queda sin ninguna transacción en mi Panel, y ya no hay forma de recuperarla.

## Lo medido (2026-09-11)

`GroupsDetachedBridgeLedger` guarda, sellados con el `sub` de la cuenta, los gastos y liquidaciones cuyo
movimiento personal se conservó. `GroupTransactionBridge.bridgeExpense`/`bridgeSettlement` consultan ese
libro y devuelven `true` (atendido) sin crear nada.

- El `true` es correcto respecto a `GroupsPendingBridgeIntent` (un `false` lo dejaría reintentándose
  hasta agotar los 3 intentos y luego lo descartaría), así que el problema **no** es el veredicto.
- Lo que falta es la salida: el libro no tiene TTL a propósito, no hay UI que lo limpie, y sus dos únicos
  borradores son un desasociar con «Quitar» o el «empiezo de cero».
- `GroupsBridgeRestoreConvergence` tampoco lo cura: pasa por `bridgeRemoteExpenses`, o sea por el mismo
  guard, y además cuenta el gasto como atendido.
- Mismo efecto si el `SplitExpense` cambia en el backend: la actualización vuelve a pasar por el guard.

## Lo que se espera

Que borrar el movimiento conservado retire su entrada del libro — el sitio natural es el mismo camino que
borra la `TransactionItem`— o que una edición remota del gasto la retire. Cualquiera de las dos devuelve
el gasto al circuito normal del puente.

## Cómo se prueba

Unit sobre el libro + el bridge con un contexto real: conservar, re-asociar, borrar la transacción, y
exigir que el puente vuelva a crearla en el ciclo siguiente.

## Otro camino al mismo hueco (2026-09-27)

Lo encontró la review de `activation-start-fresh-drops-group-settlement-legs`: un borrado de filas que conserva los grupos
(«Restaurar → Empezar desde cero» de la activación, el aviso tardío de iCloud) también se lleva el movimiento conservado,
y el libro sigue ahí. Cuando la convergencia re-puentea gastos y liquidaciones, el guard los da por atendidos sin crear
nada. Es el «borro a mano» de arriba, pero en masa. El arreglo que se elija aquí tiene que cubrir también ese borrado.

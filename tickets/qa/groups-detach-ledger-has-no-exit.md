---
id: groups-detach-ledger-has-no-exit
status: qa
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

## El borrado masivo, cerrado (2026-09-27)

`wipe-data-keeps-groups-but-drops-their-bridged-rows` hace que `DataWipeService.wipeAllUserData` retire el libro en
cualquier alcance: «Vaciar datos» y los dos borrados de iCloud que conservan grupos. Queda abierto lo de arriba: el
movimiento conservado que se borra a mano y la edición remota del gasto.

## Cerrado en código (2026-10-01)

**Qué cambia para quien usa la app.** Si borras uno de los movimientos que conservaste al soltar tu cuenta de grupos, el
gasto vuelve a su circuito normal: aparece de nuevo en el Inbox (o como movimiento, según el caso) la próxima vez que se
abra la app o que alguien edite ese gasto en el grupo. Mientras el movimiento conservado sigue en tu Panel, nada cambia:
no se duplica, tampoco si otra persona edita el gasto.

**Cómo.** El libro guarda la identidad y la huella de cada transacción que conservó. El puente pregunta si sigue ahí antes
de darla por atendida, y el arranque revisa el libro entero y pide a la intención durable del puente lo que ya no está.
Lo que no se puede afirmar (libros anteriores, borradores conservados, un store recreado) sigue frenando como antes.

**Probado.** `YalaTests/GroupsDetachedLedgerExitTests`: 18 casos contra el bridge real, con tres stores en disco, más un
source-scan del cableado del arranque.
- Vuelven: el gasto y la liquidación borrados a mano.
- El arranque recupera lo que nadie edita y no toca lo que sigue en el Panel.
- Con el movimiento vivo no hay duplicado, tampoco con una edición remota.
- Siguen frenando: gemelos del mismo día, re-importación con otra identidad, movimiento editado, store recreado (con
  re-anclaje), store vacío, desasociar a medias, libro antiguo y borrador conservado (solo, o junto a una transacción).
- Además: nota nula en la huella, y movimientos ilegibles que no tiran el libro.

Mutantes: 14, y los 14 mueren. El M01 es el código de antes, es decir, el hueco del ticket medido.

**Residuales con ticket:** `groups-detach-ledger-cannot-verify-conserved-drafts` y `detach-second-pass-replaces-the-conserved-ledger` (preexistente).

### Guion de device-QA (iPhone, cuenta real de grupos; no bloquea el merge)

1. En un iPhone con sesión privada y la cuenta de grupos asociada, entra en un grupo y registra un gasto que pagaste tú,
   eligiendo una cuenta real (Efectivo, por ejemplo).
2. Perfil → «Dónde viven tus datos» → sección **Grupos** → **Desasociar** → elige **«Conservar los gastos que pagué»**.
3. En esa misma sección, **«Asociar una cuenta para grupos»** con **la misma** cuenta. Comprueba en Registros que el gasto aparece **una sola vez**.
4. Borra ese movimiento desde Registros (deslizar → Eliminar).
5. Cierra la app del todo (deslizar en el selector de apps) y ábrela otra vez.
6. **PASS:** el gasto del grupo vuelve a pedir su movimiento personal (borrador en el Inbox o movimiento en Registros).
   **FAIL:** no vuelve nada.

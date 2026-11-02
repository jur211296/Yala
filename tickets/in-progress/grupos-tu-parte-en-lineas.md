---
id: grupos-tu-parte-en-lineas
status: in-progress
priority: high
area: "grupos, puente, estadísticas, sync personal"
created: 2026-11-01
updated: 2026-11-01
source: "sesión grupos-opcion-b-version-final; versión final en docs/disenos/grupos-tu-parte-en-lineas/README.md"
---

# Tu parte de un gasto de grupo, en líneas: diseño técnico del puente

Qué quiere Jürgen está en `docs/disenos/grupos-tu-parte-en-lineas/README.md`, sección «Versión final acordada», con las
maquetas en `opcion-b.html`. Aquí está **cómo** el puente convierte las líneas en registros, para que la card 2 del
tablero («El puente crea tus registros desde las líneas») arranque sin decisiones abiertas. Las ventas por cobrar
(cards 7-11) no entran aquí: llevan su propio `/spec` cuando se lancen.

**Hecho en la sesión del 1-nov:** las reglas de la receta, `Yala/App/Logic/GroupSplitLinesRecipe.swift` (formato,
lectura, si cuadra, qué línea está mal), con `YalaTests/Groups/GroupSplitLinesRecipeTests.swift`. Nadie la llama todavía.

## Lo medido en el árbol de hoy (2.2 tras #731)

- `GroupTransactionBridge.bridgeExpense` agrupa por `splitExpenseID` (272 referencias en ~45 ficheros de `Yala/`). Una
  pata con cuenta real es «la pata real»; una con cuenta de sistema, «virtual».
- `BridgeBranchLogic.partitionVirtualTxs` conserva **una** virtual clasificable (subcategoría `nil` o de usuario) y
  borra el resto. Una segunda pata virtual con categoría de usuario se borraría en la pasada siguiente.
- Caso A (pagaste tú, puente activo): pata real `−total` en tu cuenta (se conserva entre pasadas, con tu categoría) y
  virtual `+lent` «Préstamo a grupos» en «Grupos». Caso B (pagó otro): virtual `−myShare` en «Grupos».
- `GroupBridgeStatsAdjustment` netea `real.first + Σ(virtuales de sistema con importe > 0)` y suprime esas virtuales.
  Las virtuales con importe ≤ 0 cuentan tal cual. Estadísticas ya excluye todo `balanceAdjustmentType != nil`.
- `unbridgeExpense` y `unbridgeDeletedRemotely` borran todo lo que lleva el `splitExpenseID` del gasto.

## Decisiones

**D1 · Toda línea que no es la pata conservada pasa por «Grupos».** Las patas derivadas se apuntan en la cuenta de
sistema «Grupos» del gasto, nunca en la cuenta real con que pagaste. Por qué: la pata real refleja tu banco (`−200` en
BCP es lo que verás en el extracto) y es la que el usuario edita. Partirla en varias reales rompe el «una sola pata
real» del que dependen `GroupLegKindLogic`, `provesRealLeg`, `deleteStaleReal` y el ajuste de Estadísticas.

**D2 · Qué pata lleva la receta.** La que el puente ya conserva: la real en el Caso A con puente activo, la virtual
clasificable en el Caso B. La receta vive en su `splitLinesRaw` (card 1). Las derivadas llevan la **marca**
(`encodeDerivedMarker`) y `partitionVirtualTxs` las trata como derivadas: no son candidatas a conservar y se recrean en
cada pasada a partir de la receta.

**D3 · Las patas, caso por caso.** `L1` es la primera línea; `Σresto`, la suma del resto.

*Caso B (pagó otro). Pía, 510, todo tuyo: recarga 500 a Sip + Comisiones 10.*

| Pata | Cuenta | Importe | Qué lleva |
|---|---|---|---|
| Conservada = línea 1 | Grupos | `−L1` | receta; si L1 es gasto, su categoría; si es recarga, `balanceAdjustmentType = transfer` y su par |
| Cada gasto extra | Grupos | `−x` | categoría de la línea + marca |
| Cada recarga extra, salida | Grupos | `−x` | `transfer`, `transferPairID`, marca |
| Cada recarga, entrada | cuenta destino (Sip) | `+x` | `transfer`, mismo `transferPairID`, marca, **sin `splitExpenseID`** |

Resultado: Grupos `−510` (lo que debes a Pía), Sip `+500`, Estadísticas 10 de Comisiones. El ajuste no cambia: no hay
pata real y las virtuales son ≤ 0.

*Caso A (pagaste tú, puente activo). Súper 200 desde BCP, mitad con Pía; tu parte 100 = Supermercado 80 + Hogar 20.*

| Pata | Cuenta | Importe | Qué lleva |
|---|---|---|---|
| Real (conservada) | BCP | `−total` (−200) | receta; categoría de la primera línea de GASTO |
| Préstamo | Grupos | `+(lent + Σresto)` (+120) | «Préstamo a grupos», como hoy |
| Gasto extra | Grupos | `−20` | Hogar + marca |
| Recarga, si la hay | Grupos → destino | `−x` / `+x` | como en el Caso B |

Resultado: BCP `−200`, Grupos `+120 − 20 = +100` (Pía te debe 100), Estadísticas `−200 + 120 = −80` Supermercado y
`−20` Hogar. **`GroupBridgeStatsAdjustment` no cambia**, y es la razón de D1: el préstamo engorda en lo que las líneas
extra apuntan en «Grupos», y la pata real netea a la primera línea de gasto.

Si en el Caso A **ninguna línea es gasto** (pagaste 500 de recarga a tu Sip con BCP desde un grupo), la pata real netea
a 0: préstamo `+(lent + 500)`, salida `Grupos −500`, entrada `Sip +500`. BCP `−500`, Sip `+500`, Estadísticas 0.

**D4 · El lado de destino de una recarga no lleva `splitExpenseID`.** Se enlaza por `transferPairID` con su salida en
«Grupos», que sí lo lleva. Por qué: con `splitExpenseID`, la entrada en Sip sería una «pata real» más para los ~45
consumidores (`existingRealTx`, `deleteStaleReal`, `provesRealLeg`, el barredor de huérfanas, desasociar), y el Caso B
la borraría por `deleteStaleReal`. Precio: los tres borrados del gasto (`unbridgeExpense`, `unbridgeDeletedRemotely` y
el congelado al salir del grupo) tienen que buscar también las entradas por el `transferPairID` de las salidas que
borran. Al congelar un grupo, el par se queda como una transferencia normal.

**D5 · Puente apagado y sesión solo-grupos: la receta no se aplica.** Esos caminos dejan tu parte en una línea, como
hoy, y conservan la receta en la pata para cuando el puente vuelva. Las pantallas no ofrecen «Partir» ahí.

**D6 · Cuando la receta no cuadra con tu parte** (el gasto cambió de monto o de reparto): el puente aplica tu parte en
una línea, como hoy, conserva la receta y crea un borrador en la Bandeja con las líneas y lo que falta. Igual que el
borrador de hoy por cambio de moneda. Aprobar reescribe la receta. Nunca reparte la diferencia por su cuenta.

**D7 · Receta ilegible o de versión posterior** (`.unreadable` / `.newerVersion`): se trata como «sin receta» para
crear las patas y **no se borra ni se reescribe**. Un aparato más nuevo la rehace en su pasada.

**D8 · Las patas derivadas no se editan como registros sueltos.** `BridgedEditPolicy` las trata como del puente:
editar una abre «Partir tu parte». Borrar una recarga a mano la recrea la pasada siguiente.

## Lo que la card 2 tiene que medir antes de escribir

1. **Los consumidores de `splitExpenseID` que leen «virtual = una sola»** frente a varias patas en «Grupos» con
   categoría de usuario: el contador del aviso «Movimientos sin cuenta», `GroupDraftFinalizationLogic`,
   `GroupsAssociationDetach`, `OrphanedBridgedTxSweeper`, `GroupBridgeRaceCleaner`, `BridgedTransactionFilter`,
   `RecordRowView` y `TransactionDetailSheet`. La lista sale de `grep -rln splitExpenseID Yala`.
2. **Las transferencias con `splitExpenseID`** en la salida por «Grupos»: qué hacen hoy Registros, el detalle y el
   menú contextual con una transferencia que también es de grupo.
3. **El orden de una pasada:** partición, borrado de derivadas viejas, derivación nueva y guardado, todo en el mismo
   `save()`. Si no, el drain verá un instante sin la recarga.
4. **El mismo cambio en el port `mcp/src/logic/groups.ts`** solo si el ajuste cambia. Por D3 no debería; la card 3
   lo comprueba con tests del caso Pía y del súper.

## Card 1 hecha (2026-11-01): el campo viaja

`TransactionItem.splitLinesRaw` existe y viaja por iCloud (`CD_splitLinesRaw`, los cuatro `.ckdb`; el deploy a
Production lo hace Jürgen, `docs/despliegue-cloudkit-2-2.md`) y por el Modo Nube (`tx_items.split_lines_raw`, v6,
`g28_01` aplicada en staging y producción, Worker v6 en los dos). Nada lo escribe todavía.

**Lo que la review de la card 1 dejó para la card 2** (medido en el árbol del 1-nov, sin arreglar porque es de la card 2):

5. **`partitionVirtualTxs` se come las derivadas de gasto**: una pata derivada lleva subcategoría de usuario y cuenta como
   clasificable (`GroupTransactionBridge.swift` ~316-329, `BridgeBranchLogic.swift` ~112), así que se conserva una y se
   borran las demás. `hasUserMetadata` no mira `splitLinesRaw`: la pata con la receta puede perder contra otra con tags
   o más antigua. Es el D2 de arriba, ahora con coordenadas.
6. **`existingRealTx = first { !isSystemAccount }`** (~295): una recarga derivada con `splitExpenseID` saldría elegida
   como «la real» y `deleteStaleReal` la borraría. D4 lo evita quitándole el `splitExpenseID` a la entrada; si la card 2
   cambia D4, esto vuelve.
7. **Soltar punteros no limpia la receta**: `OrphanedBridgedTxSweeper.swift` ~331-334 y `LegacyGroupsRetirement.swift`
   ~267-270 vacían los tres punteros y dejan `splitLinesRaw` (o la marca `{"of":…}`) en un movimiento que vuelve a ser
   personal. Y si `.deleteVirtual` borra la pata con la receta, las derivadas quedan huérfanas.
8. **Cambio de divisa de una cuenta**: hoy lo bloquea cualquier fila con `splitExpenseID` (`AccountFormViewModel.swift`
   ~694-704). La entrada de una recarga no lo lleva (D4): `convertHistory` le cambiaría el importe y la receta, en la
   divisa vieja, dejaría de cuadrar.
9. **Un aparato con una build anterior a la card 2** —2.1, o una build con la card 1 sin la 2— corre el puente viejo y deja
   tu parte en una sola pata (ya aceptado en «Compatibilidad» del diseño). Por eso la card 1 no sube sola a TestFlight
   con algo que escriba la receta: no hay nada que la escriba hasta la card 2.

## Fuera de este diseño

- Ventas por cobrar (cards 7-11): otro `/spec`.
- La UI (cards 4-6).

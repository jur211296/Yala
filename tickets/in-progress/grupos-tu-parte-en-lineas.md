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

## Cards 2 y 3 hechas (2026-11-01): el puente aplica la receta y la recarga no cuenta

Encargo `2026-11-01-grupos-b-puente-y-estadisticas` (decisiones en su Paso 0). Lo que cambió respecto al diseño de arriba:

- **La ancla es la primera línea de GASTO** (o la primera si no hay ninguna, solo en el Caso B): la pata que el usuario
  clasifica sigue siendo un gasto siempre que haya uno. Mismas cifras en Pía y en el súper.
- **Las derivadas se actualizan en sitio**, no se rehacen en cada pasada; el `transferPairID` de una recarga es el id de su
  línea (determinista entre aparatos) y la entrada lleva la marca, así que se encuentra aunque llegue antes que su salida.
- **El aviso de «no cuadra» (D6)** es un `.groupExpense` con motivo `splitLinesMismatch` que pide la categoría y no se
  aprueba deslizando. Aprobarlo deja tu parte en una línea y retira la receta; «Partir» desde esa hoja es la card 5.
- **Los consumidores que borraban o soltaban patas** se midieron (lista del punto 1) y quedaron así: `CloudSyncReconciler`
  ya no poda las derivadas (las borraba en cada pull con pata real), `TransferPairReconcileService` no toca los pares del
  puente, los tres barridos y el congelado se llevan o sueltan la entrada con su pata, el borrado de cuenta la bloquea
  como de grupo, y el menú, el lote y el editor la tratan como del puente. El cambio de divisa ya la bloqueaba (es una
  transferencia). El desglose «Tu parte» del detalle suma las líneas.
- **Card 3:** `GroupBridgeStatsAdjustment` y `mcp/src/logic/groups.ts` dejan las patas de transferencia fuera del neteo.
  Con D1 la fórmula ya daba 80 + 20 y 10; el cambio es la defensa para una entrada que llegue con puntero.
  `FullFinancialContextBuilder` ya filtraba transferencias antes del ajuste: sin cambio.

**Residuales aceptados:** un cambio de pagador (A ↔ B) o de divisa del gasto pierde la receta con la pata que la llevaba;
editar la categoría de la pata conservada con receta se pisa en la pasada siguiente (la card 6 lo lleva a «Partir»); con
«Incluir grupos» apagado en Registros se ve la entrada de la recarga sin su salida (no cambia cifras).

## Cards 7 y 8 hechas (2026-11-02): categorías de ingreso y la venta por cobrar

Encargo `2026-11-02-grupos-b-ventas-por-cobrar` (decisiones en su Paso 0).

- **Formulario (card 7).** El selector de categoría del gasto de grupo enseña «Gasto | Ingreso» (solo desde ese formulario)
  y abre en el tipo de lo elegido. Pagando tú con una de ingreso es una venta (`GroupExpenseViewModel.isSale`): no se pide
  cuenta, no se pasa al guardar, no sale el «¿Lo registramos?» del puente apagado y la frase de abajo dice «Ana te debe
  S/ X. Cuenta como ingreso cuando te pague.» (o «Te deben…» con varios), también al editar. Con una de gasto, el
  formulario es el de antes píxel a píxel (salvo el reloj).
- **Puente (card 8).** `GroupTransactionBridge.bridgeSale`: sin pata real (también se va la del «Sí, registrar» con el
  puente apagado, y su borrador pendiente), sin préstamo ni líneas, una sola pata en «Grupos» por `total − tu parte` con
  la subcategoría de ingreso y `balanceAdjustmentType = "receivable"`. Se reutiliza entre pasadas. En el Caso B una
  categoría de ingreso no clasifica tu parte (`GroupSaleBridgeLogic.classifiesShare`). El editor, el lote y el menú la
  tratan como pata derivada (`GroupSaleBridgeLogic.isReceivable`).
- **Registros.** La fila dice «Ventas • Por cobrar • Grupos» en gris.
- **Consumidores medidos:** 52 `== nil` y 17 `!= nil` de `balanceAdjustmentType`; solo la reversión de la pata conservada
  leía `!= nil` como «recarga» (`GroupSaleBridgeLogic.revertsKeptLeg`).

**Para las cards 9-11:** lo cobrado se calcula sobre las patas `receivable` (el pago aún no las toca: hoy Ana paga, Yape
+120 y Grupos −120, y la venta sigue por cobrar sin contar como ingreso). El conector `mcp/` las lista como
`ajuste_de_saldo`. **Residuales con card:** la categoría viaja por NOMBRE y puede casar con una de gasto homónima
(`10u2`); el detalle, el widget de inicio, la ficha de la cuenta y la pantalla de éxito aún no dicen «por cobrar»
(`00xj`). **Versión mínima:** un aparato con 2.1 —también el de OTRO miembro— casa la categoría de ingreso por nombre y
cuenta su parte como ingreso negativo; se corta con la subida de versión mínima al publicar 2.2.

## Cards 5 y 6 hechas (2026-11-02): «Partir» en la Bandeja, la pantalla de éxito y el detalle

Encargo `2026-11-02-grupos-b-partir-en-pantallas` (decisiones en su Paso 0).

- **Bandeja (card 5).** Pastilla «Partir» junto a la de categoría en las tres hojas de gasto de grupo (pagó otro, el aviso
  de «no cuadra» y las dos que piden cuenta). Al tocarla, la tarjeta «Tu parte» ocupa su sitio y «Aprobar» espera a que
  cuadre; sin tocarla, la hoja aprueba como antes. Con varias líneas, `DraftService.approveDraft(splitLines:)` escribe la
  receta en la pata que el puente conserva y lo pasa; una sola línea de gasto se aprueba como siempre, con su categoría.
  El aviso de «no cuadra» abre con la receta que había y, aprobado con «Partir», la reescribe (sin «Partir» sigue como lo
  dejó el #737: una línea y fuera la receta, pendiente de Jürgen).
- **Pantalla de éxito y detalle (card 6).** «Partir tu parte» en el bloque de qué apuntó Yala y como fila del detalle de
  cualquier pata del gasto; abre la hoja «Tu parte» (`GroupSplitLinesSheet`) y guarda con `GroupSplitLinesService.save`.
  Volver a una sola línea retira la receta, las patas derivadas y la recarga, y deja tu parte clasificada.
- **Puerta** (`GroupSplitLinesEntryLogic`): puente activo, sesión privada, fuera de la shell solo-grupos, parte > 0, no
  saldo inicial y **no venta** (cards 7 y 8: sin pata real, el puente no aplica la receta).
- **En las hojas que piden cuenta**, la cuenta se puede cambiar después de partir: «Aprobar» no se enciende si una
  recarga va a la cuenta elegida (`GroupDraftSplitState.rechargesToItsOwnSource`).
- **Residual:** el editor de la pata con receta sigue como lo dejó el #737.

## Cards 9, 10 y 11 hechas (2026-11-02): lo cobrado cuenta el día del pago

Encargo `2026-11-02-grupos-b-cobros` (decisiones en su Paso 0).

- **Qué cubre una venta (card 9).** `GroupReceivableCoverageLogic`, pura: tu saldo en el grupo, en la divisa de la venta,
  lo más antiguo primero. Lo que lo sube (lo que adelantaste, tus ventas, lo que pagas tú) son lotes con fecha; lo que lo
  baja (tu parte de lo que pagó otro, lo que te pagan) consume el lote más antiguo, y si es una venta esa parte queda
  cobrada con la fecha de ese movimiento. Una venta que llega cuando ya debías se cobra en su fecha contra la deuda. Los
  cuatro casos de la página salen de ahí; en deudas cruzadas con el almuerzo después de la venta, 64 cuentan el día del
  almuerzo y 56 el del pago (asumido: la página no fecha esa fila).
- **Cómo queda en tus cuentas (card 10).** La pata por cobrar guarda solo el resto (sin resto, no hay pata). Cada parte
  cobrada es una pata de ingreso normal en «Grupos» (categoría de la venta, fecha del cobro, sin tipo) con la marca
  `{"k":"c","of":<movimiento>,"v":1}` en `splitLinesRaw` (`GroupSplitLinesRecipe.Stored.collected`). La escribe
  `GroupTransactionBridge.reconcileReceivables`, una pasada por grupo al final de cada puente de gasto o liquidación y de
  cada borrado (local y remoto), solo si el grupo tiene patas de venta. Identidad (venta, movimiento), actualización en
  sitio y superviviente determinista. La partición del puente aparta las cobradas; un gasto que deja de ser venta las
  borra. Registros dice «Cobrado»; editor, lote y menú las bloquean. La hoja de pago de la Bandeja dice qué venta cobra el
  pago («… cuentan como ingreso hoy», o con su fecha).
- **Estadísticas, Yala IA y el conector (card 11).** Lo por cobrar ya caía por su tipo. Lo cobrado es ingreso; el ajuste
  del puente y su port (`mcp/src/logic/groups.ts`, `isCollectedLeg`, columna `split_lines_raw` en la lectura de
  movimientos) lo apartan del neteo de préstamos.

**Residuales:** una build con las cards 2-8 lee la marca de cobrada como pata de línea y la borra al repasar la venta (se
corta con la versión mínima de 2.2). El pago cubre lo más antiguo también si es de otra persona del grupo: lo que cuenta
es tu saldo, como acordó Jürgen.

## Cabos sueltos de las cards 2-8 (2026-11-02)

Encargo `2026-11-02-grupos-b-cabos-sueltos` (decisiones en su Paso 0).

- **La categoría por nombre (10u2).** Una sola regla para formulario, puente y «Partir»: `GroupSubcategoryMatchLogic`
  (exacto antes que «contiene»; entre homónimas, la de usuario, la de gasto y el menor `shortcutID`), detrás de
  `GroupTransactionBridge.matchSubcategory`. El formulario se alinea con ella al cerrar el selector y al abrir una edición
  (`GroupExpenseViewModel.alignSubcategoryWithBridge`). **Un sitio nuevo que case `subcategoryName` pasa por
  `matchSubcategory`**: un fetch por nombre con `fetchLimit = 1` vuelve a dejar que formulario y puente elijan distinta.
- **Lo por cobrar fuera de Registros (00xj).** Detalle («Ingreso • Por cobrar»), widget de inicio (gris y «Por cobrar»,
  `WidgetTransaction.isReceivable` opcional en las dos copias), ficha de la cuenta y pantalla de éxito («¡Venta agregada!»).
- **La receta sobrevive al cambio de pagador (sbvw).** `GroupSplitLinesTransplantLogic`: se trasplanta cuando la pata nueva
  nace en la pasada. En el Caso B la divisa ya no cierra la puerta de la receta (la pata se rehace con ella dentro y el aviso
  de «no cuadra» sale en la misma pasada). Residual: `group-split-lines-recipe-lost-when-the-new-leg-is-not-born-in-the-pass`.
- **Editar la pata con receta (6u5f, D8).** En el editor, la categoría abre «Tu parte»; el lote y el menú no la cambian
  (`RecordContextActionLogic.Shape.holdsSplitRecipe`). Las derivadas siguen bloqueadas.
- **La entrada de una recarga (oibr).** Su grupo sale de su salida (`GroupSplitLineEntryGroupLogic`): cápsula del grupo en
  Registros y, con los grupos ocultos, se oculta con ella.

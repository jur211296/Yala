---
name: barrido-signo-chat
description: PR #103 — el barrido que cura los gastos del chat guardados sin signo, ya acotado para no tocar lo importado por CSV; falta device-QA.
metadata:
  type: project
---

**El barrido one-shot del signo del chat está hecho (PR #103) y ACOTADO para no tocar lo importado
por CSV**, que fue la decisión de Jürgen del 2026-09-08 cuando le llevé la medición.

**Why:** decidió migrar a ciegas aceptando **expresamente** que «los reembolsos legítimos de esa
ventana también se voltean». La review adversarial midió que el criterio alcanzaba además a las filas
importadas por CSV —guardan como `createdAt` el instante del import, así que un fichero con años de
historia importado en la ventana entraba entero, y el importador reusa categorías por nombre sin mirar
`isIncome`—. Eso no eran reembolsos y no estaba cubierto, así que paré y pregunté. Contestó: **acotar**.

**La señal que lo resolvió, y que este ticket daba por inexistente:** campo a campo esas filas SON
indistinguibles, pero **nacen a la vez**. El importador crea el lote sin `save()` intermedio; el chat
exige un toque humano por tarjeta (`saveDraft` tiene un único llamador, y no hay «guardar todas»). Y
el propio importador ya se reconoce así, con `importStart = Date.now` + `filter { $0.createdAt >=
importStart }`. `batchFlags` agrupa por huecos encadenados sobre **todas** las filas del store — con
solo las candidatas, un import de 500 filas con 3 positivas parecería 3 gastos sueltos.

**How to apply:** lo que queda es el **device-QA**, que es simulable —dictar un gasto, mirar el saldo
antes y después del primer arranque— y el barrido imprime en DEBUG cuántas filas curó, que es el
número que nunca se pudo medir desde aquí.

Lo que NO hay que rehacer: la trampa del ancla de sync está **medida y descartada**
(`SyncIdentity.localAnchor` se persiste una vez, nada lo recalcula al editar). Y el gate de
`!uiTestActive` **no arregla ningún rojo** —se midió: sin él el XCUITest sigue pasando—; está para que
ese verde no dependa de ganar una carrera de 120 s.

Residuales aceptados: un import de **una sola fila** no tiene vecino y es indistinguible; y las filas
cuya categoría se borró llegan sin categoría y se saltan.

Relacionado: [[chat-tasa-del-borrador]] (el PR #102 que lo engendró) y
[[el-prefiltro-tapa-al-criterio]], que salió de esta misma sesión.

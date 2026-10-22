---
name: el-orden-del-enum-se-ve-fuera
description: Añadir un case a un enum de error puede cambiar un número que el usuario ve en un alert y con el que se diagnostica — se declara al final, no junto a su hermano semántico.
metadata:
  type: feedback
---

**Al añadir un case a un enum de error en Swift, decláralo AL FINAL, no en el sitio que la lectura
pide.** Si el enum se puentea a `NSError` en algún camino, el orden de declaración deja de ser un
detalle de estilo: es el número que Foundation imprime en el alert («Error de Yala.GroupsRPCError
10») y con el que se diagnostica un reporte de device.

**Why:** el 2026-09-06 metí `groupArchived` junto a `groupDeleted` —son hermanos semánticos y ahí es
donde se lee mejor— y con eso corrí en uno los ocho casos siguientes.
`GroupsMembershipClientTests.nsErrorCode_perCase_isMeasuredNotInferred` lo cazó, y su docblock ya
contaba la historia: un reporte de device de agosto trajo un `10` que se interpretó como
`ownerCannotLeave`, y para cuando se diagnosticó ya no lo era, porque otro caso se había insertado en
medio entre tanto. Renumerar la tabla del test habría sido «arreglar el rojo» invalidando la lectura
de los reportes de todos los builds ya publicados.

Y ojo con la mecánica, que no es la intuitiva: **Swift numera primero los casos CON payload** (en su
orden de declaración) **y detrás los que no lo llevan, desde el 2**. Contar casos en el fichero da un
mapeo falso; por eso ese test mide en vez de inferir.

**How to apply:** ante un enum de error al que vas a añadir un caso, la pregunta previa es **si su
orden se observa fuera del código** (`as NSError`, un `rawValue` implícito, un índice serializado, una
columna de BD). Si se observa: al final, y un comentario en el case nuevo apuntando a su hermano
semántico. La agrupación se paga con un comentario; la numeración, con una tarde de diagnóstico.

Relacionado: [[review-adversarial-caza-lo-mio]] — otra vez un test PREEXISTENTE cazando un efecto
lateral que mi cambio introducía y que mis propios tests, todos verdes, no miraban.

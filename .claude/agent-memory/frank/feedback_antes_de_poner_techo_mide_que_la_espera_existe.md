---
name: antes-de-poner-techo-mide-que-la-espera-existe
description: Antes de acotar una espera, mide que la espera OCURRE para la población objetivo; el 16-sep puse techo y salida a una espera que para casi todos los usuarios terminaba al instante con un falso «hecho»
metadata:
  type: feedback
---

**Antes de ponerle techo o salida a una espera, comprueba con el código que esa espera se produce para la
población a la que va el arreglo.** Si el predicado que la cierra se cumple por vacío para esa gente, el techo es
inalcanzable y el bug real es otro: un falso «terminado».

**Why:** en `reverse-upload-has-no-ceiling-and-no-exit` (2026-09-16) diseñé techo, cancelación, copy y 12
mutantes sobre la espera de `reverseUpload`. La lente de reglas de la review cazó que el muestreo que decide esa
espera solo contaba filas con testigo `SyncIdentity`, y lo creado en el teléfono por una cuenta nacida en la nube
no tiene testigo: cero pares, «drenado» al instante. Tras el fresh start del 10-sep eso es casi toda la población,
así que para ella mi techo no actuaba nunca y la vuelta a iCloud se daba por hecha sin comprobar nada. Hasta el
propio ticket hermano lo había dado por bueno («para born-cloud arranca en pending(todas)»). Jürgen lo metió en el
PR (D15).

**How to apply:**
- Traza el predicado de fin de la espera con los datos de la población objetivo: de dónde salen las filas que
  cuenta, quién crea lo que empareja, qué devuelve con cero entradas. Un `pending = a + b` sobre una lista
  emparejada es sospechoso por construcción.
- «Mi arreglo es alcanzable» se mide igual que «el bug existe»: con la población concreta, no con la del ticket.
- Pregúntate qué hace el sistema si la lista de entrada llega vacía: si la respuesta es «terminado», es un gate que
  falla abierto por su entrada ([[un-gate-falla-abierto-por-su-entrada]]).

Relacionado: [[el-predicado-del-ticket-no-es-el-criterio]] · [[mi-arreglo-abre-un-camino-inalcanzable]] ·
[[la-premisa-del-encargo-tambien-se-mide]] · [[review-adversarial-caza-lo-mio]].

---
name: cerrar-un-atajo-quita-lo-que-capturaba
description: Al poner un candado a un camino que se lo saltaba, lista qué hacía ese camino ADEMÁS de lo prohibido — el ciclo del cierre era el único que drenaba el History
metadata:
  type: feedback
---

Poner un candado a un camino que se lo saltaba le quita también lo bueno que hacía ese camino. El 25-sep el push-all del
cierre corría `syncCycle` sin `canRunDomain()`. Lo cerré y el veredicto pasó a mirar solo el outbox. Pero ese ciclo era
lo único que DRENABA el History a la cola, y lo editado con el motor parado se iba con el borrado sin aviso. En
`.reverseFailedRollback` eso pueden ser días. Lo cazaron dos lentes de la review, no yo. El arreglo fue una sonda de solo
lectura del History.

**Why:** «el atajo no debería existir» es verdad, y justo por eso no me pregunté qué aportaba. Mi Paso 0 lo apuntó como
«residual asumido», y era una regresión de pérdida de datos.

**How to apply:** antes de cerrar un atajo, enumera sus efectos (drain, rastros, recuentos) y pregunta cuál era la ÚNICA
fuente de algo que el consumidor sigue necesitando. Lo que no se pueda hacer sin escribir, se LEE. Relacionado:
[[al-quitar-un-apagado-incondicional-busca-quien-lo-usaba]], [[mi-arreglo-quita-la-salida-que-habia]].

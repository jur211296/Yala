---
name: mi-arreglo-cumple-una-premisa-que-era-falsa
description: Al hacer verdad una frase que un docblock ya daba por cierta, los consumidores que dependían de que fuera FALSA cambian de comportamiento
metadata:
  type: feedback
---

Cuando un arreglo hace **cierta** una afirmación que la documentación ya daba por hecha, hay que buscar
quién estaba apoyado en que fuera **falsa**.

**Why:** el 2026-09-21, `ICloudRestoreInProgressLogic` documentaba su camino de cierre así: «el usuario
que toca atrás a mitad cancela ese `Task` y este camino no corre». Era **aspiración, no descripción**:
`forceFetchAndWait` no observaba cancelación, así que el flujo abandonado despertaba al minuto y medio y
sí corría. Al hacer que la cancelación cortara de verdad, `RestoreProgressView` empezó a llegar a su
apagado **por una razón nueva** —la persona salió— y apagarlo ahí cierra la ventana de sesión con el
import de CloudKit todavía bajando: el bug exacto que esa señal existe para evitar. El arreglo correcto
no era solo la cancelación: era mover el apagado detrás del `guard !Task.isCancelled`.

Y tuvo un segundo efecto que NO vi y cazó la review: ese despertar también **liberaba el reloj** de la
ventana. Sin él, quien abandona y vuelve más tarde hereda el reloj de la primera entrada y puede quedarse
sin ventana con el import a medias. Ticket propio.

**How to apply:** ante un cambio que altera CUÁNDO se alcanza un punto del código, no basta con mirar qué
hace ese punto. Hay que preguntar **qué significaba llegar ahí antes y qué significa ahora**, y recorrer
los docblocks del área buscando frases en presente que describan el comportamiento viejo: las que digan
«esto no ocurre» son las candidatas, y suelen estar en el fichero de al lado, no en el que tocas.

Relacionado: [[mi-arreglo-rompe-la-premisa-de-otro-guard]], [[el-copy-caduca-por-un-cambio-ajeno]],
[[mi-docblock-tambien-es-una-premisa]].

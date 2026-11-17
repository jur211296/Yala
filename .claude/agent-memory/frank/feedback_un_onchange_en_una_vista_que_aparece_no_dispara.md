---
name: un-onchange-en-una-vista-que-aparece-no-dispara
description: Un onChange colgado del hilo del chat no corre con el primer mensaje: el hilo aparece en ese instante. Va en la raíz.
metadata:
  type: feedback
---

Lo que reaccione al PRIMER cambio de algo va en una vista que ya estaba montada, no en la que aparece con ese cambio.
En Yala IA, cerrar el teclado al abrirse un guiado colgado del hilo (`ScrollViewReader`) no hacía nada: el hilo
sustituye al saludo con el primer mensaje y un `onChange` no se dispara al aparecer. Dos corridas de XCUITest en rojo
antes de verlo en el árbol (`chat_input` seguía con «Keyboard Focused»).

**Why:** el test del atajo del saludo pasaba y el de la frase escrita no; la diferencia era el teclado, y el árbol de
accesibilidad del fallo lo decía sin ambigüedad.

**How to apply:** ante un «mi onChange no hace nada», mira si la vista que lo lleva nace con ese mismo cambio; muévelo a
la raíz. Y lee el árbol del `.xcresult` antes de la segunda corrida. Ver [[el-guion-del-antes-se-ensaya-antes-de-la-base]].

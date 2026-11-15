---
name: feedback_toca_se_amplia_con_la_causa_medida
description: Si la causa MEDIDA de un bug del lote cae fuera del «toca», se pregunta ampliar a ese archivo exacto; Jürgen lo autoriza si no choca con otra sesión viva
metadata:
  type: feedback
---

Cuando el encargo dice «lo de fuera del toca va a card nueva» y la causa **medida** del bug principal cae en un archivo
fuera, no se deja en card sin más: se pregunta (bot dueño) con opción A «amplío el toca a ESE archivo» y opción B
«card». Jürgen eligió A el 14-nov (lote 1 de bugs de UI 2.3: el desborde del Panel estaba en `TrendsCarouselWidget`,
no en el carrusel que nombraba el encargo).

**Why:** el `toca` del encargo se escribe con la causa SUPUESTA; si la medición la mueve, dejar el bug alto fuera vacía
el lote. El `toca` existe para que dos sesiones no choquen, no para fijar la hipótesis.

**How to apply:** pregunta con el archivo exacto y la comprobación de que ninguna sesión viva lo toca (tmux de la otra
máquina + archivos de su PR). Sigue con lo demás mientras llega la respuesta. Para los arreglos pequeños fuera del toca
que NO son la causa del bug principal (Siri en `ProfileView`, la pestaña en `ContentView`), card y no preguntar.
Relacionado: [[feedback_alcance_minimo_salvo_incoherencia]].

---
name: tramo-sin-ceder-se-corta-a-3-ms
description: Al medir «tramos sin ceder» en una traza de Time Profiler, cortar las rachas de muestras con huecos de 3 ms (no 1,5): el muestreo deja huecos de 2 ms sin cesión y parte tramos de una vez
metadata:
  type: feedback
---

Al medir cuánto dura una pieza sin ceder el hilo (rachas de muestras de 1 ms del hilo principal con la pieza en la pila),
el corte va en **huecos de 3 ms o más**, el del lote 7. Con 1,5 ms la suma de saldos de la foto —de una vez, sin cesión—
salía en 80 + 71 ms en vez de 158: el muestreo deja huecos de 2 ms sin que nadie ceda (142 de 13.000 en una traza). Una
cesión (`Task.sleep(1 ms)`) también deja un hueco de ~2 ms, así que a 3 ms el «después» sale por lo alto, nunca por lo
bajo: es la lectura honesta para decir «ya no pasa de 50 ms».

**Why:** el 27-nov (lote 8) publiqué primero cifras a 1,5 ms; el «antes» salía más bajo de lo real y las conclusiones
cambiaban de pieza. Lo vi al cruzar un tramo con su pila.

**How to apply:** `tramos_calculadoras.py` (docs/qa/…/despues-eficiencia-8-…/scripts) ya corta a 3 ms por defecto. Y las
«rachas del hilo ocupado» sin mirar la pila (`bloques_panel.py`) no miden «sin ceder»: otras tareas del hilo principal
(la foto) rellenan los huecos de la cesión. Relacionado: [[medir-release-en-el-iphone-con-semilla]].

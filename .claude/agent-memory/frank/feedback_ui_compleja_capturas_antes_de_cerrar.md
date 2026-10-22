---
name: ui-compleja-capturas-antes-de-cerrar
description: En UI compleja, Jürgen aprueba sobre capturas del simulador antes del gate/PR, y suele pedir más aire que la maqueta
metadata:
  type: feedback
---

**Con UI compleja, mándale capturas del simulador (SendUserFile) y espera su «aprobado» antes del gate, el
commit y el PR**, aunque ya haya elegido propuesta en el lienzo. Elegir en el lienzo no es aprobar lo construido.

**Why:** el 2026-10-04 (gasto de grupo, propuesta B) eligió B en el lienzo y, con la B ya construida y el gate
corriendo, escribió «todo está muy apretado… muéstrame screenshots antes de avanzar, tendré que aprobar porque es
UI complejo». Pidió más aire: grupo y fecha más pequeños, pagador y reparto plegables. También vigiló que no se
perdiera una función existente al plegar («que no se pierdan las opciones rápidas»).

**How to apply:**
- Tras construir UI de varias secciones: capturas → AskUserQuestion «¿Apruebas?» → solo entonces gate/PR.
- Las maquetas del lienzo se ven más aireadas que el simulador real: compara con la captura, no con la maqueta.
- Al plegar u ocultar algo, enumera lo que estaba a la vista (atajos, avisos) y decide dónde queda. Ver
  [[disena-en-lienzo-antes-de-construir]].

---
name: bug-de-otra-rama-va-en-su-pr
description: Si un encargo con base 2.3 trae un bug que solo existe en 2.2, Jürgen pide un PR a cada rama, no meterlo todo en uno
metadata:
  type: feedback
---

Cuando el encargo pide «una base y un solo PR» pero una de sus cards es un rojo que solo existe en otra rama de versión
(el chip de Etiquetas, traído a 2.2 por un cambio que 2.3 no tenía), Jürgen eligió la opción C (2026-11-06): un PR a la
rama donde vive el bug, con solo ese arreglo, y otro PR a la base del encargo con lo demás.

**Why:** un arreglo en la rama que no tiene el bug no arregla nada, y 2.2 y 2.3 no se mezclan solas.

**How to apply:** antes de empezar, `git branch -r --contains <commit que trajo el bug>`; si no está en la base del
encargo, pregunta con las opciones y propone C. Los dos PR en cola de auto-merge, un solo cierre.

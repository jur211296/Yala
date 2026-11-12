---
name: el-test-que-se-para-antes-del-ultimo-gesto
description: Un XCUITest que se detiene antes de la confirmación final de un gesto destructivo deja sin probar justo el paso que no se puede ver; B5 del lote 20 vivió así semanas
metadata:
  type: feedback
---

Al auditar o probar un flujo destructivo, recórrelo hasta la **última** confirmación (sin aceptarla), no solo hasta la hoja que la precede.

**Why:** el 2026-10-17 (auditoría UX 2.2, lote 20) «Eliminar mi cuenta» → «Continuar» no hacía nada desde «Tu cuenta de Yala»: la alerta final colgaba de una vista tapada. `DeleteAccountDialogUITests` existía, pero su docblock decía «el test jamás toca Continuar (no completaría)» y se paraba en la hoja; por eso nadie lo vio. El paso que «no completaría» era el que estaba roto.

**How to apply:** si un test evita el último toque porque el desenlace no se puede ejecutar en el simulador, que llegue igual hasta el aviso final y lo afirme, saliendo por «Cancelar». En una auditoría, toca «Continuar» siempre y captura lo que sale (o lo que no). Relacionado: [[la-asercion-que-no-puede-fallar]].

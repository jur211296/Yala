---
name: empezar-a-llegar-no-es-haber-llegado
description: Una espera que se apaga con la PRIMERA fila que llega juzga un corpus a medias; tras saber que algo viene, el testigo es «terminó de llegar», no «empezó»
metadata:
  type: feedback
---

Cuando una guarda espera a que llegue algo (un import, una página, un corpus) para decidir, **el testigo de salida es que
terminó de llegar**, no que apareció la primera pieza.

**Why:** el 2026-09-25 (`adopt-on-an-empty-store-uploads-what-the-mirror-imports-before-the-relaunch`) hice que el adopt
preguntara a CloudKit si el corpus de iCloud existía y esperara a que llegara. La condición de salida era «ya hay una fila
local que pide linaje»: la lente de tests de la review vio que la primera tanda de un import por partes apagaba la espera,
la guarda juzgaba un corpus a medias y el resto subía después, que era el agujero del ticket con otra forma. El arreglo:
tras un «sí, viene», esperar a `hasCompletedFirstImport && isImportQuiescent`.

**How to apply:** al escribir un «espera hasta X», pregúntate si X puede cumplirse con una llegada PARCIAL. Si sí, separa
«ya sé que viene algo» (recuérdalo) de «ya llegó todo» (su propio testigo), y escribe el test con la llegada en dos tandas.
Emparenta con [[el-testigo-vive-menos-que-lo-que-describe]] y [[la-premisa-del-encargo-tambien-se-mide]].

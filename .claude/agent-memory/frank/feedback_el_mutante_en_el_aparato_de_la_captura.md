---
name: el-mutante-en-el-aparato-de-la-captura
description: Un caso de iPad verde en el Pro 13 no discriminaba: el teclado flotante solo salía en el Air 11 de la captura; y el simulador con teclado físico no pinta ninguno
metadata:
  type: feedback
---

El 2026-11-11 (barra sobre el teclado, decisión 68) el caso «el importe no abre un teclado flotante en el iPad» salió
**verde en el iPad Pro 13 con el mutante puesto**: allí el flotante no sale ni sin el arreglo. La captura de la revisión
era del **iPad Air 11**, y en el Air sí salía, también con la «hoja a tamaño de página» que yo había elegido. Sin el
mutante en el Air habría entregado un arreglo que no arreglaba nada. Antes de eso, otra corrida verde vacía: el
simulador tenía `HardwareKeyboardLastSeen = 1` y no pintaba teclado; el caso «pasaba» sin teclado en pantalla.

**Why:** un verde de un caso de aparato solo vale en el aparato donde se vio el bug; y una aserción sobre «el teclado»
pasa sin teclado si no exige uno visible.

**How to apply:** reproduce el antes en el MISMO modelo de la captura de la ficha (está en el nombre o en el pie de la
captura), corre ahí el mutante y exige que salga rojo; en un caso que mida teclados, afirma primero que hay uno en
pantalla. Si la decisión ofrece dos salidas («hoja de página o teclado acoplado»), mide la elegida contra el bug antes
de quedarte con ella. Relacionado: [[un-timeout-tapa-el-rojo-de-detras]], [[el-test-que-se-para-antes-del-ultimo-gesto]].

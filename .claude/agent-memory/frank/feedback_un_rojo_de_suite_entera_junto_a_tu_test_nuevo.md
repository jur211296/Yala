---
name: un-rojo-de-suite-entera-junto-a-tu-test-nuevo
description: Un rojo ajeno que solo sale en la suite entera se corre primero aislado y luego junto a tu test nuevo, antes de compilar la base para atribuirlo
metadata:
  type: feedback
---

Un rojo de un test que no tocaste y que solo sale en la suite entera: antes de compilar la base para saber si es
previo, córrelo **solo** y luego **junto a tus suites nuevas**, con el mismo scheme. El 2026-11-22 (reglas de captura)
`FotoWidgetPorEtapasTests` caía 3 de 3 y la base pasaba; compilé la base dos veces (~15 min) y comparé schemes distintos
(`Yala` frente a `Yala Dev`) antes de ver la causa: mi test nuevo guardaba una cuenta, eso pedía una foto de los
widgets, y la foto corría durante la suite siguiente.

**Why:** la suite entera corre en un solo proceso; un test nuevo que deja trabajo pedido (un debounce, un singleton)
contamina al siguiente por orden alfabético, y eso no lo enseña ni el diff ni la base.
**How to apply:** aislado verde + junto a lo tuyo rojo = es tuyo; arregla la limpieza en tu test. Solo si cae también
aislado, mira la base, y con el mismo scheme.

Relacionado: [[un-seam-que-deja-algo-pendiente-contamina-al-siguiente-test]].

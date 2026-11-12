---
name: un-seam-de-reloj-arranca-bajo-el-splash
description: Un seam que arranca un reloj en el onAppear de una vista puede vencer bajo el splash del arranque; mide desde lo que el test ve, o dale margen
metadata:
  type: feedback
---

El seam `-uitest-fake-cloud-session-after N` arma su reloj en el `onAppear` de la tarjeta «Crea tu cuenta». Con N = 2 el
XCUITest no llegaba a ver esa tarjeta: se monta **debajo del splash del arranque**, el reloj vencía tapado y la pestaña ya
estaba en el paso siguiente (medido el 2026-10-23: rojo con el arreglo puesto). Con N = 6, verde, y el mutante sigue rojo.

**Why:** `onAppear` no es «visible»: el overlay del splash (2,5 s en la primera impresión) cubre vistas ya montadas.

**How to apply:** un seam de tiempo para XCUITest arranca su reloj en algo que el test pueda ver, o lleva margen por encima
del splash; y comprueba el verde CON el arreglo antes de dar el test por bueno, no solo el rojo sin él.

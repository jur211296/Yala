---
name: una-parada-nueva-hereda-lo-que-el-camino-ya-hizo
description: al poner un guard que para un camino a mitad, lista los efectos que la llamada ya ejecutó ANTES de parar; con la parada nueva se quedan puestos y alguien más los lee
metadata:
  type: feedback
---

Al añadir una parada (un `guard … else { return }`) detrás de una llamada con efectos, pregunta qué dejó hecho esa llamada
antes de fallar, porque con la parada ese estado se queda, y quién lo lee después.

**Why:** 26-sep, desasociar de grupos. Puse la postcondición tras `CloudAuthService.signOut()`, pero `signOut()` borraba el
correo y el proveedor ANTES de cerrar la sesión. Antes el gesto seguía hasta `clear()` y nadie leía ese estado; con la parada,
la sesión viva sin perfil llegaba al registrador del arranque, que reescribía la asociación sin nombre en el iCloud-KV de todos
los teléfonos. Lo cazó la lente de secuencia, no mis tests: mi arreglo abría la regresión.

**How to apply:** recorre los efectos que la llamada ejecuta antes del punto que puede fallar; los que describen el estado que
la parada conserva se mueven detrás de la confirmación. Familia de [[mi-arreglo-quita-la-salida-que-habia]] y [[mi-arreglo-rompe-la-premisa-de-otro-guard]].

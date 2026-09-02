---
name: mis-mediciones-fallan-por-el-filtro
description: Mis errores de medición se repiten con la misma forma — el filtro descarta justo lo que busco y la ausencia se lee como resultado. Cuatro casos en una sola sesión (2026-09-02).
metadata:
  type: feedback
---

**Antes de creerme una medición mía, compruebo que el instrumento sabe producir el resultado
contrario.** Es la regla; lo que sigue es por qué me hace falta tenerla escrita.

**Why:** el 2026-09-02, en una sola sesión, tropecé **cuatro veces con la misma forma de error** —
un filtro que descarta lo que busco, y una ausencia que leo como dato:

1. `-only-testing` con el nombre de un **método** de Swift Testing no filtra: corre cero tests y
   devuelve `TEST SUCCEEDED`. Concluí que mi test no protegía y estuve a punto de reescribir uno
   que estaba bien. (A nivel de FICHERO sí funciona.)
2. `grep 'Co-Authored-By'` sin anclar dio positivo porque el mensaje **mencionaba** esa cadena en
   la prosa. Concluí que había puesto un trailer que no había puesto.
3. `grep -E "error:"` sobre la salida de `xcodebuild` casó con la etiqueta de parámetro Swift
   `classify(error:` y me sepultó la señal en ruido. Dos veces el mismo día.
4. Medí «45 pasos del CI en verde» filtrando por `conclusion=="success"` **a nivel de job** —o sea
   contando sólo los buenos— y además sobre un campo que `continue-on-error` pinta de verde aunque
   el comando salga con `exit 65`. La conclusión era exactamente la contraria a la realidad: el CI
   llevaba semanas verde con ocho tests en rojo.

Los cuatro comparten el patrón, y el número 4 es la lección: **un numerador sin denominador no es
una proporción**. La sesión de la mañana había cometido ese mismo error con `git log --grep` y yo
lo critiqué por escrito… antes de repetirlo dos veces.

**How to apply:**
- **Control positivo, siempre.** Antes de leer una ausencia (o un verde) como señal, corre el mismo
  instrumento sobre un caso donde la señal SÍ está y comprueba que aparece.
- **Exige el conteo.** `Test run with N tests in M suites` (Swift Testing) o `Executed N tests`
  (XCTest). Sin conteo, no has medido nada, diga lo que diga el veredicto.
- **Ancla los patrones** a la línea que buscas y nada más. Nada de `grep` de subcadenas sueltas
  sobre logs de código: el código contiene tus propias palabras clave.
- **Cuenta el total y los que cumplen por separado**, y desconfía de toda proporción que dé 100 %.
- **Un campo de estado no es el resultado.** `continue-on-error`, `advisory`, `|| true` y los
  reintentos desacoplan «lo que dice el campo» de «lo que pasó». Ve al log.

Relacionado: [[trailer-de-commit-nunca-en-yala]] (el mismo error, cometido por otra sesión, es lo
que casi tumba una regla del owner).

---
name: el-copy-caduca-por-un-cambio-ajeno
description: Una frase de la app es una afirmación verificable sobre el mecanismo, y caduca cuando cambia OTRO fichero — sin que nada se ponga rojo. Al cerrar un mecanismo, busca el copy que lo prometía.
metadata:
  type: feedback
---

**Una frase de la app es una afirmación verificable sobre el mecanismo, y el mecanismo vive en otro
fichero.** Cuando cierras, acotas o inviertes un comportamiento, busca **el copy que lo prometía** —
en los 16 locales — antes de dar el cambio por completo.

**Why:** el 2026-09-14, `remote-wipe-signal-honored-by-any-session` cerró a propósito el receptor de
la señal de vaciado: un teléfono prestado dejó de obedecerla. Correcto. Pero la hoja de «Vaciar
datos» seguía diciendo «desaparecen también de tu iPad, tu Mac y **cualquier dispositivo con este
Apple ID**». La frase **era cierta hasta esa mañana** y se volvió falsa el mismo día, **sin que nada
se pusiera rojo**: build verde, suite verde, XCUITest verde. El ticket que lo recogió salió de una
review de producto, no de un test.

La causa de fondo: **cero tests miraban el copy**. `DestructiveScopeLogicTests` mide la ESTRUCTURA
de la hoja —filas, tonos, líneas condicionales, botones— y nunca el texto. Una tabla exhaustiva de
estructura se lee como cobertura completa y no lo es. Lo mismo cazó la review del PR #160 («nadie
miraba el copy por desenlace»): es el mismo agujero, dos veces en una semana.

**How to apply:**

1. **Al cerrar un mecanismo**, grep del copy que lo describe antes de cerrar el ticket. Los términos
   que buscar son los del USUARIO, no los del código: «Apple ID», «todos tus dispositivos», «se
   borran de», no `wipeSignal*`. En este caso, un `grep 'Apple ID'` sobre `es-419` devolvió las 9
   frases del repo y **solo una** prometía borrado — el resto prometen disponibilidad y siguen
   siendo ciertas. Cuesta un grep distinguirlas.
2. **La frase nueva se verifica contra el mecanismo, no se ablanda.** «Más floja» no es «verdadera».
   Enumera las poblaciones y comprueba la frase contra cada una: aquí eran cuatro (sesión privada,
   teléfono prestado, dispositivo con la cuenta de Yala, solo-grupos con espejo montado) y la frase
   tenía que ser correcta en las cuatro. Ancla la condición a algo que el usuario pueda evaluar
   («que guardan ahí tus datos personales»), no a un absoluto.
3. **Si la key se llama como la promesa, la key también miente.** `wipeScopeCloudICloudAllDevices`
   afirmaba «AllDevices» en su nombre. Con un solo consumidor, retirarla y crear la honesta cuesta
   un `add-l10n-key.sh` y evita que el yo-futuro lea el nombre como si fuera el contrato.
4. **El test del copy va por el camino de producción, no por grep**: `Config.make` y assertar el
   `detail` de la fila. Y un barrido de los 16 ficheros de strings, o reponer la promesa en un solo
   idioma sigue pasando.
5. **Dos controles positivos, porque los dos fallos abiertos son reales**: si `L10n` devolviera la
   key cruda, `detail == L10n.…` sería cierto por los dos lados sin probar nada; y si el listado de
   `.lproj` saliera vacío, el barrido pasaría verde leyendo cero ficheros. Ver
   [[un-gate-falla-abierto-por-su-entrada]] y [[la-asercion-que-no-puede-fallar]].

Relacionado: [[mi-docblock-tambien-es-una-premisa]] — el mismo día, **tres** docblocks citaban la
promesa vieja como premisa y había que corregirlos, no uno; y
[[el-predicado-del-ticket-no-es-el-criterio]].

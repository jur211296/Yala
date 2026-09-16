---
name: el-termino-nuevo-desarma-el-test-viejo
description: Añadir una condición a un AND puede dejar sin poder discriminante a un test que ya tenías — su aserción negativa pasa a cumplirse por el término nuevo; re-mide con el mutante y corrige el docblock
metadata:
  type: feedback
---

**Al añadir un término a un `&&`, vuelve a medir qué mata a los tests que ya tenías. Una aserción
negativa que antes fijaba el término A puede pasar a cumplirse sola por el término B.**

**Why.** El 15-sep escribí un XCUITest negativo —«con la racha terminal y sesión viva, un teléfono en
`.icloud` NO ve el aviso»— y lo verifiqué con el mutante: tumbar `personalDataLivesInCloud` lo ponía
**rojo**. Su docblock decía, con razón, que discriminaba ese término.

Horas después, una lente adversarial me hizo añadir un cuarto término (`channelIsStable`). Volví a
medir por costumbre y **el mismo mutante ya no mataba el test**: en el simulador los dos términos del
canal son falsos, así que tumbar uno deja el otro sosteniendo la ausencia. Lo que pone rojo el caso es
tumbar **los dos** (verificado, exit 65). El test seguía siendo valioso —protege a la población
`.icloud` contra que el aviso deje de gatear por el canal entero— pero **su docblock había pasado a
mentir**, y ésa es la parte cara: el yo-futuro lo lee y cree que ese caso fija un término que ya no fija.

**How to apply.**

- **Cada vez que un AND gana un operando, re-corre los mutantes de los tests que ya pasaban.** No basta
  con que sigan verdes: verdes es el estado por defecto. Lo que hay que medir es **qué los pone rojos
  ahora**.
- **El síntoma es el silencio**: nada falla, nadie avisa. Por eso hay que ir a buscarlo.
- **Corrige el docblock con lo medido, no con lo que querías.** Aquí acabó diciendo: «tumbar una sola
  deja el caso en verde; lo que lo pone rojo es tumbar las dos — protege el canal ENTERO y no fija cuál
  de los dos términos lo hace», y nombrando quién sí los distingue (la tabla unitaria y el source-scan).
- Corolario: **en un test negativo, cuantos más términos del AND sean falsos en el fixture, menos
  discrimina**. Si quieres que fije uno concreto, el fixture tiene que hacer verdaderos a todos los demás.

Relacionado: [[feedback_un_numero_sustituto_lo_cumple_otra_cosa]] y
[[feedback_la_asercion_que_no_puede_fallar]] — misma familia, disparador distinto: aquí el test nació
bien y lo desarmó un cambio posterior MÍO.

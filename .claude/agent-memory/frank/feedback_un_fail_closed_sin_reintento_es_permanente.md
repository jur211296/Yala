---
name: un-fail-closed-sin-reintento-es-permanente
description: Al cerrar un gate que fallaba abierto, busca quién RE-EVALÚA el estado cerrado; si nadie lo revisita, el «no por ahora» se vuelve «no hasta relanzar».
metadata:
  type: feedback
---

Cerrar un permiso que fallaba abierto no termina en el gate: hay que buscar **quién vuelve a preguntar** cuando la
condición se cura. El 22-sep hice que un journal ilegible no arrancara el motor de la nube (`canRun(read:)` → `false`) y
dos lentes de la review cazaron que así el motor se quedaba `.idle` **hasta relanzar**: `handleBecameActive` no
re-evalúa `.idle` y el boot no vuelve a pasar por `startRuntimeIfStable`. El fail-open de antes era, sin quererlo, también
el camino que lo arrancaba.

**Why:** un estado de espera sin re-evaluación convierte un fallo pasajero (un prewarm con el store protegido) en una
avería de toda la sesión, y encima la pantalla mentía («Todo sincronizado» con el motor parado).

**How to apply:** antes de dar por bueno un fail-closed nuevo, enumera los estados en que deja al consumidor y para cada
uno pregunta «¿quién lo saca de aquí cuando la lectura vuelva?». Si la respuesta es «nadie», el arreglo necesita su
reintento en la cadencia que ya existe (aquí, el re-kick de cada primer plano). Familia de
[[mi-arreglo-quita-la-salida-que-habia]] y [[al-quitar-un-apagado-incondicional-busca-quien-lo-usaba]].

**2026-09-26, y la curación que di por hecha era falsa.** Hice que un drain de grupos cortado por el reloj bloqueara
cerrar sesión, desasociar y «Empezar de cero», y escribí en el docblock que «la deriva se cura sola con el tiempo». La
lente de regresión midió que no: el drain estampa con la FECHA DE LA TRANSACCIÓN, así que la misma transacción corta en
cada vuelta para siempre. Bloquear seguía siendo lo correcto (borrar perdía lo que ya no sube), pero el aviso «inténtalo
en un rato» prometía algo que no pasa. ⇒ **la frase «se cura solo» es una afirmación: busca el `now` que usa el camino
que falla** antes de escribirla, y si no se cura, dilo en el ticket y no en el copy.

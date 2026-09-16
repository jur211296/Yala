---
name: el-outcome-que-clasifico-lo-produce-otro
description: Antes de mapear un outcome a una causa, mira QUIÉN lo produce — en un ciclo push+pull el veredicto es el del pull siempre que el push vaya bien, y clasificarlo como «falló la subida» culpa al servidor de fallos locales.
metadata:
  type: feedback
---

Antes de mapear un enum de resultado a una causa que se le cuenta al usuario, **recorre el camino por el que
viaja ese valor y averigua quién lo escribió**. No basta con inventariar las familias de fallo que caben
dentro: hay que saber cuál de ellas está midiendo el valor que tienes en la mano.

**Why:** el 2026-09-16, separando el copy de bloqueo del cierre de sesión, mapeé `CadenceOutcome.transient`
entero a «la subida no llegó al servidor». Hice el inventario —barrí los dos ficheros, clasifiqué los 40
productores en transporte vs. local— y concluí que los locales eran patológicos y raros, así que daba igual.
**La conclusión era la equivocada, y el inventario no podía decírmelo.** Lo que no miré es que
`GroupsSyncClient.syncCycleOnce` corta con el outcome del push solo si el push PARA; si no, devuelve
`GroupsSyncCadence.outcome(pull:)`. O sea que el valor que yo estaba clasificando era, en el caso normal, **el
veredicto del pull**. Con la subida perfecta y el pull caído, mi arreglo le decía a la persona que sus cambios
no habían llegado al servidor; y al `save()` local de una página —que es H-2026-07-18-6, el caso exacto que
motivó los 45 s de reintentos del cierre— le quitaba además el reintento que sí lo cura. Lo cazó una lente
adversarial, no el inventario.

**How to apply:** cuando vayas a escribir `case X: return <causa concreta>`, la pregunta no es «¿qué cosas
caben en X?» sino **«¿quién escribió ESTE X, y podría haberlo escrito otro?»**. Si el valor pasa por una
función que compone varias etapas (push y pull, validación y envío, local y remoto), lo más probable es que
esté describiendo la última que corrió y no la que te interesa. La salida es el **testigo del ciclo**: una
marca POSITIVA que enciende la etapa concreta y un getter que la liga al outcome — el molde que este repo ya
tiene dos veces (`stoppedByChannelKill`, `stoppedByUnavailableAttest`). Marcar de menos deja el aviso
conservador de siempre; marcar de más acusa a una parte de lo que hizo otra. Ver también
[[el-oraculo-del-mutante-es-el-efecto-que-produce]] y [[la-rule-de-area-es-una-lente-mas]].

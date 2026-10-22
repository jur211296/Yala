---
name: el-dueno-se-fecha-no-se-recuerda
description: Atribuir algo escrito en el pasado exige un registro FECHADO de quién estaba, no «el último que vi»; y una red de rescate posterior no puede tocar lo que la regla dejó sin decidir a propósito.
metadata:
  type: feedback
---

Cuando haya que decidir **de quién es algo que se escribió antes de procesarlo** (History drenado tarde, colas, eventos
diferidos), el testigo es un registro de épocas fechado con el mismo reloj que el dato, no un valor único «último visto».

**Why:** 2026-09-28, `groups-outbox-rows-without-a-live-session-have-no-exit`. Mi primera versión guardaba «el último dueño
que vio el drain» y la review de tres lentes lo tumbó por tres caminos a la vez (actualizar con el libro vacío, una sesión de
paso que se abre y se cierra, una relectura del History). Y en la segunda ronda cayó la red que añadí para las filas sin
dueño: adoptaba también las que la regla nueva había dejado sin dueño A PROPÓSITO, y se las daba a la sesión viva — el bug del
ticket por otra puerta. Un tercer tropiezo: tratar todo cierre de sesión como «vuelve a la cuenta anterior» cuando solo lo es
el de una sesión de paso.

**How to apply:**
- Antes de escribir un testigo de «quién», pregunta «¿para qué instante lo voy a consultar?». Si la respuesta es «uno
  anterior al de ahora», necesitas épocas.
- Toda red de rescate (adopción, backfill, re-drive) se acota a la población que la NECESITA (aquí, `schemaVersion` del
  build anterior): lo que la regla nueva decidió «ninguno» no es un hueco que rellenar.
- Un evento de cierre tiene varios significados; el default del registro es el que no reatribuye, y el caso especial lo pide
  quien lo sabe (`signOut(returningToPreviousAccount:)`).
- Relacionado: [[la-correccion-de-la-lente-reintroduce-el-bug]], [[review-adversarial-caza-lo-mio]].

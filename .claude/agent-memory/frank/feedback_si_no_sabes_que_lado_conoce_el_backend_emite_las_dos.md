---
name: si-no-sabes-que-lado-conoce-el-backend-emite-las-dos
description: Una traducción de identidad elige un lado; en el otro teléfono va al revés. Si el servidor tolera lo que sobra, emite las dos — y MÍDELO en el servidor antes
metadata:
  type: feedback
---

Diseñé «traducir el tombstone a la identidad del relevo» y la lente de pérdida de datos lo tumbó: el MISMO código corre en el
líder desplazado, donde la identidad buena es la otra, así que allí traducía al revés y resucitaba el borrado que antes llegaba.
La salida no fue adivinar el lado sino emitir las dos, tras medir en producción (`pg_proc` de `apply_delta`, solo lectura) que
un tombstone de una identidad desconocida se guarda como fila borrada y no hace daño.

**Why:** un teléfono no sabe de qué lado de una carrera está; una regla que «elige» identidad es correcta solo en uno de los dos.

**How to apply:** cuando un arreglo decida «esta es la identidad que el backend conoce», pregúntate qué hace el mismo código en el
OTRO teléfono de la escena. Si el servidor es idempotente con lo que sobra, emitir ambas es más robusto que elegir; la premisa
del servidor se mide (SQL de solo lectura), no se supone. Relacionado: [[la-correccion-de-la-lente-reintroduce-el-bug]].

Y de paso, medido esa noche: `xcodebuild test-without-building` con tests en rojo se quedó colgado >6 min tras imprimir el
resumen. En baterías de mutantes, `timeout 240` delante de cada corrida.

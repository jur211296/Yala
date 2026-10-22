---
name: sustituir-un-latido-cambia-que-significa-el-lease
description: Al reemplazar un latido por otro «con la misma cadencia», mide CUÁNDO latía el viejo; si latía solo con avance, el nuevo cambia el significado del lease.
metadata:
  type: feedback
---

Retiré el latido best-effort de la subida («la puerta lo sustituye con la misma cadencia») y lo escribí en la regla. Era
falso: el viejo solo latía tras una página CONFIRMADA; la puerta late en toda pasada que pregunta. El lease pasó de «el
líder avanza» a «el líder está vivo», y un líder conectado con el push roto ya no cede el relevo. Lo cazó la lente de la
regla; lo acepté y documenté, pero no lo había decidido.

**Why:** «misma cadencia» compara la frecuencia y se olvida de la CONDICIÓN. Dos mecanismos a 1/min con condiciones
distintas no son intercambiables, y el que depende de la señal (el seguidor que espera) cambia de comportamiento.

**How to apply:** antes de sustituir un emisor, escribe en una línea bajo qué condición emitía el viejo y bajo cuál el
nuevo, y busca quién LEE la señal (aquí `claim_account` y el seguidor). Si cambia, es una decisión: va al Paso 0, no a
un comentario. Relacionado: [[el-estado-compartido-no-es-testigo-de-su-rama]].

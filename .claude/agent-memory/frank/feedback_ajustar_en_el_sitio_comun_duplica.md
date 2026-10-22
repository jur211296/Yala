---
name: feedback-ajustar-en-el-sitio-comun-duplica
description: Si dos productores desembocan en una función común y solo uno necesita el ajuste, ajustar en la común lo duplica en el otro.
metadata:
  type: feedback
---

Un ajuste que solo le falta a UNO de los productores va en ese productor, no en el sitio común por el que pasan los dos.

**Why:** 2026-10-05, «Empezar de cero» con cambios de otra cuenta. Sumé las entradas ajenas a la cifra en `settleFreshStartBlock`, por donde pasan el bloqueo de la subida (que no las contaba) y el residuo (que ya contaba el espejo entero). Con 1 propia + 2 ajenas el aviso decía 5. Mis 9 tests y 8 mutantes no lo vieron porque todos inyectaban el bloqueo de la subida; lo cazaron las dos lentes de la review a la vez.

**How to apply:** antes de poner una corrección en una función que reciben varios caminos, lista los productores de su entrada y pregunta, para cada uno, si ya trae lo que vas a añadir. Y escribe un test por productor, no solo por el que motivó el cambio ([[un-arreglo-en-n-sitios-se-prueba-en-los-n]]).

---
name: el-guion-de-qa-tiene-que-distinguir-builds
description: Un guion de device-QA que pasa igual con el build de antes no verifica nada — el del token nulo sin red no llegaba al arreglo porque la puerta de attest (15 min en caché) salía antes; lo cazó la segunda pasada de review
metadata:
  type: feedback
---

**Antes de dar un guion de device-QA a Jürgen, escribe qué vería con el build de ANTES en el paso que decide.** Si la
respuesta es «lo mismo», el guion no llega al código arreglado.

**Why:** el 2026-09-16 escribí «modo avión, deja pasar la hora `exp`, reabre: no debe salir "Inicia sesión"». La segunda
lente de documentos leyó `performCycle`: la puerta de App Attest corre ANTES del push, su token vive 15 min en memoria y,
sin red y caducado, el ciclo sale pasajero en la puerta, con el arreglo y sin él. El bug solo existía en la ventana en que
el JWT caduca con el attest aún en caché. El guion habría dado un PASS falso, y además yo había descrito mal a quién le
llegaba el bug («sin red y con el token caducado», sin la ventana). Es la versión de device-QA de la regla de fixtures
DISCRIMINANTES de `.claude/rules/testing.md`.

**How to apply:**

- Recorre el camino desde el gesto de la persona hasta la línea que cambiaste y apunta **cada puerta, caché o TTL** que
  corre antes. Cada una es una condición del montaje (aquí: «relanza con red a menos de 10 min de `exp`, y vuelve antes de
  14 min»).
- Añade un **control con el build de antes** o una línea de consola que solo exista con el arreglo, y di qué hacer si el
  control no sale («la ventana no se montó: repite»).
- Cita el texto de log y el copy **copiados del código**, no de memoria: el nombre de la función del rastro no es el texto
  que imprime (`runtimeStopped` escribe `CloudSyncRuntime stopped reason=…`).

Relacionado: [[el-copy-que-promete-se-recorre]] · [[mis-mediciones-fallan-por-el-filtro]].

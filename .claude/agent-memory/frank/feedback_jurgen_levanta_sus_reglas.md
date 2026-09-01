---
name: jurgen-levanta-sus-reglas
description: Jürgen levanta explícitamente sus propias reglas de proceso cuando lo pide; y cuando propone un cambio, quiere la medición que lo contradice ANTES de que lo implementes, no después
metadata:
  type: feedback
---

**Cuando Jürgen te pide algo que una regla tuya prohíbe, y te lo pide de forma directa, se hace.**
La regla es un default que protege *su* punto de control; si él lo levanta, lo está ejerciendo,
no saltándoselo.

**Why:** el 2026-09-01 pasó dos veces en la misma sesión. Mi ficha decía «No mergeas tú. Merge y
release son de Jürgen» y me pidió «ejecuta el merge a 2.1»; y decía «Nunca commiteas en `2.1`» y
me pidió escribir el cierre ahí. En los dos casos repreguntar habría sido burocracia: él es el
dueño de esa regla. Lo que sí hice, y fue lo correcto, es **decir en una línea que la regla
existía y que la estaba levantando él** — no ejecutar en silencio como si nunca hubiera estado.

**How to apply:** ejecuta, y deja dicho en una línea qué default estabas cambiando y por qué. Si
la instrucción llega con información nueva de por medio (por ejemplo: «mergea» dicho **antes** de
saber que faltaban 100 minutos de CI), eso no es repreguntar: es traerle un dato que cambia su
decisión, y ahí sí se pregunta. La diferencia es si la información es nueva para él, no si tú
tienes dudas.

**Y la otra mitad, que es la que más valor dio:** cuando propone un cambio de proceso, **quiere la
medición que lo contradice antes de que lo implementes.** Ese mismo día propuso saltarse los PR
«para no esperar los tests de GitHub»; medido, resultó que esos tests son `continue-on-error` y
nunca bloquearon nada, y que el filtro de docs del CI ya saltaba la suite sola. Se lo dije en
claro —«el ahorro no son 100 minutos, son pasos»— y no solo no le molestó: siguió adelante con el
cambio y **ajustó el criterio** (excluyó `.claude/` de la allowlist de «solo documentación»,
porque los hooks no rompen el build pero sí rompen cómo trabaja todo el mundo). ⇒ traer la
contramedida temprano mejora su decisión; callársela para no incordiar habría producido una regla
peor. Ver también [[creo-que-no-es-aprobacion]].

---
name: tablero-una-tanda-a-la-vez
description: Dos tandas de `tablero` en paralelo se pisan con 409 y fallan cards sueltas; además, la tanda larga puede deshacer lo que decides mientras corre.
metadata:
  type: feedback
---

El 21-oct lancé 435 cambios de versión en segundo plano y, a la vez, otra tanda de decisiones. Las dos chocaron: `tablero`
reintenta una vez ante un 409 y después falla, así que quedaron cards sin cambiar. La tanda larga tardó más de 40 minutos,
unos 6 segundos por card.

**Why:** el tablero guarda el documento entero, y dos escritores a la vez se invalidan entre sí. Y la tanda larga escribe
lo calculado al lanzarla: si mientras tanto Jürgen cambia de idea sobre una card, la tanda le pone la versión vieja.

**How to apply:** una sola tanda a la vez, con reintentos propios. Lo que se decida mientras corre se apunta en un
fichero de ajustes, y se aplica en una pasada final que, card por card, compara el estado real con el deseado.
Relacionado: [[tablero-nota-sustituye]].

---
name: la-fase-ajena-tiene-otros-escritores
description: Si lo que pinto sale de una fase que OTROS también escriben, mi «en vuelo» necesita marcar la vuelta — un `.idle` que yo creía transitorio lo pone otra pantalla y me deja un progreso eterno. Cazado el 15-sep por dos lentes a la vez, con la suite en verde.
metadata:
  type: feedback
---

**Cuando derivo lo que enseña una pantalla de una fase compartida, un estado propio «pedí la operación» no
basta: hace falta también «la operación volvió».**

**Why:** el 2026-09-15 modelé la hoja del cambio de Apple ID con un solo `.closing` y pinté progreso para
`.closing` + `.idle`, razonando que ese `.idle` solo dura del tap al primer turno del `Task`. Era cierto para
MI escritor. Pero `CloudSessionSignOut.phase` la mueven también Ajustes, la puerta de grupos del Welcome y el
desasociar, y `acknowledgeBlocked()` la devuelve a `.idle` desde cualquiera de ellos. Con Ajustes montado
debajo de la hoja —las hojas de las pestañas no entran en la matriz del shell—, su alert reconocía MI bloqueo
y la hoja se quedaba en un spinner sin botones, reteniendo el router hasta matar la app. Lo cazaron por
separado la lente de presentación y la de coordinador; la tabla pura y sus tests eran coherentes consigo
mismos, que es justo por lo que no lo veían.

**How to apply:**

- Antes de pintar un estado «transitorio» leído de una fase compartida, **lista TODOS los escritores de esa
  fase** —el setter y cada método que la mueve—, no solo el tuyo.
- Si alguno puede llevarla al valor que tú lees como transitorio, **marca la vuelta de tu operación** con un
  estado propio (aquí `.stopped`) y decide qué se ve ahí, siempre con salida.
- La misma forma que [[mi-arreglo-abre-un-camino-inalcanzable]] y [[el-consumidor-lee-una-copia]]: mi
  razonamiento valía para mi camino y la fase tiene más caminos que el mío.

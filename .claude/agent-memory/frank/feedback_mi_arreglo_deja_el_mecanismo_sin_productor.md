---
name: mi-arreglo-deja-el-mecanismo-sin-productor
description: Quitar el último productor de un mecanismo lo deja vivo pero inalcanzable — y el docblock que escribo sobre el cambio miente si no mido a dónde llega de verdad el outcome nuevo.
metadata:
  type: feedback
---

Cuando un arreglo **reclasifica un outcome**, hay que medir dos cosas que no son obvias y que no salen
del diff: **qué se queda sin productor** aguas arriba, y **a dónde llega de verdad** el outcome nuevo
aguas abajo. Las dos veces que no las medí, escribí un comentario falso.

**Why:** el 2026-09-14, al mover el 403 de infraestructura de `.accountUnavailable` a `.transient`:

- **Aguas arriba:** `stoppedUntilRelaunch` se quedó **sin ningún productor alcanzable**. El único que
  quedaba en el código era un 409 que el gateway **no emite en esa ruta** (`gateway/src/groups/
  routes.ts:12` lo dice de su puño). El mecanismo sigue ahí, con su gate y sus tests, pareciendo que
  cubre un caso que ya nadie puede alcanzar.
- **Aguas abajo, y esto es lo que me pilló:** escribí «el canal ya no llega a `.permanent`». **Falso.**
  `CloudSessionSignOut` colapsa con un ternario todo veredicto que no sea `.channelPaused` en
  `.permanent`, así que en esa celda el bug del ticket **seguía vivo** y mi comentario afirmaba lo
  contrario. Lo cazó una lente adversarial, no yo.

**How to apply:**

- **Aguas arriba:** tras reclasificar, `grep` de **todos los escritores** del estado que dejas de
  alimentar, y por cada uno pregunta si su condición es alcanzable **en el servidor**, no solo en el
  cliente. Un `case` que el backend nunca emite es código muerto aunque compile. Si queda sin
  productor: no lo retires de paso (eso toca otras firmas y sus tests) — **documéntalo con la medición
  y abre ticket**.
- **Aguas abajo:** sigue el outcome nuevo hasta la pantalla, **leyendo cada ternario y cada `switch`
  del camino**. Un colapso de un solo carácter (`x == .a ? .a : .b`) borra tu distinción entera, y es
  invisible desde el fichero que editas.
- **Regla para mí:** un docblock que dice «desde hoy X ya no pasa» es una afirmación medible sobre
  TODO el camino, no sobre la línea que acabo de tocar. O la mido hasta el final, o la escribo
  acotada («`classify` ya no lo produce» ≠ «ya no se ve»).
- Y si el colapso de aguas abajo afecta a más cosas que a tu objeto (ahí: también la red caída y los
  5xx), **no lo cambies**: es otro objeto y una decisión de producto. Ticket.

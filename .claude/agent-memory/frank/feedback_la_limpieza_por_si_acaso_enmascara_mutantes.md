---
name: la-limpieza-por-si-acaso-enmascara-mutantes
description: Una línea defensiva inalcanzable no es neutra — recoge lo que el camino bueno deja pasar, y mata el mutante que probaría que el camino bueno funciona
metadata:
  type: feedback
---

Una línea que limpia un estado «por si acaso» y resulta **inalcanzable** no es sólo inútil: es
peligrosa, porque hace de red del camino que sí importa y **enmascara al mutante** que probaría que
ese camino funciona. Retirarla no baja la cobertura: la sube.

**Why:** el 2026-09-21 puse `parkedStartedAt = nil` en `noteRestoreFinished` «por si el aparcado
sobrevivía», y escribí un test con su nombre. La lente de la red de tests midió que la línea no podía
ejecutarse nunca con efecto —aparcar apaga en el mismo acto, y recuperar el dueño exige pasar por el
estreno, que consume el aparcado—, así que el test que la nombraba llegaba ahí con el campo ya en
`nil` y demostraba otra cosa. Peor: los dos consumos **se tapaban mutuamente**. Borrar el del estreno
dejaba la suite verde porque lo recogía esta línea; borrar esta línea era inerte; sólo borrando los
dos salía un rojo. Retirada la línea inalcanzable, el mutante del estreno pasó de morir sólo por un
source-scan a morir por comportamiento.

**How to apply:**

- Cuando escribas una limpieza defensiva, **demuestra que su estado de entrada es alcanzable** antes
  de darla por útil: enumera los escritores del campo y qué deja cada uno en los demás.
- Si es inalcanzable, hay dos respuestas y la tercera no existe: **retirarla** (preferido — Jürgen
  prefiere lo limpio a lo defensivo) o conservarla **diciendo en el comentario que hoy no se alcanza**
  y por qué podría alcanzarse mañana. Lo que no vale es dejar un comentario describiendo un daño
  imposible: se lee como medido.
- La red correcta para «mañana alguien añade un segundo llamador» **no es la limpieza defensiva**: es
  un escáner de unicidad del call-site.
- Corolario de nombres: si un test llega a su aserción por un camino distinto del que su nombre
  anuncia, renómbralo por lo que mide. [[feedback_mi_docblock_tambien_es_una_premisa]] aplica igual a
  los nombres de test.

Relacionado: [[feedback_el_mutante_que_sobrevive_puede_sobrar]],
[[feedback_prefiere_lo_limpio_a_lo_defensivo]], [[feedback_la_segunda_capa_no_cubre_lo_que_dice]].

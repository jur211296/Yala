---
name: el-prefiltro-tapa-al-criterio
description: Cuando la misma condición vive en el fetch y en la lógica, los tests pasan por la barata y el mutante de la lógica sale VERDE — me pasó dos veces en una sesión.
metadata:
  type: feedback
---

**Si una condición está en el `#Predicate` del fetch **y** en la lógica que decide, los tests la
ejercitan por el fetch, y un mutante que la borre de la lógica sale VERDE.** El criterio queda sin
cobertura mientras la suite entera dice que sí la tiene.

**Why:** el 2026-09-08, en `chat-rows-with-unsigned-amount-have-no-repair-path`, escribí un barrido
con el acotado por ventana en los dos sitios. El caso que demuestra el AC del ticket —«un reembolso
legítimo de fuera de la ventana sobrevive»— pasaba por el predicado: esas filas **ni las devolvía el
fetch**, así que borrar la ventana de `isCandidate` dejaba los 13 casos verdes. Lo cacé con el control
positivo; sin él habría entregado el criterio de aceptación sin probar.

Lo corregí dejando el predicado como pre-filtro barato (`amount > 0`) y la lógica como única
autoridad… **y el mismo defecto sobrevivió en la condición hermana**: `amount > 0` seguía estando en
los dos sitios, así que el caso del gasto ya firmado también probaba el fetch y no el criterio. Lo
cazó la review adversarial, no yo. Dos veces el mismo error en una sesión, la segunda dentro del
arreglo de la primera.

**How to apply:**

- **El pre-filtro puede ser más ancho que el criterio, nunca igual.** Si el fetch y la lógica dicen lo
  mismo, o quitas uno, o aceptas que esa condición no está probada.
- Al arreglar una duplicación así, **enumera las demás condiciones del mismo guard antes de cerrar**.
  La que acabas de arreglar te enseña la forma; sus hermanas suelen estar al lado.
- La prueba de que un criterio está cubierto **no es un caso que pase por el servicio**: es un caso que
  llame a la lógica pura con el valor que solo ella rechaza. Cuatro líneas.
- Vale para cualquier par «filtro barato + decisión»: predicado y `filter`, guard de UI y validación de
  dominio, `where` de SQL y comprobación en código.

Relacionado: [[la-asercion-que-no-puede-fallar]] y [[mis-mediciones-fallan-por-el-filtro]] — la misma
familia: algo entre mi medición y la realidad la está contestando por mí.

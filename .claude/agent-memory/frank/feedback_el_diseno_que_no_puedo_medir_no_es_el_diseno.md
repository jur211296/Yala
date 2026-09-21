---
name: el-diseno-que-no-puedo-medir-no-es-el-diseno
description: Entre dos diseños correctos, gana el que no apoya su corrección en un contrato que no puedo comprobar aquí — y rehacer a media implementación sale barato
metadata:
  type: feedback
---

Cuando dos diseños cumplen los criterios, el desempate no es la elegancia: es **cuál de los dos
puedo comprobar con lo que hay en este repo**. Un diseño cuya corrección depende de un contrato del
framework que ningún test de aquí ejercita es un diseño a crédito.

**Why:** el 21-sep implementé el arreglo del restore con `.task(id: flowToken)`, que se apoya en que
SwiftUI vuelva a disparar un `.task` cuando cambia su `id`. Es contrato documentado, pero **la
pantalla de Restaurar no tiene ni un XCUITest que entre en ella**, así que no había forma barata de
medirlo — y si el contrato no se cumplía, el fallo no era un detalle: la búsqueda no arrancaba
NUNCA y la pantalla se quedaba girando. Lo sustituí por una puerta de montaje (`if let`), que no
depende de ningún re-disparo. Rehacer costó veinte minutos con los tests ya escritos; las dos
reviews, que corrían contra el diseño viejo, confirmaron después que sus dos hallazgos de más peso
los cerraba justo la versión nueva.

**How to apply:**

- Al elegir mecanismo, escribe **cómo se mediría que falla**. Si la respuesta es «se vería en
  producción», busca otro mecanismo.
- **Rehacer a media implementación es barato y no es retrabajo**: los tests y los mutantes ya
  escritos se reusan casi enteros, y el Paso 0 solo necesita que la decisión descartada quede
  ESCRITA con su medición — si no, el siguiente la vuelve a proponer.
- Si una review está corriendo contra el diseño viejo, **no la canceles**: sus hallazgos sobre el
  mecanismo suelen seguir valiendo, y los que ya no aplican te dicen qué cerró el rediseño.

Relacionado: [[feedback_instrumentar_gana_a_razonar]] · [[feedback_prefiere_lo_limpio_a_lo_defensivo]]

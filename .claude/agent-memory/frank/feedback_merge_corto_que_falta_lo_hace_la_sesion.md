---
name: merge-corto-que-falta-lo-hace-la-sesion
description: Si un lote 2.3 para porque 2.3 no tiene lo de 2.2, Jürgen prefiere que la misma sesión haga el merge corto (PR aparte, auto-merge) y siga con el lote.
metadata:
  type: feedback
---

El 11-nov paré el lote de Grupos con un `BLOQUEANTE:` porque `origin/2.3..origin/2.2` daba 16, como pedía el encargo. Jürgen contestó a los minutos: «haz tú el merge corto ahora, PR aparte a 2.3, con auto-merge y sin esperar el CI; en cuanto puedas basarte en esa rama, sigue con tu lote».

**Why:** la condición del encargo era una puerta de calidad, no un reparto de trabajo. Esperar a otra sesión dejaba la cola parada por algo que la propia sesión resuelve en una hora.

**How to apply:** si vuelve a pasar, el `BLOQUEANTE:` sigue siendo lo correcto en semi (no es mío decidirlo), pero en el mismo mensaje se ofrece hacer el merge aquí, con el coste estimado. El lote se apoya en la rama del merge (`git checkout -B <rama-lote> <merge>`), sin rebasar encima: un rebase aplanaría el merge. Al gate del merge le basta un subconjunto declarado de XCUITest ([[gate-globs-ancho-subconjunto]]); y un rojo se compara contra `origin/2.3` en un árbol aparte antes de atribuírselo al merge (el de la Bandeja ya venía de 2.3).

---
name: lote-que-depende-de-otro-en-cola
description: Un encargo con depende: sobre un lote cuyo PR sigue en cola de auto-merge — apilar sobre su rama y reset --keep a origin/2.3 cuando entre
metadata:
  type: feedback
---

Con `depende:` sobre un lote cuyo PR aún está en cola de auto-merge (bienvenida 2.3, lote 04 sobre el 03, 12-nov), no se
espera ni se trabaja sobre `origin/2.3` viejo: se apila la rama sobre la del lote (`git fetch origin <rama>` +
`git reset --keep FETCH_HEAD`) y, cuando su PR entra, `git reset --keep origin/2.3` (el árbol de la rama ya era el del
merge: cero conflictos). Se comprueba con `git merge-base --is-ancestor HEAD origin/2.3` y `git diff --name-only HEAD origin/2.3`.

**Why:** los lotes de una misma feature comparten Panel, mazo y catálogo de textos; partir de 2.3 sin el lote anterior
obligaba a reimplementar o a chocar en el merge, y esperar parado gasta la sesión.

**How to apply:** al leer `depende:` en un encargo, mira `gh pr view` del lote: MERGED → base normal; OPEN con
`autoMergeRequest` → apilar. Relacionado: [[no-esperar-ci-ajeno]].

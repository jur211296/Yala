---
name: el-guion-del-antes-se-ensaya-antes-de-la-base
description: Un conductor de capturas que falla a mitad obliga a otra vuelta a la base (build + revertir); se ensaya entero sobre el árbol sin tocar y cada fila se busca por dos rasgos
metadata:
  type: feedback
---

El guion XCUITest de capturas del «antes» se ensaya ENTERO contra el build del árbol sin tocar antes de empezar a editar,
y cada fila que abre se busca por dos rasgos (nombre + importe), no por uno.

**Why:** el 2026-11-02 (encargo grupos-b-cabos-sueltos) costó dos vueltas más a la base (copiar mis ficheros, `git show
HEAD:`, apartar tests nuevos, build incremental ~8 min, capturar, restaurar): la primera porque la fila de hace tres días
no estaba en el árbol de una lista perezosa y el guion se paró en la 2.ª pantalla; la segunda porque «Súper» casaba
primero con la pata derivada de 20 y no con la de 200 que llevaba la receta, y la captura salió de otro registro.

**How to apply:** en la lista perezosa, baja hasta que la fila sea `isHittable`; parte el guion en un test por pantalla
(así el «antes» de una se repite sola) y mira cada PNG del antes en cuanto sale, antes de tocar código.
Relacionado: [[antes-del-iphone-con-git-archive]].

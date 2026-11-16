---
name: merge-entre-ramas-hermanas
description: Al llevar 2.2 a 2.3, los rojos no salen en los conflictos sino en las reglas de una rama que cazan el código o el copy nuevo de la otra; y un rojo de App Group tras una corrida completa puede ser estado del simulador
metadata:
  type: feedback
---

Un merge entre ramas hermanas (2.2 → 2.3, 9-nov-2026) compiló a la primera y dio 9 rojos de unit tests, ninguno en un
conflicto: tests de 2.2 (nombre «Panel» en cada idioma, «Configurações» prohibido, `UserDefaults(suiteName:)` pelado,
plurales solo en `.stringsdict`) contra copy y tests nuevos de 2.3, y al revés. Cada arreglo destapó el siguiente
(pt es alias idéntico de pt-BR: corregir solo pt rompe la paridad).

**Why:** git solo ve líneas que chocan; las reglas por source-scan de una rama no se han corrido nunca contra el código
de la otra.

**How to apply:** tras un merge de ramas, suite completa de `YalaTests` antes de mirar nada más, y repetir los rojos
juntos hasta que salgan cero. Si tras una corrida completa caen tests del App Group (idioma, caché de Siri) que antes
pasaban, corre el mismo conjunto en la base (`git worktree add --detach … origin/<base>`): el 9-nov caían 3 en bucle y
pasaron solos tras correr la base; la corrida completa siguiente salió limpia. Ver [[regresion-aparente-se-mide-contra-la-base]].

---
name: la-resolucion-se-guarda-con-write-tree
description: Al poner al día varios PR en cadena, la resolución de conflictos de uno se guarda con git write-tree y se reaplica con merge-file 3-way cuando la base se mueve, en vez de rehacerla.
metadata:
  type: feedback
---

Cuando un PR con choques tiene que esperar a que otro entre en la base, resuelve su merge contra la base de HOY, guarda el árbol resuelto con `git write-tree` (objeto suelto, sin commit ni hooks saltados), aborta el merge, y cuando la base se mueva reaplícalo fichero a fichero: `git merge-file -p <resuelto> <base-vieja> <base-nueva>`. Solo quedan los choques que trae lo nuevo de la base.

**Why:** 2026-10-23, cuatro PR atascados a 2.2. #576 tenía 20 ficheros en conflicto con la 2.2 de la mañana; tras entrar #571 y #601, la reaplicación dejó 3 Swift y el índice resueltos solos y solo las 16 colas de Localizable por unir. Rehacerlo habría sido repetir la revisión Swift entera.

**How to apply:** encargos de «poner al día» con varios PR en orden. Se apoya en dos scripts que valen para cualquier merge de este repo: unión 3-way clave a clave de `.strings` (empate real → gana la base y se lista) y de `coverage-index.json` (`lastVerified` = máx., `coverage` = base + añadidos de cada lado). Ojo con el `coverage`: si un lado INSERTA en medio del texto base, la unión simple no lo ve y se pierde su tramo — revísalo a mano. Relacionado: [[rerun-no-recoge-el-arreglo-de-la-base]].

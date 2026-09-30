---
name: el-fallo-que-se-traga-es-gemelo-del-que-aborta
description: Al arreglar lo que pasa tras un ABORT, busca el fallo hermano que se traga (`_ =`) y deja el mismo estado aguas abajo; y un testigo de fallo va dentro de la rama que actuaría, no delante
metadata:
  type: feedback
---

Arreglé el bucle de la puerta de Grupos tras el abort S3 del borrado de arranque (archivo personal que no se deja
borrar) y la lente de estado durable cazó el gemelo: el archivo de GRUPOS que falla con `_ = deleteFiles(...)` no
aborta, el borrado «completa», mi testigo se retiraba y la puerta volvía a encontrar filas y a armar. Mismo bucle,
otra puerta. La segunda lente cazó que el testigo, mirado ANTES de la celda de cierre, tapaba pantallas que eran la
verdad (celda de la nube, coordinador no idle).

**Why:** 2026-09-30, `sign-out-wipe-abort-loops-the-groups-gate`. Los dos defectos eran de mi diseño; los tests y
los mutantes de la primera versión estaban en verde.

**How to apply:** cuando el ticket nombra un camino de fallo, lista TODOS los sitios del mismo gesto que pueden fallar
—los que abortan y los que tragan el error— y pregunta a cada uno «¿deja el estado que dispara el bug?». Y un testigo
que corta una acción se consulta justo delante de esa acción, no a la entrada de la función. Familia de
[[la-segunda-capa-no-cubre-lo-que-dice]] y [[mi-puerta-bloquea-lo-que-su-propio-flujo-dejo]].

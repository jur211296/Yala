---
name: el-mutante-cortado-se-queda-puesto
description: Un comando que muta el código, corre tests y restaura en el MISMO paso deja el mutante escrito si se corta (rechazo, interrupción); verifica el árbol antes de seguir
metadata:
  type: feedback
---

Un comando que aplica mutantes, corre los tests y restaura al final, todo en un solo Bash, deja los mutantes PUESTOS si se
corta a mitad: el rechazo del tool no deshace lo que la parte ya ejecutada escribió. Lote N3 (2026-11-05): el comando se
rechazó, creí que no había corrido, y el gate siguiente salió con tres rojos que eran exactamente mis tres mutantes.

**Why:** «rejected» no garantiza «no ejecutado»; y un mutante olvidado puede llegar al commit si el test que lo caza no
está en la corrida.

**How to apply:** tras cualquier corte de un comando de mutantes, `grep` las líneas mutadas antes de seguir; mejor aún,
muta en un paso, corre en otro y restaura en un tercero (o con `trap` que restaure). Si un rojo coincide con un mutante,
mira el árbol antes que el código. Ver también [[la-limpieza-por-si-acaso-enmascara-mutantes]].

---
name: el-comando-mutante-restaura-con-trap
description: Un mutante lanzado en segundo plano restaura con `trap … EXIT` en el mismo script; el 15-oct uno de pantalla se quedó puesto tras la corrida
metadata:
  type: feedback
---

Todo comando que aplique un mutante y corra tests en segundo plano lleva la restauración DENTRO, con `trap restore EXIT`,
y después compruebo con `diff -q` contra la copia que el fichero volvió.

**Why:** el 2026-10-15 (card 4nt6) lancé el mutante de `StorageSettingsView` en segundo plano copiando el original a
`orig/` pero sin restaurarlo en el comando. Terminó, seguí trabajando y el árbol tenía el comportamiento viejo puesto; lo
vi solo porque un `grep -c` de comprobación dio 0. Si hubiera sellado el gate en ese momento, el sello cubría el mutante.
Y un `pkill -f <patrón>` para parar un build mató el shell envoltorio y dejó vivo su `xcodebuild`, que bloqueó la base de
datos del build siguiente («database is locked»).

**How to apply:** script de mutantes = copiar originales → `trap restore EXIT` → mutar → correr → (el trap restaura) →
`diff -q` y «RESTORED». Para parar un build propio, `kill <pid del xcodebuild>` tras comprobar con `lsof -p` que su cwd es
este worktree. Relacionado: [[el-script-de-mutantes-revierte-mi-trabajo]], [[mutantes-sin-diagnose-y-con-copia]].

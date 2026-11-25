---
name: las-pruebas-de-cableado-leen-el-arbol
description: Las suites de source-scan leen el código del árbol de trabajo (#filePath), no del binario; test-without-building con productos de otra rama da rojos falsos.
metadata:
  type: feedback
---

Al correr `test-without-building` con productos compilados de una rama (la mezcla del barrido) y el árbol ya cambiado a
otra (mi rama sin esos PR), las suites de cableado de esos PR salieron rojas: 16 de 16.363, todas `*WiringTests` o scans
de `EstoLeiAjustesCardTests`. Sobre el árbol bueno, 99/99. Medido el 2026-11-25 (barrido de la build 10).

**Why:** el binario trae el código nuevo, pero el scan abre el `.swift` del árbol por `#filePath`, que era el viejo.

**How to apply:** antes de una corrida larga con `test-without-building`, comprueba que `HEAD` del worktree es el del
binario; si cambiaste de rama, o vuelves o descuenta los scans de los ficheros que difieren y repítelos al volver.
Relacionado: [[gate-globs-ancho-subconjunto]].

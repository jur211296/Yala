---
name: en-cola-puede-estar-en-conflicto
description: Un PR con auto-merge activo puede estar DIRTY contra su base y no entrar nunca; mira mergeStateStatus antes de dar por cumplido «arreglar el CI».
metadata:
  type: feedback
---

Arreglar el check rojo de un PR en cola no basta: el PR de deshacer en lote (2026-11-12) llevaba auto-merge desde
la víspera y estaba `DIRTY` contra 2.3 (71 commits detrás, 18 ficheros en conflicto). Con el CI verde tampoco habría
entrado. El encargo solo hablaba del unit.

**Why:** `autoMergeRequest` no nulo se lee como «entrará», y nadie mira el estado de merge.

**How to apply:** tras empujar a un PR ajeno, `gh pr view <n> --json mergeStateStatus`. `DIRTY` → merge de la base en
la rama (nunca rebase ni force-push sobre un PR ajeno). Si el conflicto es de diseño (dos decisiones sobre el mismo
sitio de la pantalla), pregunta a Jürgen con maqueta: aquí eligió en un toque. `BLOCKED` = solo espera checks.
Relacionado: [[auto-merge-en-2-2-no-espera-al-ci]], [[rerun-no-recoge-el-arreglo-de-la-base]].

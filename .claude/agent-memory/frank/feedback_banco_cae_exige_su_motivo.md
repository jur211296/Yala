---
name: banco-cae-exige-su-motivo
description: En un banco de casos pasa/cae, cada caso que cae exige su mensaje de error; si no, cae por una avería del banco y sale verde
metadata:
  type: feedback
---

Un banco de casos «pasa / cae» tiene que exigir a cada caso que cae **el texto de su error**, no solo el exit ≠ 0.

**Why:** 2026-11-17, banco de `qa/checklist-confiabilidad.yaml`. El JSON llegaba al validador por stdin, pero el stdin
de `python3 -` ya era el heredoc con el script: el validador leía vacío y fallaba siempre. Los 22 casos «cae» salieron
verdes por esa avería, y solo el caso «pasa» lo delató. Con el motivo exigido (`caso <n> cae <yaml> "<texto>"`), un caso
que cae por otra razón sale en rojo.

**How to apply:** al escribir o tocar un banco `*-test.sh` con casos que deben caer, añade el mensaje esperado y un
caso «pasa» por cada eje. Mismo banco: en macOS `sed` no tiene `0,/re/` ni `\n` en el reemplazo (usa `perl -0pe`), y en
la Max no hay PyYAML (el YAML de la librería estándar de Ruby sí). Relacionado: [[un-timeout-tapa-el-rojo-de-detras]].

---
name: medir-esperas-reales-en-transcripts
description: El tiempo real que las sesiones pasan esperando (merge, CI) sale de los transcripts de las dos máquinas, no de GitHub
metadata:
  type: reference
---

`esperar_merge.py` no deja log propio. Lo que hizo cada sesión vive en los transcripts:
`~/.claude/projects/*Yala*/*.jsonl` en la Max y, por `ssh mini`, en la Mini (el `tar` por ssh falló;
mandar el script con `ssh mini 'python3 -' < script.py` sí funcionó). Cada `tool_use` de Bash con
`esperar_merge.py` y su `tool_result` dan inicio, fin y `RESULTADO=`.

**Why:** el 25-nov la estimación desde GitHub (auto-merge → merge, recortado al tope) cuadró con lo real
(612 vs 601 min/día), pero solo los transcripts dijeron cómo acabó cada espera (70 de 74 en «tope»).

**How to apply:** cualquier pregunta de «cuánto tiempo pierden las sesiones en X». Los scripts quedaron en
`docs/analisis/ci-ui-rojo-2026-11-25/scripts/`. Ver también [[cierre-espera-el-merge-real]].

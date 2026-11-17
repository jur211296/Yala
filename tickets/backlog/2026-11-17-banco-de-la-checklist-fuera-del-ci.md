---
id: 2026-11-17-banco-de-la-checklist-fuera-del-ci
status: backlog
priority: medium
area: qa
created: 2026-11-17
updated: 2026-11-17
source: hallazgo de la sesión del revisor con checklist (P4, segunda parte)
---
# El banco de la checklist de confiabilidad no corre en el CI

`qa/scripts/checklist-confiabilidad-test.sh` (lo trae el PR de la checklist curada, P4 primera parte) valida que
cada glob, símbolo, prueba y línea de regla de `qa/checklist-confiabilidad.yaml` exista en el árbol. Ese PR no lo
añadió a `.github/workflows/qa.yml`, así que no corre en `coverage-index` ni en el paso 5 de `/gate`.

**Por qué importa.** El revisor del gate lee la checklist de `origin/2.3`. Un ítem cuyo símbolo se renombre deja de
dispararse en silencio; ese banco es lo único que lo caza, y hoy solo corre si alguien se acuerda.

**Qué hacer.** Un paso en `coverage-index`, junto al de `checklist-elegir-test.sh`. Ojo: valida contra el árbol, así
que un PR que renombre un símbolo de la checklist se pondrá rojo hasta actualizarla en el mismo PR (es lo buscado).

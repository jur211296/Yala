---
name: gate-sello-ancla-en-head
description: El sello del gate incluye HEAD, así que una tanda de varios commits obliga a re-sellar entre uno y otro — el disco no cambió, el ancla sí
metadata:
  type: reference
---

**Tras cada commit de una tanda hay que volver a correr `bash qa/scripts/worktree-stamp.sh >
.claude/sessions/tests-passed`, aunque no se haya tocado una línea de código.**

**Why:** el 2026-09-05, con el gate entero en verde y dos commits que hacer, el segundo se bloqueó
con «el codigo cambio desde que paso /gate. Vuelve a correr /gate». No había cambiado nada: la
huella es `HEAD + una línea por fichero que difiere de HEAD`, así que el primer commit —que mueve
HEAD— la invalida por construcción. Está escrito en la cabecera del propio script; sólo hay que
leerlo antes de que muerda.

**How to apply:**

- Un gate cubre **un árbol**, no **un commit**. Repartir ese árbol en varios commits es legítimo y
  el re-sellado entre ellos no se salta nada.
- **Antes de re-sellar, demuestra que el disco no cambió**: `git status --porcelain` tiene que
  traer sólo lo que falta por commitear, y `git show --stat HEAD` no puede nombrar ninguno de esos
  ficheros. Si el commit anterior tocó algo de lo que queda pendiente, el gate sí hay que
  re-correrlo.
- **Lo que SÍ obliga a re-correr el gate entero es mergear la rama principal**, que es lo normal en
  Yala (ADR-008): ahí entra código ajeno a los mismos ficheros. Ese día el merge de `2.1` subió la
  suite de 6046/609 a 6082/618 — números distintos, gate distinto.

Relacionado: [[mis-mediciones-fallan-por-el-filtro]] (el caso 12: el PR nace `DIRTY` y el CI ni
arranca, que es el otro efecto de que `2.1` avance mientras trabajas).

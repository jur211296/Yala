---
name: gate-apilado-sobre-un-pr-abierto
description: Rama apilada sobre un PR aún sin mergear: el gate de interfaz y el revisor se calculan contra la cabeza de ese PR, no contra origin/2.3
metadata:
  type: feedback
---

Con mi rama encima de un PR todavía abierto (21-nov: la B1 en Bandeja y Grupos sobre el PR de la B1), `interfaz-de-lo-tocado.py` y `checklist-elegir.py` contra `origin/2.3` cuentan también el diff del otro PR: 230 clases fuera del techo, la mitad pruebas que ese PR ya había pasado. Con `--base <cabeza del PR de abajo>` salieron las 18 que pasan por lo mío.

**Why:** el techo de 30 min se llena con pruebas ajenas ya validadas y las tuyas quedan fuera; el revisor recibe un diff que no es el tuyo.

**How to apply:** al apilar, anota el commit base (la cabeza del PR de abajo) y pásalo como `--base` a los dos scripts; dilo en el informe del gate. El «antes» de las capturas se hace también sobre esa base (commit local temporal + `git checkout HEAD~1 -- Yala` y build), no sobre 2.3. Relacionado: [[no-editar-con-xcodebuild-test-compilando]].

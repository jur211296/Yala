---
name: mira-los-pr-abiertos-antes-de-arreglar-ui
description: Antes de arreglar un bug de UI del barrido, busca un PR abierto que ya rediseñe esa pantalla; «ya en done» en un barrido puede ser un PR que nunca mergeó
metadata:
  type: feedback
---

El 14-nov arreglé wju5 (botón que empuja «Entrar con mi iCloud» fuera en el iPhone 14) y lo probé en el teléfono, y
solo al registrar las decisiones vi que el PR de ajustes visuales de la bienvenida —decidido por Jürgen el 13-nov— movía
ese botón a otro sitio. Seguía abierto (cola de merge, `tests` en rojo) y el barrido lo dio por «ya en done» porque el
ticket estaba en `done` dentro de la rama. Retiré mi arreglo: contradecía su diseño y chocaba al mergear.

**Why:** un ticket en `done` dentro de una rama no es código en 2.3; y la decisión de diseño de Jürgen manda sobre un
arreglo mío que «cabe».

**How to apply:** al empezar un lote de UI, `gh pr list --state open` sobre los ficheros que vas a tocar
(`gh pr view <n> --json files`) y lee `docs/DECISIONS.md` de los últimos días. Si un PR abierto ya cubre la card, la card
espera a ese PR y se dice en el cierre. Ver [[alcance-minimo-salvo-incoherencia]].

---
name: mira-los-pr-abiertos-antes-de-arreglar-ui
description: Antes de arreglar un bug del barrido, busca el PR abierto que ya lo arregla; «ya en done» o «en cola de auto-merge» puede ser un PR que nunca mergeó
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

**Segunda vez, 14-nov (lote B):** dos de las cinco cards (iCloud vaciado y «Volver a tu iCloud» colgado) las arreglaba un
PR del 13-nov **en cola de auto-merge con todo en verde** que llevaba un día `DIRTY`: chocaba solo en `DECISIONS.md` y
`TICKETS.md`, y la cola no avanza con conflicto. El barrido probó una build sin él y las dio por falladas. Lo mergeé en la
rama del lote (conflictos con la versión de 2.3) y su PR se marca mergeado al aterrizar el mío. ⇒ `gh pr view <n> --json
mergeable,mergeStateStatus` de los PR enlazados en cada card: `CONFLICTING` con auto-merge puesto es un PR muerto.

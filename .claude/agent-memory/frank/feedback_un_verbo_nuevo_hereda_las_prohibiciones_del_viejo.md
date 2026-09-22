---
name: un-verbo-nuevo-hereda-las-prohibiciones-del-viejo
description: Al partir un verbo en dos, busca los tests que PROHIBÍAN al original — los negativos se anclan al nombre y el gemelo nuevo pasa por delante en verde
metadata:
  type: feedback
---

Cuando un camino se muda de un verbo a otro —o un verbo se parte en dos—, busca no sólo quién lo
LLAMABA, sino **quién lo tenía prohibido**. Las aserciones negativas (`!code.contains("verbo(")`) se
anclan al nombre, así que el gemelo nuevo produce el mismo daño y pasa en verde.

**Why:** el 2026-09-21 saqué la confirmación de «Empezar desde cero» de `noteRestoreFinished` a un
`noteRestoreDiscardRequested` nuevo. Dos lentes independientes midieron lo mismo:
`GroupsOrganizerBranchTests.neutralReturnDoesNotCancelTheRestoreSignal` **prohíbe** llamar al apagado
desde `WelcomeGroupsGateView`, porque ahí el import sigue bajando con el latch muerto y su único
encendedor vive en otra pantalla (la enmienda D2). Ese test conocía un verbo; desde mi cambio había
dos que hacen exactamente lo mismo, y escribir el nuevo en aquella vista reabría la enmienda entera
con toda la suite en verde. El mismo fichero ya se había tropezado una vez con este punto ciego: su
comentario cuenta que anclar al literal sin el paréntesis dejaba pasar lo que prohibía.

**How to apply:**

- Antes de partir un verbo, `grep` del nombre **también en las aserciones negativas** de todo
  `YalaTests`/`YalaUITests`, no sólo en `Yala/`. Cada `!contains(<verbo>)` que aparezca es una
  prohibición que el gemelo hereda.
- Y mira la asimetría del suite: si hay escáner de unicidad para los verbos que ENCIENDEN y no para
  los que APAGAN, ése es el hueco. Los dos lados necesitan la misma red.
- Corolario al escribir el verbo nuevo: si su docblock afirma «su llamador es UNO», esa frase tiene
  que tener un test detrás. Es una afirmación con fecha de caducidad, igual que la de la rule
  `L272` de `swiftdata-cloudkit.md`.

Relacionado: [[feedback_al_quitar_un_apagado_incondicional_busca_quien_lo_usaba]],
[[feedback_el_source_scan_de_dos_literales_no_es_una_red]],
[[feedback_mi_arreglo_rompe_la_premisa_de_otro_guard]].

---
name: barrido-tasa-sellada-chat
description: PR #108 (2026-09-08) — las filas que el chat selló con tasa 1.0 ya se curan; el plan obvio dañaba; falta device-QA (sí simulable) y deja 3 tickets, uno medium
metadata:
  type: project
---

`chat-rows-sealed-before-the-fix-have-no-repair-path` cerrado el 2026-09-08 (PR #108, mergeado a
`2.1`). Está en `tickets/qa/` esperando device-QA.

**Why:** cerraba la última pieza de la cadena del chat — `#102` (signo), `#103` (barrido del signo),
`#106` (subcategoría), `#107` (divisa de la cuenta) y el arreglo hacia delante de la tasa, todos del
mismo día. Ésta era la que curaba lo **ya guardado**.

**How to apply:**

- **El device-QA SÍ es simulable**, a diferencia del de «≈»: fila sembrada con tasa `1,0000` en
  divisa ajena y monto convertido real → tras arrancar enseña la tasa verdadera, el importe **no**
  cambia y no aparece el «≈». El log de DEBUG imprime cuántas curó en el sitio y cuántas reabrió, que
  es lo que responde cuántas filas había de verdad. Está en el Grupo D del `qa/guion-tanda.md`.
- **Lo que quedó abierto y puede volver:** `fx-repair-sweep-seals-on-a-partially-restored-store`
  (**medium**) — ni el gate de quiescencia ni el guard de presencia distinguen un restore **a
  medias**, y cerrarlo pide mover `loadExchangeRates` detrás del gate de store-ready, que es una
  decisión de arranque y no un residual. Más dos `low`: el gate `!uiTestActive` que este barrido es
  el único de su vecindario en no tener, y el canario que le falta.
- **No se reabre la vía de reabrir la fila.** Se midió que daña y por qué; la razón está en
  `.claude/rules/currency-fx.md`, no aquí. Ver
  [[feedback_el_mecanismo_existente_se_probo_con_otro_corpus]].

---
name: adopt-effect-techo-y-salida
description: 2026-09-23 — el efecto del adopt (reconcile tras existing_stable) recibió techo 15 min/72 h, «Cancelar» y salida; qué quedó en tickets y qué espera producto
metadata:
  type: project
---

`adopt-effect-retries-forever-with-no-ceiling` se entregó el 2026-09-23 en sesión autónoma, a `done` sin device-QA (el
escenario no se monta en un iPhone). Jürgen contestó las tres preguntas por AskUserQuestion eligiendo la recomendación, y
una cuarta tras la review (el texto).

**Why:** cierra la serie de techos de la ida (snapshot, tres pasos, claim del adopt) por el último sitio del flujo del adopt.

**How to apply:** lo que queda vive en cuatro tickets de la review, dos con decisión de producto pendiente:
`welcome-adopt-effect-failure-has-no-reason-and-no-cancel` (texto y «Cancelar» en el Welcome — HECHO el 2026-09-23 con
la opción A de Jürgen; dejó dos low: el «desde aquí» del diálogo, que es de producto, y el «Reintentar» sobre un 403) y
`adopt-exit-keeps-the-session-it-opened` (¿cerrar la sesión al salir del adopt? tampoco lo hace el claim de #221; desde
el 23-sep también lo alcanza el «Cancelar» del Welcome). Los
otros dos son low técnicos. El diseño está en la regla «Y el EFECTO del adopt también» de `swiftdata-cloudkit.md`.
Relacionado: [[adopt-claim-techo-y-salida]].

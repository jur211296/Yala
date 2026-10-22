---
name: adopt-follower-techo-y-salida
description: 2026-09-23 — la espera del seguidor (waitingForLeader) recibió techo, aviso y «Dejar de esperar»; qué quedó en tickets
metadata:
  type: project
---

`adopt-follower-waits-for-the-leader-with-no-ceiling` se entregó el 2026-09-23 en sesión autónoma, a `done` sin device-QA.
Jürgen contestó tres preguntas por AskUserQuestion eligiendo la recomendación (techo del 22 %, salida del adopt, y tras la
review textos propios «Dejar de esperar»).

**Why:** cierra el último sitio del flujo del adopt sin techo (claim #221, efecto #226, seguidor).

**How to apply:** lo que queda son tres tickets low/very-low de la review: `forward-step-ceiling-wins-over-a-cancel-given-in-the-same-pass`,
`waiting-card-disables-stop-waiting-without-saying-why`, `follower-waits-forever-on-a-lease-with-a-null-heartbeat`. El diseño
está en la regla «Y la espera del seguidor también» de `swiftdata-cloudkit.md`. Relacionado: [[adopt-claim-techo-y-salida]],
[[adopt-effect-techo-y-salida]].

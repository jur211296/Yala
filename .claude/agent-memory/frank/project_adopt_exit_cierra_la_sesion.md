---
name: adopt-exit-cierra-la-sesion
description: 2026-09-24 — la salida del adopt cierra la sesión que abrió (PR #230); qué quedó en ticket
metadata:
  type: project
---

`adopt-exit-keeps-the-session-it-opened` se entregó el 2026-09-24 en sesión nocturna autónoma (PR #230), a `done` sin
device-QA. La decisión A ya estaba tomada; no hubo preguntas a Jürgen.

**Why:** cerraba el último cabo de la serie del adopt (#221, #226, #228, #229): salir dejaba la sesión puesta y el
arranque la registraba como cuenta de Grupos.

**How to apply:** queda `settings-adopt-stalled-before-the-claim-keeps-the-session` (low, ya existía). El diseño está en la
regla «Y la sesión que abrió el adopt» de `swiftdata-cloudkit.md`. Siguen esperando producto los dos low de #229:
`welcome-adopt-cancel-dialog-says-from-here` y `welcome-adopt-exit-offers-retry-on-a-blocked-account`.
Relacionado: [[adopt-effect-techo-y-salida]].

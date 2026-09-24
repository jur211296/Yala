---
id: claim-replay-after-a-kill-mid-commit-can-duplicate-the-onboarding
status: backlog
priority: low
area: "modo-nube, groups"
created: 2026-09-24
source: "review adversarial de `claim-promotion-lost-response-blocks-the-retry` (2026-09-24), las dos lentes"
---

# Si la app muere justo después de guardar el onboarding, repetir la activación puede duplicarlo

## El síntoma, en lenguaje de usuario

Activo Yala completo → «Tu cuenta en la nube». La app se cierra de golpe justo después de guardar mis
cuentas y categorías y antes de que suban. Al volver repito la activación y el onboarding: termina, pero
tengo dos juegos de cuentas y categorías.

## Por qué pasa (inferido del código, no reproducido)

- El plan de la nube es promote → activar almacenamiento nube (arranca el motor) → persistir [P] → …
  (`FullModeActivationFlowLogic.commitPlan`).
- Desde `qa/cloud/g16_01_…`, el reintento del mismo teléfono recibe `created` mientras la cuenta no tenga
  ninguna escritura personal. Si el kill cae después de persistir [P] y antes de la primera subida, la cuenta
  sigue «vacía» para el servidor y el segundo intento persiste [P] otra vez, con UUID nuevos.
- Estrecho: el claim del segundo intento necesita red, y con red y `.cloud` el motor suele subir lo del primero
  antes de que se rehaga el onboarding (entonces el servidor ya bloquea). Antes de g16_01 este caso bloqueaba
  siempre.
- No está medido si la activación se ofrece igual tras ese kill (`pendingCommit` vive en memoria).

## Alcance

- Reproducir en simulador con un kill forzado entre `persistOnboarding` y el primer push.
- Si se confirma: que el commit detecte lo que ya persistió el intento anterior, o marcar durable «persistido».

## Criterios de aceptación

- [ ] Un kill entre persistir [P] y la primera subida no deja dos juegos de cuentas y categorías.

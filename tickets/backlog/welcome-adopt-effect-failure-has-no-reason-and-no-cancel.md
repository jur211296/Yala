---
id: welcome-adopt-effect-failure-has-no-reason-and-no-cancel
status: backlog
priority: medium
area: "modo-nube, onboarding, adopt"
created: 2026-09-23
updated: 2026-09-23
source: "review adversarial de `adopt-effect-retries-forever-with-no-ceiling` (2026-09-23), lente de consumidores"
---

# Si entrar en tu cuenta falla desde la bienvenida, la pantalla culpa a tu conexión y no te deja cancelar

## El problema, en lenguaje de usuario

Instalo Yala en un teléfono nuevo y entro en mi cuenta de la nube desde la bienvenida. Si la parte final no puede
terminar, la barra se queda en «Conectando…» con «Retomar», sin botón para cancelar ni flecha atrás. Cuando por fin se
rinde (15 min si el fallo es del teléfono, 72 h si es la red), dice «No pudimos verificar tu cuenta. Revisa tu conexión»,
aunque la causa sea que el teléfono no pudo leer sus propios datos.

## Por qué pasa (leído el 2026-09-23; no ejecutado)

`CloudWelcomeSignInFlow.phase` mapea `.failed` a `.error(retryable: true)` sin mirar `adoptClaimExit`, así que los
dos textos nuevos del efecto (`adoptEffectLocalFailure`, `adoptEffectStalled`) solo llegan a Almacenamiento. Y
`canGoBack` es `false` en `.adopting`: el «Cancelar» del efecto (ticket `adopt-effect-retries-forever-with-no-ceiling`)
existe solo en Ajustes.

## Qué habría que decidir (es de producto)

1. ¿El error del Welcome dice el motivo con los mismos textos de Almacenamiento?
2. ¿«Cancelar» (o la flecha atrás) durante el efecto en la bienvenida, y a dónde lleva?

## Relacionado

- `adopt-effect-retries-forever-with-no-ceiling`, `adopt-claim-stays-parked-with-no-ceiling`.

## Decisión (Jürgen 2026-09-23)

**A:** mismos textos por motivo que en Almacenamiento (`adoptEffectLocalFailure` / `adoptEffectStalled`), más Cancelar o flecha atrás durante el efecto en la bienvenida.

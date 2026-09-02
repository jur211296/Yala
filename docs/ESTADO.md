---
updated: 2026-09-02
tags: [now, punto-de-retomada]
---

# NOW — 2026-09-02 (Lima)

**Rama** `2.1` · **HEAD** `eebde759` — *PR #60: avisar a Grok cuando hay push directo a `2.1`*.
TestFlight build **12** (CPV 12). **Subida Yala (TF/store) = solo Mini.**

## Esta sesión
Cuando una sesión entrega empujando directo a `2.1` —la vía normal en el árbol principal— Grok no
se enteraba: su listener de GitHub ve el merge y el CI, pero no el push a principal. Ahora cada
push a `2.1` le manda quién empujó, cuántos commits, el SHA, si fue force push y los mensajes.
**La app no cambia**: es solo CI. Estrenado en su propio merge (PR #60) con **HTTP 200** medido.
Si el webhook deja de responder, el check sale en ROJO en vez de callar — que es como murió el
webhook de `bug-triage`, un mes entregando a un 404 sin que nadie lo notara.

## Abiertos
- **`welcome-fresh-start-alert-leaves-blank-screen`** (backlog, **high**) — tocar «Es mi primera vez»
  y luego cancelar deja la app sin ningún control, sin salida salvo matarla. Preexistente, medido con
  tres lanzamientos. Onboarding de usuario nuevo con datos previos, **en producción**.
- **`scheduled-payment-once-labeled-monthly`** (backlog, low) — un pago «una sola vez» se rotula
  «Mensual»: el badge lee `recurrenceType` y nunca mira `isRecurring`. Cosmético.
- **`AUDIT-appstore-guidelines.md`** — 3 hallazgos de riesgo de rechazo (divulgación de OpenAI). De Lola.

## Release 2.1 (sin cambios)
2.0.5 no se lanza; release = 2.1. A7 y M5: **HOLD, no flip**. Prod: CLOUD_MODE 100 · GROUPS_BACKEND
100 · CLOUD_ONBOARDING_CHOICE 0 · SECONDARY_SESSION 0. Cola C: 9 ACs owner/device, no corrida; D-R1
sigue sin `ok_`. **Cero `ok_` inventado.**

## Siguiente
De los 14 de `qa/`, **8 piden tu teléfono y 3 staging al 100** — no los drena un agente. Lo que
rinde: consolidar esos 11 en **un guion único de device-QA agrupado por montaje** (2 cuentas · 2
devices · flags), una tarde tuya en vez de once sesiones. Los 9 de `in-progress` siguen parados.

## Bloqueo
Ninguno. El canal a Grok respondió **200 en los dos pushes** de hoy (`eebde759`, `f09689b2`).
Pendiente menor: `GROK_WEBHOOK_SENDER_KEY` conserva su fecha de creación pese a la rotación del
panel — o se re-guardó igual, o la clave anterior sigue viva. Lo delataría un 401, y sale en rojo.

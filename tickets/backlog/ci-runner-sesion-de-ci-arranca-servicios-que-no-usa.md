---
id: ci-runner-sesion-de-ci-arranca-servicios-que-no-usa
status: backlog
priority: very-low
area: platform
created: 2026-09-30
source: PR #309 (CI propio fase 4, r2)
updated: 2026-10-08
---

# La sesión gráfica de `ci` arranca servicios que el runner no usa

El runner propio necesita una sesión Aqua de `ci`: sin ella, los tests van ~1.000× más lentos
(ver `.claude/rules/ci-propio.md`). Esa sesión arranca todo lo de una sesión normal de macOS.
Medido el 2026-09-30, en reposo: 312 procesos que suman 2,4 GB de RSS. La suma cuenta la memoria
compartida, así que el coste real anda por 1–1,5 GB. El runner ocupa 30 MB.

Lo que sobra:

- `mediaanalysisd` (100 MB), Siri, `duetexpertd`, Centro de control y Centro de notificaciones.
- Jump Desktop, que entra como ítem de inicio global.
- `com.apple.accessibility.heard`, que se relanzaba **cada segundo** en `gui/502` (lo muestra
  `log show` entre 13:08 y 13:09).

## Hecho cuando

- La sesión de `ci` ya no arranca esos servicios, o están justificados uno a uno.
- `accessibility.heard` deja de relanzarse.
- Se mide otra vez el reposo de `ci`, con la misma suma de RSS, y la cifra queda en la regla.

Está **aparcado con el runner** (decisión de Jürgen del 2026-09-30: Yala sigue público). Mientras
nadie use el runner, cerrar la sesión de `ci` libera lo mismo.

## Medido en 2.1 (triage 2026-10-08)

- El runner sigue aparcado: solo `ci-sombra.yml` usa `[self-hosted, yala-mini]`, y solo por `workflow_dispatch`; `qa.yml` sigue en `ubuntu-latest` y `macos-26`.

Triage 2026-10-08: abierto · low → very-low · sigue sin hacer, pero va atado a un runner aparcado mientras Yala sea público: tooling lejano.

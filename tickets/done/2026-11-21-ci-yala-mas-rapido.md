---
id: 2026-11-21-ci-yala-mas-rapido
status: done
priority: medium
area: platform
created: 2026-11-21
updated: 2026-11-21
source: "Jürgen aprobó las 7 propuestas de la auditoría de tiempos del CI, 2026-11-21 08:36"
---

# CI de Yala más rápido: las 7 mejoras de la auditoría

## Qué se pidió

Implementar las 7 propuestas de `docs/auditorias/2026-11-21-ci-tiempos.md` a 0 USD: caché de
compilación entre runs, nocturna a hora fija de madrugada, simulador durante el build y context-based
en paralelo, pure-logic en 3 tandas con un job final `tests`, `coverage-index` en paralelo, una card
por test de más de 20 s y tope de 10 min en `changes` y `coverage-index`.

## Qué se hizo

Detalle, mediciones y antes/después: sección «Resultados» de la auditoría y el cuerpo del PR.
La regla durable: `.claude/rules/ci-qa.md`.

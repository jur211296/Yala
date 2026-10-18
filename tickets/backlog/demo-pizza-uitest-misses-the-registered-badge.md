---
id: demo-pizza-uitest-misses-the-registered-badge
status: backlog
priority: medium
area: testing, chat
created: 2026-10-18
updated: 2026-10-18
source: gate de la implementación UX 2.2 · lotes 11 y 16 (encargo 2026-10-18-implementar-2-2-l11-l16-estadisticas-y-ajustes)
---

# `DemoIAPizzaUITests` no encuentra «Registrado» en la card del gasto

## Medido (2026-10-18, iPhone 17 Pro, iOS 27.0, `Yala Dev`)

- `test_registrarPizzaConYalaIA` cae en `DemoIAPizzaUITests.swift:116`: «La card no dice «Registrado»». Busca
  `app.staticTexts["Registrado"]` tras tocar `chat_draft_save`; el guardado sí ocurre (el paso anterior pasa).
- Rojo en la batería completa del gate (centinela «estuviste solo»), rojo aislado, y **rojo en `origin/2.2` limpio**
  (`2776b307e`, worktree aparte): no lo trae el cambio de los lotes 11 y 16.

## Hipótesis (sin medir)

El ✓ «Registrado» de la card ya no sale como `StaticText` con ese texto exacto (combinado con la fila, o con otro
texto tras algún lote de Yala IA). Mirar el árbol (`axe describe-ui`) tras guardar antes de tocar el test.

## Hecho cuando

El caso pasa en `2.2`, y si el cambio es del test, su consulta mira lo que la card pinta de verdad.

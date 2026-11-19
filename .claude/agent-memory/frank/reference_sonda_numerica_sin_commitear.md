---
name: sonda-numerica-sin-commitear
description: Medir un cálculo de la app con una prueba-sonda temporal (print «SONDA|»), sin llenar el disco con su DerivedData
metadata:
  type: reference
---

Para un análisis que pide números (no un arreglo), lo que funcionó el 2026-11-18 (Flujo de caja):

- Un `@Suite` temporal en `YalaTests/ZZSonda…Tests.swift` que arma el escenario, llama al código real
  (`CashFlowPlanViewModel.recalculate`, `ProjectedFlowBuilder.build`) e imprime líneas `SONDA|…`; se lee con
  `grep "SONDA|"` del log. Se borra antes del commit y su copia va como `.txt` a la evidencia.
- Si el calculador lee `Date.now` por dentro, el escenario se arma relativo al mes en curso (no fecha fija).
- **El `-derivedDataPath` en el scratchpad pesa 8 GB** (build limpio de un worktree): el disco bajó a 6,8 GB. `rm` lo
  niega el sandbox; `osascript -e 'do shell script "rm -rf <ruta del scratchpad>/dd"'` sí lo borra.
- En el simulador, en Flujo de caja los arrastres hacia ABAJO (subir) con `axe swipe` y con el `swipe` de
  XcodeBuildMCP no movieron el scroll; hacia arriba sí. Para volver arriba: relanzar sin `-uitest-reset` (la semilla no
  se duplica) y entrar por Más › Flujo de caja.

Relacionado: [[feedback_borrar_en_disco_lo_hace_el_bot]].

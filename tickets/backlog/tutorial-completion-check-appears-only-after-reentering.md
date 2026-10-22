---
id: tutorial-completion-check-appears-only-after-reentering
status: backlog
area: "ux, tutoriales"
priority: low
created: 2026-10-15
updated: 2026-10-15
source: "Barrido de QA 2.1 (Frank, 2026-10-15), visto en el simulador"
---

# Al terminar un tutorial, el ✓ no aparece hasta salir y volver a Tutoriales

## Qué pasa

Avatar › Ayuda › Tutoriales › «Registrar con Apple Pay» › … › «Listo» te devuelve a Tutoriales, y la fila de «Registrar con
Apple Pay» sale **sin** la marca de completado. Si sales de Tutoriales y vuelves a entrar, la marca ya está.

El tutorial sí queda guardado como completado: lo que falla es que la lista no se repinta.

Visto en el barrido de QA del 2026-10-15 en el simulador (Yala Dev, iPhone 17 Pro, iOS 27.0, `8cd693cb6`). Capturas:
`~/Claude/worktrees/_capturas/2026-10-15-barrido-qa-2-1/a8-6-tras-listo-sin-marca.png` y
`a8-7-al-volver-a-entrar-con-marca.png`.

## Medido en el código

- `TutorialCatalog.swift:156`: `isCompleted` lee `UserDefaults.standard.bool(forKey:)` directamente; no es estado que
  SwiftUI observe.
- `ApplePayAutomationGuideView.finish()` escribe la clave y hace `dismiss()`; `TutorialDetailView.swift:70` hace lo
  mismo para el resto de tutoriales.
- `TutorialsListView.swift:110` pinta el ✓ con `tutorial.isCompleted`, así que nada la obliga a recalcularse al volver.

## Hecho cuando

Al pulsar «Listo» en cualquier tutorial, la lista muestra el ✓ en cuanto vuelves, sin salir y entrar.

---
id: maintab-drain-publishes-its-sheet-after-contentview-may-drain
status: backlog
priority: low
area: "routing, presentaciones"
owner: frank
created: 2026-10-13
updated: 2026-10-13
source: "búsqueda del patrón en `drained-notice-lets-the-next-intent-drain-before-the-matrix-blocks`"
---

# Una hoja que abre MainTab al drenar se publica a ContentView un `onChange` después

Inferido, no medido. `MainTabView.drainMainTabIntents` abre su hoja y `navigation.isMainTabModalVisible` se actualiza
en su `onChange` (`ContentView.swift`, el `ownModalVisible` de MainTab). En esa ventana, el drenaje de `.contentView`
ve la matriz libre y UIKit aún sin nada presentado, así que un aviso diferible podría salir encima. Es la misma forma
que el ticket hermano (el bloqueo lo publica un observador que corre después del `onChange(revision)`), en el otro
consumidor.

## Qué falta

Medirlo antes de tocar nada: DIAG en los dos drenajes y un caso con un intent de MainTab y uno diferible de
`.contentView` encolados juntos, en iOS 26.5 (CI), que es donde el orden de los `onChange` lo destapó.

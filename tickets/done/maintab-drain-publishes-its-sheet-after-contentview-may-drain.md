---
id: maintab-drain-publishes-its-sheet-after-contentview-may-drain
status: done
priority: low
area: "routing, presentaciones"
owner: frank
created: 2026-10-13
updated: 2026-10-25
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

## Hecho (2026-10-25, lote 12.7, card pvwt) — cierre estructural, sin la carrera medida

No se pudo medir: esta Mac no tiene runtime iOS 26.5 (solo 27.0), que es donde el orden de los `onChange` destapó al
hermano. Se cierra por construcción, en las dos mitades:
1. `drainMainTabIntents` publica `isMainTabModalVisible` justo después de manejar el intent, leyendo el `@State` real
   (`ownModalVisible`): un manejador que decide no presentar no deja el flag puesto.
2. `drainContentViewIntents` re-mide la matriz VIVA antes de `drainNext` (tras el derribo B4-04): tapada, bloquea por
   `updateContentViewReadiness` y no drena. Cubre cualquier otro consumidor que publique tarde, no solo MainTab.
Pines: `ContentViewReadinessReleaseWiringTests#drain_remeasuresTheLiveMatrix_beforeDraining` y
`#mainTabDrain_publishesItsSheetInTheSameTurn`. Si el CI de 26.5 vuelve a enseñar una oferta encima de una hoja de MainTab,
se reabre con `NSLog` en los dos drenajes.

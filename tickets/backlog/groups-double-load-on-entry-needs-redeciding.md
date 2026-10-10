---
id: groups-double-load-on-entry-needs-redeciding
status: backlog
priority: very-low
area: "groups, performance"
created: 2026-10-05
updated: 2026-10-08
source: tickets/qa/groups-tab-missing-panel-perf.md
---

# Grupos: al entrar en la lista o en un grupo se lee dos veces del disco, y la razón para dejarlo ya no existe

Sale de `groups-tab-missing-panel-perf` el 2026-10-05, donde era el único criterio que no se cierra mirando.

## Lo que le pasa a quien usa la app

Nada visible. Al abrir la pestaña Grupos o el detalle de un grupo, la app lee del disco y recalcula los saldos
una vez al montar la pantalla y otra vez cuando vuelve el refresco remoto que lanza al entrar. Con muchos gastos
es trabajo repetido en el momento en que la pantalla aparece.

## Lo medido (2026-10-05, sobre `a7b37a5f2`; las coordenadas derivan, re-mídelas antes de tocar)

- Lista: `GroupsContainerView.swift:259` (`setContext` → `loadData()`) y `:280` (`refreshFromCloud(force: false)`,
  que en `GroupsViewModel.swift:239-243` hace `loadData()` tras `syncNowFromUI()`).
- Detalle: `GroupDetailView.swift:252` y `:255`, el mismo par.
- La razón que lo difirió en julio era una propiedad de `SplitSyncManager` («`syncNow` no bumpea `dataVersion`»), y
  ese fichero ya no existe (borrado en `2f96ad84`, 2026-08-06). El canal de hoy, `GroupsSyncClient`, **sí** bumpea
  `dataVersion` por ciclo cuando el pull aplica cambios (`GroupsSyncClient.swift:88-98`), y lista y detalle ya
  reaccionan a eso con el freno de 150 ms (`RecalculationDebouncer`).

## Qué hay que decidir

Si el `loadData()` de después de `refreshFromCloud(force: false)` sobra ahora que el pull bumpea y el freno
recarga. Antes de quitarlo, mide qué pasa cuando el pull **no** bumpea: sin sesión de nube, con el kill remoto, o
en las salidas tempranas de `pullUntilExhausted` (`.transient`, sesión caducada, cap de iteraciones), que aplican
páginas sin subir `dataVersion` (`.claude/rules/swiftui-ds.md`, el live-binding de Grupos). Ahí el segundo
`loadData()` es la única recarga, y quitarlo dejaría la pantalla con datos viejos.

## Criterios

- [ ] Medido qué caminos de `refreshFromCloud(force: false)` terminan sin bumpear `dataVersion`.
- [ ] Decidido, con esa medida, si el segundo `loadData()` se quita, se condiciona a «no hubo bump» o se queda.

## Medido en 2.1 (triage 2026-10-08)

- El par sigue igual: lista en `GroupsContainerView.swift:259` (`setContext`) y `:280` (`refreshFromCloud(force: false)`); detalle en `GroupDetailView.swift:252` y `:255`. `GroupsViewModel.refreshFromCloud` sigue haciendo `syncNowFromUI()` y luego `loadData()`.
- Sin commits en los tres ficheros desde el 2026-10-05. No hay síntoma visible: es trabajo repetido al montar.

Triage 2026-10-08: abierto · low → very-low · la doble lectura sigue, sin síntoma visible; es una optimización que antes pide medir los caminos sin bump.

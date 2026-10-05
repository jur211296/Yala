---
id: scene-phase-active-guard-may-leave-the-brake-paused
status: backlog
priority: low
area: "performance, groups, panel"
created: 2026-10-05
updated: 2026-10-05
source: tickets/qa/groups-tab-missing-panel-perf.md
---

# Al volver a primer plano, un `guard` puede dejar el freno de recálculo en pausa hasta el siguiente cambio de fase

**Hipótesis sin medir.** La levantaron dos lentes independientes de la review adversarial del 2026-10-05
(`groups-tab-missing-panel-perf`, punto 2). Nadie ha visto que ocurra.

## Lo que le pasaría a quien usa la app

Al volver a Yala, una pantalla dejaría de actualizarse con los cambios que llegan —de otro aparato o del sync—
hasta que la app vuelva a pasar por segundo plano. Sin error y sin aviso: los números se quedan quietos.

## El mecanismo, leído en el código (`a7b37a5f2`)

Las pantallas con freno de recálculo hacen esto al cambiar de fase (molde: `GroupDetailView.swift:268-279`):

```swift
case .background, .inactive:
    viewModel.setBackground(true)
case .active:
    guard UIApplication.shared.applicationState == .active else { return }
    viewModel.setBackground(false)
    viewModel.reloadAndRecalculate()
```

Si `scenePhase` llega a `.active` mientras `UIApplication.shared.applicationState` todavía no lo es, el `return`
se salta `setBackground(false)`, y el freno sigue creyendo que la app está en segundo plano: ignora todo
`reloadAndRecalculate()` hasta la próxima transición de fase. Desde el 2026-10-05 los Ajustes del grupo cuelgan
del freno del detalle, así que lo heredan.

El mismo `guard` está en **10 sitios**: `ScheduledPaymentsViewModel.swift:841`, `PanelViewModel.swift:2576`,
`BudgetsViewModel.swift:813`, `RecordsStandaloneView.swift:143`, `DetailContainerView.swift:170`,
`GroupsContainerView.swift:304`, `GroupDetailView.swift:273`, `PanelView.swift:370` y
`FinancialReportView.swift:125` y `:409`. No todos llaman a un `setBackground`: hay que mirarlos uno a uno.

Con varias ventanas (iPad), `scenePhase` es el de la ventana y `applicationState` el del proceso, que es justo donde
los dos pueden discrepar.

## Qué hay que hacer

- [ ] Medir si iOS entrega alguna vez `scenePhase == .active` con `applicationState != .active` (traza en DEBUG en
      uno de los sitios; probar vuelta desde el multitarea, desde el Centro de Control, Face ID y, en iPad, dos
      ventanas).
- [ ] Si ocurre, decidir el arreglo para los 10 sitios a la vez: separar el `setBackground(false)` del `guard`, o
      dejar que el `reloadAndRecalculate()` posterior lo reintente. Si no ocurre, cerrar este ticket con la medida.

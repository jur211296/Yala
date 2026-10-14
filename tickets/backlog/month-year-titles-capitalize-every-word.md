---
id: month-year-titles-capitalize-every-word
status: backlog
priority: low
area: "copy, l10n, panel, planning"
created: 2026-10-14
updated: 2026-10-14
source: "auditoría UX 2.2 · lote 8 (B5), visto fuera del lote"
---

# Los títulos de mes con año salen «Octubre De 2026» fuera de Registros

## Qué pasa

El mes con año se formatea con la plantilla `MMMMyyyy` y luego pasa por `.capitalized`, que pone mayúscula en
**cada palabra**: en español sale «Octubre De 2026» (y en portugués «Outubro De 2026»). En el calendario de Registros
quedó arreglado en el lote 8 (`String.capitalizingFirstLetter(locale:)`, PR #499), pero el mismo patrón sigue en
(medido con `grep -rn "\.capitalized" Yala/App` el 2026-10-14):

- `Yala/App/ViewModels/PanelViewModel.swift` — `periodLabel` del Panel.
- `Yala/App/ViewModels/BudgetsViewModel.swift` y `Yala/App/Views/Planning/BudgetChartsView.swift`.
- `Yala/App/Views/Planning/Components/BudgetPeriodSelectorSheet.swift` y `BudgetChartsPeriodSelector.swift`.
- `Yala/App/ViewModels/ScheduledPaymentsViewModel.swift` y `ScheduledPaymentPeriodSelectorSheet.swift`.

No se tocó por el alcance estricto del lote 8.

## Qué hacer

Cambiar `.capitalized` por `.capitalizingFirstLetter(locale: AppLocale.current)` en esos sitios, y que sus
formatters usen `AppLocale.current` (no `.current`) para seguir el idioma elegido dentro de Yala. Ojo con los
selectores que solo pintan el mes sin año: ahí `capitalized` no se nota, pero el cambio es igual de seguro.

## Hecho cuando

Ninguna pantalla enseña «De» con mayúscula en un mes con año, en español y en portugués.

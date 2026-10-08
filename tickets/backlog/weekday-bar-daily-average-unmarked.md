---
id: weekday-bar-daily-average-unmarked
status: backlog
priority: low
area: "currency, ui"
created: 2026-09-09
updated: 2026-10-08
source: device-QA de fx-approximate-mark-missing-on-secondary-surfaces (2026-09-09)
---

# Dos tarjetas llamadas «Promedio diario», una marcada y la otra no

## Qué le pasa al usuario

En Estadísticas hay dos tarjetas con el rótulo literal **«Promedio diario»**, en pestañas hermanas.
Medido en simulador el 2026-09-09 con el mismo lanzamiento (iPhone 17 Pro, iOS 26.5, `Yala Dev`,
`-uitest -uitest-reset -uitest-skip-onboarding -uitest-seed realista -uitest-seed-foreign-account JPY`,
período «Este mes»):

| dónde | clave del rótulo | lo que se ve |
|---|---|---|
| Estadísticas → **Resumen** → «Tus cifras» | `insights.dailyAverage` | **`≈ S/ 519.22`** |
| Estadísticas → **Tendencias** → «Gasto promedio por día» | `panel.weekdayBar.smallTitle` | **`S/ 3,944.00 /semana`** |

Capturas: `qa/evidencia-fx-20260909/07-resumen-promedio-diario-CON-marca.png` y
`06-tendencias-flujo-marcado-promedio-sin-marca.png`.

Los dos salen del mismo gasto del mismo período, del que la app ya declaró que **parte de su
conversión no usó la tasa del día**. Uno lo dice y el otro no.

## Dónde, medido

`Yala/App/Views/Panel/WeekdayBarPanelWidget.swift`:

- `:36` — `AmountText(` del total, **sin** `isEstimate:` (el default de `AmountText.isEstimate` es
  `false`, `AmountText.swift:32`).
- `:137` — `appPreferences.currency(entry.average, currencyCode: currencyCode)`, también sin él.
- `:30` — `weekTotal = data.reduce(0) { $0 + $1.average }`.

## Lo que sí es un desglose y lo que no

Esta distinción es la que decide el alcance, y conviene no perderla:

- **Los siete valores por día de la semana SÍ son buckets.** La señal del período no se puede
  repartir por día sin marcar uno cuyas conversiones pudieron ser exactas — es exactamente lo que
  [[fx-per-bucket-approximate-signal-missing]] deja fuera a propósito, y esa decisión no se toca.
- **`weekTotal` NO es un bucket**: es la suma de los siete promedios, o sea un agregado del período
  entero, igual que el «Promedio diario» de Resumen. Ése es el que puede y debe marcar.

Es otra vez el corolario del `CLAUDE.md`: la tabla del ticket padre nombraba `InsightsTabView.swift:546`
para «Promedio diario» y había **otra** superficie con el mismo rótulo y la misma magnitud.

## Además se ve en el Panel

`WeekdayBarPanelWidget` no vive sólo en Estadísticas: `PanelWidgetSection.swift:679` lo monta
también como widget del Panel (oculto por defecto, `PanelDefaults.swift:56`). O sea que la
incoherencia puede quedar **en la misma pantalla** que el número grande que sí marca, para quien lo
active.

## Criterio de hecho (AC)

- [ ] El total del widget lleva la marca cuando el gasto del período la lleva, y no la lleva cuando
      no. Los siete valores por día **siguen sin marca**, y el motivo queda escrito en el docblock.
- [ ] La señal llega por el carril que ya existe (`CashFlowSummary` / el productor de
      `WeekdaySpending`), sin inventar un segundo criterio ni un `0.05` suelto.
- [ ] Un test que falle si se pierde el cableado, y un caso que distinga el total del bucket.
- [ ] Comprobado que el widget del **Panel** y el de **Estadísticas** dicen lo mismo a la vez.

## Relacionados

- [[fx-approximate-mark-missing-on-secondary-surfaces]] — la tanda que cubrió las otras superficies.
- [[fx-per-bucket-approximate-signal-missing]] — por qué los siete días se quedan sin marca.
- [[pie-header-total-unmarked]] — el otro agregado de período que quedó sin marca, hallado a la vez.

## Medido en 2.1 (triage 2026-10-08)

- El total se llama hoy `weeklyAverage` (`WeekdayBarPanelWidget.swift:29-31`, antes `weekTotal`). Su `AmountText` (`:36`) sigue sin `isEstimate:`.
- Los siete buckets (`:137`) siguen sin marca, y eso es lo correcto.
- Ningún commit tocó el fichero desde el 2026-09-09.
- `pie-header-total-unmarked` es otra superficie, sigue abierto y no es un duplicado.

Triage 2026-10-08: abierto · medium → low · El AmountText del total semanal sigue sin isEstimate; el gemelo pie-header-total-unmarked es otra superficie y sigue abierto

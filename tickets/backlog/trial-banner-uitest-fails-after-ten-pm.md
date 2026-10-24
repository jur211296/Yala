---
id: trial-banner-uitest-fails-after-ten-pm
status: backlog
priority: low
area: "pro, testing"
created: 2026-10-23
updated: 2026-10-23
source: "gate del encargo «Conectar Gmail mínimo» (2026-10-23), medido contra la base"
---

# El XCUITest del banner de la prueba falla si se corre después de las 22:00

## El problema

`YalaProLote06UITests#test_trialBanner_lastFiveDays_showsDaysPriceAndManage` espera «Te quedan 3 días de prueba» y,
corrido a las 22:20 de Lima, ve «Te quedan **4** días». Falla igual **con y sin** los cambios del encargo
(medido las dos veces el 23-oct-2026, centinela del simulador limpio). La app no tiene el bug: es el seam del test.

## Por qué pasa (leído; la hora de la corrida lo confirma)

`StoreKitManager.applyUITestPlan` fija el fin de la prueba en `ahora + días × 24 h + 2 h`, con el comentario
«`trialDaysRemaining` trunca y un "3 días" exacto daría 2». Ya no trunca: `trialDaysRemaining` cuenta **días de
calendario** (`ProPlanStatusLogic.calendarDaysRemaining`). Desde las 22:00 locales, esas 2 h de margen cruzan la
medianoche y la cuenta da un día más.

## Qué hacer

Que el seam fije el fin en el **mismo momento del día** n días después (`Calendar.date(byAdding: .day, value: n,
to: .now)`), sin margen, y corregir el comentario. Comprobar con la hora del simulador o del Mac pasadas las 22:00
y antes de las 02:00.

## Criterios de aceptación

- [ ] El test pasa corrido a cualquier hora (probado a las 23:30 y a las 10:00).
- [ ] Ningún otro uso de `-uitest-pro-trial-days` cambia su número.

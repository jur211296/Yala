---
id: flujo-de-caja-nutre-el-proyectado
status: qa
priority: medium
area: "Flujo de caja, Tendencias, Panel"
created: 2026-11-06
updated: 2026-11-07
source: "card del tablero «Mejorar la experiencia del flujo de caja para que nutra el Flujo proyectado» (versión 2.3)"
---

# El flujo de caja nutre el Flujo proyectado

## La idea, en lenguaje de usuario

Jürgen eligió que «Ver proyectado» use el plan de flujo de caja cuando existe, pero casi nadie lo arma. Esta card hace
que el plan alimente bien el proyectado y que se llegue a él desde el proyectado.

## Lo medido en `origin/2.3` (2026-11-06)

- **Con plan, el gasto fuera de sus líneas no se proyectaba.** `ProjectedFlowBuilder.build` tomaba de un lado solo «lo
  que falta» de las líneas del plan; «Otros gastos» (`CashFlowProjectionCalculator.calculateUncategorizedTotal`) solo
  existe para meses pasados y el actual, y como real. El plan que arma la pantalla de inicio marca solo las categorías
  con actividad en 4 de los últimos 6 meses: un plan normal dejaba fuera parte del gasto, y el cierre proyectado salía
  más optimista que sin plan.
- **Del proyectado no había camino al plan.** La cifra decía «Estimado con tu ritmo de gasto» y nada más; el plan vive
  en Reportes › Flujo de caja, que ya lo arma en una pantalla con líneas sugeridas (`CashFlowSetupView`).
- **Armar el plan ya es un paso**: la pantalla de inicio sugiere las líneas con sus importes y el saldo de hoy; las
  líneas se mantienen solas (promedios). Lo que no está en el plan ya se ve en «Otros gastos» con «+» para añadirlo.

## Hecho

1. **Lo que no cubre ninguna línea sigue al ritmo** (`ProjectedFlowBuilder.PlanCoverage` + `rhythmPerDay(excluding:)`):
   ritmo de los últimos 90 días de los movimientos que ninguna línea activa cubre (regla de «Otros»: la línea con
   subcategoría cubre esa subcategoría; sin ella, la categoría entera; por lado; lo sin categoría no lo cubre nadie),
   sumado a lo que falta del plan. Test `plan_spendingOutsideItsLinesFollowsTheRhythm` (muere con el mutante que quita
   la exclusión).
2. **Enlace bajo «Proyectado al cierre»**, en Tendencias y el Panel: sin plan «Afinar con un plan de flujo de caja»,
   con plan «Ver tu plan de flujo de caja»; abre Reportes › Flujo de caja. No sale en «Solo gastos». Textos en los 16
   idiomas. XCUITest `test_trends_projectionWithoutAPlan_linksToSettingUpTheCashFlowPlan`.
3. **En la pantalla de armar el plan**, bajo «¿Qué es el flujo de caja?»: «Con tu plan, «Ver proyectado» en Tendencias y
   en el Panel estima el resto del mes con estas cifras» (con el nombre de cada pantalla en su idioma: Home, Übersicht,
   Inicio…). Opción A de la pregunta 3.

## Preguntas a Jürgen y respuestas

Enviadas al bot el 2026-11-07 a las 5:00 (regla nocturna). Jürgen, 2026-11-07: **A/A/A**.

1. Lo que queda fuera del plan: ritmo de los últimos 90 días, sumado al plan.
2. El enlace bajo la cifra, siempre, con texto distinto según haya plan o no.
3. Se explica dentro de Flujo de caja, sin avisos en el Panel.

## Guion de QA (iPhone de pruebas, Yala Dev)

1. Sin plan: Estadísticas › Tendencias, período «Este mes», «Ver proyectado» encendido. Bajo la cifra sale «Afinar con
   un plan de flujo de caja». Tócalo: abre Reportes › Flujo de caja con «¿Con cuánto empiezas?».
2. Crea el plan con lo sugerido. Vuelve a Tendencias: la fuente dice «Estimado con tu plan de flujo de caja» y el enlace
   pasa a «Ver tu plan de flujo de caja».
3. Compara la cifra al cierre con la que daba sin plan: ya no debe caer de golpe por las categorías que el plan dejó
   fuera.

---
id: cashflow-this-and-future-adjustment-rewrites-past-months
status: backlog
priority: medium
area: cash-flow-plan
created: 2026-10-16
updated: 2026-10-16
source: auditoría UX 2.2, lote 18 (Reportes) — medido en el simulador
---

# «Este mes y futuros» cambia también el plan de los meses pasados y del mes en curso

**Clase:** bug de cálculo que pide una decisión de modelo. No se arregló en el lote 18: la salida limpia toca el
esquema de SwiftData y de CloudKit.

## Qué pasa

En el plan de flujo de caja, al ajustar el monto de una línea en un mes futuro y elegir «Este mes y futuros», el
monto nuevo se aplica a TODOS los meses del plan, también a los pasados y al mes en curso. La pregunta promete
«solo a este mes, o también a los meses futuros».

## Medido (simulador, 2026-10-16, semilla `realista`, Pro)

Salario estimado en 8.500. En noviembre, «Ajustar monto» → 9.000 → «Este mes y futuros».

- Setiembre (pasado): su neto en la tira pasó de +2.624 a +3.124.
- Octubre (en curso): Salario pasó a «94 %» (8.500 de 9.000), los ingresos del mes de 10.673,75 a 11.173,75 y el
  acumulado de 3.283 a 3.783.

Capturas: `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-18-reportes/capturas/18.5-05-alcance-del-ajuste.png`,
`18.5-06-tras-ajustar.png`.

## Causa (código)

`CashFlowPlanViewModel.setOverrideAndUpdateFuture` guarda el ajuste del mes y además cambia el método de la línea a
«monto fijo» con el monto nuevo (`line.estimationMethod = .manual`, `line.manualAmount = amount`).
`CashFlowProjectionCalculator.calculateLineResult` estima con el método de la línea en TODOS los meses del rango, y
los totales del mes (`totalIncome`, `totalExpense`, `netFlow`, el acumulado) suman lo estimado también en meses
pasados. No hay un «desde qué mes» en ningún sitio.

## Opciones

- **A.** La línea guarda desde qué mes vale el monto nuevo (campo nuevo en `CashFlowLine`): antes de ese mes se
  sigue estimando como antes. Es lo correcto, pero es un campo nuevo del contenedor personal: va a los cuatro
  `Cloudkit Schemas/yala*.ckdb` y se despliega a Production antes del build (regla de `swiftdata-cloudkit.md`), y en
  el canal de la nube necesita su columna. Ojo con el ticket hermano
  `personal-cloudkit-cashflow-override-line-declared-as-reference`.
- **B.** Al elegir «y futuros», guardar los meses anteriores del rango como ajustes con su monto de antes. Sin
  cambio de esquema, pero esos meses dirían «Monto ajustado manualmente» sin que nadie los ajustara.
- **C.** Cambiar el texto a «Todos los meses»: honesto con lo que hace hoy, sin tocar el modelo.

Recomendación: A.

## Hecho cuando

Ajustar un mes «y futuros» no cambia el estimado de ningún mes anterior al elegido, con un test de la proyección
que lo fije (control: el mes elegido y los siguientes sí cambian).

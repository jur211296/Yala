---
id: figures-that-dont-add-up-lote-02-necessary-2-3
status: done
priority: high
area: estadisticas
created: 2026-11-10
updated: 2026-11-10
source: lote 02 de la consolidación de mejoras necesarias 2.3 (docs/ux/revision-vistas-2.3/consolidacion-necesarias-2026-11/ficha.md), card tablero-mejoras-necesarias-2-3-cifras-que-no-cua-efqj
---
# Cifras que no cuadran: ritmo, desglose de presupuesto, día más caro y céntimo del reparto

Cuatro defectos objetivos de cifras, en 2.3. Ninguno estaba arreglado en 2.2 (`git log origin/2.3..origin/2.2` vacío en
sus zonas el 2026-11-10).

1. **Flujo proyectado sin plan.** El ritmo repartía por día el ingreso medio de 90 días y volvía a contar el sueldo ya
   cobrado: «Proyectado al cierre» bajaba de S/ 76,613 a S/ 69,390 solo con crear el plan sugerido. Decisión de Jürgen
   (2026-11-10): «lo que falta del mes» en ingreso y gasto — previsto = ritmo × días del mes, menos lo que el mes ya
   tiene (real o fechado), repartido en los días que quedan. Igual para lo que el plan no cubre.
   (`ProjectedFlowBuilder.rhythmLeftOfEachMonth`; tests `builder_rhythmWithoutPlan_*`).
2. **«Por categoría» de las gráficas de un presupuesto** saltaba lo que no tenía subcategoría y no sumaba lo gastado si
   el presupuesto filtraba por cuenta o etiqueta. Ahora suma lo gastado, con «Sin categoría» (gris) y «Sin
   subcategoría» bajo su categoría (`BudgetsViewModel.combinedBreakdown`; `BudgetBreakdownSumsSpentTests`).
3. **«Día de más gasto» (Resumen) y «tu día más caro» (Tendencias)** salían de dos cálculos. Ahora de una entrada
   (`WeekdaySpendingCalculator.forStatistics`): con «Todo» no cuenta lo fechado a futuro, el chip Ingresos no lo esconde,
   y Tendencias recalcula al cambiar el rango personalizado (`WeekdayPriciestDayParityTests`).
4. **Reparto «Monto»** aceptaba 0,02 de diferencia: 399,99 de 400 decía «Balanceado», se guardaba y el céntimo no era
   de nadie (las deudas salen de las partes; el pagador puso 400). Decisión de Jürgen (2026-11-10): no se guarda hasta
   cuadrar; «Porcentaje» tiene que sumar 100 (antes 0,1 % de margen que iba al último). Reabrir un gasto o plantilla por
   porcentaje los normaliza a 100 para no bloquear la edición de lo ya guardado (`GroupSplitCalculatorTests`,
   `GroupExpenseViewModelTests`).

Cada test se comprobó rojo con el comportamiento viejo (mutante) y verde con el arreglo. Review adversarial con dos
lentes: sin bugs de cifra en el ritmo; cazó la regresión de reabrir porcentajes (arreglada) y el rango personalizado de
Tendencias (arreglado).

**Consecuencia a saber.** Un gasto guardado antes con partes que no cuadraban al céntimo (p. ej. 133,33 × 3 de 400) pide
cuadrarlo al editarlo («Faltan S/ 0.01»): es la decisión de no guardar sin cuadrar.

**Hallazgo aparte:** `projected-flow-with-plan-counts-a-future-dated-row-twice-in-a-future-month`.

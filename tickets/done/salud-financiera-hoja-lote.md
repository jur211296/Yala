---
id: salud-financiera-hoja-lote
status: done
priority: medium
area: "panel, salud-financiera"
created: 2026-11-23
updated: 2026-11-23
card: tablero-salud-financiera-la-hoja-con-contraste-y-fqbr, tablero-salud-financiera-un-presupuesto-nuevo-cu-aqm9, tablero-salud-financiera-el-resumen-de-yala-ia-m-ssvw
source: "Jürgen en su iPhone con la build de TestFlight de 2.3 (22 y 23-nov-2026)"
---

# Salud financiera: hoja con el estilo del Panel, presupuesto nuevo que cuenta ya y negritas de Yala IA

Tres cards de la hoja «Tu salud financiera», en un lote.

## Hecho cuando

1. Las tarjetas de la hoja llevan el fondo, el borde, el radio y el aire entre secciones de las del Panel, y las cápsulas
   de arriba son chips que se ven tocables, sin la flecha de desplegar.
2. Con un solo presupuesto pasado creado a mitad de mes, la nota baja y el consejo dice por qué; desaparecen «empieza a
   contar en tu nota el…» y la cápsula «Desde el…». La línea «La nota no ve» del Panel ya no lista presupuestos.
3. El resumen de Yala IA pinta sus negritas, sin asteriscos.

## Resolución (2026-11-23)

- `FinancialScoreCalculator.bucketIsValid`: cuenta el período en que se creó el presupuesto (`bucket.end > día de
  creación`); los anteriores, no. La historia de la hoja hereda la regla.
- Fuera `cuentaDesde`, `presupuestoQueAunNoCuenta`, `MotivoSinNota.desde`, `Consejo.presupuestoEmpiezaACuenta`,
  `FinancialScoreAlerts.OverBudget.countedByScore` y `Unseen.overBudget`, con sus claves en los 16 idiomas.
- Hoja: `solidCard(radius: DS.Panel.widgetRadius)`, `DS.Spacing.xxl` entre secciones, cápsulas `.thCard` con borde.
- Yala IA: `L10n.SaludFinancieraDetalle.iaCuerpo` pasa por `AIInsightCardComponents.markdownAttributed`. Estadísticas ›
  Observaciones ya la usaba (medido): no tenía el fallo.
- Pruebas: `YalaTests/SaludFinancieraHojaLote/` (9 casos; el de la nota cae con la regla vieja) y
  `YalaUITests/SaludFinancieraHojaLote/` (2 casos).

Queda fuera: la hoja de la parte «Presupuestos» de Estadísticas › Observaciones conserva «Tu presupuesto empieza a contar
el mes que viene» para el caso raro sin nota con presupuestos (p. ej. «Mes pasado» con uno creado este mes).

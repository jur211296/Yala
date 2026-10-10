---
id: cashflow-spend-prediction
status: backlog
priority: low
area: reports
created: 2026-07-01
updated: 2026-10-08
source: YalaWiki/Ideas/Predicción de gasto dentro de línea de gasto en flujo de caja.md
---


# Predicción de gasto dentro de línea de gasto en flujo de caja

## La idea
>

## Por que importa
>

## Notas
- Capturado originalmente en Inbox sin desarrollo; reubicado en la limpieza del vault del 2026-07-01.

migrated from YalaWiki Ideas/Predicción de gasto dentro de línea de gasto en flujo de caja.md @ 1934e8ad

## Medido en 2.1 (triage 2026-10-08)

- El plan de flujo de caja ya estima cada línea en los meses futuros (`EstimationMethod`: promedio 6m y 3m, mes anterior, programado, manual; `CashFlowAddLineSheet`, desde el 2026-03-17), y la hoja de gráficas trae proyección.
- Lo que no existe es proyectar el mes EN CURSO de una línea por su ritmo: lo gastado hasta hoy → cierre estimado del mes.
- **Decisión:** A) proyección a fin de mes por ritmo en la celda del mes en curso; B) darla por cubierta con la estimación y descartarla. **Recomendada: A**, con prioridad `low`.

Triage 2026-10-08: abierto · sin prioridad → low · idea válida; la estimación existente cubre los meses futuros, no el mes en curso.

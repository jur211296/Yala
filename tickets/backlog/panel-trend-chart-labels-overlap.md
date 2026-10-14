---
id: panel-trend-chart-labels-overlap
status: backlog
area: panel
priority: low
created: 2026-10-13
updated: 2026-10-13
source: auditoría UX 2.2, lote 3 (el Panel)
---

# Gráfica de saldo del Panel: las dos últimas fechas del eje se pisan y «Hoy ⓘ» tapa la etiqueta de arriba

## Qué se vio (medido en el simulador, 2026-10-13)

Panel con «Todo el tiempo» y dos años de datos (seed `realista` + cuenta en EUR): el eje X pone
«abr 26» y «oct 26» encima uno del otro («abr 26oct 26»), y la píldora «Hoy ⓘ» cae sobre la etiqueta
más alta del eje Y («Hoy ⓘ 00K»). Captura: `3.1-todo-el-tiempo-disponible-vs-tienes.png` en
`~/Claude/entregas/Yala--auditoria-ux-2-2-lote-3-panel/capturas/`.

## Inferido, sin medir

La última etiqueta del eje X se ancla a la derecha (`SmartAxisHelper.axisLabelAnchor`) y cae a pocos
puntos de la anterior cuando «hoy» queda cerca del último corte de seis meses. La píldora se coloca a
`DS.Spacing.md` del borde superior del área de dibujo, en la misma franja que la etiqueta trailing.

## Por qué no se arregló en el lote 3

`SmartAxisHelper` lo comparten las gráficas del Panel, Estadísticas y Reportes: tocar el anclaje es un
cambio transversal que necesita su propio barrido de capturas, fuera del alcance estricto del lote.

## Acceptance Criteria

- [ ] Ninguna pareja de etiquetas del eje X se solapa con «Todo el tiempo», «Este año» y «Este mes».
- [ ] «Hoy ⓘ» no tapa ninguna etiqueta del eje Y.
- [ ] Capturas antes/después en el Panel y en Estadísticas › Tendencias.

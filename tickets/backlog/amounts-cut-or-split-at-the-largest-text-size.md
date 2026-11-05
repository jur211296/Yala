---
id: amounts-cut-or-split-at-the-largest-text-size
status: backlog
priority: high
area: "a11y, design-system, iphone"
created: 2026-11-05
updated: 2026-11-05
source: "barrido final de QA 2.2 (2026-11-05), card tablero-con-el-texto-al-maximo-cifras-cortadas-o-vd5r"
---

# Con el texto al máximo, cifras cortadas o partidas

## Qué le pasa al usuario

Con el texto en los tamaños de accesibilidad hay importes que no se leen enteros (iPhone 17 Pro y 17e, iOS 27.2,
oscuro, AX5):

1. **Panel › Tendencias**: «S/54,5….64» y «Ingresos S/254,….30»: la elipsis cae en medio de la cifra.
2. **Hoja «Esto entendí» de voz**: el importe del borrador se parte en líneas («S/ / 25.0 / 0»).
3. **Estadísticas › Resumen**: las fichas «Categoría principal / Subcategoría principal» parten las palabras en sílabas
   y cortan el importe («S/ 67,3…»).
4. **Lista de Pagos planificados en el iPad**: «-S/ 60…», «-S/ 1…» (`/Users/max-jur/Claude/worktrees/_capturas/barrido-qa-2-2-final/ipad13/oscuro-ax5/06-pagos-planificados.png`).
5. **Detalle de un pago planificado**: «Ya lo pagué / Saltar este mes» salen «Ya lo… / Salta…».

De paso, ya conocido: el eje de fechas de Tendencias se solapa y «Hoy» tapa «Promedio 28K»
([[large-text-leftovers-outside-the-main-iphone-screens]], punto 5).

## Propuesta

Filas concepto-importe con `AdaptiveRowStack`; los botones del pago, apilados a tamaños de accesibilidad como la
cabecera de Grupos (PR #771). Una cifra nunca con elipsis en medio: escala (`minimumScaleFactor`) o baja de línea entera.

## Evidencia

`/Users/max-jur/Claude/worktrees/_capturas/barrido-qa-2-2-final/iphone17pro/oscuro-ax5/01b-panel-abajo.png`, `09-voz-uno.png`, `04b2-estadisticas-abajo2.png`,
`06b-pago-detalle.png`; `/Users/max-jur/Claude/worktrees/_capturas/barrido-qa-2-2-final/iphone17e/oscuro-ax5/09-voz-uno.png`.

## Hecho cuando

A AX5 en el iPhone 17e las cuatro cifras se leen enteras y los dos botones del pago sin cortar; a tamaño normal nada
cambia (diff de píxeles).

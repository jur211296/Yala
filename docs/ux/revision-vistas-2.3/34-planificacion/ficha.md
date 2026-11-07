# Revisión por vistas 2.3 · Planificación: presupuestos y pagos planificados

**Qué es.** Revisión de UX de la zona 34 del mapa de cobertura, sobre `origin/2.3` del 7-nov-2026. No cambia la app y no
elige: deja seis problemas priorizados, cuatro alternativas maquetadas para cada uno y una recomendación. Decide Jürgen.

**Cómo abrirla.** `index.html` en el navegador (las páginas enlazan entre sí y las capturas van en `capturas/`). Desde el
móvil, `revision-planificacion.pdf`, con lo mismo.

**El caso.** Sábado 7 de noviembre. «Comidas fuera» va al 90 % y «Salidas con amigos» al 118 %; Ana quiere sacar
«Supermercados y bodegas» de «Comidas fuera». En Pagos, el Alquiler (S/ 2,200) venció el 5, el Teléfono vence el 15 y el
Gimnasio ya está pagado. Datos ficticios en las maquetas; semilla de pruebas «realista» en las capturas.

## Vistas cubiertas

| Vista | Capturas |
|---|---|
| `PlanningView` | los dos chips, desplazada, vacía, AX3, iPad |
| `BudgetsListView` · `BudgetRowView` | con datos, en el límite, pasado, mes cerrado, rueda de mes, tipo, menú de fila, plan gratis, vacía, AX3, iPad |
| `BudgetDetailView` | al 30 %, al 90 %, al 118 %, AX3, iPad |
| `BudgetEditorView` | nuevo, existente entero, elegir categorías y subcategorías, borrar, AX3 |
| `BudgetChartsView` | arriba, medio, abajo, AX3, iPad |
| `ScheduledPaymentsView` · `ScheduledPaymentsListView` · `ScheduledPaymentRowView` | con datos, vencido, pagados, saltado, línea de tiempo, calendario, día elegido, vacía, menú de fila, AX3, iPad |
| `ScheduledPaymentDetailView` | próximo, pagado, saltado, vencido, menú de fecha, «Ya lo pagué» (las dos partes), AX3, iPad |
| `ScheduledPaymentEditorView` | nuevo, guardar sin datos, «Más opciones», existente, AX3 |

Sin conexión no cambia estas vistas (datos del teléfono); lo único con red es el precio de Pro. Sin indicador de carga y
sin mensaje de error: van en los hallazgos secundarios.

## Problemas y recomendación

| # | Problema | Severidad | Recomendación |
|---|---|---|---|
| 1 | Al 90 % dice a la vez «Te quedan», «En el límite» y «Hoy te pasaste»; cinco piezas con cuatro umbrales | Alta | **S1** · un estado, una palabra, un color |
| 2 | Al pasarse, la app anima pero no ayuda (ni en qué se fue ni cómo ajustar) | Alta | **X2** · «Ver los gastos» y «Ajustar el límite» |
| 3 | Editar lo que cuenta un presupuesto: dos puertas, «Delivery +3» y 7 toques | Alta | **E2** · cambiarlo desde el detalle (+ texto de E4) |
| 4 | Un pago vencido se confunde con los próximos; pagarlo pide 4 toques | Alta | **V1** · sección «Vencidos» con «Ya lo pagué» |
| 5 | Apuntar un pago no se deshace, «Ya no está pagado» deja el gasto, saltar se anuncia como pagado | Alta | **D1 + D2 + D3** |
| 6 | Calendario de pagos: cifras de 6-9 pt sin moneda, celdas mudas, día elegido fuera de vista | Media | **C2** · se pliega a la semana (+ C4) |

Lo barato primero: S4, X4, E4, D3 y C4 son cambios de texto o de regla y no cierran la puerta a lo anterior.

## Decisiones para Jürgen

1. ¿Umbrales únicos 80 % y 100 % para barra, palabra, sección e historial? Al 100 % exacto, ¿«Llegaste al límite» o «Te pasaste»?
2. ¿Botones «Ver los gastos» y «Ajustar el límite» al pasarse? Un límite nuevo, ¿vale desde este mes o reescribe el historial?
3. ¿«Qué cuenta» se edita desde el detalle guardando al cerrar con «Deshacer»? ¿Se quita «Subcategorías» de Filtros?
4. ¿Sección «Vencidos» propia, arriba, con «Ya lo pagué» en la fila?
5. ¿Aviso con «Deshacer» al apuntar un pago, y «Ya no está pagado» que pregunte qué hacer con el gasto?
6. ¿Calendario que se pliega a la semana, igual que el propuesto para Registros?

**Bug encontrado (no se tocó):** tras «Saltar este mes», el detalle dice «Noviembre de 2026 ya está pagado»
(`ScheduledPaymentDetailView.swift:202-210` cuenta saltado como hecho y `:251-258` lo rotula «pagado»).

## Qué es medido y qué no

- **Medido:** capturas del simulador (iPhone 17 Pro e iPad Pro 13, iOS 27.2, Yala Dev de `origin/2.3`) y el tiempo de
  abrir Planificación con las marcas de carga de la app (ver «Perfiles y eficiencia»).
- **Leído en el código:** cada cita con fichero y línea.
- **Hipótesis:** los siete perfiles (simulados, no entrevistas), los toques del editor y las notas de rendimiento sin medir.
- Lo decidido en los lotes 9 y 10 de la auditoría 2.2 está implementado y no se repropone; S3 reabre L9-1 y lo dice.

## Archivos

`index.html` · `01-estado-actual.html` · `02-revision.html` · `11-en-el-limite.html` … `16-calendario.html` · `estilo.css` ·
`capturas/` · `revision-planificacion.pdf` · `fuente/` (generador: `python3 build.py`; `--todo X.html` para el PDF).

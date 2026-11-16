# Revisión por vistas 2.3 · Reportes y Flujo de caja/proyectado (zona 36)

Revisión de UX y eficiencia de Reportes (Comparativa), el plan de Flujo de caja y «Ver proyectado» en Tendencias, Panel y
widgets, **después** de la mejora del flujo de caja (ya mergeada en `origin/2.3`). No implementa nada y no elige: cada
problema prioritario trae de tres a cuatro alternativas maquetadas y una recomendación. Decide Jürgen.

- **Abrir:** `index.html`. Se abre en el móvil y en la Mac; las capturas y el estilo van al lado, en `capturas/` y `estilo.css`.
- **Respaldo:** `revision-reportes-flujo.pdf`.
- **Regenerar:** `cd fuente && python3 build.py`. Con `--todo <ruta>` deja la página única para imprimir el PDF.

## Vistas cubiertas

**Las vistas:** FinancialReportView, PivotRowView, NetFlowSummaryView, CashFlowSetupView, CashFlowTableView,
CashFlowMonthDetailView (con sus hojas de línea y de Gráficas) y «Ver proyectado» en Tendencias, Panel y en los widgets Gasto
y Saldo.

**Los casos:**
- con datos, vacío, primera semana y Free;
- guías, desglose por categoría y meses futuros;
- Solo gastos y montos ocultos;
- texto grande (AX3) e iPad Pro 13.

**Cómo se midió cada cosa:**
- Las capturas salen del simulador con datos ficticios. Los widgets, del banco del repo, a partir de una foto con plan.
- VoiceOver se midió en el árbol de accesibilidad.
- «Sin conexión» y «error» van documentados desde el código: la zona calcula en el teléfono y solo el chip «IA» de Gráficas usa la red.

## Problemas, por severidad

| | Problema | Recomendada |
|---|---|---|
| 1 · alta | «¿Llego a fin de mes?» tiene cinco cifras distintas: Panel S/ 69,390.71, el mes S/ 396.18, mayo de 2027 S/ 86,771.48, el armado S/ 587.18 y Gráficas S/ 2,893.08. Ninguna dice de qué es ni hasta cuándo | B (rótulos con métrica y fecha), y A cuando se reabra la cabecera del mes |
| 2 · alta | Lo real y lo estimado se pintan igual y se nombran de siete formas. No hay «≈» en el flujo de caja | B + A (palabras fijas y barra de dos tonos) |
| 3 · media-alta | El plan vive en Más › Reportes. Armarlo pide revisar 18 líneas en 5 desplazamientos. Los chips flotan sobre el contenido | A + D (resumen y «Crear» arriba, líneas plegadas; chips con fondo) |
| 4 · media | Leer un mes es recorrer 25 tarjetas iguales; la única que se pasó está en el puesto 20 | A + C (agrupar por «te pasaste / falta / cubierto», y barras del mes) |
| 5 · media | Con AX3 desaparecen los nombres de fila de la Comparativa y se cortan los importes. En el mes sale «No-viem-bre» y «Crear mi plan» queda a 12 arrastres | A + B (filas que se apilan; frases para VoiceOver) |
| 6 · media | La Comparativa dice «Noviembre» cuando compara el 1–7. Mezcla «=+0%», «N/A», «−100%» y abre con dos filas | A + B (tramo exacto; abrir desglosada por categoría) |
| 7 · media | En la primera semana el armado no tiene ingresos y dice «Te faltan al mes S/ 2,573» | A (preguntar el ingreso que falta) |

## Eficiencia

**Medido** (Debug, simulador, semilla de rendimiento de 730 días con plan, tres arranques en frío):

| Pantalla | Tiempo |
|---|---|
| Abrir Flujo de caja | 201-330 ms |
| Estadísticas, en el mismo recorrido | 1.282-1.508 ms |
| Registros, en el mismo recorrido | 588-647 ms |

El plan no es lento.

**Hipótesis leídas en el código**, cada una con la forma de medirla:
- La Comparativa se recalcula con el plan a la vista: 16 `onChange` la programan sin mirar qué chip está elegido.
- El plan se recalcula al cerrar cualquiera de sus seis hojas.
- El detalle de una línea recorre todo el historial varias veces por repintado.

## Fuera de esta revisión (cálculo)

Sin plan, «Estimado con tu ritmo de gasto» reparte por día los ingresos de 90 días y vuelve a contar el sueldo que ya
entró. Solo con crear el plan sugerido, «Proyectado al cierre» baja de S/ 76,613 a S/ 69,390. Necesita su propia card con
review adversarial.

## Decisiones para Jürgen

1. Problema 1: ¿el rótulo del Panel y de Tendencias pasa a «Saldo al 30 de nov.» (B)?
   ¿La cifra grande del mes pasa al saldo de cierre (A o C)? Esto reabre el lote 18.
2. Problema 2: ¿«Real» y «Estimado» como únicas palabras, y «Pago programado» pasa a «pago planificado» (B)?
   ¿«≈» puede significar también «estimado»? ¿Barra de dos tonos (A)?
3. Problema 3: ¿resumen y «Crear mi plan» arriba con las líneas plegadas (A)?
   ¿Flujo de caja se muda a Planificación (C)?
4. Problema 4: ¿líneas agrupadas por lo que piden (A) y las barras del mes (C)?
5. Problema 5: ¿filas apiladas con texto grande (A) y etiquetas de VoiceOver con frase (B)?
6. Problema 6: ¿tramo exacto en los rótulos (A)? ¿La Comparativa abre desglosada (B)?
7. Problema 7: ¿el armado pregunta el ingreso cuando no lo ve (A)?
8. Aparte: ¿se abre la card del ritmo que vuelve a contar el sueldo?

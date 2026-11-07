# Revisión por vistas 2.3 · Estadísticas (zona 35)

Revisión de UX y eficiencia de Estadísticas: Resumen, Tendencias, Distribución (con el Sankey) y Registros. No implementa
nada y no elige: cada problema prioritario trae cuatro alternativas maquetadas y una recomendación. Decide Jürgen.

- **Abrir:** `index.html` (se abre en el móvil y en la Mac; capturas y estilo van al lado, en `capturas/` y `estilo.css`).
- **Respaldo:** `revision-estadisticas.pdf` (66 páginas, ~10 MB).
- **Regenerar:** `cd fuente && python3 build.py` (con `--todo <ruta>` deja la página única para imprimir el PDF).

## Vistas cubiertas

StatisticsView, DetailContainerView, InsightsTabView (Resumen), TrendsTabView (Tendencias), PeriodComparisonChartView,
CategoriesTabView (Distribución), SankeyChartView y RecordsTabView (Registros). Casos: este mes (7-nov), mes pasado,
entrar a una categoría y volver, primera semana, vacío, diez años (11.696 registros), Free, texto grande (AX3) e iPad Pro 13.
58 capturas del simulador con datos ficticios. VoiceOver medido en el árbol de accesibilidad, sin encenderlo. «Sin conexión»
y «error» solo afectan a la IA y van documentados desde el código.

## Problemas, por severidad

| | Problema | Recomendada |
|---|---|---|
| 1 · alta | «¿En qué se me fue la plata?» no tiene respuesta en un sitio: abre en «Balance»; Distribución enseña «Saldo de cuentas»; el total frente a octubre está en Gráficas o al fondo | A1: la cifra de Distribución es lo gastado y su comparación (+ A2, tarjeta en Resumen) |
| 2 · alta | Tocar una categoría no la abre: pone «Solo X» + «Gasto», que siguen en el Panel; la cifra no cambia; volver es una X de 19 pt | B1: abre el detalle de la categoría y «atrás» vuelve (reabre lo decidido el 25-26 oct) |
| 3 · alta | Con texto grande se cortan importes («S/2,3….00»), la cuadrícula de Resumen y las pestañas | D1 + D2: filas apiladas y cuadrícula a una columna |
| 4 · media-alta | «Balance», «Saldo» y «Saldo de cuentas»: tres cifras distintas, nombres casi iguales; VoiceOver dice otro | C1: un nombre por cifra que diga qué suma (con PN-1 del Panel) |
| 5 · media-alta | VoiceOver lee las gráficas como recuentos («7 puntos», «7 categorías»), sin valores | V1 + V2: etiqueta con la conclusión y descripción de gráficas de iOS |
| 6 · media | Con una semana de datos afirma de más: «los jueves son tu día más caro», «cerraste en positivo», «N/A», «este Este mes» | F2 (+ F1): textos honestos y mínimo de datos por tarjeta |
| 7 · media | Con diez años, ~2 s congelada al entrar y al cambiar de pestaña; ejes en años ilegibles; Sankey a dos deslizamientos | G1 (medir antes) + G2: respuesta al toque y gráficas por mes/año |

Eficiencia, medido (Debug, simulador, semilla «pesado»): entrar a Estadísticas 509-516 ms con «Este mes» y 1.731-2.253 ms
con «Todo el tiempo» (marca `PERF estadisticas` de la app); el Panel se queda congelado ~2 s y cambiar a Tendencias tarda
~2 s (ráfagas cronometradas). Lo demás son hipótesis leídas en el código (todo en el hilo principal, cada pestaña repite su
cálculo, decenas de recorridos del histórico por pasada), con la forma de medirlas.

## Decisiones para Jürgen

1. Problema 1: ¿la cifra grande de Distribución pasa a ser lo gastado con su comparación (A1)? ¿Tarjeta «En qué se fue tu dinero» en Resumen (A2)?
2. Problema 2: ¿tocar una categoría abre su detalle (B1) en vez de filtrar? Reabre lo decidido el 25-26 de octubre. ¿La X de los filtros sube a 44 pt?
3. Problema 3: ¿filas apiladas (D1) y «Tus cifras» a una columna (D2) con texto grande? ¿Sin flotantes (D4)?
4. Problema 4: ¿«Entró − salió» y «Tienes en tus cuentas» (C1)? Decidirlo con PN-1 del Panel.
5. Problema 5: ¿etiquetas de VoiceOver con cifras (V1) y descripción de gráficas (V2)? ¿Se prueba con VoiceOver en el iPhone?
6. Problema 6: ¿textos honestos (F2, incluye el bug «este Este mes») y umbral de 4 semanas para el día de la semana (F1)?
7. Problema 7: ¿sesión de medición con Instruments en un iPhone real antes de G1? ¿Gráficas por mes y año (G2)?

# Revisión por vistas 2.3 · Panel (zona 30)

Revisión de UX y eficiencia del Panel con datos: lectura del mes, cuentas, nota de salud y gráfica. No implementa nada
y no elige: cada problema prioritario trae de 3 a 5 alternativas maquetadas y una recomendación. Decide Jürgen.

- **Abrir:** `index.html` (se abre en el móvil y en la Mac; capturas y estilo van al lado, en `capturas/` y `estilo.css`).
- **Respaldo:** `revision-panel.pdf` (84 páginas, ~6 MB).
- **Regenerar:** `cd fuente && python3 build.py` (con `--todo <ruta>` deja la página única para imprimir el PDF).

## Vistas cubiertas

PanelView, HeroMonthView, AccountsCarouselView, AccountCardView, FinancialScoreView, ScoreRingView, TrendChartView,
WidgetInfoChipView (hojas de ayuda) y PanelSectionsConfigView. Casos: mes típico (20-nov), mes recién empezado (1-dic),
montos ocultos, varias divisas, cargando, texto grande (AX3 y máximo) e iPad Pro 13 vertical. 38 capturas del
simulador con datos ficticios. «Sin conexión» se documenta desde el código: no se vio en pantalla.

## Problemas, por severidad

| | Problema | Recomendada |
|---|---|---|
| PN-1 · alta | «Balance» (entró − salió) se lee como lo que tienes; el total de las cuentas no está a la vista | B: total en «Tus finanzas» |
| PN-2 · alta | La nota de salud da 99-100 con pocos datos y no ve un presupuesto pasado ni una cuenta en rojo | A + B: sin nota hasta tener datos, y decir lo que no ve |
| PN-6 · alta | Con texto grande la cifra principal es lo más pequeño de la pantalla; acciones y títulos cortados | A + B: la cifra escala y el hero se reordena |
| PN-3 · media | El día 1 del mes: nota 96, gráfica de un punto, −100 % | A + B: «Día 1 de 31» y ventana de 30 días en la gráfica |
| PN-4 · media | La gráfica exagera la caída, el «+10.3 %» no dice contra qué, «PEN» y «x̄», eje «nov 24» = año | A + B: etiquetas claras e inicio y fin a la vista |
| PN-5 · media | Cuentas de una en una, sin total ni aviso de rojo; plegar oculta la nota; hueco en el iPad | C en iPhone + D en iPad |
| PN-7 · media | Con montos ocultos, la ayuda «?» de la gráfica dice el saldo exacto | A: la ayuda usa la máscara |
| PN-8 · baja | Configurar Panel: iconos sin texto, «Restablecer» sin aviso, dos sitios para lo mismo | A: botones con texto y confirmación |
| PN-9 · baja | Sin conexión la tasa cae a una tabla y el «≈» no lo dice (no validado en pantalla) | A: la conversión dice la fecha de la tasa |

Eficiencia: medido en Debug y simulador, el Panel recalcula una vez al arrancar y al cambiar de período, y ninguna
al tocar el ojo, plegar o desplazar. Lo demás (cálculos en el `body`, la gráfica al arrastrar) son hipótesis leídas en el
código, con la forma de medirlas en Instruments.

## Decisiones para Jürgen

1. PN-1: ¿dónde vive «lo que tienes» (B en «Tus finanzas», C en el hero, D interruptor)? ¿Se renombra «Balance» (A)?
2. PN-2: ¿cuántas partes hacen falta para enseñar una nota? ¿Se reabre la escala (C) o los pesos (D)?
3. PN-6: ¿la cifra del hero escala con el texto y se reordena en tamaños de accesibilidad?
4. PN-3, PN-4 y PN-5: confirmar las recomendadas o elegir otra.
5. PN-7: ¿se corrige dentro del ticket del ojo que está en QA?
6. PN-9: ¿se prueba en el iPhone en modo avión antes de decidir?

Yala
# Mejoras necesarias 2.3 · Cifras que no cuadran: ritmo, desglose de presupuesto, día más caro y céntimo del reparto
card: tablero-mejoras-necesarias-2-3-cifras-que-no-cua-efqj
toca: Yala/App/Logic/Calculators/,Yala/App/ViewModels/,Yala/App/Views/Statistics/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Lote 02 de 11 de la consolidación final de las revisiones por vistas 2.3 (`docs/ux/revision-vistas-2.3/consolidacion-necesarias-2026-11/ficha.md`). Cada punto es un defecto objetivo con evidencia: un bug, un fallo de accesibilidad o un texto que dice algo falso. No se elige ninguna alternativa de rediseño de las revisiones.
Fichas de origen: docs/ux/revision-vistas-2.3/34-planificacion/ficha.md · docs/ux/revision-vistas-2.3/35-estadisticas/ficha.md · docs/ux/revision-vistas-2.3/36-reportes-flujo/ficha.md · docs/ux/revision-vistas-2.3/37-grupos/ficha.md (problemas en la tabla; secundarios en `02-revision.html`). PRs de las revisiones: https://github.com/jur211296/Yala/pull/852 https://github.com/jur211296/Yala/pull/853 https://github.com/jur211296/Yala/pull/859 https://github.com/jur211296/Yala/pull/856.

## Encargo y criterio de terminado
Implementar SOLO estos 4 puntos:
1. Sin plan el ritmo de Flujo proyectado reparte por día los ingresos de 90 días y vuelve a contar el sueldo que ya entró: Proyectado al cierre baja de S/ 76,613 a S/ 69,390 solo con crear el plan sugerido (ProjectedFlowBuilder.rhythmPerDay; la ficha de la zona 36 pide card propia con review adversarial).
2. El desglose Por categoría de las gráficas de un presupuesto salta los gastos sin subcategoría y puede no sumar lo gastado si el presupuesto filtra por cuenta o etiqueta (BudgetsViewModel.swift:640; filterTransactions no exige subcategoría).
3. Día de más gasto en Resumen y tu día más caro en Tendencias salen de dos cálculos distintos y pueden contradecirse (InsightsTabView.swift:614-620 frente a TrendsTabView.swift:1610).
4. El reparto Monto acepta hasta 0,02 de diferencia: un gasto de S/ 400 cuyas partes suman 399,99 se guarda. Medir adónde va el céntimo y si los saldos del grupo cuadran (GroupSplitCalculator.swift:80).

Reglas del lote:
- Antes de cada punto: confirma en código que sigue vivo en origin/2.3 y corre `git log origin/2.3..origin/2.2 -- <vista>`. Si 2.2 ya lo arregló, no lo portes a mano: documéntalo en el PR y queda para la decisión de integrar 2.2 en 2.3 (card tablero-2-3-no-tiene-los-arreglos-de-2-2-de-las-3a6c).
- Si un punto exige una decisión de producto, sepáralo y déjalo pendiente con su pregunta; no elijas alternativa.
- Un test de regresión por punto (unit o XCUITest según `qa/coverage-index.json`), rojo sin el arreglo y verde con él. Capturas antes y después de lo que se vea.
- Review adversarial obligatoria: son cálculos financieros. Para cada punto, primero un test que fije la cifra correcta con un caso pequeño y medido; después el arreglo.
- Si la cifra correcta de un punto es decisión de producto (qué cuenta el ritmo sin plan, adónde va el céntimo), propón la opción con su porqué y déjala como pregunta: no elijas.
- Regla de fechas de CLAUDE.md (intervalos cerrados y el segundo de menos) en cualquier intervalo que toques.
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día. Card a in qa con su guion; el device-QA no bloquea el merge.
- gate de proyecto.
## Añadido por Frank (Jürgen, 10-nov 6:03 Lima)
- Este lote espera en la cola a que cierre el merge de 2.2 en 2.3. Antes de nada, comprueba que `git rev-list --count origin/2.3..origin/2.2` dé 0 o casi 0. Si 2.3 no tiene lo de 2.2, para de inmediato con un `BLOQUEANTE:` corto.
- Haz tú el QA en el simulador o en el iPhone 14 por DeviceMCP y mueve la card a done con evidencia. Solo queda en qa lo que de verdad necesite la mano de Jürgen, y lo dices en el cierre.

FIN

## Paso 0 (Frank, 10-nov)

- Precondición: `origin/2.3..origin/2.2` = 8 commits, todos de la bienvenida con iCloud (opción B) y de marketing; ninguno toca Calculators, ViewModels, Statistics ni Groups. El merge de 2.2 en 2.3 ya entró. Se sigue, rama rehecha sobre origin/2.3.
- `git log origin/2.3..origin/2.2` vacío para las cuatro zonas: nada que 2.2 ya arreglara.
- Punto 1 (ritmo sin plan): decisión de Jürgen 10-nov → «lo que falta del mes» en ingreso y gasto: previsto del mes = ritmo diario × días del mes; se proyecta max(previsto − ya real del mes, 0) en los días que quedan; meses enteros por delante, el ritmo × días. Misma regla para lo que el plan no cubre.
- Punto 2 (desglose del presupuesto): sin decisión; regla de la casa (`ingreso-gasto.md`): trozo «Sin categoría» gris y fila «Sin subcategoría» bajo su categoría.
- Punto 3 (día más caro): una sola entrada para los dos, la de Resumen (filtros de sesión con «Compartidos/Personales», intervalo de conteo). Asumido: el chip Ingresos/Gastos no cambia este dato, que siempre es de gasto (Tendencias ya lo ignoraba).
- Punto 4 (céntimo del reparto): decisión de Jürgen 10-nov → no se guarda hasta cuadrar; tolerancia de medio céntimo en Monto y 100 % en Porcentaje.

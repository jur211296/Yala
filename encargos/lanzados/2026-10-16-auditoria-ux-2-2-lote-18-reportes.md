# Auditoría UX 2.2 · lote 18: Reportes: Comparativa y Flujo de caja

> **ALCANCE ESTRICTO:** solo los flujos del lote 18. Los criterios UX/UI se aplican solo a sus pantallas. Si ves algo fuera, anótalo en una línea en el informe y no lo toques.

Card: la de título «Auditoría UX 2.2 · lote 18: …» (búscala con `tablero listar --version 2.2`; muévela a in progress al empezar y a done al cerrar) (Yala, 2.2, high). Card madre ogl6: no la muevas.

**Base y PR: 2.2.** `lanzar-sesion` ignora --base: Frank ya te deja sobre origin/2.2; ANTES de tu primer commit, `git fetch origin && git log origin/2.2..HEAD` debe salir vacío. PR contra **2.2**.

## Fuentes
- Brief madre (método, cinco lentes, formato de informe, HTML acumulado y «Criterios UX/UI permanentes de Jürgen»): ~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md. Léelo entero.
- Mapa: docs/ux/mapa-de-flujos-2.2.md (sección lote 18).
- SIMULADOR A CUALQUIER HORA (Jürgen, 2026-10-14): ya NO existe la franja de 9:00 a 11:00 Lima. Si el mapa (docs/ux/mapa-de-flujos-2.2.md, regla 7) o un encargo viejo dice lo contrario, está desactualizado: ignóralo. Sigue: 1 simulador a la vez y apagado al terminar.
- Lotes anteriores como ejemplo: ~/Claude/entregas/Yala--auditoria-ux-2-2-lote-7-cuentas-categorias/informe.md y ~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html.
- Referencia visual: ~/Claude/referencias-ui/kargul-2026-10-07/.

## Lote 18 · Reportes: Comparativa y Flujo de caja (del mapa)
| # | Flujo | Entrada | Pantallas | Ficheros | XCUITest |
|---|---|---|---|---|---|
| 18.1 | Abrir Reportes | Más › «Comparativa» o «Flujo de caja» · su pestaña si se configuró | `FinancialReportView` (chips Comparativa y Flujo de caja, guía) | `V/Reports/FinancialReportView.swift`, `V/More/MoreView.swift` | `CashFlowPlan` |
| 18.2 | Comparar este mes con el anterior | Chip Comparativa | Filtros (período, «P-1/A-1»), agrupaciones (Tipo … «Naturaleza») → `GroupingReorderSheet` → tabla → `NetFlowSummaryView` | `V/Reports/FinancialReportView.swift`, `GroupingChipsBar.swift`, `PivotRowView.swift`, `NetFlowSummaryView.swift` | no |
| 18.3 | Crear mi plan de flujo de caja | Chip Flujo de caja sin plan | `CashFlowSetupView` («¿Qué es el flujo de caja?», líneas sugeridas, «¿Con cuánto empiezas?», «Crear mi plan») → `CashFlowTableView` con tour | `V/Reports/CashFlow/CashFlowSetupView.swift`, `CashFlowTableView.swift`, `VM/CashFlowPlanViewModel.swift` | parcial (`CashFlowPlan`, solo monta) |
| 18.4 | Revisar el plan mes a mes | Tira de meses | `CashFlowMonthStrip` → `CashFlowMonthDetailView` → `CashFlowOthersSheet` | `V/Reports/CashFlow/CashFlowMonthDetailView.swift` | no |
| 18.5 | Ajustar el monto de un mes | Tocar una celda | `CashFlowCellDetailSheet` («Solo este mes / Este mes y futuros») | `V/Reports/CashFlow/CashFlowCellDetailSheet.swift` | no |
| 18.6 | Cambiar cómo se calcula una línea | Tocar una línea | `CashFlowLineConfigSheet` (promedios, fijo, tendencia, personalizado; candado Pro) | `V/Reports/CashFlow/CashFlowLineConfigSheet.swift` | no |
| 18.7 | Añadir una línea al plan | «Agregar línea» · «+ Agregar al plan» | `CashFlowAddLineSheet`, `CashFlowOthersSheet` | `V/Reports/CashFlow/CashFlowAddLineSheet.swift` | no |
| 18.8 | Borrar una línea | Pulsación larga en la fila del mes · configuración de la línea | Menú contextual / diálogo | `V/Reports/CashFlow/CashFlowDetailLineRow.swift`, `CashFlowMonthDetailView.swift` | no |
| 18.9 | Cambiar el saldo inicial | Resumen del mes | `EditStartingBalanceSheet` | `V/Reports/CashFlow/CashFlowTableView.swift` | no |
| 18.10 | Configurar el horizonte o reiniciar el plan | Menú ··· | `CashFlowHorizonSheet`, diálogo «Reiniciar plan» | `V/Reports/CashFlow/CashFlowHorizonSheet.swift` | no |
| 18.11 | Ver las gráficas del flujo de caja | Icono de gráfica | `CashFlowChartsSheet` (5 gráficas, chip IA) | `V/Reports/CashFlow/CashFlowChartsSheet.swift` | no |

**Visto en el código:**
- 18.8 está **verificado**: desde el menú, el botón se llama como la pregunta de confirmación y borra sin preguntar.
  Ticket `cashflow-line-context-menu-deletes-without-asking`.
- Reportes está escondido en Más por defecto.
- Jerga: «Naturaleza», «Profundizar», «P-1», «A-1», «Flujo neto», «Acum», «% ejecutado», «Proyección»,
  «Configurar horizonte».
- La guía de la Comparativa explica con color: «Rojo = gastaste más, verde = gastaste menos».
- Sin Pro, el chip de IA de las gráficas ofrece «Insights con IA», no el flujo de caja.

**Tickets abiertos del lote:** `cashflow-line-context-menu-deletes-without-asking`, `financial-report-amounts-unmarked`,
`qa/cashflow-scheduled-line-ignores-payment-currency`, `cashflow-spend-prediction`,
`ipad-reports-and-search-get-a-readable-width`, `multi-currency-accounts-4-reports-and-export`.

---

## Qué hacer
1. Recorre cada flujo en el simulador; capturas en ~/Claude/entregas/<sesión>/capturas/.
2. Informe en español (entregas/<sesión>/informe.md): mejoras numeradas L18-1, L18-2…; por cada una: problema, tipo de usuario, captura, opciones A/B/C y recomendación. Añade la sección del lote 18 al HTML acumulado sin borrar nada.
3. No implementes cambios de UX: solo propone. Arregla únicamente bugs claros, cada uno con su card (Yala, 2.2, frank), en un PR a 2.2 con antes/después.
4. Una card en espera decisión (Yala, 2.2, assignee jurgen) por cada mejora, con sus opciones y la ruta de sus capturas.

## Elecciones de UI: variantes y CERRAR (Jürgen, 2026-10-14 13:01)
Si alguna mejora es una elección visual, construye ~/Claude/propuestas/auditoria-ux-2.2/variantes-L18.html: autocontenida (imágenes en base64), pestañas o rejilla, **2–3 variantes claramente distintas lado a lado** por item más el «antes», hechas con maquetas reales en el simulador. Guarda también las PNG de cada variante en ~/Claude/entregas/<sesión>/capturas/ (`L18-k-antes.png`, `L18-k-A.png`…), porque Frank se las enseñará a Jürgen pregunta por pregunta.
**No esperes la elección de Jürgen.** Cuando termines, `xcrun simctl shutdown all` y cierra normal con /cerrar-total. Frank junta las decisiones después y las guarda en las cards para la fase de implementación.

## Reglas duras de UI
- NADA de degradados, NADA de glows/brillos, NADA de contraste en blanco sólido.
- El botón «Siguiente» NO se toca.
- El liquid glass se queda.
- La moneda «S/» frente a «PEN» es una preferencia del usuario: nunca la pongas como opción A/B/C.
- Capturas de HOY (de esta sesión) y maquetas reales en el simulador para cada propuesta visual.
- Copy nueva en los 16 idiomas (es-AR con voseo).

## Cómo
- Pipeline serie en la Mini: `nice -n 10 xcodebuild -jobs 2`, como máximo 1 simulador, `xcrun simctl shutdown all` al terminar.
- Tests de lo que arregles con -only-testing y /gate.

## Reglas
Totalmente autónomo: nunca AskUserQuestion ni preguntas, decide tú. Sin deploy.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Sobre qué base?** → `origin/2.2` (medido: `HEAD` = `origin/2.2` al arrancar, `dd8649da8`). PR contra 2.2.
Por qué: lo pide el encargo y la base ya es esa. Alternativa descartada: ninguna.

**D2 · ¿Qué se arregla en código?** → Solo bugs claros del lote, cada uno con card (Yala, 2.2, frank) y test.
El primero ya está verificado: `cashflow-line-context-menu-deletes-without-asking` (18.8). Lo demás va a card de Jürgen.
Por qué: el encargo prohíbe implementar UX. Alternativa descartada: arreglar la jerga de copy — es UX y la decide Jürgen.

**D3 · ¿Qué hago con `financial-report-amounts-unmarked`?** → No se toca: se cita en el informe.
Por qué: es la marca «≈» de FX en 22 importes (calculador + vista), un trabajo de su familia FX, no un bug de UX
acotado. Alternativa descartada: arreglarlo aquí, que mezcla un cambio de cálculo en un PR de auditoría.

**D4 · ¿Cómo conduzco el simulador?** → iPhone 17 Pro (`386CA5C3`), Yala Dev, `-uitest -uitest-seed realista -uitest-pro`
para el recorrido; sin `-uitest` (preferencias forzadas) solo para lo que `-uitest` esconde (guías). Un simulador,
apagado al terminar.
Por qué: semilla determinista y Pro para ver todos los métodos; las guías se ocultan bajo `-uitest`.

**D5 · ¿Cómo hago las maquetas de variantes?** → Molde del lote 17: un fichero Swift local (`ZZLote18Maquetas.swift`)
que pinta la propuesta encima de la pantalla real con `-l18v <pantalla>-<A|B|C>`, nunca commiteado; se retira antes del gate.
Por qué: el encargo pide maquetas reales en el simulador. Alternativa descartada: maquetas en HTML.

**D6 · Disco (15 GB libres, umbral 25).** → Un solo DerivedData de sesión; limpieza de cachés del simulador antes del gate.
Por qué: una tanda de capturas cuesta ~12 GB (memoria de Frank). Alternativa descartada: parar a pedir espacio.

**D7 · Las guías bajo `-uitest`.** → En vez de lanzar sin `-uitest` (D4), un gancho local `-l18-guides` en
`ContextualGuideBanner` para verlas con la semilla puesta; retirado antes del gate como las maquetas.
Por qué: sin `-uitest` no hay semilla ni Pro forzado, y la guía de la Comparativa (B10) solo se entiende con datos.

**D8 · «Este mes y futuros» reescribe los meses pasados.** → No se arregla aquí: ticket
`cashflow-this-and-future-adjustment-rewrites-past-months` y card de Jürgen (L18-8).
Por qué: la salida limpia es un campo nuevo en `CashFlowLine` (esquema de iCloud a Production antes del build) y elegir
entre eso, ajustes de relleno o cambiar el texto es una decisión de producto. Alternativa descartada: cambiar el texto a
«Todos los meses» sin preguntar, que fija como diseño lo que hoy es un bug.

**D9 · Los diálogos sin «Cancelar».** → `.alert` en vez de `confirmationDialog` en los dos diálogos del flujo de caja.
Por qué: borrar una línea y reiniciar el plan son decisiones sobre datos, y la regla de `swiftui-ds.md` ya pedía que la
salida de no hacer nada se viera. Alternativa descartada: colgarlos de otra vista, que no es comprobable sin medir cada sitio.

**D10 · ¿Los XCUITest nuevos cazan el bug?** → Sí, medido: con los arreglos revertidos (un build mutante), los 4 caen
con su línea de fallo; con los arreglos, los 5 de `CashFlowPlanUITests` pasan.

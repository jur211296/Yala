# Auditoría UX 2.2 · lote 9: Presupuestos

> **ALCANCE ESTRICTO:** solo los flujos del lote 9. Los criterios UX/UI se aplican solo a sus pantallas. Si ves algo fuera, anótalo en una línea en el informe y no lo toques.

Card: la de título «Auditoría UX 2.2 · lote 9: …» (búscala con `tablero listar --version 2.2`; muévela a in progress al empezar y a done al cerrar) (Yala, 2.2, high). Card madre ogl6: no la muevas.

**Base y PR: 2.2.** `lanzar-sesion` ignora --base: Frank ya te deja sobre origin/2.2; ANTES de tu primer commit, `git fetch origin && git log origin/2.2..HEAD` debe salir vacío. PR contra **2.2**.

## Fuentes
- Brief madre (método, cinco lentes, formato de informe, HTML acumulado y «Criterios UX/UI permanentes de Jürgen»): ~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md. Léelo entero.
- Mapa: docs/ux/mapa-de-flujos-2.2.md (sección lote 9).
- Lotes anteriores como ejemplo: ~/Claude/entregas/Yala--auditoria-ux-2-2-lote-7-cuentas-categorias/informe.md y ~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html.
- Referencia visual: ~/Claude/referencias-ui/kargul-2026-10-07/.

## Lote 9 · Presupuestos (del mapa)
| # | Flujo | Entrada | Pantallas | Ficheros | XCUITest |
|---|---|---|---|---|---|
| 9.1 | Ver mis presupuestos y cómo voy | Planificación › Presupuestos · Más · widget y sección del Panel · `yala://budgets` | `PlanningView` → `BudgetsListView` (Semanal/Mensual/Anual/Único, flechas, Excedidos/Activos/Inactivos) | `V/Planning/PlanningView.swift`, `BudgetsListView.swift`, `BudgetRowView.swift`, `VM/BudgetsViewModel.swift` | `BudgetsCrud` |
| 9.2 | Poner un límite de gasto (crear presupuesto) | Botón + · paso de «Primeros pasos» · Ajustes › Presupuestos › + | `BudgetEditorView` (datos, período, rango si es Único, activo, alertas, filtros de categoría, «Incluir gastos compartidos») | `V/Planning/BudgetEditorView.swift` | `BudgetsCrud` |
| 9.3 | Llegar al límite gratis de presupuestos | + con 3 activos | `LimitReachedBanner` → `UpgradePromptSheet(.budgets)` | `V/Planning/BudgetsListView.swift`, `S/FeatureGateService.swift` | no |
| 9.4 | Ver el detalle de un presupuesto | Tocar la fila | `BudgetDetailView` | `V/Planning/BudgetDetailView.swift` | `AdaptiveNavigation` |
| 9.5 | Ver las gráficas de un presupuesto | Detalle › icono de gráfica | `BudgetChartsView` → `BudgetChartsPeriodSelector` | `V/Planning/BudgetChartsView.swift` | no |
| 9.6 | Cambiar el período que veo | Flechas o etiqueta del período | `PeriodNavigationHeader` → `BudgetPeriodSelectorSheet` | `V/Planning/Components/BudgetPeriodSelectorSheet.swift` | no |
| 9.7 | Editar un presupuesto | Detalle › lápiz · pulsación larga · Ajustes | `BudgetEditorView` | `V/Planning/BudgetEditorView.swift` | no |
| 9.8 | Borrar un presupuesto | Editor › «Eliminar presupuesto» | Alerta «¿Eliminar presupuesto?…» | `V/Planning/BudgetEditorView.swift` | no |
| 9.9 | Pedir aviso al acercarme al límite | Editor › Alertas | Interruptor y umbrales 50/75/90/100 | `V/Planning/BudgetEditorView.swift`, `YS/BudgetAlertService.swift` | `BudgetAlertsConfig` |
| 9.10 | Tocar una alerta de presupuesto | Notificación «Ya llevas el 75 % de "X"…» | Abre la lista de presupuestos | `YS/BudgetAlertService.swift`, `YS/NotificationService.swift` | no |
| 9.11 | Encender o apagar todas las alertas | Ajustes › Notificaciones | `NotificationsSettingsView` | `V/Settings/NotificationsSettingsView.swift` | parcial (`BudgetAlertsConfig`) |
| 9.12 | Elegir qué presupuestos salen en el widget | Ajustes › Presupuestos | `BudgetsFavoritesSettingsView` | `V/Settings/BudgetsFavoritesSettingsView.swift` | no |

**Visto en el código:**
- «Único» no explica qué significa.
- Sin filtros, el presupuesto cuenta todos los gastos, y no se ve.
- «Incluir gastos compartidos» es vocabulario de Grupos.
- Con las alertas generales apagadas solo dice «Activa las alertas de presupuesto en Perfil > Notificaciones», sin enlace.
- La notificación lleva a la lista, no al presupuesto avisado.
- Hay dos sitios para gestionar presupuestos (Planificación y Ajustes), y el widget solo se elige desde Ajustes.
- «Tu cumplimiento en los últimos 6 períodos»: «cumplimiento» es abstracto.

**Tickets abiertos del lote:** `budget-tied-to-income-or-expense`, `ai-recommended-budgets`, `ipad-list-highlights-the-open-row`.

---

## Qué hacer
1. Recorre cada flujo en el simulador; capturas en ~/Claude/entregas/<sesión>/capturas/.
2. Informe en español (entregas/<sesión>/informe.md): mejoras numeradas L9-1, L9-2…; por cada una: problema, tipo de usuario, captura, opciones A/B/C y recomendación. Añade la sección del lote 9 al HTML acumulado sin borrar nada.
3. No implementes cambios de UX: solo propone. Arregla únicamente bugs claros, cada uno con su card (Yala, 2.2, frank), en un PR a 2.2 con antes/después.
4. Una card en espera decisión (Yala, 2.2, assignee jurgen) por cada mejora, con sus opciones y la ruta de sus capturas.

## Elecciones de UI: variantes y CERRAR (Jürgen, 2026-10-14 13:01)
Si alguna mejora es una elección visual, construye ~/Claude/propuestas/auditoria-ux-2.2/variantes-L9.html: autocontenida (imágenes en base64), pestañas o rejilla, **2–3 variantes claramente distintas lado a lado** por item más el «antes», hechas con maquetas reales en el simulador. Guarda también las PNG de cada variante en ~/Claude/entregas/<sesión>/capturas/ (`L9-k-antes.png`, `L9-k-A.png`…), porque Frank se las enseñará a Jürgen pregunta por pregunta.
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

## Paso 0 (Frank, 2026-10-14, autónomo)

- **Base:** `origin/2.2` (6308b01bc); `origin/2.2..HEAD` vacío. PR contra 2.2.
- **Corpus:** `-uitest-seed realista` (2 cuentas, 2 años, 6 presupuestos mensuales). Los presupuestos semanal, anual y único se crean en la app durante el recorrido (también ejercita 9.2).
- **Qué cuenta como bug claro (se arregla):** un número que miente, datos que se pierden, un texto mal formado o en otro idioma, VoiceOver que lee otra cosa. Lo demás es propuesta con card.
- **Candidatos medidos en el código antes del simulador:** (1) el gastado de periodos de hace más de un año (anual «Año pasado», historial de 6 años, flechas hacia atrás) sale corto porque solo se cargan los movimientos del último año; (2) «Octubre De 2026» (`.capitalized`) en Presupuestos, gráficas y selectores — el ticket `month-year-titles-capitalize-every-word` lo dejó fuera del lote 8; se arreglan aquí las cuatro piezas de Presupuestos y el ticket sigue para Panel y Pagos; (3) Ajustes › Presupuestos formatea importes con su propio formateador, sin la preferencia de divisa del usuario; (4) textos fijos en inglés para VoiceOver. Cada uno se confirma en el simulador antes de tocarlo.
- **Reembolsos en una categoría de gasto** (se suman como gasto por `abs`): no es bug claro, es cómo cuenta el presupuesto; va como propuesta.
- **Gastado de periodos viejos:** cálculo financiero ⇒ review adversarial antes del commit.
- **Copy nueva:** 16 idiomas (es-AR con voseo), leyendo BRAND-VOICE.
- **Variantes visuales:** maquetas locales en el simulador (parche fuera del PR), `variantes-L9.html` autocontenido.
- **Simulador:** 1 (iPhone 17 Pro), `nice -n 10 -jobs 2`, `simctl shutdown all` al terminar.

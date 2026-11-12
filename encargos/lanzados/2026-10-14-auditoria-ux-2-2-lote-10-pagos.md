# Auditoría UX 2.2 · lote 10: Pagos planificados

> **ALCANCE ESTRICTO:** solo los flujos del lote 10. Los criterios UX/UI se aplican solo a sus pantallas. Si ves algo fuera, anótalo en una línea en el informe y no lo toques.

Card: la de título «Auditoría UX 2.2 · lote 10: …» (búscala con `tablero listar --version 2.2`; muévela a in progress al empezar y a done al cerrar) (Yala, 2.2, high). Card madre ogl6: no la muevas.

**Base y PR: 2.2.** `lanzar-sesion` ignora --base: Frank ya te deja sobre origin/2.2; ANTES de tu primer commit, `git fetch origin && git log origin/2.2..HEAD` debe salir vacío. PR contra **2.2**.

## Paso 0 (antes de la auditoría): arreglar el rojo de 2.2
`YalaTests/BudgetsCopyTests/stateIsNotTheSectionHeader()` (BudgetsCopyAndWiringTests.swift:32) falla siempre en 2.2 desde el PR #500: `L10n.Budgets.state(isActive:)` («Active»/«Inactive») es igual a `BudgetStatus.*.localized…`. Arregla el texto o la clave, sin debilitar el test, en los 16 idiomas. Va en un PR propio a 2.2; mergéalo con el CI verde y mueve a done la card «Rojo en 2.2: BudgetsCopyTests…». Run: https://github.com/jur211296/Yala/actions/runs/38660174526. Después sigue con la auditoría.

## Fuentes
- Brief madre (método, cinco lentes, formato de informe, HTML acumulado y «Criterios UX/UI permanentes de Jürgen»): ~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md. Léelo entero.
- Mapa: docs/ux/mapa-de-flujos-2.2.md (sección lote 10).
- Lotes anteriores como ejemplo: ~/Claude/entregas/Yala--auditoria-ux-2-2-lote-7-cuentas-categorias/informe.md y ~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html.
- Referencia visual: ~/Claude/referencias-ui/kargul-2026-10-07/.

## Lote 10 · Pagos planificados (del mapa)
| # | Flujo | Entrada | Pantallas | Ficheros | XCUITest |
|---|---|---|---|---|---|
| 10.1 | Ver mis pagos del mes | Planificación › Pagos planificados · Más · widget · notificación | `ScheduledPaymentsView` (Todos/Recurrentes/Suscripciones) → `ScheduledPaymentsListView` (total, Pagado/Pendiente, lista o calendario) | `V/Planning/ScheduledPaymentsView.swift`, `ScheduledPaymentsListView.swift`, `ScheduledPaymentRowView.swift` | parcial (`ScheduledPaymentSkip`) |
| 10.2 | Apuntar un pago que se repite | Botón + · «Primeros pasos» · Ajustes › Pagos planificados › + · «Recurrente» del formulario | `ScheduledPaymentEditorView` | `V/Planning/ScheduledPaymentEditorView.swift`, `V/Settings/ScheduledPaymentsSettingsView.swift` | parcial (`ScheduledPaymentsCrud`, solo desde Ajustes) |
| 10.3 | Elegir cada cuánto se repite | Editor › Recurrencia | «Una sola vez» o cada N días/semanas/meses/años, días, fecha de fin | `V/Planning/ScheduledPaymentEditorView.swift` | `ScheduledPaymentRecurrenceA11y` |
| 10.4 | Compartir un pago recurrente con un grupo | Editor › «¿Es un gasto compartido?» | Hojas de grupo, moneda y división; al vencer, borrador en la Bandeja → formulario de grupo | `V/Planning/ScheduledPaymentEditorView.swift`, `V/Inbox/InboxView.swift` | no |
| 10.5 | Ver el detalle y el historial de un pago | Tocar la fila | `ScheduledPaymentDetailView` | `V/Planning/ScheduledPaymentDetailView.swift` | `ScheduledPaymentSkip` |
| 10.6 | Saltarme un pago | Detalle › fecha › «Saltar» / «Revertir» | Diálogo en el detalle | `V/Planning/ScheduledPaymentDetailView.swift` | `ScheduledPaymentSkip` |
| 10.7 | Marcar un pago como hecho (vincular un gasto ya apuntado) | Detalle › fecha › «Vincular gasto» | `TransactionAssociationSheet` → «Ver registro» | `V/Planning/Components/TransactionAssociationSheet.swift` | no |
| 10.8 | Pagar por adelantado | Detalle › primera fecha › «Adelantar gasto» | `InboxDraftEditSheet` | `V/Planning/ScheduledPaymentDetailView.swift` | no |
| 10.9 | Tocar un recordatorio de pago | Notificación «Hoy toca pagar X…» | Planificación › Pagos planificados | `YS/ScheduledPaymentNotificationService.swift` | no |
| 10.10 | Tocar el aviso de pago de la tarjeta de crédito | Notificación de cuenta | No lleva a ningún sitio (`deepLink: "accounts"`) | `YS/ScheduledPaymentNotificationService.swift` | no |
| 10.11 | Editar, pausar o borrar un pago | Detalle › lápiz · Ajustes › Pagos planificados (deslizar) | `ScheduledPaymentEditorView`, alerta | `V/Planning/ScheduledPaymentEditorView.swift` | no |

**Visto en el código:**
- El mismo concepto se llama «Pagos planificados», «Pago programado» y «Pagos programados».
- No hay botón «Marcar como pagado»: hay que «Vincular gasto». En un ingreso también dice «gasto».
- Las cadenas de «¿Saltar esta ocurrencia?» y de «¡Tienes pagos pendientes!» existen sin que nadie las use.
- Gestión duplicada en Planificación y Ajustes; crear desde Planificación no tiene test.

**Tickets abiertos del lote:** `scheduled-payment-once-labeled-monthly`, `qa/scheduled-payments-notif-dedup`,
`notification-deeplink-accounts-not-parsed`, `qa/account-currency-change-leaves-scheduled-and-favorites-stale`.
**Cards de 2.2 que lo cambian:** «Pagos en cuotas».

---

## Qué hacer
1. Recorre cada flujo en el simulador; capturas en ~/Claude/entregas/<sesión>/capturas/.
2. Informe en español (entregas/<sesión>/informe.md): mejoras numeradas L10-1, L10-2…; por cada una: problema, tipo de usuario, captura, opciones A/B/C y recomendación. Añade la sección del lote 10 al HTML acumulado sin borrar nada.
3. No implementes cambios de UX: solo propone. Arregla únicamente bugs claros, cada uno con su card (Yala, 2.2, frank), en un PR a 2.2 con antes/después.
4. Una card en espera decisión (Yala, 2.2, assignee jurgen) por cada mejora, con sus opciones y la ruta de sus capturas.

## Elecciones de UI: variantes y CERRAR (Jürgen, 2026-10-14 13:01)
Si alguna mejora es una elección visual, construye ~/Claude/propuestas/auditoria-ux-2.2/variantes-L10.html: autocontenida (imágenes en base64), pestañas o rejilla, **2–3 variantes claramente distintas lado a lado** por item más el «antes», hechas con maquetas reales en el simulador. Guarda también las PNG de cada variante en ~/Claude/entregas/<sesión>/capturas/ (`L10-k-antes.png`, `L10-k-A.png`…), porque Frank se las enseñará a Jürgen pregunta por pregunta.
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

- **Base:** `origin/2.2` (6c177e1e3); `origin/2.2..HEAD` vacío. Dos PR contra 2.2: el del rojo (propio, rama `fix/2.2-budgets-state-vs-section-header`) y el del lote.
- **Rojo de 2.2:** en inglés, alemán, neerlandés y polaco el rótulo de sección de Presupuestos y el estado de UN presupuesto se escriben igual. Cambia el rótulo de sección (`budgets.status.*`: «Active budgets», «Aktive Budgets»…), que además se lee mejor en la lista; el estado («Active») se queda, porque es también el rótulo del interruptor del editor. El test no se toca; se le suma uno que lee los 16 `.strings` (el actual solo ve el idioma del simulador). Se mergea con el CI verde; la auditoría sigue en paralelo.
- **Corpus:** `-uitest-seed realista -uitest-scheduled-seed-day 1 -uitest-scheduled-due-today` (los 8 pagos sembrados el día 1: hay vencidos, de hoy y próximos, y dos años de gastos para vincular). Lo compartido con un grupo (10.4) con el perfil `grupos` + sesión fingida y consentimiento.
- **Bug claro (se arregla):** un número o una fecha que miente, datos que se pierden, un texto mal formado o en otro idioma, VoiceOver que lee otra cosa. Lo demás es propuesta con card.
- **Candidatos medidos en el código, a confirmar en el simulador antes de tocarlos:** (1) la fila de un pago «una sola vez» dice «Mensual» (tickets `scheduled-payment-once-labeled-monthly` y `one-off-scheduled-payment-row-says-monthly`, el mismo bug); (2) el interruptor del editor dice «Activas» para un pago (el `common.active` del filtro de Cuentas, como B3 del lote 9); (3) el aviso «En 1 días toca pagar…» con «1 día antes»; (4) en el detalle, con «Próximo mes» elegido, el historial enseña fechas que aún no llegaron como «Vencido» y «Próximos» se salta la de este mes; (5) la fecha larga del detalle sale «miércoles, 14 octubre 2026» (sin «de») y con el idioma del sistema; (6) «Octubre De 2026» en Pagos (lo deja abierto `month-year-titles-capitalize-every-word`; aquí se arreglan las dos piezas de Pagos); (7) el ✓ apagado le dice a VoiceOver «crea una cuenta primero» aunque falte otra cosa; (8) el pago recién creado no sale en la lista (ticket del lote 5).
- **Fuera de alcance por decisión:** el destino del aviso de la tarjeta (10.10) es decisión de Jürgen (Panel o ficha de la cuenta) ⇒ propuesta. «Pagos en cuotas» es card propia de 2.2: no se diseña aquí.
- **Review adversarial:** si un arreglo toca el total del mes o qué ocurrencia cuenta como pagada (cálculo financiero). Las fechas del detalle no suman dinero: tests unitarios y mutante.
- **Copy nueva:** 16 idiomas (es-AR con voseo), leyendo BRAND-VOICE.
- **Variantes visuales:** maquetas locales en el simulador (parche fuera del PR), `variantes-L10.html` autocontenido.
- **Simulador:** 1 (iPhone 17 Pro, iOS 27.0), `nice -n 10 -jobs 2`, `simctl shutdown all` al terminar.

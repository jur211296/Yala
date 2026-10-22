---
esfuerzo: high
---
# Los gastos compartidos planificados aparecen dos veces en la Bandeja

**Card:** tablero-los-gastos-compartidos-planificados-apar-qo5b · **Prioridad:** high

Reporte de Jürgen en su iPhone (10-oct 07:11): los gastos compartidos (de grupo) planificados le salen DOBLE en la Bandeja.

**Jürgen (07:12): un solo dispositivo y el pago no está guardado dos veces.** Descartadas esas dos hipótesis: el doble borrador nace en un mismo teléfono.

## Que se pide
1. Reproducir PRIMERO con un test que falle (unit, sobre un ModelContext en memoria): un pago programado de grupo vencido → recorrer todas las rutas que crean borradores (`ScheduledPaymentDraftService.processDuePayments`, `createAdvancedDraft`, el camino de unskip, `GroupNotificationService`/bridge de grupos, lo que materialice borradores `.groupScheduledExpense` al entrar a Grupos o al volver a primer plano) y comprobar que queda UN solo borrador pendiente.
2. Pistas: borrador `.scheduledPayment` + borrador `.groupScheduledExpense` del mismo pago; dos rutas que no se ven entre sí (`hasExistingDraft` filtra por `sourceScheduledPaymentID`: ¿la otra ruta lo rellena?); dos llamadas concurrentes (arranque + scenePhase) sin guardar entre medias.
3. Arreglar la causa (no un barrido cosmético), con el test en verde, y un barrido idempotente de los duplicados pendientes que ya existan en teléfonos reales (mantener el más antiguo).
4. Hecha cuando: un pago compartido planificado genera un solo borrador en la Bandeja, con test. Device-QA para Jürgen en el cierre (pasos cortos).

## Reglas de siempre
- Arranca sobre `origin/2.1` y trabaja sin esperar a nadie. Justo antes de abrir el PR: `git fetch` y rebase sobre `origin/2.1`, resolviendo ahí los conflictos (strict=false); si el rebase toca lo tuyo, recompila y repite los tests afectados con un solo simulador.
- Tickets nuevos al tablero (antes del `/cerrar-total`): por cada ticket nuevo en `tickets/`, mira con `tablero listar --proyecto Yala --todas` que no tenga card y, si no, `tablero crear --proyecto Yala --agente frank --asignado frank --estado backlog --prioridad <la del ticket> --titulo "<título claro en español neutro>" --contexto "<una línea>" --enlace "Ticket|https://github.com/jur211296/Yala/blob/2.1/tickets/backlog/<slug>.md" --enlace "PR #<N>|<url>"`. SIN --fecha (opcional desde el ADR-068; sin fecha de relleno). Lista esas cards en el aviso de cierre.
- Sin deploy, sin secretos y sin decisiones de UI de Jürgen: si algo lo pide, para y anótalo en el cierre.
- Cierre: `/cerrar-total` autónomo (PR a 2.1 en auto-merge, limpieza de simulador, worktree y DerivedData).

## Carga de la Mini (OBLIGATORIO)
- Todo xcodebuild va con `nice -n 10 xcodebuild -jobs 2 ...`.
- Nunca dos builds o tests a la vez (ni build + tests); pipeline serie: build → 1 simulador → tests → erase.
- Antes de cada build espera a que la carga baje de 8: `while [ $(sysctl -n vm.loadavg | awk '{print int($2)}') -ge 8 ]; do sleep 30; done`.
- Nunca pases xcodebuild por `| head` (mata el build): escribe a un log y lee el log.
- Los `-only-testing:` van en un array de zsh, no en un string.

## Paso 0 — decisiones (resueltas en autónomo (bypass))

1. **Las rutas de creación del borrador planificado no duplican.** Medido en el código de `origin/2.1` (dc9ad91c9): las tres que crean un `.groupScheduledExpense` (`processDuePayments`, `createAdvancedDraft`, `recreateDraftIfNeeded`) pasan por `createDraft` y las tres miran antes si hay un pendiente con el mismo `sourceScheduledPaymentID`, que `createDraft` siempre rellena. El arranque y la vuelta a primer plano corren en el main actor, sin `await` entre la comprobación y el `save()`. Ninguna otra pieza (bridge de grupos, notificaciones, Grupos) crea borradores con `sourceScheduledPaymentID`. Se deja un test que lo fija (las cuatro rutas → un solo pendiente).
2. **El segundo borrador sale al APROBAR.** El formulario de grupo que abre la Bandeja recibe del pago importe, reparto, cuenta y fecha, pero no su categoría (`GroupExpensePrefillTemplate` no tiene el campo). El gasto de grupo nace sin categoría y el puente de grupos crea un borrador `.groupExpense` «elige categoría» del mismo gasto: misma nota, mismo importe, misma fecha. Es la causa medida; que sea exactamente lo que Jürgen vio queda para el device-QA.
3. **Arreglo en la causa.** La plantilla gana `subcategory`, sin valor por defecto (como `date`: cada productor decide). La del pago planificado pasa la categoría del pago; `applyTemplate` la deja elegida en el formulario, y el gasto nace clasificado. Con eso el puente no pide nada más.
4. **El otro productor de la plantilla tiene el mismo hueco** (convertir un borrador personal en gasto de grupo pierde la categoría del borrador): se arregla igual, porque es el mismo patrón y la misma línea.
5. **Barrido de lo que ya existe.** Al arrancar y al volver a primer plano (`processDuePayments`, con su puerta de quiescencia): un borrador pendiente que solo pide categoría, de un gasto de grupo cuya transacción real está enlazada a un pago planificado con categoría y sigue sin ella, se resuelve como si la persona lo aprobara con esa categoría. Idempotente. Lo que no alcanza (modo puente apagado: no hay transacción real enlazada al pago) queda como residual con ticket. «Mantener el más antiguo» no aplica: no hay dos borradores iguales que fundir.
6. **Sin decisiones de UI.** El chip de categoría ya existe en el formulario; solo llega relleno, como ya llegaba la cuenta.
7. **Review adversarial** no aplica en sentido estricto (no es sync, cálculo ni migración), pero el barrido toca transacciones reales: se revisa con mutantes sobre sus guardas.

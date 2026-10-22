---
esfuerzo: medium
---
# El flujo de caja cuenta un pago programado en dólares como si fueran soles

**Card:** `tablero-el-flujo-de-caja-cuenta-un-pago-programa-r6pd` · **Ticket:** `tickets/backlog/cashflow-scheduled-line-ignores-payment-currency.md`

## Objetivo
Un pago programado en otra divisa (por ejemplo USD en un plan en PEN) entra al flujo de caja convertido a la divisa del plan, con la misma tasa y regla que el resto de la app.

## Pista del triage
`estimateScheduled` y el ViewModel del flujo de caja usan `abs(payment.amount)` sin convertir. `PlannedOccurrenceBuilder` ya convierte y es el molde: reutiliza esa conversión, no la copies.

## Hecho cuando
- Test: plan en PEN + pago programado de 100 USD ⇒ la línea suma 100 USD convertidos (no 100 PEN); misma divisa ⇒ igual que hoy.
- La marca ≈ si la tasa es aproximada, igual que en el resto de importes convertidos.

## Reglas de siempre
- Arranca sobre `origin/2.1`. Lee primero el ticket entero y comprueba que el problema sigue vivo en 2.1 (mídelo); si ya no lo está, dilo en el PR y cierra el ticket.
- Test que falle con el código viejo y pase con el nuevo (control rojo), en las dos direcciones; mutante verificado.
- `/gate`: builds `Yala` y `Yala Dev`, unit de las áreas tocadas y XCUITest solo de las pantallas tocadas, con un solo simulador.
- Rebase al final, sin esperar a nadie: justo antes de abrir el PR, `git fetch` y rebase sobre `origin/2.1`, resolviendo ahí cualquier conflicto (strict=false). Si el rebase trae cambios que tocan lo tuyo, vuelve a compilar y repetir los tests afectados.
- Tickets nuevos al tablero (antes del `/cerrar-total`): por cada ticket nuevo que abra esta sesión en `tickets/`, mira primero con `tablero listar --proyecto Yala --todas` que no tenga ya card y, si no la tiene, créala: `tablero crear --proyecto Yala --agente frank --asignado frank --estado backlog --prioridad <la del ticket> --titulo "<título claro en español neutro>" --contexto "<una línea>" --enlace "Ticket|https://github.com/jur211296/Yala/blob/2.1/tickets/backlog/<slug>.md" --enlace "PR #<N>|<url del PR>"`. Lista esas cards (título e id) en el aviso de cierre. Va SIN --fecha (la fecha de las cards es opcional desde el ADR-068; no pongas fecha de relleno).
- Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, card tablero-el-flujo-de-caja-cuenta-un-pago-programa-r6pd a «in qa» con jurgen si queda device-QA o a «done» con frank si no; limpiar worktree, tmux, DerivedData y cachés; ningún simulador encendido). Antes/después en el PR (capturas si hay cambio visible).
- Decisiones técnicas: Jürgen las delegó; elige siempre la opción más robusta y anótala en el Paso 0 del encargo.

## Carga de la Mini (OBLIGATORIO)
El puente de Grok Bot se cae con los picos de carga de Xcode (llegó a 17). Por eso:
- Todo `xcodebuild` (build y test) va como `nice -n 10 xcodebuild -jobs 2 ...`.
- Nunca corras dos builds o tests a la vez (ni en paralelo ni en segundo plano).
- Antes de cada build o test, espera a que la carga de 1 minuto baje de 8: `while [ $(sysctl -n vm.loadavg | awk '{print int($2)}') -ge 8 ]; do sleep 30; done`.
- No filtres la salida de xcodebuild con `| head` (corta la tubería y mata el build): escribe a un log y busca en él.
- En zsh, los `-only-testing:` van en un array, no en una variable de texto.

## Paso 0

Medido en `origin/2.1` (65afdcef3): el bug sigue vivo en 4 sitios del flujo de caja, no en 3 —
`estimateScheduled` (proyección), `CashFlowPlanViewModel` ×2 (sugerencia y recálculo del método) y
la fila del pago en `CashFlowAddLineSheet` (pintaba `abs(payment.amount)` con la divisa del plan).
`FinancialScoreCalculator` ya convierte: fuera.

Decisiones (delegadas, la más robusta):
1. **Una sola conversión.** Se extrae la del molde (`PlannedOccurrenceBuilder`) a
   `ScheduledPaymentAmountConversion` y el molde pasa a usarla: no hay segunda copia.
2. **Tasa = la última** (`convertCheckedWithLatestRate`), como el molde y el Financial Score: un pago
   programado es futuro, no tiene fecha histórica que anclar.
3. **«≈» por línea, no por total.** `CashFlowLineResult.isPlannedApproximate` = línea programada,
   sin override, con tasa no exacta. Se pinta en el importe del plan de la línea (fila del detalle
   del mes, hoja de celda) y en la fila de sugerencia / de añadir línea. Los totales del mes no
   llevan marca hoy para nada (tampoco las transacciones convertidas): meterla ahí es otra decisión
   de producto y queda fuera.
4. Misma divisa ⇒ ruta rápida `abs(amount)`, exacta: idéntico a hoy.

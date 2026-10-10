---
esfuerzo: medium
---
# En el Panel, lo gastado por cuenta sube con una devolución en vez de bajar

**Card:** `tablero-en-el-panel-lo-gastado-por-cuenta-sube-c-wld4` · **Ticket:** `tickets/backlog/panel-spent-per-account-counts-refunds-as-spending.md`

## Objetivo
Una devolución (registro con categoría de gasto e importe a favor) baja lo gastado por cuenta en el Panel y en el detalle de la cuenta, en vez de subirlo.

## Pista del triage
`PanelViewModel.calculateAccountPeriodExpenses` suma `abs(transaction.amount)` de todo registro con categoría de gasto, y `AccountDetailCalculator` copia la regla. Saca la regla a una sola función lógica pura usada por los dos (y alineada con cómo cuenta devoluciones el resto de estadísticas).

## Hecho cuando
- Test: gasto de 100 + devolución de 30 en la misma cuenta ⇒ gastado 70 en Panel y en detalle de cuenta; sin devoluciones ⇒ igual que hoy.
- Paridad entre Panel y detalle de cuenta con una sola función.

## Reglas de siempre
- Arranca sobre `origin/2.1`. Lee primero el ticket entero y comprueba que el problema sigue vivo en 2.1 (mídelo); si ya no lo está, dilo en el PR y cierra el ticket.
- Test que falle con el código viejo y pase con el nuevo (control rojo), en las dos direcciones; mutante verificado.
- `/gate`: builds `Yala` y `Yala Dev`, unit de las áreas tocadas y XCUITest solo de las pantallas tocadas, con un solo simulador.
- Rebase al final, sin esperar a nadie: justo antes de abrir el PR, `git fetch` y rebase sobre `origin/2.1`, resolviendo ahí cualquier conflicto (strict=false). Si el rebase trae cambios que tocan lo tuyo, vuelve a compilar y repetir los tests afectados.
- Tickets nuevos al tablero (antes del `/cerrar-total`): por cada ticket nuevo que abra esta sesión en `tickets/`, mira primero con `tablero listar --proyecto Yala --todas` que no tenga ya card y, si no la tiene, créala: `tablero crear --proyecto Yala --agente frank --asignado frank --estado backlog --prioridad <la del ticket> --titulo "<título claro en español neutro>" --contexto "<una línea>" --enlace "Ticket|https://github.com/jur211296/Yala/blob/2.1/tickets/backlog/<slug>.md" --enlace "PR #<N>|<url del PR>"`. Lista esas cards (título e id) en el aviso de cierre. Va SIN --fecha (la fecha de las cards es opcional desde el ADR-068; no pongas fecha de relleno).
- Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, card tablero-en-el-panel-lo-gastado-por-cuenta-sube-c-wld4 a «in qa» con jurgen si queda device-QA o a «done» con frank si no; limpiar worktree, tmux, DerivedData y cachés; ningún simulador encendido). Antes/después en el PR (capturas si hay cambio visible).
- Decisiones técnicas: Jürgen las delegó; elige siempre la opción más robusta y anótala en el Paso 0 del encargo.

## Carga de la Mini (OBLIGATORIO)
El puente de Grok Bot se cae con los picos de carga de Xcode (llegó a 17). Por eso:
- Todo `xcodebuild` (build y test) va como `nice -n 10 xcodebuild -jobs 2 ...`.
- Nunca corras dos builds o tests a la vez (ni en paralelo ni en segundo plano).
- Antes de cada build o test, espera a que la carga de 1 minuto baje de 8: `while [ $(sysctl -n vm.loadavg | awk '{print int($2)}') -ge 8 ]; do sleep 30; done`.
- No filtres la salida de xcodebuild con `| head` (corta la tubería y mata el build): escribe a un log y busca en él.
- En zsh, los `-only-testing:` van en un array, no en una variable de texto.

## Paso 0

Medido en `origin/2.1` (2e3a0e737): el bug sigue vivo. `PanelViewModel.calculateAccountPeriodExpenses` suma
`abs(transaction.amount)`; `AccountDetailCalculator.topCategories` y `dailySpending` también.

Decisiones (delegadas, se toma la más robusta):

1. **Una sola regla, en `Yala/App/Logic/AccountSpendingLogic.swift`** (enum puro, sin SwiftData): qué registro cuenta
   como gasto de la cuenta y cuánto aporta. El Panel y la vista de cuenta la llaman los dos; `AccountDetailCalculator.isExpense`
   delega en ella.
2. **Acumulación con signo**: aporta `-importe`. Un gasto de −100 suma 100; una devolución de +30 en categoría de gasto
   resta 30. Es como acumulan Registros y Tendencias (`TransactionClassificationLogic` + suma con signo).
3. **Qué cuenta no cambia**: sin ajustes ni transferencias, categoría no de ingreso. Un registro sin categoría sigue fuera
   (cambiarlo es otro ticket; aquí solo se arregla la devolución).
4. **Un neto negativo se enseña negativo** (más devuelto que gastado en el período), igual que un bucket de Registros. «En
   qué se fue» ya oculta las categorías con neto ≤ 0. Recortar a 0 escondería la devolución y descuadraría la curva.
5. **Moneda**: la de la cuenta (`amount`), como hasta hoy.

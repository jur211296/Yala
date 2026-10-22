---
esfuerzo: medium
---
# El resumen de Registros suma importes en divisas preferidas distintas sin convertirlos

**Card:** `tablero-el-resumen-de-registros-suma-importes-en-5o94` · **Ticket:** `tickets/backlog/records-summary-mixes-preferred-currencies.md`

## Objetivo
El resumen de Registros (totales de ingresos, gastos y neto) convierte cada importe a la divisa principal antes de sumar, como ya hace `CashFlowCalculator`.

## Pista del triage
`calculateSummary` sigue sin la rama de conversión que tiene `CashFlowCalculator`. Reutiliza la misma función de conversión (sin copiar la regla) y respeta la marca ≈.

## Hecho cuando
- Test: registros en PEN y USD con principal PEN ⇒ el total suma los USD convertidos; todo en una divisa ⇒ igual que hoy.
- Paridad con el Panel para el mismo periodo y filtro.

## Reglas de siempre
- Arranca sobre `origin/2.1`. Lee primero el ticket entero y comprueba que el problema sigue vivo en 2.1 (mídelo); si ya no lo está, dilo en el PR y cierra el ticket.
- Test que falle con el código viejo y pase con el nuevo (control rojo), en las dos direcciones; mutante verificado.
- `/gate`: builds `Yala` y `Yala Dev`, unit de las áreas tocadas y XCUITest solo de las pantallas tocadas, con un solo simulador.
- Rebase al final, sin esperar a nadie: justo antes de abrir el PR, `git fetch` y rebase sobre `origin/2.1`, resolviendo ahí cualquier conflicto (strict=false). Si el rebase trae cambios que tocan lo tuyo, vuelve a compilar y repetir los tests afectados.
- Tickets nuevos al tablero (antes del `/cerrar-total`): por cada ticket nuevo que abra esta sesión en `tickets/`, mira primero con `tablero listar --proyecto Yala --todas` que no tenga ya card y, si no la tiene, créala: `tablero crear --proyecto Yala --agente frank --asignado frank --estado backlog --prioridad <la del ticket> --titulo "<título claro en español neutro>" --contexto "<una línea>" --enlace "Ticket|https://github.com/jur211296/Yala/blob/2.1/tickets/backlog/<slug>.md" --enlace "PR #<N>|<url del PR>"`. Lista esas cards (título e id) en el aviso de cierre. Va SIN --fecha (la fecha de las cards es opcional desde el ADR-068; no pongas fecha de relleno).
- Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, card tablero-el-resumen-de-registros-suma-importes-en-5o94 a «in qa» con jurgen si queda device-QA o a «done» con frank si no; limpiar worktree, tmux, DerivedData y cachés; ningún simulador encendido). Antes/después en el PR (capturas si hay cambio visible).
- Decisiones técnicas: Jürgen las delegó; elige siempre la opción más robusta y anótala en el Paso 0 del encargo.

## Carga de la Mini (OBLIGATORIO)
El puente de Grok Bot se cae con los picos de carga de Xcode (llegó a 17). Por eso:
- Todo `xcodebuild` (build y test) va como `nice -n 10 xcodebuild -jobs 2 ...`.
- Nunca corras dos builds o tests a la vez (ni en paralelo ni en segundo plano).
- Antes de cada build o test, espera a que la carga de 1 minuto baje de 8: `while [ $(sysctl -n vm.loadavg | awk '{print int($2)}') -ge 8 ]; do sleep 30; done`.
- No filtres la salida de xcodebuild con `| head` (corta la tubería y mata el build): escribe a un log y busca en él.
- En zsh, los `-only-testing:` van en un array, no en una variable de texto.

## Paso 0 — decisiones (resueltas en autónomo (bypass))

1. **¿Sigue vivo?** Sí, medido en `origin/2.1` (ecc503317): `calculateSummary` lee `statsAdjustment.amountInPreferredCurrency` sin condicionar por `preferredCurrencyCode`.
2. **Cómo reutilizar sin copiar la regla.** Se extrae de `CashFlowCalculator` un `static func resolvedAmount(_:currencyCode:adjustment:converter:) -> (value, approximateMagnitude)` con las dos ramas (monto guardado / reconversión con la tasa de su fecha). Lo usan el Panel y Registros. El cuerpo de `calculateCashFlow` queda igual en comportamiento.
3. **De dónde sale la divisa principal en Registros.** Parámetro obligatorio `currencyCode` en `applyFilters`, que los dos llamadores ya tienen (`appPreferences.defaultCurrencyCode` en `RecordsStandaloneView`, `inputs.currencyCode` en `StatisticsRecalculation`). Obligatorio y no con default: un default silencioso es la forma de que un llamador nuevo vuelva a mezclar. `converter` sí con default `.shared` (como el Panel), inyectable en tests.
4. **Marca ≈.** Sale de la rama que decidió: flag vía `adjustment` si se lee el guardado, `RateQuality` si se reconvierte. Es la del Panel; el umbral y el neto con cociente propio no cambian.
5. **Calendario de Registros (`DailySpendingCalculator`).** Su docblock fija paridad literal con el resumen («así ambos coinciden»). Arreglar solo el resumen dejaría las barras descuadradas con el chip de gasto en la misma pantalla ⇒ se le aplica la misma función (alcance mínimo salvo incoherencia). `currencyCode` obligatorio; la vista ya lo recibía.
6. **Recalcular al cambiar de divisa.** Ninguna de las dos pantallas observa `defaultCurrencyCode`; no se toca: el cambio de divisa migra las transacciones y eso ya dispara el recálculo, igual que en el Panel. No es una regresión (antes tampoco dependía de la divisa).
7. **Sin cambio visible en datos normales** (todo en una divisa ⇒ mismo número). Sin capturas de antes/después: el caso solo se da con filas sin recalcular tras cambiar de divisa, y lo cubre el test.

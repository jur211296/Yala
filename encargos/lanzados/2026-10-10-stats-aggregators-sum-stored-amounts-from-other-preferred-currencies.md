---
esfuerzo: medium
---
# Más totales de Estadísticas suman importes guardados en otra divisa principal

**Card:** `tablero-mas-totales-de-estadisticas-suman-import-ct4d` · **Ticket:** `tickets/backlog/stats-aggregators-sum-stored-amounts-from-other-preferred-currencies.md` (entra a 2.1 con el PR #434; si aún no está, léelo de la rama `encargo/2026-10-10-records-summary-mixes-preferred-currencies`)

## Objetivo
Sankey de Distribución, gasto por etiqueta, tabla dinámica y hero de Estadísticas suman el importe en la divisa principal vigente, resolviendo cada transacción con la regla única `CashFlowCalculator.resolvedAmount(_:currencyCode:adjustment:converter:)` (extraída en el PR #434), con su marca «≈». Sin copiar la regla.

## Hecho cuando
- `SankeyFlowCalculator`, `TagSpendingCalculator`, `PivotTableCalculator` (las dos ramas) y `HeroBucketsCalculator` usan `resolvedAmount`.
- Un test por superficie con dos filas de `preferredCurrencyCode` distinto: el total sale en la divisa vigente; con una sola divisa, igual que hoy. Control rojo y mutante.
- El barrido de los ~40 ficheros del ticket queda hecho y anotado en el ticket: los que agregan se arreglan aquí o reciben ticket propio.
## Reglas de siempre
- Arranca sobre `origin/2.1`. Lee primero el ticket entero y comprueba que el problema sigue vivo en 2.1 (mídelo); si ya no lo está, dilo en el PR y cierra el ticket.
- Test que falle con el código viejo y pase con el nuevo (control rojo), en las dos direcciones; mutante verificado.
- `/gate`: builds `Yala` y `Yala Dev`, unit de las áreas tocadas y XCUITest solo de las pantallas tocadas, con un solo simulador.
- Rebase al final, sin esperar a nadie: justo antes de abrir el PR, `git fetch` y rebase sobre `origin/2.1`, resolviendo ahí cualquier conflicto (strict=false). Si el rebase trae cambios que tocan lo tuyo, vuelve a compilar y repetir los tests afectados.
- Tickets nuevos al tablero (antes del `/cerrar-total`): por cada ticket nuevo que abra esta sesión en `tickets/`, mira primero con `tablero listar --proyecto Yala --todas` que no tenga ya card y, si no la tiene, créala: `tablero crear --proyecto Yala --agente frank --asignado frank --estado backlog --prioridad <la del ticket> --titulo "<título claro en español neutro>" --contexto "<una línea>" --enlace "Ticket|https://github.com/jur211296/Yala/blob/2.1/tickets/backlog/<slug>.md" --enlace "PR #<N>|<url del PR>"`. Lista esas cards (título e id) en el aviso de cierre. Va SIN --fecha (la fecha de las cards es opcional desde el ADR-068; no pongas fecha de relleno).
- Cierre: `/cerrar-total` autónomo (PR a 2.1 con auto-merge, card tablero-mas-totales-de-estadisticas-suman-import-ct4d a «in qa» con jurgen si queda device-QA o a «done» con frank si no; limpiar worktree, tmux, DerivedData y cachés; ningún simulador encendido). Antes/después en el PR (capturas si hay cambio visible).
- Decisiones técnicas: Jürgen las delegó; elige siempre la opción más robusta y anótala en el Paso 0 del encargo.

## Carga de la Mini (OBLIGATORIO)
El puente de Grok Bot se cae con los picos de carga de Xcode (llegó a 17). Por eso:
- Todo `xcodebuild` (build y test) va como `nice -n 10 xcodebuild -jobs 2 ...`.
- Nunca corras dos builds o tests a la vez (ni en paralelo ni en segundo plano).
- Antes de cada build o test, espera a que la carga de 1 minuto baje de 8: `while [ $(sysctl -n vm.loadavg | awk '{print int($2)}') -ge 8 ]; do sleep 30; done`.
- No filtres la salida de xcodebuild con `| head` (corta la tubería y mata el build): escribe a un log y busca en él.
- En zsh, los `-only-testing:` van en un array, no en una variable de texto.

## Paso 0 — decisiones (resueltas en autónomo (bypass))

1. **¿Sigue vivo?** Sí, medido en `origin/2.1` (1c101c4a8): `SankeyFlowCalculator:74`, `TagSpendingCalculator:53`, `PivotTableCalculator:56,59` y `HeroBucketsCalculator:103` leen `adjustment.amountInPreferredCurrency(tx)` sin mirar `tx.preferredCurrencyCode`.
2. **Regla.** Los cuatro llaman a `CashFlowCalculator.resolvedAmount`; no se copia ninguna rama. Sankey, etiquetas y hero suman magnitudes (`abs` del valor resuelto), como hoy.
3. **Divisa.** Tag y Pivot ya la reciben (`currencyCode` / `preferredCurrency`). Sankey y Hero reciben un `currencyCode` **obligatorio** (un default silencioso es como un llamador nuevo vuelve a mezclar); `converter` con default `.shared`, inyectable en tests. Statistics la tiene en `calculateSankeyData(defaultCurrencyCode:)`; el Panel en `self.defaultCurrencyCode` y `self.currencyConverter`.
4. **Pivot, rama de monto original** (`.divisa`/`.cuenta`): suma el nativo, no el preferido; no es este bug y no se toca. Se arreglan las dos ramas del período (actual y anterior) del monto preferido.
5. **Marca «≈».** El hero ya marca: su magnitud dudosa pasa a salir de `resolvedAmount` (misma fuente que el Panel/Registros: flag vía `adjustment` si se lee el guardado, `RateQuality` si se reconvierte). Sankey, etiquetas y tabla dinámica **no tienen marca hoy** y añadirla es UI nueva con tickets propios (`financial-report-amounts-unmarked`, `pie-header-total-unmarked`): fuera.
6. **Sin cambio visible con una sola divisa.** Sin capturas: el caso solo se da con filas sin recalcular tras cambiar de divisa, y lo cubre el test.
7. **«Hero de Estadísticas» era el del Panel.** El ticket lo nombra así pero señala `HeroBucketsCalculator`, que alimenta el hero del Panel. Se arregla ese, como dice «Hecho cuando».
8. **Alcance: se completa lo que comparte pantalla con lo arreglado** (la review de consumidores lo cazó). El neto de Informes va encima de la tabla dinámica; la tarjeta de Tendencias (`TrendDataProcessor`, total y curva) comparte el Panel con el hero, y su KPI en Estadísticas (`StatisticsViewModel.calculateTotals`) comparte tarjeta con la curva. Arreglar solo una mitad dejaba cada pantalla con dos números para el mismo dinero. El KPI se extrae a `periodTotals` (estático, con converter inyectable) para poder probarlo.
9. **Lo demás del barrido va a tickets**, agrupado por superficie: Tendencias por cuenta/histórico/saldos, salud financiera, Yala IA y widgets. Los saldos acumulados son otra pregunta (saldo con qué tasa) y no se mezclan aquí.

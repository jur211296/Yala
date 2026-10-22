---
id: fx-repair-sweep-is-the-only-boot-sweep-without-a-uitest-gate
status: backlog
priority: very-low
area: "currency, testing"
created: 2026-09-08
updated: 2026-10-08
source: hallazgo de camino en chat-rows-sealed-before-the-fix-have-no-repair-path (2026-09-08)
---

# El barrido de tasas es el único de su vecindario que corre durante los XCUITest

## Qué pasa

`TransactionUpdateService.repairLegacyOneToOneRatesIfNeeded` cuelga de
`AppBootstrapper.loadExchangeRates`, que se llama **incondicional** en el paso 2. Sus vecinos —el
barrido del signo del chat (paso 2.6), los pagos programados, Apple Pay/Siri, el aviso de borradores—
van todos dentro de `if !uiTestActive`, y el del chat lo explica: «una migración de datos históricos
no tiene nada que hacer sobre un store sembrado sintéticamente».

## Hoy no muerde, y por qué (medido el 2026-09-08)

`ExchangeRateRepairLogic.needsRepair` pide divisa distinta de la preferida. Y:

- `DevSeedTransactions` solo escribe `exchangeRate: 1.0` en filas **PEN** (`currency == "PEN" ? 1.0 : rate`),
  con `preferredCurrencyCode: "PEN"` fijo; los fixtures de desync y dead-pointer usan
  `currencyCode == preferredCurrencyCode` por construcción.
- La suite fuerza `-AppleLocale es_PE` (`XCUIApplication+Yala.swift`), así que la preferida es PEN y
  nadie escribe `defaultCurrencyCode` bajo `-uitest`.

⇒ cero candidatas en toda la suite de UI. **Pero la protección es un accidente de dos constantes
ajenas entre sí**, no un gate: cambiar el locale de la suite, o añadir un perfil de seed en divisa
ajena con tasa 1.0, pone el barrido a escribir sobre el fixture sin nada que lo pare.

## Coste secundario, ya presente

Con `-uitest-reset` el store está vacío en el paso 2 (el wipe corre en `YalaApp.init()`, el seed al
final del bootstrap), así que el guard de presencia impide que el flag se selle **nunca** en la
suite: un fetch de tabla completa más un `fetchCount` en cada lanzamiento de cada test.

## Criterio de hecho (AC)

- [ ] El barrido queda gateado por `!uiTestActive` como sus vecinos, o queda escrito por qué éste no
      debe estarlo.
- [ ] Si se gatea, comprobar que ningún XCUITest dependía de que corriera.

## Medido en 2.1 (triage 2026-10-08)

- `AppBootstrapper.loadExchangeRates` sigue llamando a `repairLegacyOneToOneRatesIfNeeded` sin `!uiTestActive`, mientras el barrido del signo del chat (paso 2.6) y los pasos 4, 4b y 4c sí lo llevan.
- Hoy no muerde: el propio ticket midió cero candidatas con el seed en PEN. Es un riesgo latente de test intermitente, no un hueco del gate.

Triage 2026-10-08: abierto · low → very-low · sigue sin gate de UI tests pero hoy no tiene candidatas; es higiene de la suite.

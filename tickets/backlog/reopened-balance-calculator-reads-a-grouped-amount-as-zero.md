---
id: reopened-balance-calculator-reads-a-grouped-amount-as-zero
status: backlog
priority: medium
area: "onboarding, calculadora de saldo"
created: 2026-10-13
updated: 2026-10-13
source: "auditoría UX 2.2 · lote 1, nueva propuesta UI (sesión del 2026-10-13), hallazgo de camino"
---

# Al reabrir la calculadora con un saldo de 1.000 o más, la calculadora dice 0

## El problema, en lenguaje de usuario

En el paso del saldo del onboarding, si ya hay un saldo de 1.000 o más y la persona vuelve a abrir la
calculadora («Editar»), el campo enseña la cifra («1,800.00») pero el resultado dice **S/ 0.00**. Si toca
«Usar este saldo», el saldo de la cuenta pasa a 0. Es un bug, no una decisión.

## Por qué pasa (leído y visto en el simulador el 2026-10-13)

`OnboardingView.prefillCalculatorFromInitialBalance()` rellena el campo con
`AmountInputHelper.formatWithGrouping(amount)`, que lleva separador de miles («1,800.00»; «1.800,00» en es-ES).
`BalanceCalculatorSheet.parseAmount` hace `Double(text.replacing(",", with: "."))`: «1.800.00» no es un
`Double` y da 0. Con menos de 1.000 no hay separador y funciona. Lo afecta a las tres variantes (cuenta, tarjeta
y «Todo junto»): las tres leen el campo prefijado con el mismo `parseAmount`. Además, si la persona edita ese
campo, `filterCalcInput` toma la coma de miles por decimal y el valor queda en «1.80».

Visto en el iPhone 17 Pro (iOS 27.0): saldo 1.800 calculado, cambio de tipo de cuenta a tarjeta, «Editar» →
«¿Cuánto llevas gastado? S/ 1,800.00» y «Tu saldo → S/ 0.00».

Solo el onboarding prefija la calculadora; `AccountFormView` no.

## Cómo se sabe que está arreglado

- El prefijado escribe el número sin separador de miles (o `parseAmount` entiende el formato que escribe el
  prefijado), con un test que cubra 1.800 en es-PE y en es-ES.
- Reabrir la calculadora con 1.800 enseña 1.800 en el resultado y «Usar este saldo» lo conserva.

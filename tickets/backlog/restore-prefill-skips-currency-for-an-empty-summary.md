---
id: restore-prefill-skips-currency-for-an-empty-summary
status: backlog
priority: low
area: "welcome, onboarding, restore"
created: 2026-09-21
updated: 2026-09-21
source: "review adversarial de `restore-treats-budgets-and-groups-as-no-data` (2026-09-21), hallazgo 2 de la lente de consumidores"
---

# Restaurar unos presupuestos y nada más te salta la pregunta de la divisa

## El problema, en lenguaje de usuario

Restauro de iCloud, la app encuentra tres presupuestos y nada más, toco «Continuar» y entro al
onboarding. Ahí **no me pregunta en qué moneda llevo mis cuentas**: la da por sabida. No he
restaurado ninguna cuenta ni ninguna categoría — solo unos presupuestos.

## Medido (2026-09-21)

- `OnboardingStepPlan` decide los pasos con `hasPrefill`, que es `prefilledData != nil`
  (`Yala/App/Logic/OnboardingStepPlan.swift:69-77`, alimentado desde `OnboardingView.swift:133-141`).
  **Es un `!= nil`, no «el resumen tiene contenido».**
- El productor es `ContentView.swift:855-857`: `prefilledOnboardingData = summary` en cuanto el
  restore devuelve un summary.
- `primaryCurrencyCode` **nunca es `nil`**: el constructor lo llena siempre con
  `appPreferences.defaultCurrencyCode.rawValue` (`iCloudSyncService.swift`, y el docblock de
  `isFullyPrefilled` ya lo dice). ⇒ con `hasPrefill == true` el plan **salta `.currencyName`
  siempre**, y `.name` si hay nombre en preferencias.
- `isFullyPrefilled` sí es coherente (exige cuentas + categorías), así que `.directToApp` no se
  alcanza: el destino es el onboarding, solo que con dos pasos menos.

## Por qué aparece ahora

Hasta el 2026-09-21 un corpus de solo presupuestos no encendía `hasAnyData`, así que esa persona
caía en `.notFound` → «Empezar desde cero», que pone `prefilledOnboardingData = nil`
(`ContentView.swift:864`) y sí le preguntaba las dos cosas.
`restore-treats-budgets-and-groups-as-no-data` la mandó a `.found`, que es lo correcto —sus
presupuestos existen— pero la trae por un camino donde el prefill está puesto y casi vacío.

## Qué habría que decidir

- ¿`hasPrefill` debe mirar el CONTENIDO del resumen en vez de su existencia? Es un cambio en un
  choke-point del onboarding y afecta a todos los restores, así que no es un `if` suelto.
- O, más acotado: que el plan mire `primaryCurrencyCode` **solo si el resumen trajo algo con
  divisa** (cuentas o movimientos).

El valor que hoy se fija en silencio es el de las propias preferencias de la persona, así que el
daño es pequeño; lo que no es correcto es dejar de preguntar por un restore que no trajo nada de
eso.

## Relación con otros tickets

- `restore-treats-budgets-and-groups-as-no-data` — de donde sale.

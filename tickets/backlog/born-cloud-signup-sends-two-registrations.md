---
id: born-cloud-signup-sends-two-registrations
status: backlog
priority: low
area: telemetry
created: 2026-11-06
updated: 2026-11-06
source: encargo 2026-11-06-telemetria-propia-construccion (hallazgo de camino)
---

# Un alta con cuenta en la nube manda dos avisos de alta

## Qué pasa

Medido el 2026-11-06 leyendo el código: el alta «Tu cuenta en la nube» manda `register cloud bornCloud`
(`BornCloudSignUpService`, al crearse la cuenta) y, al terminar el onboarding que viene después, `register local
initial` (`OnboardingView.completeOnboarding`). Cualquiera que cuente avisos de alta cuenta esa persona dos veces y la
cuenta también como «sin cuenta». La propuesta de noviembre lo hizo así («8 altas en 7 días, 5 locales y 3 nube»).

## Qué se hizo ya

El panel (`panel/src/summarize.ts`, `signupsByInstall`) cuenta altas por PERSONA: la primera vez que una instalación
aparece con un alta, y en la nube si tiene un `cloud|bornCloud`. Quien consulte Analytics Engine a mano con el SQL de
`qa/cloud/README.md` sigue viendo los dos avisos.

## Qué falta decidir

Si la app debe mandar un solo aviso (cambia la serie histórica de `register`) o si basta con que el panel lo cuente
bien y el README lo avise. Recomendación: dejar la app como está y añadir la nota al SQL de referencia.
